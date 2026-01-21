# Plan: Split C2 Services to Match Local Architecture

## Current State

### Local (docker-compose.yml)
- ✅ `lab1-vulnerable-site` container (nginx + vulnerable site on port 80)
- ✅ `lab1-c2-server` container (C2 server on port 3000)
- ✅ Traefik routes `/lab1/c2` → strips `/lab1/c2` → `/` → C2 container

### Cloud Run (Current)
- ❌ Single container: `lab-01-basic-magecart-stg` (nginx + C2 via init.sh)
- ❌ Traefik routes `/lab1/c2` → strips `/lab1/c2` → `/` → nginx → doesn't match `/c2` location → 502

## Proposed State

### Cloud Run (After Split)
- ✅ `lab-01-basic-magecart-stg` container (nginx + vulnerable site only)
- ✅ `lab-01-basic-magecart-c2-stg` container (C2 server only)
- ✅ Traefik routes `/lab1/c2` → strips `/lab1/c2` → `/` → C2 container (same as local!)

## Changes Required

### 1. Update Main Lab Dockerfile
**File**: `labs/01-basic-magecart/Dockerfile`
- Remove C2 server installation
- Remove init.sh (or simplify to just start nginx)
- Remove node/npm installation (not needed if C2 is separate)

### 2. Update nginx.conf
**File**: `labs/01-basic-magecart/vulnerable-site/nginx.conf`
- Remove `/c2` proxy location block (C2 is now separate service)

### 3. Update Workflow
**File**: `.github/workflows/deploy_labs.yml`
- Add step to build and deploy C2 service separately
- Update Traefik labels for C2 to point to separate service
- Update C2 service to use port 3000 (or 8080 for Cloud Run)

### 4. Update Traefik Labels
**File**: `.github/workflows/deploy_labs.yml`
- Change `traefik_http_routers_lab1-c2_service=lab1` → `traefik_http_routers_lab1-c2_service=lab1-c2-server`
- Update service port to 8080 (Cloud Run standard) or keep 3000 if C2 uses that

### 5. Update C2 Dockerfile for Cloud Run
**File**: `labs/01-basic-magecart/malicious-code/c2-server/Dockerfile`
- Ensure it listens on port 8080 (Cloud Run requirement) or update Cloud Run to use port 3000
- Cloud Run requires services to listen on the port specified in `--port` flag

## Benefits

1. **Architecture Consistency**: Local and Cloud Run match exactly
2. **Simpler Routing**: Same middleware works for both environments
3. **No Nginx Proxy**: C2 is accessed directly, no proxy complexity
4. **Easier Debugging**: Issues are isolated to specific services
5. **Better Scaling**: Can scale C2 and main site independently

## Implementation Steps

### ✅ Completed
1. ✅ Updated C2 server.js to use `process.env.PORT || 3000` (works for both local and Cloud Run)
2. ✅ Updated C2 Dockerfile to expose both ports (8080 for Cloud Run, 3000 for local)

### 🔲 Remaining Steps
1. Update workflow to build and deploy C2 as separate service
   - Build C2 image from `labs/01-basic-magecart/malicious-code/c2-server/Dockerfile`
   - Deploy as `lab-01-basic-magecart-c2-stg` with `--port=8080`
   - Add Traefik labels for C2 service
   
2. Update main lab Dockerfile
   - Remove C2 server installation (node, npm, C2 files)
   - Remove init.sh or simplify to just start nginx
   - Remove C2-related code

3. Update nginx.conf
   - Remove `/c2` proxy location block (C2 is now separate service)

4. Update Traefik labels in workflow
   - Change `traefik_http_routers_lab1-c2_service=lab1` → `traefik_http_routers_lab1-c2_service=lab1-c2-server`
   - Update service port to 8080 in labels

5. Test locally (should still work - docker-compose already sets PORT=3000)
6. Deploy to staging
7. Verify routing works

## Decisions Made

1. **Port**: C2 will use port 8080 for Cloud Run (required), 3000 for local
   - ✅ Updated `server.js` to use `process.env.PORT || 3000`
   - ✅ Cloud Run will set `PORT=8080` automatically
   - ✅ Local docker-compose can set `PORT=3000` or use default

2. **Service Name**: Use `lab-01-basic-magecart-c2-stg` format
   - Matches workflow pattern: `lab-${{ matrix.lab }}-c2-${{ needs.setup.outputs.environment }}`

3. **Auth**: C2 does NOT need auth middleware
   - C2 is the attacker's server - should be accessible
   - Current labels don't include auth for C2 route
   - Keep it public (matches the attack scenario)
