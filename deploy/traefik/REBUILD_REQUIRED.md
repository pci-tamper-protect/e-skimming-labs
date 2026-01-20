# Traefik Image Rebuild Required

## Problem
The deployed Traefik image is using the **old architecture** (entrypoint.sh, no plugin). It needs to be rebuilt with the **new plugin architecture**.

## Verification Results
- ❌ Wrong entrypoint script (using old entrypoint.sh instead of entrypoint-plugin.sh)
- ❌ Plugin directory missing (plugins-local/ not in image)
- ❌ Missing experimental.localPlugins configuration
- ❌ .traefik.yml not in image

## Root Cause
The image was built **before** we:
1. Added `setup-plugin.sh` call to `build-and-push.sh`
2. Switched to `entrypoint-plugin.sh`
3. Added plugin source to Dockerfile
4. Updated `traefik.cloudrun.yml` with `experimental.localPlugins`

## Solution: Rebuild and Redeploy

### Option 1: Use build-and-push.sh (Recommended)
```bash
cd e-skimming-labs/deploy/traefik
./build-and-push.sh stg
./deploy.sh stg
```

This will:
1. ✅ Call `setup-plugin.sh` to copy plugin source
2. ✅ Build image with plugin included
3. ✅ Deploy to Cloud Run

### Option 2: Use deploy-all-stg.sh
```bash
cd e-skimming-labs/deploy
./deploy-all-stg.sh --force-rebuild
```

This will rebuild all services including Traefik.

## Verification After Rebuild

After rebuilding, verify the new image:

```bash
./deploy/traefik/debug/verify-deployed-image.sh stg
```

Expected results:
- ✅ Using entrypoint-plugin.sh
- ✅ Plugin directory exists
- ✅ .traefik.yml exists
- ✅ Has experimental.localPlugins configuration
- ✅ Go is available

## What Changed

### Before (Old Image)
- Entrypoint: `entrypoint.sh` (legacy, generates routes.yml)
- Config: `traefik.yml` (no plugin config)
- No plugin source in image
- No `.traefik.yml` manifest

### After (New Image)
- Entrypoint: `entrypoint-plugin.sh` (simplified, plugin handles routes)
- Config: `traefik.cloudrun.yml` (with experimental.localPlugins)
- Plugin source in `/plugins-local/`
- `.traefik.yml` manifest in plugin directory

## Troubleshooting

If rebuild still fails:

1. **Check setup-plugin.sh runs successfully:**
   ```bash
   cd deploy/traefik
   ./setup-plugin.sh
   ls -la plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider/
   ```

2. **Verify plugin source exists:**
   ```bash
   ls -la ../traefik-cloudrun-provider/.traefik.yml
   ls -la ../traefik-cloudrun-provider/plugin/
   ```

3. **Check Dockerfile copies correctly:**
   ```bash
   docker build -f Dockerfile.cloudrun -t traefik-test .
   docker run --rm --user root traefik-test ls -la /plugins-local/
   ```

4. **Verify entrypoint:**
   ```bash
   docker run --rm --user root --entrypoint cat traefik-test /entrypoint.sh | head -5
   ```
