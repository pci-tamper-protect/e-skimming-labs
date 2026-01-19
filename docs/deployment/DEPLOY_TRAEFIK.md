# Deploy Traefik Gateway

Deploys the Traefik gateway with provider sidecar to Cloud Run.

## Services Deployed

| Service | Description |
|---------|-------------|
| `traefik-stg` | Main gateway with provider sidecar |
| `traefik-dashboard-stg` | Dashboard service |

## Usage

```bash
./deploy/traefik/deploy-sidecar.sh [stg|prd]
```

### Examples

```bash
# Deploy to staging
./deploy/traefik/deploy-sidecar.sh stg

# Deploy to production
./deploy/traefik/deploy-sidecar.sh prd
```

## Architecture

The Traefik deployment uses a sidecar architecture on Cloud Run:

```
┌─────────────────────────────────────────────────────────────┐
│              Cloud Run Service: traefik-stg                  │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  Main Traefik     │  │  Provider Sidecar │                │
│  │  (port 8080)      │  │  (no port)        │                │
│  │                   │  │                   │                │
│  │  - Routes traffic │  │  - Polls Cloud    │                │
│  │  - Reads routes   │  │    Run API        │                │
│  │    from volume    │  │  - Generates      │                │
│  │                   │  │    routes.yml     │                │
│  └────────┬─────────┘  └────────┬──────────┘                │
│           │                     │                            │
│           └──────────┬───────────┘                           │
│                      │                                       │
│              ┌───────▼────────┐                             │
│              │ Shared Volume  │                             │
│              │ (routes.yml)   │                             │
│              └────────────────┘                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│          Cloud Run Service: traefik-dashboard-stg           │
├─────────────────────────────────────────────────────────────┤
│  │ Dashboard UI + API proxy to main Traefik                │
└─────────────────────────────────────────────────────────────┘
```

## Components

### Main Traefik Container

- Routes web traffic to backend Cloud Run services
- Reads dynamic routes from shared volume
- Listens on port 8080

### Provider Sidecar

- Polls Cloud Run API for services with Traefik labels
- Generates `routes.yml` with routers, services, and middlewares
- Fetches identity tokens for authenticated requests
- Writes to shared volume

### Dashboard Service

- Serves Traefik dashboard UI
- Proxies API requests to main Traefik service

## Source Locations

| Component | Source |
|-----------|--------|
| Main Traefik | `deploy/traefik/Dockerfile.cloudrun.sidecar` |
| Provider | `../traefik-cloudrun-provider/` |
| Dashboard | `deploy/traefik/Dockerfile.dashboard-sidecar` |

## After Deploying

The provider automatically discovers services with Traefik labels. No additional configuration needed.

To verify:

```bash
# Check service status
gcloud run services describe traefik-stg \
  --project=labs-stg \
  --region=us-central1 \
  --format="value(status.latestReadyRevisionName)"

# Check logs
gcloud run services logs read traefik-stg \
  --project=labs-stg \
  --region=us-central1 \
  --container=provider \
  --limit=50
```

## Troubleshooting

### Provider not generating routes

Check provider logs:

```bash
gcloud run services logs read traefik-stg \
  --project=labs-stg \
  --region=us-central1 \
  --container=provider \
  --limit=50
```

### Startup probe failures

Check main Traefik logs:

```bash
gcloud run services logs read traefik-stg \
  --project=labs-stg \
  --region=us-central1 \
  --container=traefik \
  --limit=50
```

### Port binding errors

Traefik must listen on port 8080 (Cloud Run requirement). Check the entrypoint script.

### Dashboard not accessible

Check dashboard service logs:

```bash
gcloud run services logs read traefik-dashboard-stg \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

## Manual Deployment

If the script fails, see the YAML files:

- `deploy/traefik/cloudrun-sidecar.yaml` - Main service
- `deploy/traefik/traefik-dashboard-sidecar.yaml` - Dashboard service

Deploy with:

```bash
gcloud run services replace deploy/traefik/cloudrun-sidecar.yaml \
  --project=labs-stg \
  --region=us-central1
```
