# Docker Build Optimization Guide

## Current State

Currently, Docker images are built and pushed on:
1. Every Terraform run (via `build-images.sh`)
2. Every GitHub PR (via `deploy_labs.yml` workflow)

This can be wasteful if the source code hasn't changed.

## Best Practices

### ✅ Recommended Approach: Content Hash Checking

**Option 1: Check if image already exists (Simple)**
- Check if image with same tag already exists in Artifact Registry
- Skip build if image exists
- Pros: Simple, fast
- Cons: Doesn't detect content changes if using `latest` tag

**Option 2: Content-based hashing (Better)**
- Calculate hash of source files (Dockerfile, source code, dependencies)
- Tag images with content hash: `image:content-hash` and `image:latest`
- Check if content hash already exists before building
- Pros: Detects actual content changes, more efficient
- Cons: More complex, requires hash calculation

**Option 3: Git SHA-based (Current in GHA)**
- GitHub Actions already uses `${{ github.sha }}` for tags
- Each commit gets unique tag
- Docker layer caching via `cache-from: type=gha`
- Pros: Already implemented, commit-based versioning
- Cons: Still builds on every PR even if code unchanged

## Implementation Recommendations

### For Local Scripts (`build-images.sh`)

1. **Check if image exists before building:**
   ```bash
   if gcloud artifacts docker images describe "$IMAGE" &>/dev/null; then
       echo "Image already exists, skipping build"
       return 0
   fi
   ```

2. **Use content hash for `latest` tag:**
   - Calculate hash of source files
   - Check if image with that hash exists
   - Only build if hash changed

### For GitHub Actions

1. **Already optimized with:**
   - `cache-from: type=gha` - Uses GitHub Actions cache
   - `cache-to: type=gha,mode=max` - Saves layers for next build
   - SHA-based tags - Each commit gets unique tag

2. **Additional optimization:**
   - Check if image with `${{ github.sha }}` already exists
   - Skip build if image already pushed (useful for re-runs)
   - Use `paths` filter to only build when relevant files change

## Example: Optimized Build Script

See `build-images-optimized.sh` for an implementation that:
- Calculates content hash of source files
- Checks if image already exists
- Only builds/pushes if content changed or image missing

## When to Build

**Always build:**
- Source code changed (detected via git diff or content hash)
- Dependencies changed (go.mod, package.json, etc.)
- Dockerfile changed

**Skip build:**
- Image with same content hash already exists
- No relevant files changed (for PRs with `paths` filter)

## Trade-offs

**Building every time:**
- ✅ Always up-to-date
- ✅ Simple
- ❌ Wastes time/resources
- ❌ Slower CI/CD

**Content hash checking:**
- ✅ Efficient
- ✅ Faster CI/CD
- ✅ Saves resources
- ❌ More complex
- ❌ Need to handle hash collisions (unlikely with SHA256)

## Recommendation

For **local scripts**: Use content hash checking (see `build-images-optimized.sh`)

For **GitHub Actions**: 
- Keep current approach (SHA tags + caching)
- Add check to skip if image with SHA already exists
- Use `paths` filter to only trigger on relevant file changes

