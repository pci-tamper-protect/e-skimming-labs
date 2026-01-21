# Getting Started

Choose the mode that best fits your use case.

## Quick Decision Guide

| I want to... | Use |
|--------------|-----|
| Develop and test quickly | [Local Sidecar](./LOCAL_SIDECAR.md) |
| Work offline | [Local Docker](./LOCAL_DOCKER.md) |
| Access staging/production | [Cloud Run](./CLOUD_RUN.md) |

## Modes Overview

### 1. Local Sidecar Simulation (Recommended)

**Best for:** Day-to-day development

Runs Traefik locally and proxies to remote Cloud Run services. Provides instant feedback without deploying.

```bash
docker compose -f docker-compose.sidecar-local.yml up -d
open http://localhost:9090
```

[Full Guide →](./LOCAL_SIDECAR.md)

### 2. Local Docker Compose (Legacy)

**Best for:** Offline development, modifying service code

Runs all services locally in Docker containers.

```bash
docker-compose up -d
open http://localhost:8080
```

[Full Guide →](./LOCAL_DOCKER.md)

### 3. Cloud Run Access

**Best for:** Testing deployed services, demos

Access deployed services directly via Traefik gateway.

```bash
# Staging (via proxy)
gcloud run services proxy traefik-stg --region=us-central1 --project=labs-stg --port=8082
open http://127.0.0.1:8082

# Production
open https://labs.pcioasis.com
```

[Full Guide →](./CLOUD_RUN.md)

## Port Summary

| Mode | Gateway | Dashboard |
|------|---------|-----------|
| Local Sidecar | 9090 | 9091 |
| Local Docker | 8080 | 8081 |
| Cloud Run Proxy | 8082 | N/A |

## Prerequisites

All modes require:
- Docker installed and running

Sidecar and Cloud Run modes also require:
- Google Cloud CLI (`gcloud`)
- Authenticated: `gcloud auth login`

## Next Steps

After getting started:
- [Deploy changes](../deployment/README.md)
- [Run tests](../testing/README.md)
- [Understand the architecture](../architecture/ROUTING.md)
