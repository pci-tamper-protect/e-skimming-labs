# Traefik Labels on Cloud Run Services

This document explains how to use Traefik labels on Cloud Run services to simplify routing configuration, similar to how docker-compose.yml uses labels.

## Overview

Instead of hardcoding routes in `entrypoint.sh` and `routes.yml`, we can:
1. Add Traefik labels to Cloud Run services during deployment
2. Generate `routes.yml` from those labels at runtime
3. Simplify `entrypoint.sh` to just call the label reader

## Label Format

Traefik labels follow the same format as docker-compose.yml:

```bash
--labels="traefik.enable=true,\
traefik.http.routers.<router-name>.rule=PathPrefix(\`/path\`),\
traefik.http.routers.<router-name>.priority=100,\
traefik.http.routers.<router-name>.entrypoints=web,\
traefik.http.routers.<router-name>.middlewares=middleware1@file,middleware2@file,\
traefik.http.services.<service-name>.loadbalancer.server.port=8080"
```

## Example: Home Index Service

```bash
gcloud run deploy home-index-stg \
  --image=... \
  --labels="environment=stg,component=index,project=e-skimming-labs-home,\
traefik.enable=true,\
traefik.http.routers.home-index.rule=PathPrefix(\`/\`),\
traefik.http.routers.home-index.priority=1,\
traefik.http.routers.home-index.entrypoints=web,\
traefik.http.routers.home-index.middlewares=forwarded-headers@file,\
traefik.http.services.home-index.loadbalancer.server.port=8080,\
traefik.http.routers.home-index-signin.rule=Path(\`/sign-in\`) || Path(\`/sign-up\`),\
traefik.http.routers.home-index-signin.priority=100,\
traefik.http.routers.home-index-signin.entrypoints=web,\
traefik.http.routers.home-index-signin.middlewares=signin-headers@file,\
traefik.http.routers.home-index-signin.service=home-index"
```

## Example: Lab Service

```bash
gcloud run deploy lab-01-basic-magecart-stg \
  --image=... \
  --labels="environment=stg,lab=01-basic-magecart,project=e-skimming-labs,\
traefik.enable=true,\
traefik.http.routers.lab1-static.rule=PathPrefix(\`/lab1/css/\`) || PathPrefix(\`/lab1/js/\`) || PathPrefix(\`/lab1/images/\`),\
traefik.http.routers.lab1-static.priority=250,\
traefik.http.routers.lab1-static.entrypoints=web,\
traefik.http.routers.lab1-static.middlewares=strip-lab1-prefix@file,\
traefik.http.routers.lab1-static.service=lab1,\
traefik.http.routers.lab1.rule=PathPrefix(\`/lab1\`),\
traefik.http.routers.lab1.priority=200,\
traefik.http.routers.lab1.entrypoints=web,\
traefik.http.routers.lab1.middlewares=lab1-auth-check@file,strip-lab1-prefix@file,\
traefik.http.services.lab1.loadbalancer.server.port=8080"
```

## Generating Routes from Labels

The `generate-routes-from-labels.sh` script queries Cloud Run services and generates `routes.yml`:

```bash
./deploy/traefik/generate-routes-from-labels.sh
```

This script:
1. Queries all Cloud Run services in both projects
2. Extracts Traefik labels from service labels
3. Generates router and service definitions
4. Adds identity token auth middlewares automatically
5. Outputs to `/etc/traefik/dynamic/routes.yml`

## Benefits

1. **Single source of truth**: Routing config lives with the service
2. **Simpler entrypoint.sh**: Just calls the label reader script
3. **Consistent with docker-compose**: Same label format everywhere
4. **Easier maintenance**: Update labels when deploying, not in separate config files

## Migration Path

1. Add Traefik labels to all Cloud Run service deployments
2. Update `entrypoint.sh` to call `generate-routes-from-labels.sh`
3. Simplify `routes.yml` to only contain middlewares (no routers/services)
4. Remove hardcoded routes from `entrypoint.sh`
