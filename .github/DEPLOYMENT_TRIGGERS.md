# Deployment Triggers and Force Keywords

## Overview

The `deploy_labs.yml` workflow is configured to only deploy containers when their specific code changes, reducing unnecessary builds and deployments. Force keywords in commit messages allow you to override this behavior.

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

## Force Deployment Keywords

When you need to force a deployment regardless of code changes, include these keywords in your commit message:

### `[force-all]` or `force-all`
Deploys all components (home and labs):
```bash
git commit -m "Update config [force-all]"
git push origin feature/branch
```

### `[force-home]` or `force-home`
Deploys only home components (SEO and Index services):
```bash
git commit -m "Fix SEO service [force-home]"
git push origin feature/branch
```

### `[force-labs]` or `force-labs`
Deploys only labs components (Analytics, individual labs, and labs index):
```bash
git commit -m "Update labs [force-labs]"
git push origin feature/branch
```

**Advantages of commit message keywords:**
- ✅ Works on any branch (feature branches, stg, main)
- ✅ Can be reused multiple times
- ✅ No tag management needed
- ✅ Works immediately (no need to merge workflow first)
- ✅ Case-insensitive matching

## How It Works

1. **Change Detection**: The workflow compares changed files against the base branch (for PRs) or previous commit (for pushes)
2. **Keyword Detection**: Checks commit message for `[force-all]`, `[force-home]`, or `[force-labs]` keywords
3. **Component Mapping**: Changes/keywords are mapped to specific components:
   - Home components → `deploy_home=true`
   - Labs components → `deploy_labs=true`
4. **Job Conditions**: Each deployment job only runs if its corresponding flag is `true`

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
git commit -m "Infrastructure update [force-all]"
git push origin feature/infra-update

# All components deploy regardless of code changes
```

### Example 4: Force Labs Only
```bash
# Force redeploy labs (e.g., after fixing deployment issue)
git commit -m "Fix deployment [force-labs]"
git push origin feature/fix-deploy

# Only labs components deploy
```

## Environment Detection

The workflow automatically determines the target environment:
- **PRs against `stg`** → Deploy to `labs-stg` and `labs-home-stg`
- **PRs against `main`** → Deploy to `labs-prd` and `labs-home-prd`
- **Push to `stg` branch** → Deploy to `labs-stg` and `labs-home-stg`
- **Push to `main` branch** → Deploy to `labs-prd` and `labs-home-prd`

## Manual Trigger

You can also manually trigger the workflow via GitHub Actions UI:
1. Go to Actions → Deploy CloudRun
2. Click "Run workflow"
3. Select environment (stg or prd)
4. This will deploy ALL components (both home and labs)

## Image Caching

The workflow checks if Docker images already exist before building:
- If an image with the current SHA tag exists, the build step is skipped
- This saves time and resources when force-keywording without code changes
- Images are still pushed to ensure the latest tag is updated

## Troubleshooting

### Containers Not Deploying

1. **Check if paths match**: Ensure your changes are in the monitored paths
2. **Check job conditions**: Look at the workflow run to see if jobs were skipped
3. **Use force keywords**: If you need to deploy, add `[force-all]`, `[force-home]`, or `[force-labs]` to your commit message

### Force Keyword Not Working

1. **Check keyword spelling**: Must be `[force-all]`, `[force-home]`, or `[force-labs]` (case-insensitive)
2. **Check commit message**: Keyword must be in the commit message, not just the PR title
3. **Check workflow logs**: Look at the "Detect changes and force keywords" step output
