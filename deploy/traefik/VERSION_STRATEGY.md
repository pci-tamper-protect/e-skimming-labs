# Traefik Version Strategy

## Default: Traefik v3.0

All Dockerfiles and deployment scripts target **Traefik v3.0** by default. Images are tagged `:latest`.
Legacy Traefik v2.10 assets are archived under `deploy/traefik/deprecated-v2/` and tagged `:legacy` if needed for rollback.

## Legacy: Traefik v2.10

Traefik v2.10 resources live under `deploy/traefik/deprecated-v2/`. Use them only when needed for rollback scenarios.

## Dockerfiles

### Sidecar Architecture (Cloud Run)

- **Default**: `Dockerfile.cloudrun.sidecar.traefik-3.0` → Traefik v3.0 (pushes `:latest`)
- **Legacy**: `deprecated-v2/Dockerfile.cloudrun.sidecar` → Traefik v2.10 (push as `:legacy` for rollback)

- **Default**: `Dockerfile.dashboard-sidecar.traefik-3.0` → Traefik v3.0 (pushes `:latest`)
- **Legacy**: `deprecated-v2/Dockerfile.dashboard-sidecar` → Traefik v2.10 (push as `:legacy` for rollback)

### Plugin Architecture (Legacy)

- **Legacy**: `Dockerfile.cloudrun` → Traefik v2.10 plugin-based architecture (not recommended)

### Local Development

- `Dockerfile.local.cloudrun` → v3.0 (local plugin development)
- `Dockerfile.test` → v3.0 (testing)

## When to Use v3.0 (Default)

All production and staging deployments use v3.0. Use `deploy-sidecar.sh` or `deploy-sidecar-traefik-3.0.sh` (both now build v3.0).

## When to Use v2.10 (Legacy)

Only for rollback if a v3.0 regression is found. Build from `deprecated-v2/` and tag `:legacy`.

## Configuration Compatibility

The v3.0 config files (`traefik.cloudrun.sidecar.traefik-3.0.yml`, etc.) are v3-specific. The main v3 changes from v2:
- `sslRedirect` removed from headers middleware (now an entrypoint option)
- Some API/dashboard route configuration changes
