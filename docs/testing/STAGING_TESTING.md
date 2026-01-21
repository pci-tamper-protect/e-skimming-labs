# Staging Testing

Testing E-Skimming Labs against the staging environment.

## Prerequisites

### Start the Proxy

Staging requires IAM authentication. Use the gcloud proxy:

```bash
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082
```

Keep this running in a terminal.

## Quick Tests

### Health Check

```bash
curl http://127.0.0.1:8082/ping
# Expected: OK
```

### Home Page

```bash
curl -s http://127.0.0.1:8082/ | head -20
# Expected: HTML content
```

### Lab Routes

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8082/lab1
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8082/lab2
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8082/lab3
# Expected: 200 for each
```

## Browser Testing

1. Open http://127.0.0.1:8082
2. Click through each lab
3. Verify navigation works
4. Check C2 dashboards

## After Deploying Changes

**Important:** After deploying, restart the proxy to see changes:

```bash
# Stop the proxy (Ctrl+C or kill)
pkill -f "gcloud run services proxy"

# Restart
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082
```

## Direct Service Testing

Test individual services directly (requires authentication):

```bash
# Get identity token
TOKEN=$(gcloud auth print-identity-token)

# Test home-index directly
curl -H "Authorization: Bearer $TOKEN" \
  https://home-index-stg-xxx.run.app/

# Test lab service directly
curl -H "Authorization: Bearer $TOKEN" \
  https://lab-01-basic-magecart-stg-xxx.run.app/
```

### Get Service URLs

```bash
gcloud run services list \
  --project=labs-stg \
  --region=us-central1 \
  --format="table(SERVICE,URL)"
```

## Check Cloud Run Logs

```bash
# Home index logs
gcloud run services logs read home-index-stg \
  --project=labs-home-stg \
  --region=us-central1 \
  --limit=50

# Lab service logs
gcloud run services logs read lab-02-dom-skimming-stg \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50

# Traefik provider logs
gcloud run services logs read traefik-stg \
  --project=labs-stg \
  --region=us-central1 \
  --container=provider \
  --limit=50
```

## Common Issues

### 403 Forbidden

Your account doesn't have access. Contact admin to be added to:
- `core-eng@pcioasis.com`
- `2025-interns@pcioasis.com`

### Stale Content After Deploy

Restart the proxy:
```bash
pkill -f "gcloud run services proxy"
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082
```

### Service Not Found

Check if service is deployed:
```bash
gcloud run services list \
  --project=labs-stg \
  --region=us-central1
```

### 502 Bad Gateway

Service is unhealthy. Check logs:
```bash
gcloud run services logs read SERVICE_NAME \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

## E2E Tests

Run Playwright tests against staging:

```bash
# Set environment
export BASE_URL=http://127.0.0.1:8082

# Run tests
npx playwright test
```

## Verify Deployment

After deploying, verify the new revision is serving:

```bash
gcloud run services describe home-index-stg \
  --project=labs-home-stg \
  --region=us-central1 \
  --format="value(status.latestReadyRevisionName)"
```

Compare with the revision before deployment to confirm the update.
