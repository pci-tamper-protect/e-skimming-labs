# Traefik Routing Architecture Design

## Executive Summary

This document outlines the design for implementing Traefik as a unified reverse proxy for the e-skimming-labs project, providing consistent path-based routing across local, staging, and production environments.

## Problem Statement

### Current Architecture Issues

1. **Inconsistent Routing**
   - Local: Port-based routing (localhost:3000, localhost:9001, etc.)
   - Production: Separate Cloud Run service URLs
   - No unified domain structure

2. **Privacy Concerns**
   - Don't want Google/Cloudflare to access lab content (want private services)
   - Need end-to-end control of routing

3. **Developer Experience**
   - Different URLs between local and production
   - Manual port management
   - Complex service discovery

## Proposed Architecture

### Overview

Traefik will serve as the single entry point for all services, providing:
- Path-based routing (e.g., `/lab1`, `/lab2`, `/lab3`)
- Consistent URLs across environments
- Automatic service discovery
- HTTPS/TLS termination
- Health checks and monitoring

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Client                               │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    Traefik Proxy                            │
│                                                              │
│  - Path-based routing                                       │
│  - HTTPS/TLS termination                                    │
│  - Service discovery                                        │
│  - Health checks                                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Home Index   │ │ Lab 1        │ │ Lab 2        │
│ Service      │ │ Service      │ │ Service      │
│ (/)          │ │ (/lab1)      │ │ (/lab2)      │
└──────────────┘ └──────────────┘ └──────────────┘
        │               │               │
        └───────────────┼───────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │ Shared Services       │
            │ - SEO                 │
            │ - Analytics           │
            └───────────────────────┘
```

## Routing Configuration

### Path-Based Routes

| Path | Service | Description |
|------|---------|-------------|
| `/` | home-index | Main landing page |
| `/lab1/*` | lab1-vulnerable-site | Basic Magecart lab |
| `/lab1/c2/*` | lab1-c2-server | Lab 1 C2 server |
| `/lab2/*` | lab2-vulnerable-site | DOM skimming lab |
| `/lab2/c2/*` | lab2-c2-server | Lab 2 C2 server |
| `/lab3/*` | lab3-vulnerable-site | Extension hijacking lab |
| `/lab3/extension/*` | lab3-extension-server | Lab 3 extension server |
| `/api/seo/*` | home-seo | SEO service |
| `/api/analytics/*` | labs-analytics | Analytics service |
| `/health` | traefik | Traefik health check |

### Variants (Advanced Labs)

| Path | Service | Description |
|------|---------|-------------|
| `/lab1/variants/event-listener/*` | lab1-event-listener-variant | Event listener variant |
| `/lab1/variants/obfuscated/*` | lab1-obfuscated-variant | Obfuscated base64 variant |
| `/lab1/variants/websocket/*` | lab1-websocket-variant | WebSocket exfiltration variant |

## Environment-Specific Configuration

### Local Development

**URL**: `http://localhost:8080`

**Configuration**:
- Traefik runs as Docker container
- Service discovery via Docker labels
- File-based configuration for static routes
- No TLS (HTTP only)

**docker-compose.yml additions**:
```yaml
services:
  traefik:
    image: traefik:v3.0
    ports:
      - "8080:80"      # Main entry point
      - "8081:8080"    # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./deploy/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./deploy/traefik/dynamic:/etc/traefik/dynamic:ro
    networks:
      - labs-network
    labels:
      - "traefik.enable=true"
```

### Staging Environment

**URL**: `https://labs.stg.pcioasis.com`

**Configuration**:
- Traefik deployed as Cloud Run service
- Service discovery via environment variables
- HTTPS with Let's Encrypt
- IAM-based access control

**Features**:
- Restricted access to developer groups
- Let's Encrypt staging certificates
- Full logging and monitoring

### Production Environment

**URL**: `https://labs.pcioasis.com`

**Configuration**:
- Traefik deployed as Cloud Run service
- Service discovery via environment variables
- HTTPS with Let's Encrypt production certificates
- Public access for main page, IAM for admin endpoints

**Features**:
- Let's Encrypt production certificates
- Rate limiting
- Full logging and monitoring
- Backup/fallback routing

## Implementation Details

### Traefik Configuration

**Static Configuration** (`traefik.yml`):
```yaml
# Entry points
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

# Providers
providers:
  docker:
    exposedByDefault: false
    network: labs-network
  file:
    directory: /etc/traefik/dynamic
    watch: true

# API and dashboard
api:
  dashboard: true
  insecure: false

# Logging
log:
  level: INFO

accessLog:
  fields:
    headers:
      defaultMode: keep

# Health check
ping:
  entryPoint: web
```

**Dynamic Configuration** (`dynamic/routes.yml`):
```yaml
http:
  routers:
    # Home page
    home:
      rule: "PathPrefix(`/`)"
      service: home-index
      priority: 1
      middlewares:
        - strip-prefix-home

    # Lab 1
    lab1:
      rule: "PathPrefix(`/lab1`)"
      service: lab1-vulnerable-site
      priority: 100
      middlewares:
        - strip-prefix-lab1

    lab1-c2:
      rule: "PathPrefix(`/lab1/c2`)"
      service: lab1-c2-server
      priority: 200
      middlewares:
        - strip-prefix-lab1-c2

  middlewares:
    strip-prefix-lab1:
      stripPrefix:
        prefixes:
          - "/lab1"

    strip-prefix-lab1-c2:
      stripPrefix:
        prefixes:
          - "/lab1/c2"

  services:
    home-index:
      loadBalancer:
        servers:
          - url: "http://home-index:8080"

    lab1-vulnerable-site:
      loadBalancer:
        servers:
          - url: "http://lab1-vulnerable-site:80"

    lab1-c2-server:
      loadBalancer:
        servers:
          - url: "http://lab1-c2-server:3000"
```

### Docker Labels for Service Discovery

Each service in docker-compose will have labels like:

```yaml
lab1-vulnerable-site:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.lab1.rule=PathPrefix(`/lab1`)"
    - "traefik.http.routers.lab1.priority=100"
    - "traefik.http.middlewares.lab1-strip.stripprefix.prefixes=/lab1"
    - "traefik.http.routers.lab1.middlewares=lab1-strip"
    - "traefik.http.services.lab1.loadbalancer.server.port=80"
```

### Cloud Run Deployment

**Traefik Container**:
- Runs as a Cloud Run service
- Configured via environment variables
- Routes to backend services via service URLs
- Uses Cloud Run service-to-service authentication

**Environment Variables**:
```bash
# Service URLs
HOME_INDEX_URL=https://home-index-prd-xxx.run.app
LAB1_URL=https://lab1-xxx.run.app
LAB2_URL=https://lab2-xxx.run.app
LAB3_URL=https://lab3-xxx.run.app
SEO_URL=https://home-seo-prd-xxx.run.app
ANALYTICS_URL=https://labs-analytics-prd-xxx.run.app

# Environment
ENVIRONMENT=prd
DOMAIN=labs.pcioasis.com
```

## Security Considerations

### Authentication & Authorization
- IAM-based authentication for Cloud Run services
- Traefik forwards authentication headers
- Service-to-service authentication using service accounts

### Privacy
- All routing handled by Traefik (no Cloudflare path rules)
- SSL/TLS termination at Traefik
- No external proxies accessing lab content

### Rate Limiting
```yaml
http:
  middlewares:
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
```

## Monitoring & Observability

### Metrics
- Request count by path
- Response time by service
- Error rates
- Active connections

### Logging
- Access logs with path and service info
- Error logs
- Health check logs

### Alerts
- Service down alerts
- High error rate alerts
- Certificate expiration warnings

## Testing Strategy

### Unit Tests
- Traefik configuration validation
- Route matching tests
- Middleware behavior tests

### Integration Tests
- End-to-end routing tests
- Service discovery tests
- Health check tests

### E2E Tests
- Browser-based tests for each lab
- Multi-path navigation tests
- Performance tests

## Benefits

1. **Consistency**: Same URLs across all environments
2. **Simplicity**: Single entry point, no port management
3. **Privacy**: Full control over routing, no third-party access
4. **Scalability**: Easy to add new labs/services
5. **Monitoring**: Centralized observability
6. **Security**: IAM integration, rate limiting, TLS termination

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Traefik becomes SPOF | High | Deploy with auto-scaling, health checks |
| Performance overhead | Medium | Use connection pooling, caching |
| Complex configuration | Low | Template-based config, good documentation |
| Certificate renewal | Medium | Let's Encrypt auto-renewal, monitoring |

## Alternative Approaches Considered

1. **Nginx**: Less dynamic, harder configuration
2. **GCP Load Balancer**: More expensive, complex setup
3. **Cloudflare Workers**: Privacy concerns, vendor lock-in
4. **Envoy**: More complex, steeper learning curve

## Troubleshooting

### Common Issues

**404 Not Found**
- Check Traefik dashboard: `http://localhost:8081/dashboard/`
- Verify service is running: `docker-compose ps`
- Check service labels in `docker-compose.yml`
- Restart Traefik: `docker-compose restart traefik`

**502 Bad Gateway**
- Check if backend service is running
- View backend logs: `docker-compose logs <service-name>`
- Verify service port matches Traefik configuration

**Static Assets Not Loading**
- Check if `stripPrefix` middleware is correctly configured
- Verify paths in HTML are relative (not absolute)
- Check browser console for errors

For Cloud Run deployment issues, see [TRAEFIK_ROUTER_SETUP.md](../deploy/TRAEFIK_ROUTER_SETUP.md).

## Related Documentation

- **[Quick Start Guide](./TRAEFIK-QUICKSTART.md)** - Get running in 5 minutes
- **[Router Setup Guide](../deploy/TRAEFIK_ROUTER_SETUP.md)** - Cloud Run deployment details
- **[Traefik Config README](../deploy/traefik/README.md)** - Configuration details
