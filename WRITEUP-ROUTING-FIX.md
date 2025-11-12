# Writeup Routing Fix - Step by Step

## Problem
Clicking "Writeup" button gives: `Lab writeup not found: 01-basic-magecart`

## Root Cause
The README files are not in the Docker container at `/app/docs/labs/{lab-id}/README.md` because:
1. The Dockerfile needs to copy the README files from their original location (`labs/{lab-id}/README.md`)
2. The container needs to be rebuilt to include these files

## Architecture
- **Source location**: `labs/{lab-id}/README.md` (docs stay close to code, no duplication)
- **Container location**: `/app/docs/labs/{lab-id}/README.md` (copied during build)
- **Local dev**: Reads directly from `labs/{lab-id}/README.md` (no duplication needed)

## Solution Steps

### Step 1: Rebuild the container
```bash
docker-compose build home-index
docker-compose up -d home-index
```

### Step 2: Verify files are in container
```bash
docker exec e-skimming-labs-home-index ls -la /app/docs/labs/
docker exec e-skimming-labs-home-index test -f /app/docs/labs/01-basic-magecart/README.md && echo "✅ File exists"
```

### Step 3: Test the route
```bash
curl http://localhost:3000/lab-01-writeup
```

### Step 4: Check logs if still failing
```bash
docker logs e-skimming-labs-home-index | grep -i writeup
```

## Architecture

- **No nginx routing involved** - The Go service handles routing directly
- **Routes**: `/lab-01-writeup`, `/lab-02-writeup`, `/lab-03-writeup`
- **Source files**: `labs/{lab-id}/README.md` (original location, no duplication)
- **Container paths**: `/app/docs/labs/{lab-id}/README.md` (copied during build)
- **Dockerfile copies**: Individual README files from `labs/` to `docs/labs/` during build

## Debugging

Use the debug script:
```bash
./debug-writeup.sh
```

This will:
1. Check if files exist locally
2. Check if container is running
3. Check if files exist in container
4. Test the routes
5. Show container logs

## Added Logging

The Go service now logs:
- Which path it's trying
- Success/failure of file reads
- Contents of `/app/docs` if file not found

View logs with:
```bash
docker logs -f e-skimming-labs-home-index
```
