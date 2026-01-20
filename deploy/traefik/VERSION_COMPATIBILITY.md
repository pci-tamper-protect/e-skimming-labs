# Traefik Version Compatibility

## Current Configuration

**Production (e-skimming-labs):**
- **Traefik Version**: v3.0
- **Plugin Mode**: Local plugin (experimental.localPlugins)
- **Plugin Location**: `/plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider`
- **Required Files**: `.traefik.yml` (plugin manifest)

**Testing (traefik-cloudrun-provider examples):**
- **Traefik Version**: v2.10 (for E2E testing)
- **Note**: v2.10 doesn't support local plugins, so examples use Docker provider

## Version Requirements

### Traefik v3.0 (Production)
- ✅ Supports `experimental.localPlugins`
- ✅ Requires `.traefik.yml` in plugin directory
- ✅ Compiles plugins at runtime
- ✅ Uses `github.com/traefik/genconf v0.5.2` (compatible)

### Traefik v2.10 (Testing Only)
- ❌ Does NOT support `experimental.localPlugins`
- ❌ Cannot use local plugin mode
- ✅ Can use Docker provider for testing
- ⚠️ Examples in `traefik-cloudrun-provider` use v2.10 for E2E testing

## Plugin Compatibility

The `traefik-cloudrun-provider` plugin:
- **Designed for**: Traefik v3.0 (local plugin mode)
- **Uses**: `github.com/traefik/genconf v0.5.2` (v3.0 compatible)
- **Requires**: `.traefik.yml` manifest file
- **Location**: Must be in `/plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider`

## Verification

To verify Traefik version in production:
```bash
# Check Dockerfile
grep "FROM traefik:" deploy/traefik/Dockerfile.cloudrun
# Should show: FROM traefik:v3.0

# Check running container
docker run --rm <traefik-image> traefik version
# Should show: v3.0.x
```

## Important Notes

1. **Do NOT change Traefik version** in `Dockerfile.cloudrun` without updating the plugin
2. **Local plugin mode** is only available in Traefik v3.0+
3. **E2E tests** in `traefik-cloudrun-provider` use v2.10 for Docker provider testing (not local plugins)
4. **Production** must use v3.0 for local plugin support
