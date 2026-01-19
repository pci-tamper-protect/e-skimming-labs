# Getting Started with E-Skimming Labs

This guide covers the three main ways to run and deploy E-Skimming Labs.

## Architecture Overview

**Key Principle**: Services use **relative URLs only**. All routing is handled by Traefik.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Traefik Gateway                          │
│                    (Port 9090 local, 8080 Cloud Run)            │
├─────────────────────────────────────────────────────────────────┤
│  /           → home-index-stg     (labs home page)              │
│  /lab1       → lab-01-basic-magecart-stg                        │
│  /lab1/c2    → lab1-c2-stg        (C2 dashboard)                │
│  /lab2       → lab-02-dom-skimming-stg                          │
│  /lab2/c2    → lab2-c2-stg        (C2 dashboard)                │
│  /lab3       → lab-03-extension-hijacking-stg                   │
│  /lab3/extension → lab3-extension-stg (extension server)        │
│  /mitre-attack → home-index-stg   (MITRE ATT&CK matrix)         │
│  /api/seo    → home-seo-stg       (SEO service)                 │
│  /api/analytics → labs-analytics-stg                            │
└─────────────────────────────────────────────────────────────────┘
```

## Port Configuration

| Environment | Gateway Port | Dashboard Port | Notes |
|-------------|--------------|----------------|-------|
| Local Sidecar | 9090 | 9091 | Via docker-compose.sidecar-local.yml |
| Cloud Run | 8080 | 8080 | Each service on its own URL |
| Legacy Local | 8080 | 8081 | Via docker-compose.yml |

---

## Option 1: Local Sidecar Simulation (Recommended for Development)

This simulates the Cloud Run sidecar architecture locally, proxying to remote Cloud Run services.

### Prerequisites

1. **Google Cloud CLI** authenticated:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Service Account Impersonation** (one-time setup):
   ```bash
   # Grant yourself permission to impersonate the Traefik service account
   # Replace YOUR_EMAIL with your Google account email
   gcloud projects add-iam-policy-binding labs-stg \
     --member="user:YOUR_EMAIL" \
     --role="roles/iam.serviceAccountTokenCreator" \
     --condition=None
   ```

3. **Docker** installed and running

### Quick Start

```bash
cd e-skimming-labs

# Start the local sidecar simulation
docker compose -f docker-compose.sidecar-local.yml up -d

# View logs
docker compose -f docker-compose.sidecar-local.yml logs -f

# Access the labs
open http://localhost:9090
```

### Access Points

| URL | Description |
|-----|-------------|
| http://localhost:9090 | Labs home page |
| http://localhost:9090/lab1 | Lab 1: Basic Magecart |
| http://localhost:9090/lab2 | Lab 2: DOM Skimming |
| http://localhost:9090/lab3 | Lab 3: Extension Hijacking |
| http://localhost:9090/lab1/c2 | Lab 1 C2 Dashboard |
| http://localhost:9090/lab2/c2 | Lab 2 C2 Dashboard |
| http://localhost:9090/lab3/extension | Lab 3 Extension Server |
| http://localhost:9090/mitre-attack | MITRE ATT&CK Matrix |
| http://localhost:9091/dashboard/ | Traefik Dashboard |

### Common Commands

```bash
# Restart provider (refresh tokens - do this if you get 401 errors)
docker compose -f docker-compose.sidecar-local.yml restart provider

# Restart everything
docker compose -f docker-compose.sidecar-local.yml restart

# Stop
docker compose -f docker-compose.sidecar-local.yml down

# View provider logs (route generation)
docker compose -f docker-compose.sidecar-local.yml logs -f provider

# View Traefik logs
docker compose -f docker-compose.sidecar-local.yml logs -f traefik
```

### Troubleshooting

**401 Unauthorized errors**: Tokens have expired. Restart the provider:
```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

**"invalid_grant" / "reauth related error"**: Your gcloud credentials expired:
```bash
gcloud auth application-default login
docker compose -f docker-compose.sidecar-local.yml restart provider
```

**Lab shows wrong content (e.g., C2 at /lab2 instead of main page)**: The service needs redeployment. See Option 3 below.

---

## Option 2: Direct Cloud Run Access (Staging/Production)

Access the deployed services directly via their Cloud Run URLs or custom domain.

### Staging URLs

| URL | Description |
|-----|-------------|
| https://labs.stg.pcioasis.com | Labs home (via Traefik) |
| https://labs.stg.pcioasis.com/lab1 | Lab 1 |
| https://labs.stg.pcioasis.com/lab2 | Lab 2 |
| https://labs.stg.pcioasis.com/lab3 | Lab 3 |

### Direct Service URLs (for debugging)

```bash
# Get service URLs
gcloud run services list --project=labs-stg --region=us-central1

# Example direct access (requires authentication)
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" https://home-index-stg-xxx.run.app/
```

---

## Option 3: Deploy Services to Cloud Run

### Deploy All Services (Staging)

```bash
cd e-skimming-labs

# Deploy everything
./deploy/deploy-all-stg.sh
```

### Deploy Specific Components

**Home Services** (home-index, home-seo):
```bash
./deploy/deploy-home.sh stg
./deploy/deploy-home.sh stg --force-rebuild  # Force rebuild
```

**Lab Services** (analytics, lab1, lab2, lab3):
```bash
# Deploy all labs
./deploy/deploy-labs.sh stg all

# Deploy specific lab
./deploy/deploy-labs.sh stg 01  # Lab 1
./deploy/deploy-labs.sh stg 02  # Lab 2
./deploy/deploy-labs.sh stg 03  # Lab 3

# Force rebuild
./deploy/deploy-labs.sh stg 02 --force-rebuild
```

**Traefik Gateway** (sidecar architecture):
```bash
./deploy/traefik/deploy-sidecar.sh stg
```

### After Deploying

After deploying changes, restart the local provider to pick up new routes:
```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

---

## Service Architecture

### Multi-Process Containers (Labs with C2)

Labs 1, 2, and 3 run **two processes** in a single container:
- **Nginx** on port 8080 (Cloud Run's PORT) - serves the vulnerable site
- **Node.js C2 server** on port 3000 - handles C2 API requests

Nginx proxies `/c2` or `/extension` requests to the Node.js server.

```
┌─────────────────────────────────────────┐
│         Lab Container (e.g., lab2)      │
├─────────────────────────────────────────┤
│  Nginx (port 8080)                      │
│    /          → vulnerable site HTML    │
│    /c2/*      → proxy to localhost:3000 │
├─────────────────────────────────────────┤
│  Node.js C2 (port 3000)                 │
│    /          → C2 dashboard            │
│    /api/*     → C2 API endpoints        │
└─────────────────────────────────────────┘
```

### Standalone C2 Services

Each lab also has a **standalone C2 service** (e.g., `lab2-c2-stg`) that runs just the Node.js server on port 8080. These are used for direct C2 access via Traefik routing.

**Important**: The standalone C2 services use `C2_STANDALONE=true` environment variable to bind to port 8080 instead of 3000.

---

## Routing Architecture Principle

**CRITICAL**: Services must NOT contain routing logic. All routing belongs to Traefik.

### DO
- Use relative URLs: `/lab1`, `/lab2/c2`, `/mitre-attack`
- Let Traefik handle path-based routing
- Keep services simple and stateless

### DON'T
- Detect environment (localhost vs staging vs production)
- Generate absolute URLs based on hostname
- Check `X-Forwarded-Host` for routing decisions
- Hardcode ports like `localhost:8080`

See [ROUTING_ARCHITECTURE.md](../ROUTING_ARCHITECTURE.md) for details.

---

## Environment Variables

### Required for Local Sidecar

Set in `.env` or export:
```bash
ENVIRONMENT=stg
LABS_PROJECT_ID=labs-stg
HOME_PROJECT_ID=labs-home-stg
REGION=us-central1
```

### Token Refresh

The provider caches identity tokens for 25 minutes by default. Tokens are automatically refreshed on each poll (every 30 seconds).

```bash
# Override token cache duration (optional)
TOKEN_CACHE_DURATION=25m

# Override poll interval (optional)
POLL_INTERVAL=30s
```

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `deploy/deploy-all-stg.sh` | Deploy all services to staging |
| `deploy/deploy-home.sh stg` | Deploy home services only |
| `deploy/deploy-labs.sh stg [01\|02\|03\|all]` | Deploy lab services |
| `deploy/traefik/deploy-sidecar.sh stg` | Deploy Traefik gateway |
| `deploy/build-images.sh` | Build all Docker images |
| `deploy/load-env.sh` | Load environment variables (sourced by other scripts) |

### Terraform Scripts (Infrastructure)

| Script | Purpose |
|--------|---------|
| `deploy/deploy-tf.sh` | Main Terraform deployment |
| `deploy/deploy-home-tf.sh` | Terraform for home services |
| `deploy/deploy-labs-tf.sh` | Terraform for lab services |

---

## Next Steps

1. **Start locally**: Use Option 1 to run the sidecar simulation
2. **Explore labs**: Visit http://localhost:9090 and try each lab
3. **Make changes**: Edit code, rebuild, and redeploy
4. **Debug**: Check Traefik dashboard at http://localhost:9091/dashboard/

For more details:
- [ROUTING_ARCHITECTURE.md](../ROUTING_ARCHITECTURE.md) - Routing principles
- [deploy/traefik/TESTING.md](../deploy/traefik/TESTING.md) - Testing guide
- [deploy/traefik/SIDECAR_ARCHITECTURE.md](../deploy/traefik/SIDECAR_ARCHITECTURE.md) - Sidecar details
