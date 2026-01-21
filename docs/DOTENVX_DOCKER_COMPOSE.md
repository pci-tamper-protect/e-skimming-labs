# Using dotenvx with Docker Compose

This guide explains how to use encrypted `.env.stg` files with Docker Compose for local development.

## Overview

Your `.env.stg` file is encrypted using `dotenvx`. To use it with Docker Compose, you need to:

1. Decrypt the environment variables at runtime using `dotenvx run`
2. Pass the decryption key (`DOTENV_PRIVATE_KEY`) to Docker Compose
3. Use the decrypted environment variables in your services

## Method 1: Using dotenvx run with docker-compose (Recommended)

This method uses `dotenvx run` to decrypt the `.env.stg` file and pass variables to docker-compose:

```bash
# Set the decryption key from .env.keys.stg
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"

# Run docker-compose with dotenvx
dotenvx run --env-file=.env.stg -- docker-compose up -d --build
```

**How it works:**
- `dotenvx run` decrypts `.env.stg` using `DOTENV_PRIVATE_KEY`
- Decrypted environment variables are injected into the shell
- `docker-compose` reads these variables from the environment
- Docker Compose uses `${VARIABLE_NAME}` syntax to reference them

## Method 2: Using env_file in docker-compose.yml

Docker Compose can read `.env` files automatically, but it doesn't support encrypted files directly. You have two options:

### Option 2a: Decrypt to temporary file

```bash
# Decrypt .env.stg to a temporary .env file
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"
dotenvx decrypt -f .env.stg -fk .env.keys.stg > .env.tmp

# Use the decrypted file
docker-compose --env-file .env.tmp up -d --build

# Clean up (IMPORTANT: don't commit .env.tmp!)
rm .env.tmp
```

### Option 2b: Use dotenvx in container startup

Modify your `docker-compose.yml` to use `dotenvx run` as the command:

```yaml
services:
  home-index:
    build: .
    # Use dotenvx to decrypt and run
    command: dotenvx run --env-file=/app/.env.stg -- ./your-binary
    environment:
      # Pass the decryption key
      - DOTENV_PRIVATE_KEY=${DOTENV_PRIVATE_KEY}
    volumes:
      # Mount the encrypted .env file
      - ./.env.stg:/app/.env.stg:ro
      # Mount the key file
      - ./.env.keys.stg:/app/.env.keys.stg:ro
```

**Note:** This requires `dotenvx` to be installed in your Docker image.

## Method 3: Export variables manually (Simple but less secure)

```bash
# Decrypt and export all variables
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"
eval $(dotenvx decrypt -f .env.stg -fk .env.keys.stg | sed 's/^/export /')

# Now docker-compose can use them
docker-compose up -d --build
```

## Recommended Setup for This Project

Based on your existing `docker-compose.auth.yml`, here's the recommended approach:

### Step 1: Create a helper script

Create `deploy/docker-compose-auth.sh`:

```bash
#!/bin/bash
set -e

# Check if .env.keys.stg exists
if [ ! -f .env.keys.stg ]; then
    echo "❌ Error: .env.keys.stg not found"
    echo "   This file should be committed to git for staging"
    exit 1
fi

# Check if .env.stg exists
if [ ! -f .env.stg ]; then
    echo "❌ Error: .env.stg not found"
    exit 1
fi

# Set the decryption key
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"

# Extract specific variables needed for docker-compose
# This avoids passing all variables to docker-compose
FIREBASE_API_KEY=$(dotenvx run --env-file=.env.stg -- printenv FIREBASE_API_KEY)
FIREBASE_PROJECT_ID=$(dotenvx run --env-file=.env.stg -- printenv FIREBASE_PROJECT_ID)

# Export for docker-compose
export FIREBASE_API_KEY
export FIREBASE_PROJECT_ID

# Run docker-compose with auth override
docker-compose -f docker-compose.yml -f docker-compose.auth.yml "$@"
```

Make it executable:
```bash
chmod +x deploy/docker-compose-auth.sh
```

### Step 2: Use the helper script

```bash
# Start services with auth
./deploy/docker-compose-auth.sh up -d --build

# Stop services
./deploy/docker-compose-auth.sh down

# View logs
./deploy/docker-compose-auth.sh logs -f
```

## Complete Example

Here's a complete example that integrates with your existing setup:

### 1. Update docker-compose.auth.yml

The file already references dotenvx in comments. Update it to use environment variables:

```yaml
version: '3.8'

services:
  home-index:
    environment:
      # These will be set by the helper script
      - FIREBASE_API_KEY=${FIREBASE_API_KEY}
      - FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-ui-firebase-pcioasis-stg}
      - ENABLE_AUTH=${ENABLE_AUTH:-true}
      - REQUIRE_AUTH=${REQUIRE_AUTH:-true}
```

### 2. Create the helper script

```bash
#!/bin/bash
# deploy/docker-compose-auth.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Check prerequisites
if [ ! -f .env.keys.stg ]; then
    echo "❌ Error: .env.keys.stg not found in project root"
    echo "   Run: git pull (if in git) or create the key file"
    exit 1
fi

if [ ! -f .env.stg ]; then
    echo "❌ Error: .env.stg not found in project root"
    exit 1
fi

# Check if dotenvx is installed
if ! command -v dotenvx &> /dev/null; then
    echo "❌ Error: dotenvx not found"
    echo "   Install with: npm install -g @dotenvx/dotenvx"
    exit 1
fi

echo "🔓 Decrypting .env.stg..."

# Set decryption key
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"

# Extract environment variables from encrypted .env.stg
# Using dotenvx run to decrypt and extract specific vars
export FIREBASE_API_KEY=$(dotenvx run --env-file=.env.stg -- printenv FIREBASE_API_KEY 2>/dev/null || echo "")
export FIREBASE_PROJECT_ID=$(dotenvx run --env-file=.env.stg -- printenv FIREBASE_PROJECT_ID 2>/dev/null || echo "ui-firebase-pcioasis-stg")

# Set defaults if not found
export ENABLE_AUTH=${ENABLE_AUTH:-true}
export REQUIRE_AUTH=${REQUIRE_AUTH:-true}

if [ -z "$FIREBASE_API_KEY" ]; then
    echo "⚠️  Warning: FIREBASE_API_KEY not found in .env.stg"
    echo "   Auth will be disabled"
    export ENABLE_AUTH=false
fi

echo "✅ Environment variables loaded"
echo "   FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID"
echo "   ENABLE_AUTH: $ENABLE_AUTH"
echo "   REQUIRE_AUTH: $REQUIRE_AUTH"

# Run docker-compose with both files
docker-compose -f docker-compose.yml -f docker-compose.auth.yml "$@"
```

### 3. Usage

```bash
# Start with authentication
./deploy/docker-compose-auth.sh up -d --build

# View logs
./deploy/docker-compose-auth.sh logs -f home-index

# Stop
./deploy/docker-compose-auth.sh down
```

## Alternative: Using dotenvx in Dockerfile

If you want to decrypt inside the container, install dotenvx in your Dockerfile:

```dockerfile
# In deploy/shared-components/home-index-service/Dockerfile
FROM golang:1.21-alpine AS builder
# ... build steps ...

FROM alpine:latest
# Install dotenvx
RUN apk add --no-cache nodejs npm && \
    npm install -g @dotenvx/dotenvx

# Copy encrypted .env file
COPY .env.stg /app/.env.stg

# Use dotenvx in CMD
CMD ["dotenvx", "run", "--env-file=/app/.env.stg", "--", "./main"]
```

Then in docker-compose.yml:

```yaml
services:
  home-index:
    build: .
    environment:
      - DOTENV_PRIVATE_KEY=${DOTENV_PRIVATE_KEY}
    volumes:
      - ./.env.stg:/app/.env.stg:ro
```

## Security Best Practices

1. **Never commit `.env.keys.prd`** - Only staging keys should be in git
2. **Use `.dockerignore`** - Add `.env.keys.*` to prevent accidental inclusion
3. **Clean up temporary files** - Remove any decrypted `.env.tmp` files
4. **Use helper scripts** - Centralize the decryption logic
5. **Limit variable exposure** - Only extract variables you need, not all of them

## Troubleshooting

### "Cannot decrypt" error

```bash
# Verify the key file exists
ls -la .env.keys.stg

# Test decryption manually
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"
dotenvx decrypt -f .env.stg -fk .env.keys.stg
```

### "dotenvx: command not found"

```bash
# Install dotenvx globally
npm install -g @dotenvx/dotenvx

# Or use npx
npx @dotenvx/dotenvx --version
```

### Variables not being passed to containers

Make sure you're exporting variables before running docker-compose:

```bash
# This works
export FIREBASE_API_KEY="value"
docker-compose up

# This doesn't work (variables are in subshell)
FIREBASE_API_KEY="value" docker-compose up
```

## References

- [dotenvx Official Docs](https://dotenvx.com/)
- [dotenvx Docker Compose Guide](https://dotenvx.com/docs/platforms/docker-compose.html)
- [Project dotenvx Documentation](./deploy/secrets/DOTENVX_QUICKSTART.md)
