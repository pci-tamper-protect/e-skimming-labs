# Traefik Version Strategy

## Default: Traefik v3.0

All Dockerfiles and deployment scripts now target **Traefik v3.0** by default. Legacy Traefik v2.10 assets have been moved to `deploy/traefik/deprecated-v2/` for reference and manual use.

## Legacy: Traefik v2.10

Traefik v2.10 resources live under `deploy/traefik/deprecated-v2/`. Use them only when needed for compatibility or rollback scenarios.

## Dockerfiles

### Sidecar Architecture (Cloud Run)

- **Legacy**: `deprecated-v2/Dockerfile.cloudrun.sidecar` → Traefik v2.10
- **Variant**: `Dockerfile.cloudrun.sidecar.traefik-3.0` → Traefik v3.0

- **Legacy**: `deprecated-v2/Dockerfile.dashboard-sidecar` → Traefik v2.10
- **Variant**: `Dockerfile.dashboard-sidecar.traefik-3.0` → Traefik v3.0

### Plugin Architecture (Legacy)

- **Default**: `Dockerfile.cloudrun` → Traefik v2.10
- **Note**: This uses the plugin-based architecture (legacy)

### Local Development

- `Dockerfile.local.cloudrun` → Currently v3.0 (for local plugin development)
- `Dockerfile.test` → Currently v3.0 (for testing)

## When to Use v3.0

Use Traefik v3.0 variants when:
- Testing v3.0-specific features
- Troubleshooting issues that might be resolved in v3.0
- Experimenting with new functionality

## When to Use v2.10 (Default)

Use Traefik v2.10 (default) for:
- Production deployments
- Stable, well-tested configurations
- When v3.0 features are not needed

## Configuration Compatibility

The configuration files (`traefik.cloudrun.sidecar.yml`, etc.) are compatible with both v2.10 and v3.0. The main differences are:
- v3.0: Some API/dashboard configuration changes
- v2.10: Stable API configuration

Both versions support the file provider and sidecar architecture.
