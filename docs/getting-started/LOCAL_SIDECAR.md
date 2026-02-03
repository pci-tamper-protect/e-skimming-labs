# Local Sidecar Simulation

**Recommended for development and testing.**

This mode runs Traefik locally and proxies requests to remote Cloud Run services. It provides instant feedback without deploying changes.

## When to Use

- Day-to-day development
- Testing routing changes
- Debugging service issues
- Fast iteration without deployment

## Prerequisites

1. **Docker** installed and running

2. **Google Cloud CLI** authenticated:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

3. **Service Account Impersonation** (one-time setup):
   ```bash
   # Replace YOUR_EMAIL with your Google account email
   gcloud projects add-iam-policy-binding labs-stg \
     --member="user:YOUR_EMAIL" \
     --role="roles/iam.serviceAccountTokenCreator" \
     --condition=None
   ```

## Quick Start

```bash
cd e-skimming-labs

# Start the sidecar simulation
docker compose -f docker-compose.sidecar-local.yml up -d

# Open your browser
open http://localhost:9090
```

## Access Points

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

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Local Docker Compose                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Traefik Gateway │  │ Provider Sidecar│                  │
│  │ (port 9090)     │  │ (polls Cloud    │                  │
│  │                 │  │  Run API)       │                  │
│  └────────┬────────┘  └────────┬────────┘                  │
│           │                    │                            │
│           └────────┬───────────┘                            │
│                    │                                        │
│           ┌────────▼────────┐                              │
│           │ Shared Volume   │                              │
│           │ (routes.yml)    │                              │
│           └─────────────────┘                              │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼ (proxies to)
┌─────────────────────────────────────────────────────────────┐
│                   Cloud Run Services                         │
│  home-index-stg, lab-01-basic-magecart-stg, etc.           │
└─────────────────────────────────────────────────────────────┘
```

## Common Commands

```bash
# View all logs
docker compose -f docker-compose.sidecar-local.yml logs -f

# View provider logs (route generation)
docker compose -f docker-compose.sidecar-local.yml logs -f provider

# View Traefik logs
docker compose -f docker-compose.sidecar-local.yml logs -f traefik

# Restart provider (refresh tokens)
docker compose -f docker-compose.sidecar-local.yml restart provider

# Restart everything
docker compose -f docker-compose.sidecar-local.yml restart

# Stop
docker compose -f docker-compose.sidecar-local.yml down

# Stop and remove volumes
docker compose -f docker-compose.sidecar-local.yml down -v
```

## Token Refresh

The provider automatically refreshes identity tokens every 25 minutes. If you get 401 errors, restart the provider:

```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

## Troubleshooting

### Lab shows home page instead of lab content

**This is the most common issue and usually means expired credentials.**

When ADC expires, the provider can't fetch identity tokens, causing lab routes to fail authentication. Traefik falls back to the home-index route (lowest priority), so you see the home page at `/lab1`.

**Fix:**
```bash
# Refresh credentials
gcloud auth application-default login

# Restart provider
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### 401 Unauthorized

Tokens have expired. First check if ADC is valid:
```bash
gcloud auth application-default print-access-token
```

If that fails, refresh ADC:
```bash
gcloud auth application-default login
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### "invalid_grant" / "reauth related error"

Your gcloud credentials expired:
```bash
gcloud auth application-default login
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### Lab shows C2 content at root

The deployed service has a port conflict. Redeploy:
```bash
./deploy/deploy-labs.sh stg 02 --force-rebuild
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### No routes generated

Check provider logs for errors:
```bash
docker compose -f docker-compose.sidecar-local.yml logs provider
```

Look for:
- "invalid_grant" - ADC expired
- "Failed to list services" - permission issue
- "Failed to get identity token" - token generation failed

## Configuration

Environment variables (set in `.env` or export):

| Variable | Default | Description |
|----------|---------|-------------|
| `ENVIRONMENT` | `stg` | Environment (stg/prd) |
| `LABS_PROJECT_ID` | `labs-stg` | Labs GCP project |
| `HOME_PROJECT_ID` | `labs-home-stg` | Home services GCP project |
| `REGION` | `us-central1` | GCP region |
| `POLL_INTERVAL` | `30s` | How often to poll Cloud Run API |
| `TOKEN_CACHE_DURATION` | `25m` | How long to cache identity tokens |

## Next Steps

- [Testing locally](../testing/LOCAL_TESTING.md)
- [Deploying changes](../deployment/README.md)
- [Troubleshooting](../troubleshooting/README.md)
