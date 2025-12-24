# Traefik Migration Guide

## Overview

This guide explains how to migrate from the current port-based routing to path-based routing using Traefik as a reverse proxy.

## Current State vs. Future State

### Current (Port-Based Routing)

**Local Development:**
```
http://localhost:3000      → Home page
http://localhost:9001      → Lab 1 vulnerable site
http://localhost:9002      → Lab 1 C2 server
http://localhost:9003      → Lab 2 vulnerable site
http://localhost:9004      → Lab 2 C2 server
http://localhost:9005      → Lab 3 vulnerable site
http://localhost:9006      → Lab 3 extension server
```

**Production:**
```
https://labs.pcioasis.com              → Home page
https://lab1-prd-xxx.run.app           → Lab 1 (separate URL)
https://lab1-c2-prd-xxx.run.app        → Lab 1 C2 (separate URL)
https://lab2-prd-xxx.run.app           → Lab 2 (separate URL)
...
```

### Future (Path-Based Routing)

**All Environments (Local, Staging, Production):**
```
http://localhost:8080/                 → Home page (local)
https://labs.pcioasis.com/             → Home page (production)

http://localhost:8080/lab1             → Lab 1
http://localhost:8080/lab1/c2          → Lab 1 C2 server
http://localhost:8080/lab2             → Lab 2
http://localhost:8080/lab2/c2          → Lab 2 C2 server
http://localhost:8080/lab3             → Lab 3
http://localhost:8080/lab3/extension   → Lab 3 extension server

http://localhost:8080/api/seo          → SEO service
http://localhost:8080/api/analytics    → Analytics service
```

## Benefits

1. **Consistency**: Same URL structure across all environments
2. **Simplicity**: Single port to remember (8080 locally, 443 for HTTPS)
3. **Privacy**: Full control over routing without third-party services
4. **Scalability**: Easy to add new labs
5. **Production-Like**: Local development mirrors production

## Migration Steps

### Phase 1: Local Development Setup

#### 1.1 Start Services with Traefik

```bash
# Start all services with Traefik
docker-compose -f docker-compose.traefik.yml up -d

# Verify Traefik is running
curl http://localhost:8080/ping

# Check Traefik dashboard
open http://localhost:8081/dashboard/
```

#### 1.2 Test Routes

```bash
# Run automated tests
./tests/test-traefik-routing.sh

# Or test manually
curl http://localhost:8080/
curl http://localhost:8080/lab1
curl http://localhost:8080/lab2
curl http://localhost:8080/lab3
```

#### 1.3 Update Development Workflow

Update your scripts and documentation to use the new URLs:

```bash
# Old way
open http://localhost:9001

# New way
open http://localhost:8080/lab1
```

### Phase 2: Update Lab Code

#### 2.1 Update C2 Server URLs

In lab JavaScript files, update hardcoded C2 URLs:

**Old:**
```javascript
const c2Url = 'http://localhost:9002';
```

**New:**
```javascript
// For local development
const c2Url = 'http://localhost:8080/lab1/c2';

// For production (environment-aware)
const baseUrl = window.location.origin;
const c2Url = `${baseUrl}/lab1/c2`;
```

#### 2.2 Update Internal Service References

**Old:**
```javascript
fetch('http://localhost:3001/api/seo')
```

**New:**
```javascript
fetch('/api/seo')  // Relative URL works across environments
```

#### 2.3 Search and Replace

```bash
# Find all occurrences of old URLs
grep -r "localhost:9001" labs/
grep -r "localhost:9002" labs/
grep -r "localhost:9003" labs/

# Replace (after reviewing)
find labs -type f -name "*.js" -exec sed -i '' 's|localhost:9001|localhost:8080/lab1|g' {} \;
find labs -type f -name "*.js" -exec sed -i '' 's|localhost:9002|localhost:8080/lab1/c2|g' {} \;
find labs -type f -name "*.js" -exec sed -i '' 's|localhost:9003|localhost:8080/lab2|g' {} \;
```

### Phase 3: Staging Deployment

#### 3.1 Deploy Traefik to Staging

```bash
# Deploy infrastructure
cd deploy
./deploy-labs.sh  # Uses .env.stg

# Deploy Traefik service
gh workflow run deploy-traefik.yml -f environment=stg
```

#### 3.2 Test Staging

```bash
# Set environment
export BASE_URL=https://labs.stg.pcioasis.com

# Run tests
npx playwright test tests/traefik-routing.test.ts
```

#### 3.3 Update DNS (if needed)

If not already configured:

1. Go to Cloudflare DNS settings
2. Update/create A record for `labs.stg.pcioasis.com`
3. Point to Cloud Run Traefik service IP

### Phase 4: Production Deployment

#### 4.1 Pre-Deployment Checklist

- [ ] All tests passing in staging
- [ ] DNS records configured
- [ ] SSL certificates ready
- [ ] Rollback plan documented
- [ ] Monitoring alerts configured
- [ ] Team notified of change

#### 4.2 Deploy to Production

```bash
# Deploy Traefik
gh workflow run deploy-traefik.yml -f environment=prd

# Verify deployment
curl -I https://labs.pcioasis.com/ping
```

#### 4.3 Update DNS

1. Update Cloudflare DNS for `labs.pcioasis.com`
2. Point to new Traefik Cloud Run service
3. Monitor DNS propagation

#### 4.4 Monitor and Validate

```bash
# Run production tests
export BASE_URL=https://labs.pcioasis.com
npx playwright test tests/traefik-routing.test.ts

# Check logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-prd" --limit 50

# Check metrics in Cloud Console
open https://console.cloud.google.com/run/detail/us-central1/traefik-prd/metrics
```

### Phase 5: Cleanup (Post-Migration)

#### 5.1 Deprecate Old Services

Once confident in the new setup:

1. Update GitHub Actions to not deploy individual lab services
2. Keep old services running for 1 week as backup
3. Monitor for any remaining references
4. Delete old Cloud Run services

#### 5.2 Update Documentation

- Update README with new URLs
- Update lab instructions
- Update screenshots/videos
- Archive old documentation

## Rollback Plan

If issues occur in production:

### Quick Rollback (DNS)

1. Revert DNS to point to original home service
2. Individual labs still accessible via their direct URLs
3. Traefik can remain deployed but unused

```bash
# In Cloudflare, revert A record for labs.pcioasis.com
# to point to: home-index-prd-xxx.run.app
```

### Full Rollback (Infrastructure)

1. Stop deploying Traefik
2. Revert to old docker-compose.yml
3. Update environment variables to old URLs
4. Redeploy services

```bash
# Use old docker-compose
docker-compose -f docker-compose.yml up -d

# Redeploy old services
cd deploy
./deploy-labs.sh
```

## Testing Checklist

### Local Testing

- [ ] Traefik starts without errors
- [ ] All services register with Traefik
- [ ] Home page loads at http://localhost:8080/
- [ ] Lab 1 loads at http://localhost:8080/lab1
- [ ] Lab 2 loads at http://localhost:8080/lab2
- [ ] Lab 3 loads at http://localhost:8080/lab3
- [ ] C2 servers accessible
- [ ] Static assets load correctly
- [ ] API endpoints work

### Staging Testing

- [ ] Traefik deploys successfully
- [ ] HTTPS works correctly
- [ ] All routes accessible
- [ ] IAM authentication works
- [ ] Monitoring/logging working
- [ ] Performance acceptable

### Production Testing

- [ ] All staging tests pass
- [ ] DNS resolves correctly
- [ ] SSL certificates valid
- [ ] All labs accessible
- [ ] Analytics tracking works
- [ ] No broken links
- [ ] Mobile responsive

## Common Issues and Solutions

### Issue: 404 Not Found

**Symptoms:** Accessing a lab returns 404

**Solutions:**
1. Check Traefik dashboard to see if service is registered
2. Verify service is running: `docker-compose ps`
3. Check service labels in docker-compose.traefik.yml
4. Restart Traefik: `docker-compose restart traefik`

### Issue: 502 Bad Gateway

**Symptoms:** Traefik returns 502 when accessing a lab

**Solutions:**
1. Check if backend service is running
2. View backend logs: `docker-compose logs lab1-vulnerable-site`
3. Check service health: `docker exec lab1-techgear-store wget -O- http://localhost:80`
4. Verify service port matches Traefik configuration

### Issue: Static Assets Not Loading

**Symptoms:** HTML loads but CSS/JS fails

**Solutions:**
1. Check if stripPrefix middleware is correctly configured
2. Verify paths in HTML are relative (not absolute)
3. Update asset paths to be relative: `/css/style.css` → `css/style.css`
4. Check browser console for errors

### Issue: Infinite Redirects

**Symptoms:** Browser shows "too many redirects"

**Solutions:**
1. Check if multiple middlewares are adding redirects
2. Verify X-Forwarded-Proto header handling
3. Disable HTTP to HTTPS redirect in local development
4. Check Cloud Run ingress settings

## Environment Variables Reference

### Local Development

No environment variables needed. All configuration is file-based.

### Staging/Production

Required in Cloud Run:
```bash
ENVIRONMENT=stg|prd
DOMAIN=labs.stg.pcioasis.com|labs.pcioasis.com
HOME_INDEX_URL=https://home-index-XXX.run.app
SEO_URL=https://home-seo-XXX.run.app
ANALYTICS_URL=https://labs-analytics-XXX.run.app
LAB1_URL=https://lab1-XXX.run.app
LAB1_C2_URL=https://lab1-c2-XXX.run.app
LAB2_URL=https://lab2-XXX.run.app
LAB2_C2_URL=https://lab2-c2-XXX.run.app
LAB3_URL=https://lab3-XXX.run.app
LAB3_EXTENSION_URL=https://lab3-extension-XXX.run.app
```

## Performance Tuning

### Connection Pooling

Traefik maintains connection pools to backend services. Adjust if needed:

```yaml
# In dynamic/routes.yml
http:
  services:
    lab1-vulnerable-site:
      loadBalancer:
        passHostHeader: true
        responseForwarding:
          flushInterval: 100ms
```

### Caching

Add caching middleware for static assets:

```yaml
http:
  middlewares:
    cache-static:
      headers:
        customResponseHeaders:
          Cache-Control: "public, max-age=31536000"
```

### Rate Limiting

Protect against abuse:

```yaml
http:
  middlewares:
    rate-limit-api:
      rateLimit:
        average: 100
        burst: 50
        period: 1m
```

## Security Considerations

1. **Service-to-Service Auth**: Traefik authenticates to backend services using service account
2. **IAM Policies**: Cloud Run services have proper IAM bindings
3. **HTTPS**: Always use HTTPS in production
4. **Security Headers**: Added via middleware
5. **Path Traversal**: Traefik validates all paths

## Support

For issues or questions:
1. Check Traefik logs: `docker-compose logs traefik`
2. Review GitHub Discussion #98
3. Consult Traefik documentation: https://doc.traefik.io/
4. Open an issue in the repository

## Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Local Setup | 1 week | ✅ Complete |
| Phase 2: Code Updates | 1 week | 🔄 In Progress |
| Phase 3: Staging Deploy | 1 week | ⏳ Pending |
| Phase 4: Production Deploy | 1 week | ⏳ Pending |
| Phase 5: Cleanup | 1 week | ⏳ Pending |

**Total Estimated Time**: 5 weeks

## Success Criteria

- [ ] All labs accessible via path-based routes
- [ ] Same URLs work across all environments
- [ ] No performance degradation
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Team trained on new setup
