# Creating a New Lab

This guide walks through adding a new lab (e.g., Lab 5) to the e-skimming-labs platform.

## Prerequisites

- Docker and Docker Compose installed
- `yq` installed (`brew install yq` on macOS)
- Access to the GCP project for deployment

## Steps

### 1. Create the lab directory

Copy the most similar existing lab as a starting point:

```bash
cp -r labs/04-steganography-favicon labs/05-<your-lab-name>
```

Update the lab content (HTML, skimmer code, C2 server, etc.) in the new directory.

### 2. Add services to docker-compose.yml

Add your lab's services with traefik labels. These labels are the **single source of truth** for routing — all Cloud Run labels are generated from them.

#### Vulnerable site service

```yaml
lab5-vulnerable-site:
  build: ./labs/05-<your-lab-name>
  container_name: lab5-<your-lab-name>
  networks:
    - labs-network
  depends_on:
    - traefik
  healthcheck:
    test: ['CMD', 'wget', '--no-verbose', '--tries=1', '--spider', 'http://localhost:8080/health']
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 5s
  labels:
    - "lab=lab5-<your-lab-name>"
    - "component=vulnerable-site"
    - "traefik.enable=true"
    # Health check router (no auth) - warms container on home-page prefetch
    - "traefik.http.routers.lab5-health.rule=Path(`/lab5/health`)"
    - "traefik.http.routers.lab5-health.priority=400"
    - "traefik.http.routers.lab5-health.entrypoints=web"
    - "traefik.http.routers.lab5-health.middlewares=strip-lab5-prefix@file"
    - "traefik.http.routers.lab5-health.service=lab5-vulnerable-site"
    # Static files router (no auth, higher priority)
    - "traefik.http.routers.lab5-static.rule=PathPrefix(`/lab5/css/`) || PathPrefix(`/lab5/js/`) || PathPrefix(`/lab5/images/`) || PathPrefix(`/lab5/img/`) || PathPrefix(`/lab5/static/`) || PathPrefix(`/lab5/assets/`)"
    - "traefik.http.routers.lab5-static.priority=250"
    - "traefik.http.routers.lab5-static.entrypoints=web"
    - "traefik.http.routers.lab5-static.middlewares=strip-lab5-prefix@file"
    - "traefik.http.routers.lab5-static.service=lab5-vulnerable-site"
    # Main router (with auth, lower priority)
    - "traefik.http.routers.lab5-main.rule=PathPrefix(`/lab5`)"
    - "traefik.http.routers.lab5-main.priority=200"
    - "traefik.http.routers.lab5-main.entrypoints=web"
    - "traefik.http.routers.lab5-main.middlewares=lab5-auth-check@file,strip-lab5-prefix@file"
    - "traefik.http.routers.lab5-main.service=lab5-vulnerable-site"
    - "traefik.http.services.lab5-vulnerable-site.loadbalancer.server.port=8080"
```

#### C2 server — choose one pattern

**Option A: Use shared-c2 (preferred for labs 1-3 style)**

Add C2 routes to the existing `shared-c2` service in docker-compose.yml:

```yaml
# In the shared-c2 labels section, add:
# ── Lab 5 C2 routes ──────────────────────────────────────────────────────
# Collect (no auth — skimmer posts from victim browser)
- "traefik.http.routers.lab5-c2-collect.rule=Path(`/lab5/c2/collect`)"
- "traefik.http.routers.lab5-c2-collect.priority=350"
- "traefik.http.routers.lab5-c2-collect.entrypoints=web"
- "traefik.http.routers.lab5-c2-collect.service=shared-c2"
# Dashboard & API (auth required)
- "traefik.http.routers.lab5-c2.rule=PathPrefix(`/lab5/c2`)"
- "traefik.http.routers.lab5-c2.priority=300"
- "traefik.http.routers.lab5-c2.entrypoints=web"
- "traefik.http.routers.lab5-c2.middlewares=lab5-auth-check@file"
- "traefik.http.routers.lab5-c2.service=shared-c2"
```

Also add a volume mount to shared-c2:
```yaml
volumes:
  - ./labs/05-<your-lab-name>/c2-server/stolen-data:/app/data/lab5
```

**Option B: Embed C2 in the lab container (lab4 pattern)**

Include nginx + C2 server in a single container. Traefik routes all `/lab5` traffic to this one service, which nginx proxies internally to the C2 on a local port. See `labs/04-steganography-favicon` for the pattern.

### 3. Regenerate Cloud Run labels

Run the label generator to update `deploy/traefik/lab-labels.sh`:

```bash
./deploy/traefik/generate-lab-labels.sh
```

This reads your new docker-compose.yml labels and generates the Cloud Run label format. Commit the updated `lab-labels.sh` alongside your changes.

### 4. Add traefik middlewares

Two files need updating:

#### `deploy/traefik/dynamic/routes.yml` — strip-prefix middlewares

```yaml
http:
  middlewares:
    strip-lab5-prefix:
      stripPrefix:
        prefixes:
          - "/lab5"
    # Add additional strip middlewares only if needed (e.g. separate c2 prefix strip)
    # strip-lab5-c2-prefix:
    #   stripPrefix:
    #     prefixes:
    #       - "/lab5/c2"
```

Also add the health router to the static routers section (used by Cloud Run where Docker labels aren't available):

```yaml
http:
  routers:
    lab5-health:
      rule: "Path(`/lab5/health`)"
      service: lab5-vulnerable-site
      priority: 400
      entryPoints:
        - web
      middlewares:
        - strip-lab5-prefix
```

#### `deploy/traefik/dynamic/local-auth-stubs.yml` — local dev auth no-op

This file disables auth for local Docker Compose. Add an empty chain for the new lab:

```yaml
http:
  middlewares:
    lab5-auth-check:
      chain:
        middlewares: []
```

> Note: In Cloud Run (stg/prd), the real `lab5-auth-check` ForwardAuth middleware is generated automatically by the `traefik-cloudrun-provider`. You never define it in static files.

### 5. Add deploy function (for manual deploys via script)

Edit `deploy/deploy-labs.sh`:

1. Add `"05"` to the argument parsing:
   ```bash
   elif [ "$arg" = "05" ]
   ```

2. Add the deploy function:
   ```bash
   deploy_lab05() {
     echo ""
     echo "Deploying Lab 05: <Your Lab Name>..."

     LAB5_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/05-<your-lab-name>:${IMAGE_TAG}"
     build_and_push "lab-05-<your-lab-name>-${ENVIRONMENT}" "labs/05-<your-lab-name>" "Dockerfile" "$LAB5_IMAGE"

     TRAEFIK_LABELS=$(get_lab_labels "lab5-vulnerable-site")
     gcloud run deploy lab-05-<your-lab-name>-${ENVIRONMENT} \
       --image="$LAB5_IMAGE" \
       --region=${LABS_GAR_LOCATION} --platform=managed --project=${LABS_PROJECT_ID} \
       --no-allow-unauthenticated \
       --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
       --port=8080 --memory=512Mi --cpu=1 --min-instances=0 --max-instances=10 \
       --set-env-vars="LAB_NAME=05-<your-lab-name>,ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},HOME_URL=https://${DOMAIN_PREFIX}" \
       --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
       --labels="environment=${ENVIRONMENT},lab=05-<your-lab-name>,project=e-skimming-labs,${TRAEFIK_LABELS}"
   }
   ```

3. Add to the case statement and summary.

### 6. Add to GHA matrix

The `discover-labs` step automatically finds all directories under `labs/` — no manual addition needed there. However, you **must** add the COMPOSE_SVC mapping so the workflow knows which docker-compose service to pull labels from.

Edit `.github/workflows/deploy_labs.yml`, in the `Deploy to Cloud Run` step's case statement:

```bash
case "${{ matrix.lab }}" in
  ...
  05-<your-lab-name>) COMPOSE_SVC="lab5-vulnerable-site" ; COMPOSE_SVC2="" ;;
esac
```

If your lab uses an embedded C2 (Option B above), set `COMPOSE_SVC2` to the C2 compose service name so those labels are merged onto the single Cloud Run service.

### 7. Test locally

```bash
docker compose up --build
```

Verify routing works:
- `http://localhost:8080/lab5` — main lab page
- `http://localhost:8080/lab5/health` — health check (no auth)
- `http://localhost:8080/lab5/c2` — C2 dashboard (if applicable)
- `http://localhost:8081/dashboard/` — traefik dashboard shows new routers

### 8. Deploy to staging

```bash
./deploy/deploy-labs.sh stg 05
```

Or just push to `stg` branch — GHA will auto-detect the new lab directory and deploy it.

### 9. Verify deployment

Check the traefik dashboard for new routers:
```bash
curl https://traefik-dashboard-stg-<hash>.a.run.app/api/http/routers | jq
```

Verify the lab is accessible:
```bash
curl https://labs.stg.pcioasis.com/lab5
```

## Label Architecture

```
docker-compose.yml (source of truth)
        |
        v
generate-lab-labels.sh (yq)
        |
        v
lab-labels.sh (generated, committed)
       / \
      v   v
deploy-labs.sh   deploy_labs.yml (GHA)
      |              |
      v              v
  Cloud Run labels (gcloud deploy)
```

Key conversions from compose to Cloud Run labels:
- Dots to underscores: `traefik.http.routers` -> `traefik_http_routers`
- `@file` to `-file`: `strip-lab1-prefix@file` -> `strip-lab1-prefix-file`
- Comma-separated middlewares to `__`: `a@file,b@file` -> `a-file__b-file`
- Port override: compose uses `8080`, Cloud Run uses `8080` (same)
- Long rules (>63 chars) use `rule_id` shorthand instead of inline `rule=`

## Auth middleware split

| File | Purpose |
|------|---------|
| `dynamic/local-auth-stubs.yml` | Empty chain no-ops for local Docker Compose dev |
| `dynamic/routes.yml` | Strip-prefix and other non-auth middlewares |
| traefik-cloudrun-provider (runtime) | Generates real `ForwardAuth` middlewares for stg/prd |

Never put a `forwardAuth` definition in the static files — the provider generates those from Cloud Run service labels at runtime.
