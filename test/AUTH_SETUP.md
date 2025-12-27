# Authentication Setup for Staging E2E Tests

## Overview

Staging environment requires authentication. E2E tests authenticate once using a test account and reuse the auth state across all tests for better performance and reliability.

## Setup Steps

### 1. Create Test Account in Firebase

1. Go to Firebase Console: https://console.firebase.google.com/project/ui-firebase-pcioasis-stg
2. Navigate to **Authentication** → **Users**
3. Click **Add user**
4. Create user with:
   - **Email**: `labs.test+1@pcioasis.com`
   - **Password**: Generate a random secure password (save it!)

### 2. Create Encrypted Test Credentials File

1. Create `.env.tests.stg` file in the repository root:

```bash
cat > .env.tests.stg << 'EOF'
# Test account email
TEST_USER_EMAIL_STG=labs.test+1@pcioasis.com

# Test account password (use the password you set in Firebase)
TEST_USER_PASSWORD_STG=YOUR_RANDOM_PASSWORD_HERE

# Enable authentication for tests
AUTH_ENABLED=true
EOF
```

2. Encrypt the file using dotenvx:

```bash
# Make sure you have the dotenvx converter script
./deploy/secrets/dotenvx-converter.py .env.tests.stg --env tests-stg
```

This will create:
- `.env.tests.stg` (encrypted, safe to commit)
- `.env.keys.tests-stg` (decryption key, safe to commit for tests)
- `.env.hashes.tests-stg` (hash audit trail, safe to commit)

3. Commit the encrypted files:

```bash
git add .env.tests.stg .env.keys.tests-stg .env.hashes.tests-stg
git commit -m "Add encrypted test credentials for staging E2E tests"
```

**Important**: The `.env.tests.stg.bak.*` backup files contain plaintext secrets and should NOT be committed (already in `.gitignore`).

### 3. How It Works

#### Global Setup (Runs Once)

When tests run in staging with `AUTH_ENABLED=true` and test credentials provided:

1. **Global Setup** (`test/utils/global-setup-auth.js`) runs before all tests:
   - Launches a browser
   - Signs in to `stg.pcioasis.com/sign-in` with test credentials
   - Retrieves Firebase access token
   - Navigates to `labs.stg.pcioasis.com` with token
   - Saves auth state (cookies, localStorage, sessionStorage) to `test/.auth/storage-state.json`

#### Test Execution (Reuses Auth State)

2. **All tests** automatically use the saved auth state:
   - Playwright config loads `storage-state.json` if it exists
   - All page contexts start with authenticated state
   - No need to authenticate in individual tests

#### Benefits

- ✅ **Faster tests**: Authenticate once, not in every test
- ✅ **More reliable**: No flaky auth failures
- ✅ **Cleaner tests**: No auth boilerplate in test code
- ✅ **Automatic**: Works transparently for all tests

### 4. Running Tests Locally

```bash
cd test

# Decrypt test credentials
export DOTENV_PRIVATE_KEY="$(cat ../.env.keys.tests-stg)"
dotenvx run -f ../.env.tests.stg -fk ../.env.keys.tests-stg -- env | grep -E '^(TEST_USER_EMAIL_STG|TEST_USER_PASSWORD_STG|AUTH_ENABLED)=' > /tmp/test-env.sh
source /tmp/test-env.sh

# Run tests
TEST_ENV=stg npm test
```

Or use a helper script:

```bash
# Create test/run-tests-stg.sh
#!/bin/bash
cd "$(dirname "$0")"
export DOTENV_PRIVATE_KEY="$(cat ../.env.keys.tests-stg)"
dotenvx run -f ../.env.tests.stg -fk ../.env.keys.tests-stg -- bash -c 'export TEST_ENV=stg && npm test'
```

### 5. GitHub Actions

The workflow automatically:
1. Installs `dotenvx` for staging tests
2. Decrypts `.env.tests.stg` using `.env.keys.tests-stg`
3. Exports `TEST_USER_EMAIL_STG`, `TEST_USER_PASSWORD_STG`, and `AUTH_ENABLED`
4. Runs global setup to authenticate
5. All tests use the saved auth state

### 6. Troubleshooting

#### Tests still getting 403 errors

- Check that `.env.tests.stg` and `.env.keys.tests-stg` are committed
- Verify test account exists in Firebase
- Check that `AUTH_ENABLED=true` is set
- Look for global setup errors in test output

#### Global setup fails

- Verify test credentials are correct
- Check that `stg.pcioasis.com/sign-in` is accessible
- Verify Firebase project is `ui-firebase-pcioasis-stg`
- Check browser console for errors during sign-in

#### Auth state not being used

- Check that `test/.auth/storage-state.json` exists after global setup
- Verify `TEST_ENV=stg` is set
- Check that `AUTH_ENABLED=true` is set
- Look for errors in Playwright config loading storage state

### 7. Security Notes

- Test account should have minimal permissions (read-only if possible)
- Password should be random and secure
- Encrypted files are safe to commit (they're encrypted)
- Decryption keys for tests can be committed (they're for test accounts only)
- Never commit `.env.tests.stg.bak.*` files (they contain plaintext)
