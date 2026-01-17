# Traefik Cloud Run Plugin Migration

## Overview

This document describes the migration from bash script-based route generation to a native Traefik plugin using local plugin mode.

## Changes Made

### 1. Plugin Implementation (`traefik-cloudrun-provider`)

- **Created**: `plugin/plugin.go` - Traefik plugin wrapper that implements:
  - `CreateConfig() *Config`
  - `New(ctx context.Context, config *Config, name string) (*PluginProvider, error)`
  - `Init() error`
  - `Provide(cfgChan chan<- json.Marshaler) error`
  - `Stop() error`

- **Dependencies**: Added `github.com/traefik/genconf/dynamic` for Traefik configuration types

### 2. Plugin Directory Structure

- **Created**: `plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider/`
- **Setup Script**: `setup-plugin.sh` - Copies plugin source from sibling directory

### 3. Traefik Configuration

**File**: `traefik.cloudrun.yml`

- **Added**: `experimental.localPlugins` section to load the plugin
- **Updated**: `providers.plugin.cloudrun` configuration
- **Kept**: `providers.file` for static middlewares (retry-cold-start, etc.)

### 4. Dockerfile Updates

**File**: `Dockerfile.cloudrun`

- **Added**: Copy `plugins-local/` directory to container
- **Removed**: Go binary build steps (no longer needed)
- **Simplified**: Entrypoint script (plugin handles route generation)

### 5. Entrypoint Script

**File**: `entrypoint-plugin.sh` (new simplified version)

- **Removed**: All route generation logic (handled by plugin)
- **Removed**: Identity token fetching (handled by plugin)
- **Kept**: Directory creation and environment variable validation

## How It Works

1. **Plugin Discovery**: Traefik loads the plugin from `/plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider`

2. **Service Discovery**: Plugin polls Cloud Run Admin API every 30s for services with `traefik_enable=true` label

3. **Token Management**: Plugin automatically fetches and caches GCP identity tokens for each service

4. **Route Generation**: Plugin generates Traefik dynamic configuration with:
   - Routers (from `traefik_http_routers_*` labels)
   - Services (from service URLs)
   - Middlewares (auth tokens, retry, etc.)

5. **Configuration Updates**: Plugin sends updates to Traefik via `cfgChan` whenever services change

## Environment Variables

The plugin reads configuration from environment variables:

- **Required**:
  - `LABS_PROJECT_ID` - Primary GCP project ID
  - `REGION` - GCP region (defaults to `us-central1`)

- **Optional**:
  - `HOME_PROJECT_ID` - Secondary GCP project ID
  - `LOG_LEVEL` - Logging level (DEBUG, INFO, WARN, ERROR)
  - `LOG_FORMAT` - Log format (text, json)

## Testing

### Local Testing

1. **Setup plugin**:
   ```bash
   cd e-skimming-labs
   ./deploy/traefik/setup-plugin.sh
   ```

2. **Build and test**:
   ```bash
   cd deploy/traefik
   docker build -f Dockerfile.cloudrun -t traefik-plugin-test .
   ```

3. **Run with docker-compose** (update docker-compose.yml to use new image)

### Cloud Run Testing

1. **Deploy Traefik**:
   ```bash
   gcloud run deploy traefik-stg \
     --source deploy/traefik \
     --region=us-central1 \
     --set-env-vars="LABS_PROJECT_ID=your-project-id,REGION=us-central1" \
     --no-allow-unauthenticated
   ```

2. **Verify plugin loads**:
   ```bash
   gcloud run services logs read traefik-stg --limit=50
   ```

3. **Check routes**:
   ```bash
   gcloud run services proxy traefik-stg --port=8082
   curl http://localhost:8082/dashboard/
   ```

## Service Labels

Services must have the following labels to be discovered:

- `traefik_enable=true` - Enables discovery
- `traefik_http_routers_<name>_rule_id=<rule-id>` - Router rule (or `rule` for custom)
- `traefik_http_routers_<name>_priority=<number>` - Router priority
- `traefik_http_routers_<name>_entrypoints=web` - Entry points
- `traefik_http_routers_<name>_middlewares=<middleware-list>` - Middlewares (use `-file` suffix for file provider middlewares)

Example:
```bash
gcloud run services update my-service \
  --update-labels="\
traefik_enable=true,\
traefik_http_routers_myapp_rule_id=home-index-root,\
traefik_http_routers_myapp_priority=200,\
traefik_http_routers_myapp_entrypoints=web,\
traefik_http_routers_myapp_middlewares=retry-cold-start-file"
```

## Benefits

1. **Dynamic Updates**: Routes update automatically when services change (no container restart needed)
2. **Better Token Management**: Automatic token fetching and caching with refresh
3. **Cleaner Code**: Go-based plugin instead of complex bash scripts
4. **Better Testing**: Can test plugin logic independently
5. **Native Integration**: Uses Traefik's plugin system instead of file generation

## Migration Checklist

- [x] Create plugin wrapper
- [x] Set up plugin directory structure
- [x] Update Traefik config
- [x] Update Dockerfile
- [x] Create simplified entrypoint
- [ ] Test in local docker-compose
- [ ] Test in Cloud Run staging
- [ ] Verify token forwarding works
- [ ] Update deployment documentation

## Troubleshooting

### Plugin Not Loading

- Check that `plugins-local/` directory exists in container
- Verify plugin source code is copied correctly
- Check Traefik logs for plugin loading errors

### Routes Not Appearing

- Verify services have `traefik_enable=true` label
- Check Cloud Run API permissions
- Review plugin logs for discovery errors

### Token Issues

- Verify service account has `iam.serviceAccounts.getAccessToken` permission
- Check metadata server is accessible
- Review token manager logs

## Next Steps

1. Test plugin in local environment
2. Deploy to staging and verify routes
3. Test token forwarding with private services
4. Remove old bash scripts once verified
