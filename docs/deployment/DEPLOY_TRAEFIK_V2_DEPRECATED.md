# Deprecated: Traefik v2 Sidecar Deployment

Use this document only when you must fall back to the legacy Traefik v2.10 build path.
All currently supported deployments default to Traefik v3.0; the v2 artifacts live under `deploy/traefik/deprecated-v2/`.

## Components

- **Main Traefik**: `deploy/traefik/deprecated-v2/Dockerfile.cloudrun.sidecar`
- **Dashboard**: `deploy/traefik/deprecated-v2/Dockerfile.dashboard-sidecar`
- **Entrypoint**: `deploy/traefik/deprecated-v2/entrypoint-sidecar.sh`
- **Static config**: `deploy/traefik/deprecated-v2/traefik.cloudrun.sidecar.yml` and `traefik.cloudrun.yml`

## Build (legacy)

```bash
cd deploy/traefik
docker build -f deprecated-v2/Dockerfile.cloudrun.sidecar -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:legacy .
docker build -f deprecated-v2/Dockerfile.dashboard-sidecar -t us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik-dashboard:legacy .
```

## Deploy (legacy)

```bash
HOME_INDEX_URL=$(gcloud run services describe home-index-stg --region=us-central1 --project=labs-home-stg --format='value(status.url)')
env HOME_INDEX_URL="$HOME_INDEX_URL" gcloud run services replace deprecated-v2/traefik.cloudrun.sidecar.yml \
  --region=us-central1 --project=labs-stg

gcloud run services replace traefik-dashboard-sidecar.yaml \
  --region=us-central1 --project=labs-stg
```

## Notes

- The v2 entrypoint writes the same `lab*-auth-check` middlewares, but the script is now archived in `deprecated-v2/`.
- Do **not** modify the v2 scripts unless you are troubleshooting the legacy stack.
