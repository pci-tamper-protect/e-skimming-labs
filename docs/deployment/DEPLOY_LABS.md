# Deploy Lab Services

Deploys lab services to Cloud Run using gcloud commands.

## Services Deployed

| Lab | Main Service | C2 Service |
|-----|--------------|------------|
| 01 | `lab-01-basic-magecart-stg` | `lab1-c2-stg` |
| 02 | `lab-02-dom-skimming-stg` | `lab2-c2-stg` |
| 03 | `lab-03-extension-hijacking-stg` | `lab3-extension-stg` |

Also deploys: `labs-analytics-stg`

## Usage

```bash
./deploy/deploy-labs.sh [stg|prd] [01|02|03|all] [image-tag] [--force-rebuild]
```

### Examples

```bash
# Deploy all labs to staging
./deploy/deploy-labs.sh stg all

# Deploy specific lab
./deploy/deploy-labs.sh stg 01  # Lab 1
./deploy/deploy-labs.sh stg 02  # Lab 2
./deploy/deploy-labs.sh stg 03  # Lab 3

# Force rebuild (no Docker cache)
./deploy/deploy-labs.sh stg 02 --force-rebuild

# With custom image tag
./deploy/deploy-labs.sh stg all abc123

# Deploy to production
./deploy/deploy-labs.sh prd all
```

## What Gets Deployed

### Lab 1: Basic Magecart

- **Main service** (`lab-01-basic-magecart-stg`): Vulnerable e-commerce site
- **C2 service** (`lab1-c2-stg`): Command and control dashboard

### Lab 2: DOM Skimming

- **Main service** (`lab-02-dom-skimming-stg`): Banking site with DOM-based attack
- **C2 service** (`lab2-c2-stg`): Data collection dashboard

### Lab 3: Extension Hijacking

- **Main service** (`lab-03-extension-hijacking-stg`): Site vulnerable to extension attacks
- **Extension service** (`lab3-extension-stg`): Extension data server

### Analytics

- **Analytics service** (`labs-analytics-stg`): Shared analytics for all labs

## Multi-Process Containers

Labs 1, 2, and 3 run **two processes** in a single container:

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

**Important:** The C2 server must use port 3000, not 8080. The `init.sh` script handles this.

## After Deploying

Restart the local provider to pick up new routes:

```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

## Troubleshooting

### Service shows C2 content at root path

The C2 server is binding to port 8080 instead of 3000. Check `init.sh`:

```bash
# Correct: C2 on port 3000
C2_PORT=3000
cd /app/c2-server && PORT=$C2_PORT node c2-server.js &

# Wrong: C2 using Cloud Run's PORT
cd /app/c2-server && node c2-server.js &  # Will use PORT=8080
```

### Build uses cached layers

Use `--force-rebuild` or manually build with `--no-cache`:

```bash
cd labs/02-dom-skimming
docker build --no-cache -t image:tag .
```

### Service not starting

Check Cloud Run logs:

```bash
gcloud run services logs read lab-02-dom-skimming-stg \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

## Manual Deployment

If the script fails, deploy manually:

```bash
# Build
cd labs/02-dom-skimming
docker build -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/lab2:latest .

# Push
docker push us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/lab2:latest

# Deploy
gcloud run deploy lab-02-dom-skimming-stg \
  --image=us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/lab2:latest \
  --project=labs-stg \
  --region=us-central1 \
  --no-allow-unauthenticated
```
