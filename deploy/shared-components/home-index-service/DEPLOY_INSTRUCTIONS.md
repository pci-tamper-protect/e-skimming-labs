# Deploy home-index-service to Staging

## Prerequisites
- `gcloud` CLI installed and authenticated
- Docker installed and running
- Access to `labs-home-stg` project
- Access to Artifact Registry

## Quick Deploy

Run the deployment script:
```bash
cd /Users/kestenbroughton/projectos/e-skimming-labs
./deploy/shared-components/home-index-service/deploy-stg.sh
```

## Manual Deploy Steps

If the script doesn't work, follow these steps:

### 1. Authenticate to Artifact Registry
```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 2. Build the Docker Image
```bash
cd /Users/kestenbroughton/projectos/e-skimming-labs

# Get current commit SHA for image tag
IMAGE_TAG=$(git rev-parse --short HEAD)

# Build the image
docker build \
  -f deploy/shared-components/home-index-service/Dockerfile \
  --build-arg ENVIRONMENT=stg \
  -t us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:${IMAGE_TAG} \
  -t us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:latest \
  .
```

### 3. Push the Image
```bash
docker push us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:${IMAGE_TAG}
docker push us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:latest
```

### 4. Deploy to Cloud Run
```bash
gcloud run deploy home-index-stg \
  --image=us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:${IMAGE_TAG} \
  --region=us-central1 \
  --platform=managed \
  --project=labs-home-stg \
  --no-allow-unauthenticated \
  --service-account=home-runtime-sa@labs-home-stg.iam.gserviceaccount.com \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --labels="environment=stg,component=index,project=e-skimming-labs-home,service-type=service" \
  --set-env-vars="HOME_PROJECT_ID=labs-home-stg,ENVIRONMENT=stg,DOMAIN=labs.stg.pcioasis.com,LABS_DOMAIN=labs.stg.pcioasis.com,MAIN_DOMAIN=pcioasis.com,LABS_PROJECT_ID=labs-stg,LAB1_URL=https://lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.run.app,LAB2_URL=https://lab-02-dom-skimming-stg-mmwwcfi5za-uc.a.run.app/banking.html,LAB3_URL=https://lab-03-extension-hijacking-stg-mmwwcfi5za-uc.a.run.app/index.html" \
  --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
  --labels="environment=stg,component=index,project=e-skimming-labs-home"
```

### 5. Grant Access to Developer Groups
```bash
gcloud run services add-iam-policy-binding home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --member="group:2025-interns@pcioasis.com" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --member="group:core-eng@pcioasis.com" \
  --role="roles/run.invoker"
```

### 6. Verify Deployment
```bash
gcloud run services describe home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --format="value(status.url)"
```

## What Changed

This deployment includes the fix for proxy navigation:
- Detects when accessed via proxy (`127.0.0.1:8081` or `localhost:8081`)
- Uses relative URLs (`/mitre-attack` instead of `https://labs.stg.pcioasis.com/mitre-attack`)
- Allows navigation through the proxy without browser authentication

## Testing After Deployment

1. Start the proxy:
   ```bash
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```

2. Access the home page:
   ```bash
   # This should work
   curl http://127.0.0.1:8081/
   
   # This may give 404 (IPv6/IPv4 issue)
   curl http://localhost:8081/
   ```

3. Test navigation:
   - Open `http://127.0.0.1:8081/` in browser
   - Click "MITRE ATT&CK" link
   - Should navigate to `http://127.0.0.1:8081/mitre-attack` (not the domain)
