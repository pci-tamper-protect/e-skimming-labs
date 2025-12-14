# Deployment Triggers and Force Tags

## Overview

The `deploy_labs.yml` workflow is configured to only deploy containers when their specific code changes, reducing unnecessary builds and deployments. Force tags are available to override this behavior.

## Automatic Deployment Triggers

### Path-Based Triggers

The workflow only triggers on PRs when changes are made to relevant paths:

**Home Components** (deploy-home-components job):
- `deploy/shared-components/seo-service/**`
- `deploy/shared-components/home-index-service/**`
- `deploy/Dockerfile.index`

**Labs Components** (deploy-labs-components, deploy-labs, deploy-index jobs):
- `deploy/shared-components/analytics-service/**`
- `labs/**` (any lab directory)
- `deploy/Dockerfile.index`

**Workflow Changes**:
- `.github/workflows/deploy_labs.yml` (triggers all deployments for safety)

### Ignored Paths

The following paths are ignored and will NOT trigger deployments:
- `test/**`
- `**/*.spec.js`
- `**/playwright.config.js`
- `**/test/**`
- `labs/**/test/**`
- `labs/**/README.md`
- `labs/**/*.md`

## Force Deployment Tags

When you need to force a deployment regardless of code changes, use these git tags:

### `force-all`
Deploys all components (home and labs):
```bash
git tag force-all
git push origin force-all
```

### `force-home`
Deploys only home components (SEO and Index services):
```bash
git tag force-home
git push origin force-home
```

### `force-labs`
Deploys only labs components (Analytics, individual labs, and labs index):
```bash
git tag force-labs
git push origin force-labs
```

## How It Works

1. **Change Detection**: The workflow compares changed files against the base branch (for PRs) or previous commit (for pushes)
2. **Component Mapping**: Changes are mapped to specific components:
   - Home components → `deploy_home=true`
   - Labs components → `deploy_labs=true`
3. **Job Conditions**: Each deployment job only runs if its corresponding flag is `true`
4. **Force Tags**: Tags override change detection and force deployment of specified components

## Examples

### Example 1: Only Home Code Changed
```bash
# Change SEO service code
git commit -m "Update SEO service"
git push origin feature/update-seo

# PR is created → Only home components deploy
```

### Example 2: Only Lab Code Changed
```bash
# Change lab-01 code
git commit -m "Update lab-01"
git push origin feature/update-lab1

# PR is created → Only labs components deploy
```

### Example 3: Force All Deployments
```bash
# Force deploy everything (e.g., after infrastructure changes)
git tag force-all
git push origin force-all

# All components deploy regardless of code changes
```

### Example 4: Force Labs Only
```bash
# Force redeploy labs (e.g., after fixing deployment issue)
git tag force-labs
git push origin force-labs

# Only labs components deploy
```

## Environment Detection

The workflow automatically determines the target environment:
- **PRs against `stg`** → Deploy to `labs-stg` and `labs-home-stg`
- **PRs against `main`** → Deploy to `labs-prd` and `labs-home-prd`
- **Push to `stg` branch** → Deploy to `labs-stg` and `labs-home-stg`
- **Push to `main` branch** → Deploy to `labs-prd` and `labs-home-prd`
- **Tags** → Use the branch they were created from (stg → stg, main → prd)

## Manual Trigger

You can also manually trigger the workflow via GitHub Actions UI:
1. Go to Actions → Deploy CloudRun
2. Click "Run workflow"
3. Select environment (stg or prd)
4. This will deploy ALL components (both home and labs)

## Image Caching

The workflow checks if Docker images already exist before building:
- If an image with the current SHA tag exists, the build step is skipped
- This saves time and resources when force-tagging without code changes
- Images are still pushed to ensure the latest tag is updated

## Troubleshooting

### Containers Not Deploying

1. **Check if paths match**: Ensure your changes are in the monitored paths
2. **Check job conditions**: Look at the workflow run to see if jobs were skipped
3. **Use force tags**: If you need to deploy, use `force-all`, `force-home`, or `force-labs`

### Force Tag Not Working

1. **Check tag name**: Must be exactly `force-all`, `force-home`, or `force-labs`
2. **Check push**: Tag must be pushed to the remote repository
3. **Check workflow logs**: Look at the "Detect changes and force tags" step output

