# Traefik Quick Start Guide

## TL;DR - Get Started in 5 Minutes

### Option A: Local Sidecar Simulation (Recommended)

This proxies to remote Cloud Run services via Traefik.

```bash
# Prerequisites: gcloud auth application-default login

# Start
docker compose -f docker-compose.sidecar-local.yml up -d

# Access
open http://localhost:9090

# Stop
docker compose -f docker-compose.sidecar-local.yml down
```

**Access Points:**
- **Home Page**: http://localhost:9090/
- **Lab 1**: http://localhost:9090/lab1
- **Lab 2**: http://localhost:9090/lab2
- **Lab 3**: http://localhost:9090/lab3
- **Traefik Dashboard**: http://localhost:9091/dashboard/

### Option B: Legacy Local Docker Compose

This runs all services locally in Docker containers.

```bash
docker-compose up -d
```

**Access Points:**
- **Home Page**: http://localhost:8080/
- **Lab 1**: http://localhost:8080/lab1
- **Lab 2**: http://localhost:8080/lab2
- **Lab 3**: http://localhost:8080/lab3
- **Traefik Dashboard**: http://localhost:8081/dashboard/

### Stop Everything

```bash
# Sidecar simulation
docker compose -f docker-compose.sidecar-local.yml down

# Legacy local
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

### Problem: localhost:8080 returns 404

**Solution:**
```bash
# Ensure home-index (and any other required services) are up
docker compose ps

# Check if Traefik sees the home-index router and service
curl -s http://localhost:8081/api/http/routers | jq '.[] | select(.name | contains("home-index"))'
curl -s http://localhost:8081/api/http/services | jq '.[] | select(.name | contains("home-index"))'

# Confirm home-index container is on the labs network
docker inspect e-skimming-labs-home-index --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}'
# Should show: e-skimming-labs-network

# Restart Traefik after changing traefik.yml or dynamic/ config
docker compose restart traefik
```

With `allowEmptyServices: true` in `traefik.yml`, the home-index router stays defined even when the backend is down; you get **503** instead of 404 until the home-index container is healthy.

### Problem: Clicking on a lab shows the home page instead

Lab routes (`/lab1`, `/lab2`, `/lab3`) are created by Traefik from the **lab containers**. If those containers are not running, Traefik has no router for `/lab1` (etc.), so the request falls through to the catch-all home-index route and you see the home page again.

**Solution:** Start the lab containers you need:
```bash
# Start all labs
docker compose up -d lab1-vulnerable-site lab2-vulnerable-site lab3-vulnerable-site

# Or start only the labs you use
docker compose up -d lab1-vulnerable-site lab2-vulnerable-site

# Verify containers and routers
docker compose ps
curl -s http://localhost:8081/api/http/routers | jq '.[] | select(.name | test("lab1|lab2|lab3")) | .name'
```

Then open http://localhost:8080/lab1 (or /lab2, /lab3) again.

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
