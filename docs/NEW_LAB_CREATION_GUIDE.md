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

Add your lab's services with traefik labels. These labels are the **single source of truth** for routing -- all Cloud Run labels are generated from them.

#### Vulnerable site service

```yaml
lab5-vulnerable-site:
  build: ./labs/05-<your-lab-name>/vulnerable-site
  container_name: lab5-vulnerable-site
  networks:
    - labs-network
  depends_on:
    - traefik
  healthcheck:
    test: ['CMD', 'wget', '--no-verbose', '--tries=1', '--spider', 'http://localhost:80/']
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 5s
  labels:
    - "lab=lab5-<your-lab-name>"
    - "component=vulnerable-site"
    - "traefik.enable=true"
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
    - "traefik.http.services.lab5-vulnerable-site.loadbalancer.server.port=80"
```

#### C2 server service (if applicable)

```yaml
lab5-c2-server:
  build: ./labs/05-<your-lab-name>/c2-server
  container_name: lab5-c2-server
  networks:
    - labs-network
  environment:
    - NODE_ENV=development
    - PORT=3000
  depends_on:
    - traefik
  labels:
    - "lab=lab5-<your-lab-name>"
    - "component=c2-server"
    - "traefik.enable=true"
    - "traefik.http.routers.lab5-c2.rule=PathPrefix(`/lab5/c2`)"
    - "traefik.http.routers.lab5-c2.priority=300"
    - "traefik.http.routers.lab5-c2.entrypoints=web"
    - "traefik.http.routers.lab5-c2.middlewares=lab5-auth-check@file,strip-lab5-c2-prefix@file"
    - "traefik.http.services.lab5-c2-server.loadbalancer.server.port=3000"
```

### 3. Regenerate Cloud Run labels

Run the label generator to update `deploy/traefik/lab-labels.sh`:

```bash
./deploy/traefik/generate-lab-labels.sh
```

This reads your new docker-compose.yml labels and generates the Cloud Run label format. Commit the updated `lab-labels.sh` alongside your changes.

### 4. Add traefik middlewares

Edit `deploy/traefik/dynamic/routes.yml` to add strip-prefix and auth-check middlewares for your lab:

```yaml
http:
  middlewares:
    strip-lab5-prefix:
      stripPrefix:
        prefixes:
          - "/lab5"
    strip-lab5-c2-prefix:
      stripPrefix:
        prefixes:
          - "/lab5/c2"
    lab5-auth-check:
      forwardAuth:
        address: "http://home-index:8080/api/auth/check"
        trustForwardHeader: true
```

### 5. Add deploy function

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

     # Lab 5 C2 Server (if applicable)
     LAB5_C2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab5-c2:${IMAGE_TAG}"
     build_and_push "lab5-c2-${ENVIRONMENT}" "labs/05-<your-lab-name>/c2-server" "Dockerfile" "$LAB5_C2_IMAGE"

     LAB5_C2_TRAEFIK_LABELS=$(get_lab_labels "lab5-c2-server")
     gcloud run deploy lab5-c2-${ENVIRONMENT} \
       --image="$LAB5_C2_IMAGE" \
       --region=${LABS_GAR_LOCATION} --platform=managed --project=${LABS_PROJECT_ID} \
       --no-allow-unauthenticated \
       --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
       --port=8080 --memory=256Mi --cpu=1 --min-instances=0 --max-instances=5 \
       --set-env-vars="ENVIRONMENT=${ENVIRONMENT}" \
       --labels="environment=${ENVIRONMENT},component=c2,lab=05-<your-lab-name>,project=e-skimming-labs,${LAB5_C2_TRAEFIK_LABELS}"

     # Lab 5 Main Service
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

Edit `.github/workflows/deploy_labs.yml`:

1. In the `Deploy to Cloud Run` step, add the mapping:
   ```bash
   case "${{ matrix.lab }}" in
     ...
     05-<your-lab-name>) COMPOSE_SVC="lab5-vulnerable-site" ;;
   esac
   ```

The lab will be automatically discovered by the `discover-labs` step (it finds all directories under `labs/`).

### 7. Test locally

```bash
docker compose up --build
```

Verify routing works:
- `http://localhost:8080/lab5` - main lab page
- `http://localhost:8080/lab5/c2` - C2 server (if applicable)
- `http://localhost:8081/dashboard/` - traefik dashboard shows new routers

### 8. Deploy to staging

```bash
./deploy/deploy-labs.sh stg 05
```

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
- Port override: compose uses `80` (nginx), Cloud Run uses `8080`
- Long rules (>63 chars) use `rule_id` shorthand instead of inline `rule=`
