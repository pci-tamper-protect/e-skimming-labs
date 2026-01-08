# Traefik Labels Implementation Guide

## Overview

This document explains how to add Traefik routing labels to Cloud Run services to simplify Traefik configuration, matching the docker-compose.yml approach.

## Benefits

1. **Single source of truth**: Routing config lives with the service deployment
2. **Simpler entrypoint.sh**: No need to hardcode routes
3. **Simpler routes.yml**: Only contains middlewares, not routers/services
4. **Consistent with docker-compose**: Same label format everywhere

## How It Works

1. **Add Traefik labels** to Cloud Run services during deployment
2. **Traefik entrypoint.sh** calls `generate-routes-from-labels.sh`
3. **Script queries** Cloud Run services and extracts Traefik labels
4. **Generates routes.yml** with routers and services automatically
5. **Falls back** to environment variable-based generation if labels not found

## Label Format

Labels follow the same format as docker-compose.yml:

```bash
--labels="traefik.enable=true,\
traefik.http.routers.<router-name>.rule=PathPrefix(\`/path\`),\
traefik.http.routers.<router-name>.priority=100,\
traefik.http.routers.<router-name>.entrypoints=web,\
traefik.http.routers.<router-name>.middlewares=middleware1@file,middleware2@file,\
traefik.http.services.<service-name>.loadbalancer.server.port=8080"
```

## Service Examples

### Home Index Service

```bash
--labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs-home,\
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

### SEO Service

```bash
--labels="environment=${ENVIRONMENT},component=seo,project=e-skimming-labs-home,\
traefik.enable=true,\
traefik.http.routers.home-seo.rule=PathPrefix(\`/api/seo\`),\
traefik.http.routers.home-seo.priority=500,\
traefik.http.routers.home-seo.entrypoints=web,\
traefik.http.routers.home-seo.middlewares=strip-seo-prefix@file,\
traefik.http.services.home-seo.loadbalancer.server.port=8080"
```

### Analytics Service

```bash
--labels="environment=${ENVIRONMENT},component=analytics,project=e-skimming-labs,\
traefik.enable=true,\
traefik.http.routers.labs-analytics.rule=PathPrefix(\`/api/analytics\`),\
traefik.http.routers.labs-analytics.priority=500,\
traefik.http.routers.labs-analytics.entrypoints=web,\
traefik.http.routers.labs-analytics.middlewares=strip-analytics-prefix@file,\
traefik.http.services.labs-analytics.loadbalancer.server.port=8080"
```

### Lab Service (Lab 1 Example)

```bash
--labels="environment=${ENVIRONMENT},lab=01-basic-magecart,project=e-skimming-labs,\
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

## Implementation Status

### ✅ Completed
- Created `generate-routes-from-labels.sh` script
- Updated `entrypoint.sh` to use label-based generation
- Updated `Dockerfile.cloudrun` to include script and jq
- Added Traefik labels to home-index service (staging)
- Simplified `routes.yml` documentation

### ✅ Completed
- Added Traefik labels to all services:
  - [x] home-index (staging & production)
  - [x] home-seo (staging & production)
  - [x] labs-analytics (staging & production)
  - [x] lab-01, lab-02, lab-03 (staging & production)
  - [x] Note: C2 servers are built into lab services (not separate deployments)

### 📝 Next Steps
1. Add labels to all service deployments in `.github/workflows/deploy_labs.yml`
2. Test label-based generation in staging
3. Remove hardcoded routes from `entrypoint.sh` once labels are verified
4. Update documentation

## Testing

To test label-based generation:

```bash
# In Traefik container or Cloud Run service
/app/generate-routes-from-labels.sh /tmp/test-routes.yml

# Check output
cat /tmp/test-routes.yml
```

## Fallback Behavior

If label-based generation fails or finds no services with `traefik.enable=true`, the entrypoint falls back to the existing environment variable-based generation. This ensures backward compatibility.
