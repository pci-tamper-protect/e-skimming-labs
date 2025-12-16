# Scripts

This directory contains utility scripts for the e-skimming-labs project.

## generate-catalog-info.sh

Generates `catalog-info.yaml` based on discovered services and labs in the repository.

### What it does

- Scans `deploy/shared-components/` for services (analytics-service, seo-service, home-index-service)
- Scans `labs/` directory for lab services (lab-01-basic-magecart, lab-02-dom-skimming, lab-03-extension-hijacking)
- Extracts git information (commit SHA, branch, author, etc.)
- Generates a comprehensive `catalog-info.yaml` file with:
  - Service metadata
  - Dependencies (services and labs)
  - Git information
  - Monitoring and security configuration

### Usage

```bash
./scripts/generate-catalog-info.sh
```

### Pre-commit Hook

A pre-commit hook (`.git/hooks/pre-commit`) automatically runs this script when:
- Any files in `deploy/shared-components/` change
- Any files in `labs/` change
- `config.yml` changes

The hook will:
1. Detect relevant changes
2. Regenerate `catalog-info.yaml`
3. Automatically add it to the commit if it changed

### Manual Regeneration

To manually regenerate the catalog info:

```bash
./scripts/generate-catalog-info.sh
git add catalog-info.yaml
git commit -m "Update catalog-info.yaml"
```

