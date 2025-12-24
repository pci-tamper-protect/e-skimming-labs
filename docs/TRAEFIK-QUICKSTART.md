# Traefik Quick Start Guide

## TL;DR - Get Started in 5 Minutes

### 1. Start Everything

```bash
docker-compose -f docker-compose.traefik.yml up -d
```

### 2. Access Services

- **Home Page**: http://localhost:8080/
- **Lab 1**: http://localhost:8080/lab1
- **Lab 2**: http://localhost:8080/lab2
- **Lab 3**: http://localhost:8080/lab3
- **Traefik Dashboard**: http://localhost:8081/dashboard/

### 3. Test Routing

```bash
./tests/test-traefik-routing.sh
```

### 4. Stop Everything

```bash
docker-compose -f docker-compose.traefik.yml down
```

## What Changed?

### Before (Port-Based)

```bash
docker-compose up -d
```

**Services at:**
- Home: http://localhost:3000
- Lab 1: http://localhost:9001
- Lab 1 C2: http://localhost:9002
- Lab 2: http://localhost:9003
- Lab 3: http://localhost:9005

### After (Path-Based with Traefik)

```bash
docker-compose -f docker-compose.traefik.yml up -d
```

**Everything at:** http://localhost:8080
- Home: http://localhost:8080/
- Lab 1: http://localhost:8080/lab1
- Lab 1 C2: http://localhost:8080/lab1/c2
- Lab 2: http://localhost:8080/lab2
- Lab 3: http://localhost:8080/lab3

## Why This is Better

1. ✅ **Same URLs everywhere** - Local matches production
2. ✅ **Single port** - No more port juggling
3. ✅ **Privacy** - No third-party routing
4. ✅ **Easier to remember** - Just add `/lab1`, `/lab2`, etc.
5. ✅ **Production-ready** - Same setup as Cloud Run

## Debugging

### Check if Traefik is Running

```bash
docker ps | grep traefik
curl http://localhost:8080/ping
```

### View Traefik Logs

```bash
docker-compose -f docker-compose.traefik.yml logs -f traefik
```

### Check Registered Services

```bash
curl http://localhost:8081/api/http/services | jq
```

### Check Routers

```bash
curl http://localhost:8081/api/http/routers | jq
```

### Test a Specific Route

```bash
curl -v http://localhost:8080/lab1
```

## Common Commands

### Start Services

```bash
# Start all services
docker-compose -f docker-compose.traefik.yml up -d

# Start only specific services
docker-compose -f docker-compose.traefik.yml up -d traefik home-index lab1-vulnerable-site

# Start in foreground (see logs)
docker-compose -f docker-compose.traefik.yml up
```

### View Logs

```bash
# All logs
docker-compose -f docker-compose.traefik.yml logs

# Follow logs
docker-compose -f docker-compose.traefik.yml logs -f

# Specific service
docker-compose -f docker-compose.traefik.yml logs -f lab1-vulnerable-site
```

### Restart Services

```bash
# Restart all
docker-compose -f docker-compose.traefik.yml restart

# Restart Traefik only
docker-compose -f docker-compose.traefik.yml restart traefik

# Restart a lab
docker-compose -f docker-compose.traefik.yml restart lab1-vulnerable-site
```

### Stop Services

```bash
# Stop all (keeps volumes)
docker-compose -f docker-compose.traefik.yml stop

# Stop and remove (keeps volumes)
docker-compose -f docker-compose.traefik.yml down

# Stop and remove everything including volumes
docker-compose -f docker-compose.traefik.yml down -v
```

### Rebuild Services

```bash
# Rebuild all
docker-compose -f docker-compose.traefik.yml build

# Rebuild specific service
docker-compose -f docker-compose.traefik.yml build lab1-vulnerable-site

# Rebuild and restart
docker-compose -f docker-compose.traefik.yml up -d --build
```

## Troubleshooting

### Problem: Can't access http://localhost:8080

**Solution:**
```bash
# Check if Traefik is running
docker ps | grep traefik

# Check Traefik logs
docker logs e-skimming-labs-traefik

# Restart Traefik
docker-compose -f docker-compose.traefik.yml restart traefik
```

### Problem: Lab returns 404

**Solution:**
```bash
# Check if service is running
docker-compose -f docker-compose.traefik.yml ps

# Check if service is registered in Traefik
curl http://localhost:8081/api/http/services | jq '.[] | select(.name | contains("lab1"))'

# Check service labels
docker inspect lab1-techgear-store | jq '.[0].Config.Labels'

# Restart the service
docker-compose -f docker-compose.traefik.yml restart lab1-vulnerable-site
```

### Problem: Lab returns 502 Bad Gateway

**Solution:**
```bash
# Check service is healthy
docker-compose -f docker-compose.traefik.yml ps

# Check service logs
docker-compose -f docker-compose.traefik.yml logs lab1-vulnerable-site

# Test service directly
docker exec lab1-techgear-store wget -O- http://localhost:80

# Restart the service
docker-compose -f docker-compose.traefik.yml restart lab1-vulnerable-site
```

### Problem: Changes to code not reflected

**Solution:**
```bash
# Rebuild the service
docker-compose -f docker-compose.traefik.yml build lab1-vulnerable-site

# Restart with new image
docker-compose -f docker-compose.traefik.yml up -d --build lab1-vulnerable-site

# Force recreate
docker-compose -f docker-compose.traefik.yml up -d --force-recreate lab1-vulnerable-site
```

## Next Steps

1. Read the full [Traefik Architecture Design](./traefik-architecture.md)
2. Read the [Migration Guide](./traefik-migration-guide.md)
3. Check the [Traefik Configuration README](../deploy/traefik/README.md)
4. Run the tests: `./tests/test-traefik-routing.sh`
5. Explore the Traefik dashboard: http://localhost:8081/dashboard/

## Configuration Files

- `docker-compose.traefik.yml` - Main compose file with Traefik
- `deploy/traefik/traefik.yml` - Traefik static configuration
- `deploy/traefik/dynamic/routes.yml` - Route definitions
- `deploy/traefik/Dockerfile.cloudrun` - Cloud Run deployment
- `deploy/terraform-labs/traefik.tf` - Terraform configuration

## Production Deployment

This same setup works in production:

**Staging:** https://labs.stg.pcioasis.com
**Production:** https://labs.pcioasis.com

Deploy with:
```bash
gh workflow run deploy-traefik.yml -f environment=stg
gh workflow run deploy-traefik.yml -f environment=prd
```

## Help

For more help:
- Check logs: `docker-compose -f docker-compose.traefik.yml logs`
- View Traefik dashboard: http://localhost:8081/dashboard/
- Read Traefik docs: https://doc.traefik.io/
- Open an issue on GitHub
