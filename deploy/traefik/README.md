# Traefik Configuration for E-Skimming Labs

This directory contains Traefik reverse proxy configuration for unified routing across all environments.

## Quick Start

### Local Development

1. **Start all services with Traefik:**
   ```bash
   docker-compose up -d
   ```

2. **Access services:**
   - Main landing page: http://localhost:8080/
   - Lab 1: http://localhost:8080/lab1
   - Lab 1 C2 Server: http://localhost:8080/lab1/c2
   - Lab 2: http://localhost:8080/lab2
   - Lab 2 C2 Server: http://localhost:8080/lab2/c2
   - Lab 3: http://localhost:8080/lab3
   - Lab 3 Extension Server: http://localhost:8080/lab3/extension
   - SEO API: http://localhost:8080/api/seo
   - Analytics API: http://localhost:8080/api/analytics
   - Traefik Dashboard: http://localhost:8081/dashboard/

3. **View logs:**
   ```bash
   docker-compose logs -f traefik
   ```

4. **Stop services:**
   ```bash
   docker-compose down
   ```

## Directory Structure

```
deploy/traefik/
├── README.md                  # This file
├── traefik.yml                # Static configuration
├── dynamic/                   # Dynamic configuration
│   └── routes.yml             # Route definitions
├── Dockerfile.cloudrun        # Dockerfile for Cloud Run deployment
└── config/                    # Environment-specific configs
    ├── local.env              # Local environment variables
    ├── stg.env                # Staging environment variables
    └── prd.env                # Production environment variables
```

## Configuration Files

### traefik.yml (Static Configuration)

This file contains:
- Entry points (HTTP/HTTPS)
- Provider configuration (Docker, File)
- API/Dashboard settings
- Logging configuration
- Metrics/monitoring

**Do not modify** unless you need to change fundamental Traefik behavior.

### dynamic/routes.yml (Dynamic Configuration)

This file defines:
- Routes (URL path to service mappings)
- Middlewares (request/response transformations)
- Services (backend server addresses)

**Modify this file** to add new labs or change routing rules.

## Adding a New Lab

To add a new lab (e.g., Lab 4):

### 1. Add service to docker-compose.yml

```yaml
lab4-vulnerable-site:
  build: ./labs/04-new-lab/vulnerable-site
  container_name: lab4-new-lab
  networks:
    - labs-network
  depends_on:
    - traefik
  labels:
    - "lab=lab4-new-lab"
    - "component=vulnerable-site"
    - "traefik.enable=true"
    - "traefik.http.routers.lab4-main.rule=PathPrefix(`/lab4`)"
    - "traefik.http.routers.lab4-main.priority=200"
    - "traefik.http.routers.lab4-main.entrypoints=web"
    - "traefik.http.routers.lab4-main.middlewares=strip-lab4-prefix"
    - "traefik.http.services.lab4-vulnerable-site.loadbalancer.server.port=80"
```

### 2. Add middleware to dynamic/routes.yml

```yaml
http:
  middlewares:
    strip-lab4-prefix:
      stripPrefix:
        prefixes:
          - "/lab4"
```

### 3. Restart Traefik

```bash
docker-compose restart traefik
```

## Debugging

### Check if service is registered

```bash
# View all routers
curl http://localhost:8081/api/http/routers | jq

# View all services
curl http://localhost:8081/api/http/services | jq

# View specific router
curl http://localhost:8081/api/http/routers/lab1-main | jq
```

### Test routing

```bash
# Test Lab 1
curl -v http://localhost:8080/lab1

# Test with headers
curl -v -H "Host: labs.pcioasis.com" http://localhost:8080/lab1

# Test C2 server
curl -v http://localhost:8080/lab1/c2
```

### View Traefik logs

```bash
# All logs
docker-compose logs traefik

# Follow logs
docker-compose logs -f traefik

# Access logs only
docker exec e-skimming-labs-traefik tail -f /var/log/access.log
```

## Cloud Run Deployment

### Build Traefik image for Cloud Run

```bash
cd deploy/traefik
docker build -f Dockerfile.cloudrun -t traefik-cloudrun .
```

### Deploy to Cloud Run

Traefik can be deployed manually using the deployment script:

```bash
cd deploy/traefik
./deploy.sh [stg|prd]
```

This script will:
1. Build and push the Docker image (if it doesn't exist)
2. Deploy Traefik to Cloud Run with proper configuration
3. Set up environment variables for backend service URLs

**Note:** Terraform manages IAM bindings, but the initial service deployment is done via this script or `gcloud` commands.

**Alternative:** You can also deploy manually using `gcloud run deploy` after building the image:

```bash
# Build and push image
./build-and-push.sh prd

# Deploy manually
gcloud run deploy traefik-prd \
  --image=us-central1-docker.pkg.dev/labs-prd/e-skimming-labs/traefik:latest \
  --region=us-central1 \
  --project=labs-prd \
  --service-account=traefik-prd@labs-prd.iam.gserviceaccount.com
```

## Environment Variables

### Local Development

No environment variables needed. Configuration is file-based.

### Staging/Production

Required environment variables:
- `ENVIRONMENT`: `stg` or `prd`
- `DOMAIN`: Domain name (e.g., `labs.pcioasis.com`)
- `HOME_INDEX_URL`: Cloud Run URL for home index service
- `LAB1_URL`: Cloud Run URL for Lab 1
- `LAB2_URL`: Cloud Run URL for Lab 2
- `LAB3_URL`: Cloud Run URL for Lab 3
- `SEO_URL`: Cloud Run URL for SEO service
- `ANALYTICS_URL`: Cloud Run URL for analytics service

## Monitoring

### Metrics

Traefik exposes Prometheus metrics at:
- http://localhost:8081/metrics

Key metrics:
- `traefik_http_requests_total`: Total HTTP requests
- `traefik_http_request_duration_seconds`: Request duration
- `traefik_backend_requests_total`: Backend requests by service
- `traefik_entrypoint_requests_total`: Requests by entry point

### Health Check

- http://localhost:8080/ping (returns 200 OK if healthy)
- http://localhost:8081/api/health (detailed health info)

## Security

### Dashboard Access

The Traefik dashboard is exposed at http://localhost:8081/dashboard/ in local development.

**In production:**
- Dashboard is protected by IAM
- Only accessible to authorized users
- Accessed via: https://labs.pcioasis.com/traefik/dashboard/

### Service-to-Service Authentication

In Cloud Run, Traefik authenticates to backend services using:
- Service account identity
- Cloud Run IAM policies
- Automatic token injection

## Troubleshooting

### Service not responding

1. Check service is running:
   ```bash
   docker-compose ps
   ```

2. Check Traefik can reach service:
   ```bash
   docker exec e-skimming-labs-traefik wget -O- http://lab1-vulnerable-site:80
   ```

3. Check router configuration:
   ```bash
   curl http://localhost:8081/api/http/routers/lab1-main | jq
   ```

### 404 Not Found

1. Check route priority (higher number = higher priority)
2. Verify path prefix matches your request
3. Check middleware is stripping prefix correctly

### 502 Bad Gateway

1. Backend service is down or not responding
2. Check service health:
   ```bash
   docker-compose logs lab1-vulnerable-site
   ```

### Changes not taking effect

1. Restart Traefik:
   ```bash
   docker-compose restart traefik
   ```

2. Check file watch is enabled in traefik.yml:
   ```yaml
   providers:
     file:
       watch: true
   ```

## Migration from Port-Based to Path-Based

### Before (port-based)
- Home: http://localhost:3000
- Lab 1: http://localhost:9001
- Lab 2: http://localhost:9003

### After (path-based)
- Home: http://localhost:8080/
- Lab 1: http://localhost:8080/lab1
- Lab 2: http://localhost:8080/lab2

### Update References

Search and replace in lab code:
```bash
# Update C2 server URLs in skimmer code
find labs -name "*.js" -exec sed -i 's|localhost:9002|localhost:8080/lab1/c2|g' {} \;

# Update internal service URLs
grep -r "localhost:9001" labs/ --include="*.html" --include="*.js"
```

## Performance

### Connection Pooling

Traefik maintains connection pools to backend services for better performance.

Configure in dynamic/routes.yml:
```yaml
http:
  services:
    lab1-vulnerable-site:
      loadBalancer:
        passHostHeader: true
        responseForwarding:
          flushInterval: 100ms
```

### Rate Limiting

Apply rate limiting to specific routes:
```yaml
http:
  middlewares:
    lab-rate-limit:
      rateLimit:
        average: 100
        burst: 50
```

Then add to router:
```yaml
http:
  routers:
    lab1-main:
      middlewares:
        - strip-lab1-prefix
        - lab-rate-limit
```

## Further Reading

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [File Provider](https://doc.traefik.io/traefik/providers/file/)
- [Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)
