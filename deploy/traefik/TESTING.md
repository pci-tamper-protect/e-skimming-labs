# Testing entrypoint.sh Locally

This directory contains test scripts to validate `entrypoint.sh` configuration generation without deploying to Cloud Run.

## Quick Test

Run the main test script:

```bash
cd deploy/traefik
./test-entrypoint.sh [local|stg|prd]
```

**Default:** `local` (if no argument provided)

**Examples:**
```bash
# Test local environment (default - no auth tokens)
./test-entrypoint.sh
./test-entrypoint.sh local

# Test staging environment (with auth tokens)
./test-entrypoint.sh stg

# Test production environment (with auth tokens)
./test-entrypoint.sh prd
```

This will:
1. Mock the environment variables for the specified environment
2. Mock identity tokens (skip metadata server calls) - only for stg/prd
3. Generate the Traefik configuration
4. Validate the YAML syntax
5. Verify Authorization headers are present (stg/prd only)
6. Check router middleware configuration

## What Gets Tested

- ✅ Token fetching logic (mocked)
- ✅ YAML generation
- ✅ Token escaping (handles special characters, newlines)
- ✅ Middleware creation
- ✅ Router middleware assignment
- ✅ YAML syntax validation

## Test Output

The test generates:
- `test-output/dynamic/cloudrun-services.yml` - Generated Traefik config
- `test-output/test-output.log` - Full test output

## Manual Inspection

After running the test, inspect the generated config:

```bash
cat test-output/dynamic/cloudrun-services.yml | grep -A 10 "home-index-auth"
```

## Troubleshooting

If the test fails:

1. **YAML validation errors**: Check token escaping in `entrypoint.sh`
2. **Missing Authorization header**: Verify middleware generation logic
3. **Router not using middleware**: Check router configuration in `entrypoint.sh`

## Integration with CI/CD

You can add this test to your CI/CD pipeline:

```yaml
- name: Test entrypoint.sh
  run: |
    cd deploy/traefik
    ./test-entrypoint.sh
```

## Next Steps

After local testing passes:
1. Rebuild and push the image: `./build-and-push.sh stg`
2. Update Cloud Run service
3. Check logs to verify auth headers are being sent
