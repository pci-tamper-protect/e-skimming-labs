# Traefik Implementation Plan

This document outlines all files that need to be created or modified to implement the Traefik routing design.

## Overview

The implementation is divided into three phases:
1. **Local Development Setup** - Add Traefik to docker-compose
2. **Production Deployment** - Deploy Traefik to Cloud Run
3. **Testing & Documentation** - Update tests and docs

## Files to Create

### Traefik Configuration Files

1. **`deploy/traefik/traefik.yml`**
   - Main Traefik configuration
   - Entry points, providers, logging
   - Used by both local and production

2. **`deploy/traefik/dynamic/routes.yml`** (Production only)
   - Cloud Run service URLs
   - Environment-specific routing rules
   - Loaded via file provider

3. **`deploy/traefik/Dockerfile`**
   - Traefik container image
   - Includes configuration files
   - Used for Cloud Run deployment

4. **`deploy/traefik/.dockerignore`**
   - Exclude unnecessary files from Docker build

5. **`deploy/traefik/README.md`**
   - Traefik configuration documentation
   - Local vs production differences
   - Troubleshooting guide

### Terraform Files

6. **`deploy/terraform-labs/traefik.tf`** (New)
   - Cloud Run service for Traefik
   - IAM bindings
   - Environment variables
   - Domain mapping

7. **`deploy/terraform-labs/variables.tf`** (Modify)
   - Add Traefik-related variables:
     - `traefik_image`
     - `traefik_memory_limit`
     - `traefik_cpu_limit`

### GitHub Actions Workflows

8. **`.github/workflows/deploy_traefik.yml`** (New)
   - Build and push Traefik Docker image
   - Deploy to Cloud Run
   - Update routing configuration

9. **`.github/workflows/deploy_labs.yml`** (Modify)
   - Update to mark lab services as internal-only
   - Add Traefik dependency

### Documentation

10. **`docs/TRAEFIK_ROUTING_DESIGN.md`** (Rewrite)
    - Already completed - proper markdown format

11. **`docs/TRAEFIK_DEPLOYMENT.md`** (New)
    - Step-by-step deployment guide
    - Local setup instructions
    - Production deployment checklist
    - Troubleshooting

12. **`docs/LOCAL_DEVELOPMENT.md`** (Modify)
    - Update with Traefik routing
    - Remove port-based instructions
    - Add Traefik dashboard access

## Files to Modify

### Docker Compose

13. **`docker-compose.yml`** (Major changes)
    - Add Traefik service
    - Remove port mappings from all services (except Traefik)
    - Add Traefik labels to all services
    - Update network configuration
    - Add Traefik dashboard service

### Service Code

14. **`deploy/shared-components/home-index-service/main.go`**
    - Update URL generation to use path-based routing
    - Remove port-based URL construction
    - Update lab URLs to use `/lab1`, `/lab2`, `/lab3` paths

15. **`labs/01-basic-magecart/vulnerable-site/nginx.conf`** (If exists)
    - Ensure base path handling works correctly
    - May need to update asset paths

16. **`labs/02-dom-skimming/vulnerable-site/nginx.conf`** (If exists)
    - Ensure base path handling works correctly
    - May need to update asset paths

17. **`labs/03-extension-hijacking/vulnerable-site/nginx.conf`** (If exists)
    - Ensure base path handling works correctly
    - May need to update asset paths

### Terraform Configuration

18. **`deploy/terraform-labs/cloud-run.tf`** (Modify)
    - Mark lab services as internal-only (no public IAM)
    - Add annotations for Traefik routing
    - Update service URLs to use internal Cloud Run URLs

19. **`deploy/terraform-labs/domain-mapping.tf`** (Modify or create)
    - Map `labs.pcioasis.com` to Traefik service
    - Remove individual lab domain mappings (if any)

20. **`deploy/terraform-labs/outputs.tf`** (Modify)
    - Add Traefik service URL output
    - Update lab service URLs to use Traefik paths

### Test Files

21. **`test/config/test-env.js`** (Modify)
    - Update URLs to use path-based routing
    - Remove port numbers
    - Update for both local (`localhost`) and production (`labs.pcioasis.com`)

22. **`test/e2e/*.spec.js`** (Review all)
    - Update any hardcoded URLs
    - Ensure paths work with Traefik routing
    - Test path stripping behavior

23. **`test/playwright.config.js`** (Modify)
    - Update base URL configuration
    - Remove port-based URLs

### Scripts

24. **`scripts/generate-catalog-info.sh`** (Review)
    - May need updates if it references service URLs

25. **`deploy/deploy-labs.sh`** (Modify)
    - Add Traefik deployment step
    - Update service deployment order

26. **`deploy/deploy-home.sh`** (Modify)
    - Ensure Traefik is deployed before other services

### Configuration Files

27. **`config.yml`** (Review)
    - Update any URL references
    - Add Traefik configuration if needed

## Implementation Checklist

### Phase 1: Local Development

- [ ] Create `deploy/traefik/traefik.yml`
- [ ] Create `deploy/traefik/dynamic/` directory structure
- [ ] Modify `docker-compose.yml`:
  - [ ] Add Traefik service
  - [ ] Add labels to all services
  - [ ] Remove port mappings
- [ ] Update `home-index-service/main.go` for path-based URLs
- [ ] Test locally with `docker-compose up`
- [ ] Verify Traefik dashboard at `localhost:8080`
- [ ] Test all routes: `/`, `/lab1`, `/lab2`, `/lab3`, `/mitre-attack`, `/threat-model`
- [ ] Update `docs/LOCAL_DEVELOPMENT.md`

### Phase 2: Production Deployment

- [ ] Create `deploy/traefik/Dockerfile`
- [ ] Create `deploy/traefik/dynamic/routes.yml` with Cloud Run URLs
- [ ] Create `deploy/terraform-labs/traefik.tf`
- [ ] Update `deploy/terraform-labs/variables.tf`
- [ ] Update `deploy/terraform-labs/cloud-run.tf` to mark services as internal
- [ ] Create `.github/workflows/deploy_traefik.yml`
- [ ] Update `.github/workflows/deploy_labs.yml`
- [ ] Deploy Traefik to staging
- [ ] Test staging routes
- [ ] Deploy Traefik to production
- [ ] Test production routes
- [ ] Update Cloudflare DNS if needed

### Phase 3: Testing & Documentation

- [ ] Update `test/config/test-env.js`
- [ ] Update all Playwright test files
- [ ] Run full test suite locally
- [ ] Run full test suite in CI
- [ ] Create `docs/TRAEFIK_DEPLOYMENT.md`
- [ ] Update `docs/ARCHITECTURE.md` with Traefik
- [ ] Update `README.md` with new routing information

## Migration Strategy

### Step-by-Step Migration

1. **Deploy Traefik alongside existing services** (no breaking changes)
2. **Test Traefik routing** while keeping old URLs working
3. **Update service URLs gradually** (one service at a time)
4. **Update tests** to use new paths
5. **Remove old port mappings** from docker-compose
6. **Mark lab services as internal** in Cloud Run
7. **Update documentation** and remove old references

### Rollback Plan

- Keep old port mappings in docker-compose until fully tested
- Keep lab services publicly accessible until Traefik is verified
- Maintain both routing methods during transition period
- Document rollback steps in case of issues

## Testing Requirements

### Local Testing

- [ ] All routes accessible via `localhost/`
- [ ] Path stripping works correctly
- [ ] Static assets load correctly
- [ ] C2 servers accessible via `/lab*/c2`
- [ ] Traefik dashboard accessible
- [ ] Health checks work

### Production Testing

- [ ] All routes accessible via `labs.pcioasis.com/`
- [ ] Lab services not directly accessible (internal-only)
- [ ] Authentication works with Traefik
- [ ] Playwright tests pass
- [ ] Performance is acceptable
- [ ] Error handling works correctly

## Estimated Effort

- **Phase 1 (Local)**: 4-6 hours
- **Phase 2 (Production)**: 6-8 hours
- **Phase 3 (Testing)**: 4-6 hours
- **Total**: 14-20 hours**

## Dependencies

- Traefik v2.11+ installed locally (via Docker)
- Cloud Run API enabled in GCP projects
- Terraform access to modify infrastructure
- GitHub Actions workflow access
- DNS access (Cloudflare) for domain mapping

## Notes

- Traefik dashboard should only be accessible in local development
- Production Traefik should not expose dashboard
- Consider adding authentication to Traefik dashboard in local dev
- Monitor Cloud Run costs during initial deployment
- Keep old routing working during transition period

