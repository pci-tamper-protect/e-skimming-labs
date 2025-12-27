# Traefik Quick Start Guide

## TL;DR - Get Started in 5 Minutes

### 1. Start Everything

```bash
docker-compose up -d
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
docker-compose down
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
docker-compose up -d
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
docker-compose logs -f traefik
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
docker-compose up -d

# Start only specific services
docker-compose up -d traefik home-index lab1-vulnerable-site

# Start in foreground (see logs)
docker-compose up
```

### View Logs

```bash
# All logs
docker-compose logs

# Follow logs
docker-compose logs -f

# Specific service
docker-compose logs -f lab1-vulnerable-site
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart Traefik only
docker-compose restart traefik

# Restart a lab
docker-compose restart lab1-vulnerable-site
```

### Stop Services

```bash
# Stop all (keeps volumes)
docker-compose stop

# Stop and remove (keeps volumes)
docker-compose down

# Stop and remove everything including volumes
docker-compose down -v
```

### Rebuild Services

```bash
# Rebuild all
docker-compose build

# Rebuild specific service
docker-compose build lab1-vulnerable-site

# Rebuild and restart
docker-compose up -d --build
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
docker-compose restart traefik
```

### Problem: Lab returns 404

**Solution:**
```bash
# Check if service is running
docker-compose ps

# Check if service is registered in Traefik
curl http://localhost:8081/api/http/services | jq '.[] | select(.name | contains("lab1"))'

# Check service labels
docker inspect lab1-techgear-store | jq '.[0].Config.Labels'

# Restart the service
docker-compose restart lab1-vulnerable-site
```

### Problem: Lab returns 502 Bad Gateway

**Solution:**
```bash
# Check service is healthy
docker-compose ps

# Check service logs
docker-compose logs lab1-vulnerable-site

# Test service directly
docker exec lab1-techgear-store wget -O- http://localhost:80

# Restart the service
docker-compose restart lab1-vulnerable-site
```

### Problem: Changes to code not reflected

**Solution:**
```bash
# Rebuild the service
docker-compose build lab1-vulnerable-site

# Restart with new image
docker-compose up -d --build lab1-vulnerable-site

# Force recreate
docker-compose up -d --force-recreate lab1-vulnerable-site
```

## Next Steps

1. Read the full [Traefik Architecture Design](./TRAEFIK-ARCHITECTURE.md)
2. Check the [Traefik Configuration README](../deploy/traefik/README.md)
3. For Cloud Run deployment, see [Router Setup Guide](../deploy/TRAEFIK_ROUTER_SETUP.md)
4. Run the tests: `./tests/test-traefik-routing.sh`
5. Explore the Traefik dashboard: http://localhost:8081/dashboard/

## Configuration Files

- `docker-compose.yml` - Default compose file with Traefik
- `docker-compose.no-traefik.yml` - Legacy compose file (port-based)
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
# Build and push image
cd deploy/traefik
./build-and-push.sh stg  # or prd

# Then deploy via gcloud or Terraform
# See deploy/TRAEFIK_ROUTER_SETUP.md for details
```

## Help

For more help:
- Check logs: `docker-compose logs`
- View Traefik dashboard: http://localhost:8081/dashboard/
- Read Traefik docs: https://doc.traefik.io/
- Open an issue on GitHub
