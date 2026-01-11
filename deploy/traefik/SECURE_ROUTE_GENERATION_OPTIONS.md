# Secure Route Generation Options

## Security Concern

Traefik is the **outermost, most exposed service** that receives all user traffic. Granting it `roles/run.viewer` (project-level read access to all Cloud Run services) is a security risk:
- If Traefik is compromised, attacker can enumerate all services
- Violates principle of least privilege
- Traefik should only have permissions to **route traffic**, not **discover services**

## Current Architecture

**Runtime generation** (current approach):
- Traefik container runs `generate-routes-from-labels.sh` at startup
- Script queries Cloud Run Admin API to discover services
- Requires `roles/run.viewer` permission on Traefik SA
- **Problem**: Grants Traefik broad read access

## Option 1: Deploy-Time Generation (RECOMMENDED)

**Generate routes.yml in GitHub Actions, bake into image**

### How it works:
1. **During Traefik deployment** (GitHub Actions):
   - Run `generate-routes-from-labels.sh` in the CI/CD environment
   - Generate `routes.yml` with all current services
   - Copy `routes.yml` into Docker image
   - Deploy Traefik with pre-generated routes

2. **When other services deploy**:
   - Option A: Trigger Traefik redeploy (updates routes.yml)
   - Option B: Update routes.yml in a shared location (Cloud Storage, ConfigMap)
   - Option C: Accept that routes update on next Traefik deploy

### Pros:
- ✅ **No runtime permissions needed** - Traefik only reads a file
- ✅ **Follows Traefik principle** - Container is simple, routing config is external
- ✅ **Secure** - Traefik SA doesn't need `run.viewer`
- ✅ **Fast** - No API calls at startup
- ✅ **Deterministic** - Routes are known at build time

### Cons:
- ⚠️ Routes only update when Traefik is redeployed
- ⚠️ Need to handle service deployments that happen between Traefik deploys

### Implementation:
```yaml
# .github/workflows/deploy_labs.yml
- name: Generate routes.yml
  run: |
    ./deploy/traefik/generate-routes-from-labels.sh deploy/traefik/dynamic/routes.yml
    
- name: Build Traefik image
  run: |
    docker build -f deploy/traefik/Dockerfile.cloudrun -t traefik-stg .
    # routes.yml is already in deploy/traefik/dynamic/ from previous step
```

## Option 2: Separate Read-Only Service Account

**Create minimal SA just for discovery, Traefik uses it**

### How it works:
1. Create `traefik-discovery-stg@labs-stg.iam.gserviceaccount.com`
2. Grant it `roles/run.viewer` (read-only)
3. Traefik container uses this SA for API calls (via workload identity or token)
4. Traefik's main SA stays minimal

### Pros:
- ✅ Traefik's main SA stays secure
- ✅ Separation of concerns
- ✅ Can revoke discovery SA independently

### Cons:
- ⚠️ Still grants read access (just to a different SA)
- ⚠️ More complex (two SAs, workload identity setup)
- ⚠️ Traefik still needs to make API calls at runtime

## Option 3: Event-Driven Updates (Cloud Scheduler/Eventarc)

**Separate service watches for changes, updates routes**

### How it works:
1. Create separate `traefik-route-updater` Cloud Run service
2. Grant it `roles/run.viewer` (not Traefik)
3. Service watches for Cloud Run changes (Eventarc) or polls periodically
4. Updates routes.yml in Cloud Storage or triggers Traefik config update
5. Traefik reads from file (no API calls)

### Pros:
- ✅ Traefik stays simple (just reads file)
- ✅ Real-time updates possible
- ✅ Traefik SA has no extra permissions

### Cons:
- ⚠️ Another service to maintain
- ⚠️ More moving parts
- ⚠️ Complexity

## Option 4: Custom Role with Service-Level Permissions

**Grant only `run.services.get` on specific services**

### How it works:
1. Create custom role with only `run.services.get`
2. Grant it at service level (not project level)
3. Only on services Traefik needs to discover

### Pros:
- ✅ More restrictive than `roles/run.viewer`
- ✅ Can limit to specific services

### Cons:
- ⚠️ Still grants Traefik read access
- ⚠️ Complex to maintain (need to grant on each new service)
- ⚠️ Doesn't solve the security concern

## Recommendation: Option 1 (Deploy-Time Generation)

**Why:**
1. **Most secure** - Traefik has zero extra permissions
2. **Simplest** - No new services, no complex SA setup
3. **Follows Traefik principle** - Container is simple, config is external
4. **Fast startup** - No API calls needed
5. **Deterministic** - Routes are known at build time

**Trade-off:**
- Routes update when Traefik is redeployed (not immediately when services deploy)
- **Mitigation**: Deploy Traefik when deploying services, or accept slight delay

**Implementation steps:**
1. Move route generation to GitHub Actions
2. Generate routes.yml during Traefik build
3. Remove runtime generation from entrypoint.sh
4. Remove `run.viewer` permission requirement
5. Update deployment workflow to generate routes before building image

## Comparison

| Option | Security | Complexity | Update Speed | Traefik Permissions |
|--------|---------|------------|--------------|-------------------|
| 1. Deploy-time | ✅✅✅ | ✅✅✅ | ⚠️ On deploy | ✅ None needed |
| 2. Separate SA | ✅✅ | ⚠️ Medium | ✅ Real-time | ✅ None needed |
| 3. Event-driven | ✅✅✅ | ❌ High | ✅✅ Real-time | ✅ None needed |
| 4. Custom role | ✅ | ⚠️ Medium | ✅ Real-time | ⚠️ Minimal read |
| Current (run.viewer) | ❌ | ✅ Simple | ✅ Real-time | ❌ Project read |



