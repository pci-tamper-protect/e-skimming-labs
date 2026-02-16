# Authentication Deployment Guide for E-Skimming Labs

## Firebase Project Configuration

E-Skimming Labs uses the **same Firebase projects** as e-skimming-app for SSO:

- **Staging**: `ui-firebase-pcioasis-stg`
- **Production**: `ui-firebase-pcioasis-prd`

This ensures seamless single sign-on between:
- `stg.pcioasis.com` ↔ `labs.stg.pcioasis.com`
- `www.pcioasis.com` ↔ `labs.pcioasis.com`

## Environment Variables

### Required Variables

```bash
# Enable/disable authentication
ENABLE_AUTH=true

# Require authentication (blocks unauthenticated access)
REQUIRE_AUTH=false  # Set to true to require auth

# Firebase project ID (must match e-skimming-app)
FIREBASE_PROJECT_ID=ui-firebase-pcioasis-stg  # For staging
# OR
FIREBASE_PROJECT_ID=ui-firebase-pcioasis-prd  # For production

# Optional: Path to Firebase service account key
# If not provided, uses default credentials (Application Default Credentials)
FIREBASE_CREDENTIALS_PATH=/path/to/service-account.json
```

### Staging Environment

```bash
ENABLE_AUTH=true
REQUIRE_AUTH=false  # Optional, set to true to require auth
FIREBASE_PROJECT_ID=ui-firebase-pcioasis-stg
MAIN_DOMAIN=stg.pcioasis.com
```

### Production Environment

```bash
ENABLE_AUTH=true
REQUIRE_AUTH=false  # Optional, set to true to require auth
FIREBASE_PROJECT_ID=ui-firebase-pcioasis-prd
MAIN_DOMAIN=pcioasis.com
```

## Deployment Configuration

### Cloud Run Deployment

Update the deployment workflow (`.github/workflows/deploy_labs.yml`) to include auth environment variables:

```yaml
--set-env-vars="
  ENVIRONMENT=${{ needs.setup.outputs.environment }},
  DOMAIN=${{ needs.setup.outputs.domain_prefix }},
  MAIN_DOMAIN=pcioasis.com,
  ENABLE_AUTH=true,
  REQUIRE_AUTH=false,
  FIREBASE_PROJECT_ID=ui-firebase-pcioasis-${{ needs.setup.outputs.environment == 'stg' && 'stg' || 'prd' }}
"
```

### Firebase Service Account Setup

1. **Create Service Account** (if not exists):
   ```bash
   gcloud iam service-accounts create labs-auth-validator \
     --project=ui-firebase-pcioasis-stg
   ```

2. **Grant Firebase Admin SDK permissions**:
   ```bash
   gcloud projects add-iam-policy-binding ui-firebase-pcioasis-stg \
     --member="serviceAccount:labs-auth-validator@ui-firebase-pcioasis-stg.iam.gserviceaccount.com" \
     --role="roles/firebase.admin"
   ```

3. **Create and download key**:
   ```bash
   gcloud iam service-accounts keys create labs-auth-key.json \
     --iam-account=labs-auth-validator@ui-firebase-pcioasis-stg.iam.gserviceaccount.com \
     --project=ui-firebase-pcioasis-stg
   ```

4. **Store in Secret Manager**:
   ```bash
   gcloud secrets create FIREBASE_CREDENTIALS_STG \
     --project=labs-stg \
     --data-file=labs-auth-key.json
   ```

5. **Mount in Cloud Run**:
   ```yaml
   --set-secrets="FIREBASE_CREDENTIALS_PATH=FIREBASE_CREDENTIALS_STG:latest"
   ```

## Testing

### Run Staging Tests

```bash
cd test
TEST_ENV=stg \
  TEST_USER_EMAIL_STG=your-test-email@example.com \
  TEST_USER_PASSWORD_STG=your-test-password \
  AUTH_ENABLED=true \
  npm test -- e2e/auth-stg.spec.js
```

### Test Authentication Flow

1. Sign in at `stg.pcioasis.com/sign-in`
2. Navigate to `labs.stg.pcioasis.com?token=<token>`
3. Verify token is validated and stored
4. Verify access to protected routes

## Troubleshooting

### Token Validation Fails

- Check `FIREBASE_PROJECT_ID` matches e-skimming-app project
- Verify service account has `roles/firebase.admin`
- Check Cloud Run logs for validation errors

### Redirect Loop

- Verify `MAIN_DOMAIN` is set correctly
- Check `REQUIRE_AUTH` is not set to `true` if auth is optional
- Verify sign-in URL generation in `/api/auth/sign-in-url`

### CORS Issues

- Ensure Firebase Auth domain is configured for both domains
- Check browser console for CORS errors
- Verify token is being passed correctly

## Traefik HOME_INDEX_URL (Lab Auth)

For lab routes to require login, Traefik needs `HOME_INDEX_URL` so its entrypoint can write ForwardAuth middlewares. The deploy workflow fetches this from the Home project using the Labs deploy SA (`labs-deploy-sa`).

### Grant Labs SA Permissions

The Labs deploy SA must have `roles/run.viewer` on the Home project to describe `home-index-stg`:

```bash
./deploy/traefik/APPLY_PERMISSIONS.sh stg
```

### When HOME_INDEX_URL Is Not Set

If the debug script reports `HOME_INDEX_URL not set on Traefik`, either:

1. Run `./deploy/traefik/APPLY_PERMISSIONS.sh stg` (then redeploy Traefik), or
2. Run `./deploy/traefik/set-home-index-url.sh stg` (fix without redeploy)

### Why It May Not Deploy Correctly

1. **Missing permissions**: Labs deploy SA needs `roles/run.viewer` on `labs-home-stg`. Run `./deploy/traefik/APPLY_PERMISSIONS.sh stg`.
2. **Traefik not redeployed**: Traefik only deploys when `deploy/traefik/` changes (or `[force-all]`). Pushes that only change home-index do not redeploy Traefik; use `set-home-index-url.sh` to fix without a full redeploy.

## Security Considerations

1. **Token Storage**: Tokens are stored in `sessionStorage` (not `localStorage`) for better security
2. **Token Validation**: All tokens are validated server-side using Firebase Admin SDK
3. **HTTPS Only**: Ensure all environments use HTTPS
4. **Service Account**: Use least-privilege IAM roles for service account

