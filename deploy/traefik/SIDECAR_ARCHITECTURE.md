# Traefik Sidecar Architecture for Cloud Run

## Local Simulation

For fast local debugging (logs appear instantly instead of waiting 5 minutes for Cloud Logging), use the local sidecar simulation:

```bash
# Start local simulation
docker-compose -f docker-compose.sidecar-local.yml up -d

# View logs
docker-compose -f docker-compose.sidecar-local.yml logs -f

# Run tests
./deploy/traefik/test-sidecar-local.sh
```

See [TESTING.md](./TESTING.md#local-sidecar-simulation-fast-debugging) for detailed documentation.

---

## Architecture Decision: Sidecar vs Plugin

We originally implemented a Traefik **local plugin** using Yaegi (Traefik's Go interpreter).
This approach failed because Yaegi cannot interpret the GCP Go SDK — library conflicts
cause panics at runtime. The plugin source is retained in `plugins-local/` for reference,
but the **sidecar architecture is the active deployment mechanism**.

| Approach | Status | Why |
|----------|--------|-----|
| **Sidecar** (active) | Working in stg/prd | Provider runs as compiled Go binary, avoids Yaegi limitations |
| **Plugin** (legacy) | Kept for reference | Yaegi can't handle GCP SDK deps; may revisit if Yaegi improves |

The `plugins-local/vendor/` directory is gitignored (26MB of third-party deps).
Only our provider source code is tracked. If you need to restore vendor for plugin
mode, run `go mod vendor` inside the provider directory.

## Version Strategy

| Version | Status | Deploy Script | Use Case |
|---------|--------|---------------|----------|
| **v2.10** | Stable | `deploy-sidecar.sh` | Fallback if v3.0 has issues |
| **v3.0** | Default | `deploy.sh` / `deploy-sidecar-traefik-3.0.sh` | Active deployments |

`deploy.sh` is a wrapper that calls `deploy-sidecar-traefik-3.0.sh`.

## Overview

This document describes the sidecar-based architecture for deploying Traefik to Google Cloud Run. The architecture separates concerns into three containers:

1. **Main Traefik Container**: Serves web traffic and routes requests to backend services
2. **Provider Sidecar**: Generates `routes.yml` from Cloud Run service labels into a shared volume
3. **Dashboard Sidecar**: Serves the Traefik dashboard UI (separate service)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│              Cloud Run Service: traefik-stg            │
│                                                         │
│  ┌──────────────────┐  ┌──────────────────┐         │
│  │  Main Traefik     │  │  Provider Sidecar │         │
│  │  (port 8080)      │  │  (no port)        │         │
│  │                   │  │                   │         │
│  │  - Web traffic    │  │  - Polls Cloud    │         │
│  │  - Routes to      │  │    Run API        │         │
│  │    backends       │  │  - Generates      │         │
│  │  - Reads routes   │  │    routes.yml     │         │
│  │    from shared    │  │  - Writes to      │         │
│  │    volume         │  │    shared volume  │         │
│  └────────┬─────────┘  └────────┬──────────┘         │
│           │                     │                    │
│           └──────────┬───────────┘                    │
│                      │                                │
│              ┌───────▼────────┐                      │
│              │ Shared Volume  │                      │
│              │ (in-memory)    │                      │
│              │                │                      │
│              │ routes.yml     │                      │
│              └────────────────┘                      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│      Cloud Run Service: traefik-dashboard-stg          │
│                                                         │
│  ┌──────────────────┐                                 │
│  │ Dashboard Sidecar │                                 │
│  │ (port 8080)       │                                 │
│  │                   │                                 │
│  │  - Serves UI      │                                 │
│  │  - Proxies API    │                                 │
│  │    to main        │                                 │
│  │    Traefik        │                                 │
│  └───────────────────┘                                 │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. Main Traefik Container

**Purpose**: Routes web traffic to backend Cloud Run services

**Configuration**:
- Static config: `traefik.cloudrun.sidecar.yml`
- Reads dynamic routes from: `/shared/traefik/dynamic/routes.yml`
- Uses file provider (no plugin)
- API enabled for dashboard sidecar access
- Dashboard disabled (served by separate sidecar)

**Key Features**:
- Listens on port 8080 (Cloud Run requirement)
- Watches shared volume for route updates
- No plugin compilation needed (simpler, faster startup)

### 2. Provider Sidecar

**Purpose**: Generates `routes.yml` from Cloud Run service labels

**Configuration**:
- Runs in daemon mode (polls every 30s)
- Writes to: `/shared/traefik/dynamic/routes.yml`
- Reads from environment variables:
  - `LABS_PROJECT_ID` (required)
  - `HOME_PROJECT_ID` (optional)
  - `REGION` (default: us-central1)
  - `MODE` (default: daemon)
  - `POLL_INTERVAL` (default: 30s)
  - `USER_AUTH_ENABLED` (default: false) - See User Authentication below

**Key Features**:
- Standalone binary (no Traefik dependency)
- Automatic route regeneration on service changes
- Shared volume ensures main Traefik sees updates immediately
- Dynamic forwardAuth middleware generation for user JWT validation

### 3. Dashboard Service

**Purpose**: Serves Traefik dashboard UI

**Configuration**:
- Static config: `traefik.dashboard-sidecar.yml`
- Proxies API requests to main Traefik service via HTTP
- Serves dashboard UI on port 8080
- Main Traefik API URL provided via `TRAEFIK_API_URL` environment variable

**Key Features**:
- Separate Cloud Run service (not a sidecar - Cloud Run limitation)
- Accesses main Traefik API via HTTP (service-to-service)
- Dashboard accessible without affecting main service
- Entrypoint script generates dynamic routes to proxy API calls

## Shared Volumes

Cloud Run uses in-memory volumes to share data between sidecar containers. For detailed documentation, see: [Configure in-memory volume mounts for services](https://docs.cloud.google.com/run/docs/configuring/services/in-memory-volume-mounts)

### Volume: `shared-routes`
- **Type**: In-memory (emptyDir)
- **Size**: 10Mi
- **Mount Path**: `/shared/traefik/dynamic`
- **Purpose**: Share `routes.yml` between provider and main Traefik

### Volume: `shared-stats`
- **Type**: In-memory (emptyDir)
- **Size**: 50Mi
- **Mount Path**: `/shared/traefik/stats`
- **Purpose**: Share dashboard stats/data (if needed)

## Deployment

### Prerequisites

1. **Gen2 Execution Environment**: Required for sidecars and shared volumes
   - See: [Configure in-memory volume mounts for services](https://docs.cloud.google.com/run/docs/configuring/services/in-memory-volume-mounts)
2. **Service Account**: Must have permissions to:
   - Query Cloud Run services (`roles/run.viewer`)
   - Generate identity tokens (`roles/iam.serviceAccountTokenCreator`)

### Build Images

**Default (Traefik v2.10)**:
```bash
# Main Traefik (v2.10) - DEFAULT
cd deploy/traefik
docker build -f Dockerfile.cloudrun.sidecar -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:latest .

# Provider sidecar
cd ../../traefik-cloudrun-provider
docker build -f Dockerfile.provider.sidecar -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik-cloudrun-provider:latest .

# Dashboard sidecar (v2.10) - DEFAULT
cd ../e-skimming-labs/deploy/traefik
docker build -f Dockerfile.dashboard-sidecar -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik-dashboard:latest .
```

**Traefik v3.0** (latest features):
```bash
# Main Traefik (v3.0)
docker build -f Dockerfile.cloudrun.sidecar.traefik-3.0 -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:v3.0 .

# Dashboard sidecar (v3.0)
docker build -f Dockerfile.dashboard-sidecar.traefik-3.0 -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik-dashboard:v3.0 .
```

**Version Notes**:
- **Default is Traefik v3.0** via `deploy.sh` (wrapper for `deploy-sidecar-traefik-3.0.sh`)
- **Traefik v2.10** is available as fallback via `deploy-sidecar.sh`
- v3.0 images are tagged `:v3.0`, v2.10 images use `:latest`

### Deploy

```bash
# Default (Traefik v3.0 sidecar)
./deploy/traefik/deploy.sh stg

# Explicitly use v3.0
./deploy/traefik/deploy-sidecar-traefik-3.0.sh stg

# Fallback to v2.10
./deploy/traefik/deploy-sidecar.sh stg

# Or using YAML directly
gcloud run services replace cloudrun-sidecar.yaml \
  --region=us-central1 \
  --project=labs-stg
```

## Benefits

1. **Separation of Concerns**: Each container has a single responsibility
2. **No Plugin Compilation**: Main Traefik doesn't need Go or plugin source
3. **Faster Startup**: No plugin compilation overhead
4. **Easier Updates**: Provider can be updated independently
5. **Better Resource Management**: Each sidecar has dedicated resources

## Limitations

1. **Cloud Run Port Limitation**: Only one container's port 8080 can be exposed per service
   - **Solution**: Dashboard is a separate Cloud Run service
2. **Shared Volume Size**: In-memory volumes are limited by container memory
   - **Solution**: Use Cloud Storage volumes for larger data (if needed)
3. **Network Access**: Sidecars share network namespace but only one port is exposed
   - **Solution**: Dashboard sidecar proxies to main Traefik's API

## Troubleshooting

### Provider not generating routes

```bash
# Check provider logs
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=provider

# Verify shared volume mount
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="yaml(spec.template.spec.containers[1].volumeMounts)"
```

### Main Traefik not reading routes

```bash
# Check main Traefik logs
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=traefik

# Verify file provider is watching shared volume
# Look for: "file provider: watching directory /shared/traefik/dynamic"
```

### Dashboard not accessible

```bash
# Check dashboard service logs
gcloud run services logs read traefik-dashboard-stg \
  --region=us-central1 \
  --project=labs-stg

# Verify dashboard can reach main Traefik API
# Dashboard should proxy requests to main Traefik's /api/* endpoints
```

## Migration from Plugin Architecture

To migrate from the plugin-based architecture:

1. **Build new images**: Use sidecar Dockerfiles
2. **Update deployment**: Use `deploy-sidecar.sh` or `cloudrun-sidecar.yaml`
3. **Verify routes**: Check that `routes.yml` is generated correctly
4. **Test dashboard**: Verify dashboard is accessible
5. **Monitor**: Watch logs for any issues

## User Authentication

The `USER_AUTH_ENABLED` environment variable controls whether labs require user authentication:

| Environment | `USER_AUTH_ENABLED` | Behavior |
|-------------|---------------------|----------|
| Local (docker-compose.sidecar-local.yml) | `false` (default) | Labs are publicly accessible |
| Staging (cloudrun-sidecar.yaml) | `true` | Labs require Firebase JWT authentication |
| Production | `true` | Labs require Firebase JWT authentication |

### How It Works

When `USER_AUTH_ENABLED=true`:
1. Provider discovers the home-index Cloud Run URL during service discovery
2. Provider generates `lab1-auth-check`, `lab2-auth-check`, `lab3-auth-check` forwardAuth middlewares
3. These middlewares call `{home-index-url}/api/auth/check` for JWT validation
4. Lab routes include the auth-check middleware in their middleware chain

When `USER_AUTH_ENABLED=false` (or not set):
1. Provider skips auth-check middleware generation
2. Auth-check middlewares are filtered out of router configurations
3. Labs are publicly accessible (only Cloud Run IAM auth via service tokens)

### Public Routes (No Auth Required)

The following routes are always public regardless of `USER_AUTH_ENABLED`:
- `/` - Labs home page
- `/mitre-attack` - MITRE ATT&CK matrix
- `/threat-model` - Interactive threat model
- `/sign-in`, `/sign-up` - Authentication pages

### Testing Auth Locally

To test authentication flow locally:
```bash
# Start with auth enabled
USER_AUTH_ENABLED=true docker compose -f docker-compose.sidecar-local.yml up
```

Note: This requires the home-index service to be running with Firebase configured.

## Future Improvements

1. **Cloud Storage Volumes**: Use persistent storage for routes.yml (if needed)
2. **Eventarc Integration**: Use Cloud Run events instead of polling
3. **Metrics**: Add Prometheus metrics for provider performance
4. **Health Checks**: Improve health checks for all sidecars
