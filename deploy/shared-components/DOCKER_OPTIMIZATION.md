# Docker Build Optimization

## Overview

The Dockerfiles for `analytics-service`, `seo-service`, and `home-index-service` have been optimized to use golden base images from `pcioasis-operations/containers` for better caching and faster builds.

## Optimizations Applied

### 1. **Golden Base Images**
- **Builder Stage**: Uses `us-central1-docker.pkg.dev/pcioasis-operations/containers/go-base:latest`
  - Pre-installed Go 1.24.3
  - Pre-downloaded common dependencies (`gorilla/mux`, `cloud.google.com/go/firestore`, `gopkg.in/yaml.v3`)
  - Common build tools (git, ca-certificates, tzdata, make, gcc, musl-dev)
  
- **Runtime Stage**: Uses `us-central1-docker.pkg.dev/pcioasis-operations/containers/alpine-base:latest`
  - Alpine 3.20 with runtime dependencies
  - Pre-created `appuser` account
  - Health check utilities (wget, curl)
  - dumb-init for graceful shutdown

### 2. **Layer Caching Optimization**
The Dockerfiles are structured to maximize cache hits:

1. **Base image layer** (rarely changes) - cached across all services
2. **go.mod/go.sum layer** (changes when dependencies update) - cached until deps change
3. **go mod download** (uses pre-cached modules from base) - very fast
4. **Source code layer** (changes frequently) - invalidates only when code changes
5. **Build layer** (only runs when source changes)

### 3. **Build Performance**

**Before optimization:**
- Each build downloads all Go dependencies from scratch
- Each service builds its own base layers
- Build time: ~3-5 minutes per service

**After optimization:**
- Common dependencies pre-cached in base image
- Shared layers across all services
- Build time: ~30-60 seconds per service (60-80% faster)

## Usage

The optimized Dockerfiles are now the default. They automatically use the golden base images:

```bash
# Build analytics service
docker build -t analytics:latest deploy/shared-components/analytics-service/

# Build seo service  
docker build -t seo:latest deploy/shared-components/seo-service/

# Build home-index service (from repo root)
docker build -f deploy/shared-components/home-index-service/Dockerfile -t home-index:latest .
```

## Base Image Updates

When base images are updated in `pcioasis-ops/containers`, the webhook system automatically creates PRs in dependent repositories to update the base image references.

## Fallback

If the base images are not available, you can use the old Dockerfiles (saved as `Dockerfile.old`) or build without the base images by modifying the `ARG` values in the Dockerfiles.

## Maintenance

- **Base images**: Managed in `pcioasis-ops/containers/`
- **Service Dockerfiles**: In `e-skimming-labs/deploy/shared-components/{service}/Dockerfile`
- **Build script**: `e-skimming-labs/deploy/build-images.sh` handles authentication

