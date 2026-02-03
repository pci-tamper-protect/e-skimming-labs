# Local Docker Compose (Legacy)

**For running all services locally in Docker containers.**

This mode runs all services locally without connecting to Cloud Run. Useful for offline development or when you need to modify service code.

## When to Use

- Offline development
- Modifying service source code
- Testing without Cloud Run access
- Full local environment

## Prerequisites

- Docker installed and running
- Docker Compose v2+

## Quick Start

```bash
cd e-skimming-labs

# Start all services
docker-compose up -d

# Open your browser
open http://localhost:8080
```

## Access Points

| URL | Description |
|-----|-------------|
| http://localhost:8080 | Labs home page |
| http://localhost:8080/lab1 | Lab 1: Basic Magecart |
| http://localhost:8080/lab2 | Lab 2: DOM Skimming |
| http://localhost:8080/lab3 | Lab 3: Extension Hijacking |
| http://localhost:8080/lab1/c2 | Lab 1 C2 Dashboard |
| http://localhost:8080/lab2/c2 | Lab 2 C2 Dashboard |
| http://localhost:8080/lab3/extension | Lab 3 Extension Server |
| http://localhost:8081/dashboard/ | Traefik Dashboard |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Local Docker Compose                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐                                        │
│  │ Traefik Gateway │ (port 8080)                           │
│  └────────┬────────┘                                        │
│           │                                                  │
│     ┌─────┴─────┬─────────┬─────────┬─────────┐            │
│     ▼           ▼         ▼         ▼         ▼            │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐        │
│  │home- │  │lab1  │  │lab2  │  │lab3  │  │...   │        │
│  │index │  │      │  │      │  │      │  │      │        │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘        │
│                                                              │
│  All services run as local Docker containers                │
└─────────────────────────────────────────────────────────────┘
```

## Common Commands

```bash
# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f lab1-vulnerable-site

# Restart a service
docker-compose restart lab1-vulnerable-site

# Rebuild a service
docker-compose build lab1-vulnerable-site
docker-compose up -d lab1-vulnerable-site

# Rebuild all
docker-compose up -d --build

# Stop
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

## Differences from Sidecar Mode

| Feature | Local Docker | Sidecar Simulation |
|---------|--------------|-------------------|
| Services | Run locally | Proxy to Cloud Run |
| Changes | Require rebuild | Require deploy to Cloud Run |
| Network | Docker network | Internet to Cloud Run |
| Speed | Instant (after build) | Depends on Cloud Run cold start |
| Offline | Works offline | Requires internet |
| Port | 8080 | 9090 |

## Troubleshooting

### Port 8080 already in use

```bash
# Find what's using port 8080
lsof -i :8080

# Kill it
lsof -ti :8080 | xargs kill -9

# Or use a different port (edit docker-compose.yml)
```

### Service returns 502 Bad Gateway

```bash
# Check if service is running
docker-compose ps

# Check service logs
docker-compose logs lab1-vulnerable-site

# Restart the service
docker-compose restart lab1-vulnerable-site
```

### Changes not reflected

```bash
# Rebuild the service
docker-compose build lab1-vulnerable-site

# Restart with new image
docker-compose up -d --build lab1-vulnerable-site
```

## Next Steps

- [Testing locally](../testing/LOCAL_TESTING.md)
- [Deploying to Cloud Run](../deployment/README.md)
- [Switching to sidecar mode](./LOCAL_SIDECAR.md)
