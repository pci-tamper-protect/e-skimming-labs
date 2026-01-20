# Cloud Run Access

**For accessing deployed services directly.**

This mode accesses the deployed Cloud Run services directly, either via the Traefik gateway or individual service URLs.

## When to Use

- Production access
- Staging verification
- Testing deployed changes
- Demo/presentation

## Environments

| Environment | URL | Project |
|-------------|-----|---------|
| Staging | https://labs.stg.pcioasis.com | labs-stg |
| Production | https://labs.pcioasis.com | labs-prd |

## Staging Access

### Via Proxy (Recommended)

Staging requires IAM authentication. Use the gcloud proxy for easy access:

```bash
# Start the proxy
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082

# Access via browser
open http://127.0.0.1:8082
```

**Note:** After deploying changes, restart the proxy to see updates.

### Via Direct URL

Direct access requires Google authentication:

1. Sign in to Google with an authorized account
2. Navigate to https://labs.stg.pcioasis.com
3. Complete the OAuth flow if prompted

## Production Access

Production is publicly accessible:

```bash
open https://labs.pcioasis.com
```

## Access Points (via Gateway)

| Path | Description |
|------|-------------|
| `/` | Labs home page |
| `/lab1` | Lab 1: Basic Magecart |
| `/lab2` | Lab 2: DOM Skimming |
| `/lab3` | Lab 3: Extension Hijacking |
| `/lab1/c2` | Lab 1 C2 Dashboard |
| `/lab2/c2` | Lab 2 C2 Dashboard |
| `/lab3/extension` | Lab 3 Extension Server |
| `/mitre-attack` | MITRE ATT&CK Matrix |
| `/threat-model` | Threat Model |

## Direct Service URLs

For debugging, you can access services directly (requires authentication):

```bash
# Get an identity token
TOKEN=$(gcloud auth print-identity-token)

# Access a service directly
curl -H "Authorization: Bearer $TOKEN" \
  https://home-index-stg-xxx.run.app/
```

### List Service URLs

```bash
gcloud run services list \
  --project=labs-stg \
  --region=us-central1 \
  --format="table(SERVICE,URL)"
```

## Troubleshooting

### 403 Forbidden (Staging)

Your account doesn't have access. Contact an admin to be added to:
- `core-eng@pcioasis.com`
- `2025-interns@pcioasis.com`

### 401 Unauthorized

The identity token is invalid or expired:
```bash
# Refresh your credentials
gcloud auth login
gcloud auth application-default login
```

### Service Not Found

The service may not be deployed. Check:
```bash
gcloud run services list \
  --project=labs-stg \
  --region=us-central1
```

### Stale Content

After deploying, the proxy may cache old content:
```bash
# Restart the proxy
pkill -f "gcloud run services proxy"
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082
```

## Next Steps

- [Deploying changes](../deployment/README.md)
- [Testing in staging](../testing/STAGING_TESTING.md)
- [Local development](./LOCAL_SIDECAR.md)
