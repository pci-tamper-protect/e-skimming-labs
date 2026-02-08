# Optional dynamic config (remote home-index)

This folder is **not** mounted by default when running `docker-compose up`.

- **docker-compose.yml** (no auth): Uses `dynamic/` only (routes.yml + middlewares). The **home-index** service comes from the Docker provider (local container). No auth.
- **docker-compose.auth.yml** (auth overlay): Same. Auth is enabled by adding Firebase env vars to the existing services; home-index is still the local container.

The file `home-index.remote.yml` here defines a **file-provider** home-index service pointing at a remote Cloud Run URL. It is for setups where Traefik should route `/` to a remote home-index instead of the local container (e.g. some Cloud Run or staging workflows). Traefik does not expand `${HOME_INDEX_URL}` in YAML, so that file is only useful when the URL is substituted at deploy time or when using a different config pipeline.

Do not copy `home-index.remote.yml` into `dynamic/` for normal local development, or the file provider will override the Docker home-index and the service will fail (invalid URL or wrong target).
