# Traefik Routing - Complete Guide

## 🚀 Quick Start

New to Traefik setup? Start here:

1. **[Quick Start Guide](./TRAEFIK-QUICKSTART.md)** - Get running in 5 minutes
2. **[Implementation Summary](../TRAEFIK-IMPLEMENTATION-SUMMARY.md)** - What was built and why
3. **[Architecture Design](./traefik-architecture.md)** - Deep dive into the design
4. **[Migration Guide](./traefik-migration-guide.md)** - How to migrate from old setup

## 📚 Documentation Index

### Getting Started
- **[Quick Start](./TRAEFIK-QUICKSTART.md)** - Fast setup and common commands
- **[Implementation Summary](../TRAEFIK-IMPLEMENTATION-SUMMARY.md)** - Overview of what was implemented

### Design & Architecture
- **[Architecture Design](./traefik-architecture.md)** - Complete architecture documentation
  - Problem statement
  - Proposed solution
  - Routing configuration
  - Environment-specific configs
  - Security considerations

### Migration & Deployment
- **[Migration Guide](./traefik-migration-guide.md)** - Step-by-step migration plan
  - Current vs. future state
  - Migration phases
  - Testing checklist
  - Rollback procedures
  - Troubleshooting

### Configuration & Usage
- **[Traefik Config README](../deploy/traefik/README.md)** - Traefik configuration details
  - Directory structure
  - Adding new labs
  - Debugging guide
  - Environment variables

## 🎯 Common Tasks

### Local Development

**Start services:**
```bash
docker-compose -f docker-compose.traefik.yml up -d
```

**Access services:**
- Home: http://localhost:8080/
- Lab 1: http://localhost:8080/lab1
- Lab 2: http://localhost:8080/lab2
- Lab 3: http://localhost:8080/lab3
- Dashboard: http://localhost:8081/dashboard/

**Run tests:**
```bash
./tests/test-traefik-routing.sh
npx playwright test tests/traefik-routing.test.ts
```

**Stop services:**
```bash
docker-compose -f docker-compose.traefik.yml down
```

### Debugging

**View Traefik logs:**
```bash
docker-compose -f docker-compose.traefik.yml logs -f traefik
```

**Check registered services:**
```bash
curl http://localhost:8081/api/http/services | jq
```

**Check routers:**
```bash
curl http://localhost:8081/api/http/routers | jq
```

**Test a specific route:**
```bash
curl -v http://localhost:8080/lab1
```

### Cloud Deployment

**Deploy to staging:**
```bash
gh workflow run deploy-traefik.yml -f environment=stg
```

**Deploy to production:**
```bash
gh workflow run deploy-traefik.yml -f environment=prd
```

## 📁 Key Files

### Configuration Files
```
deploy/traefik/
├── traefik.yml              # Static config (local)
├── traefik.cloudrun.yml     # Static config (Cloud Run)
├── Dockerfile.cloudrun      # Cloud Run Dockerfile
├── entrypoint.sh           # Cloud Run entrypoint
└── dynamic/
    └── routes.yml          # Route definitions
```

### Docker Compose
```
docker-compose.traefik.yml   # Traefik-enabled compose file
docker-compose.yml          # Original compose file (still works)
```

### Terraform
```
deploy/terraform-labs/traefik.tf  # Traefik Cloud Run infrastructure
```

### Tests
```
tests/
├── test-traefik-routing.sh      # Bash test script
└── traefik-routing.test.ts      # Playwright tests
```

### CI/CD
```
.github/workflows/deploy-traefik.yml  # Deployment workflow
```

## 🔄 URL Mappings

### Local Development

| Old URL | New URL | Service |
|---------|---------|---------|
| http://localhost:3000 | http://localhost:8080/ | Home |
| http://localhost:9001 | http://localhost:8080/lab1 | Lab 1 |
| http://localhost:9002 | http://localhost:8080/lab1/c2 | Lab 1 C2 |
| http://localhost:9003 | http://localhost:8080/lab2 | Lab 2 |
| http://localhost:9004 | http://localhost:8080/lab2/c2 | Lab 2 C2 |
| http://localhost:9005 | http://localhost:8080/lab3 | Lab 3 |
| http://localhost:9006 | http://localhost:8080/lab3/extension | Lab 3 Extension |

### Production

All labs accessible at: https://labs.pcioasis.com

- `/` - Home page
- `/lab1` - Lab 1
- `/lab1/c2` - Lab 1 C2 server
- `/lab2` - Lab 2
- `/lab2/c2` - Lab 2 C2 server
- `/lab3` - Lab 3
- `/lab3/extension` - Lab 3 extension server
- `/api/seo` - SEO service
- `/api/analytics` - Analytics service

## ✅ Benefits

1. **Consistency** - Same URLs across all environments
2. **Simplicity** - Single entry point, no port juggling
3. **Privacy** - Full control over routing
4. **Scalability** - Easy to add new labs
5. **Security** - Built-in authentication and authorization
6. **Monitoring** - Centralized observability

## 🧪 Testing

### Run All Tests
```bash
# Quick bash tests
./tests/test-traefik-routing.sh

# Comprehensive Playwright tests
npx playwright test tests/traefik-routing.test.ts

# Test specific environment
BASE_URL=https://labs.stg.pcioasis.com ./tests/test-traefik-routing.sh
TEST_ENV=stg npx playwright test tests/traefik-routing.test.ts
```

### Manual Testing
```bash
# Test home page
curl http://localhost:8080/

# Test Lab 1
curl http://localhost:8080/lab1

# Test Lab 1 C2
curl http://localhost:8080/lab1/c2

# Test Lab 2
curl http://localhost:8080/lab2

# Test Lab 3
curl http://localhost:8080/lab3

# Test API
curl http://localhost:8080/api/seo
curl http://localhost:8080/api/analytics
```

## 🔧 Troubleshooting

### Common Issues

**Can't access http://localhost:8080**
```bash
docker ps | grep traefik
docker logs e-skimming-labs-traefik
docker-compose -f docker-compose.traefik.yml restart traefik
```

**Lab returns 404**
```bash
docker-compose -f docker-compose.traefik.yml ps
curl http://localhost:8081/api/http/services | jq
docker-compose -f docker-compose.traefik.yml restart lab1-vulnerable-site
```

**Lab returns 502 Bad Gateway**
```bash
docker-compose -f docker-compose.traefik.yml logs lab1-vulnerable-site
docker exec lab1-techgear-store wget -O- http://localhost:80
docker-compose -f docker-compose.traefik.yml restart lab1-vulnerable-site
```

For more troubleshooting, see:
- [Traefik README](../deploy/traefik/README.md#troubleshooting)
- [Migration Guide](./traefik-migration-guide.md#common-issues-and-solutions)

## 📈 Monitoring

### Local Dashboard
- **Traefik Dashboard**: http://localhost:8081/dashboard/
- **API Overview**: http://localhost:8081/api/overview
- **Metrics**: http://localhost:8081/metrics

### Production Monitoring
- Cloud Run metrics in GCP Console
- Cloud Logging for access logs
- Prometheus metrics endpoint
- Health check: https://labs.pcioasis.com/ping

## 🛠️ Adding a New Lab

See [Traefik README - Adding a New Lab](../deploy/traefik/README.md#adding-a-new-lab) for detailed instructions.

Quick steps:
1. Add service to `docker-compose.traefik.yml` with Traefik labels
2. Add middleware to `deploy/traefik/dynamic/routes.yml`
3. Restart Traefik
4. Test the new route

## 🚨 Emergency Rollback

If issues occur in production:

1. **Quick DNS rollback:**
   - Revert DNS to point to original home service
   - Individual labs still accessible via direct URLs

2. **Full rollback:**
   ```bash
   # Use old docker-compose locally
   docker-compose -f docker-compose.yml up -d

   # Revert DNS changes
   # Redeploy old services
   ```

See [Migration Guide - Rollback Plan](./traefik-migration-guide.md#rollback-plan) for details.

## 📞 Support

- **Issues**: Open a GitHub issue
- **Discussion**: See [GitHub Discussion #98](https://github.com/pci-tamper-protect/e-skimming-labs/discussions/98)
- **Traefik Docs**: https://doc.traefik.io/

## 🎓 Learning Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Provider Guide](https://doc.traefik.io/traefik/providers/docker/)
- [Middlewares Overview](https://doc.traefik.io/traefik/middlewares/overview/)
- [Cloud Run Best Practices](https://cloud.google.com/run/docs/tips/general)

## 🗺️ Roadmap

- [x] Design architecture
- [x] Implement local development setup
- [x] Create Cloud Run deployment
- [x] Write comprehensive tests
- [x] Document everything
- [ ] Test locally (next step)
- [ ] Update lab code
- [ ] Deploy to staging
- [ ] Deploy to production
- [ ] Cleanup old setup

## 📝 Change Log

### 2024-12-23 - Initial Implementation
- Created Traefik configuration for local and Cloud Run
- Implemented path-based routing for all labs
- Created comprehensive test suite
- Documented architecture and migration plan
- Set up CI/CD pipeline

---

**Ready to get started?** Begin with the [Quick Start Guide](./TRAEFIK-QUICKSTART.md)!
