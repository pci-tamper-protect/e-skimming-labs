# E-Skimming Labs - Local Development with Docker Compose

This Docker Compose setup provides a complete local development environment for the E-Skimming Labs platform, including all shared services and individual labs.

## 🚀 Quick Start

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

## 📋 Services Overview

### 🏠 Labs-Home Services (Landing Page & Shared Components)

| Service | Port | Description | URL |
|---------|------|-------------|-----|
| **home-index** | 8080 | Main landing page with lab directory | http://localhost:8080 |
| **home-seo** | 8081 | SEO integration service | http://localhost:8081 |
| **labs-analytics** | 8082 | Lab progress tracking | http://localhost:8082 |

### 🧪 Individual Labs

#### Lab 1: Basic Magecart Attack
| Service | Port | Description | URL |
|---------|------|-------------|-----|
| **lab1-vulnerable-site** | 9001 | TechGear Store (compromised) | http://localhost:9001 |
| **lab1-c2-server** | 9002 | Attacker's C2 server | http://localhost:9002 |

#### Lab 2: DOM-Based Skimming
| Service | Port | Description | URL |
|---------|------|-------------|-----|
| **lab2-vulnerable-site** | 9003 | SecureBank (compromised) | http://localhost:9003 |
| **lab2-c2-server** | 9004 | DOM skimming C2 server | http://localhost:9004 |

#### Lab 3: Browser Extension Hijacking
| Service | Port | Description | URL |
|---------|------|-------------|-----|
| **lab3-vulnerable-site** | 9005 | Vulnerable e-commerce site | http://localhost:9005 |
| **lab3-extension-server** | 9006 | Extension data server | http://localhost:9006 |

### 🔬 Lab Variants (Advanced Scenarios)

| Service | Port | Description | URL |
|---------|------|-------------|-----|
| **lab1-event-listener-variant** | 9011 | Event listener attack variant | http://localhost:9011 |
| **lab1-obfuscated-variant** | 9012 | Obfuscated base64 variant | http://localhost:9012 |
| **lab1-websocket-variant** | 9013 | WebSocket exfiltration variant | http://localhost:9013 |

## 🛠️ Development Commands

### Start Specific Services

```bash
# Start only labs-home services
docker-compose up -d home-index home-seo labs-analytics

# Start only Lab 1
docker-compose up -d lab1-vulnerable-site lab1-c2-server

# Start only Lab 2
docker-compose up -d lab2-vulnerable-site lab2-c2-server

# Start only Lab 3
docker-compose up -d lab3-vulnerable-site lab3-extension-server
```

### Rebuild Services

```bash
# Rebuild all services
docker-compose build

# Rebuild specific service
docker-compose build home-index

# Rebuild and restart
docker-compose up -d --build
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f home-index

# Last 100 lines
docker-compose logs --tail=100 -f
```

### Clean Up

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (stolen data)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Complete cleanup
docker-compose down -v --rmi all --remove-orphans
```

## 🔧 Configuration

### Environment Variables

The services use the following environment variables:

- `ENVIRONMENT=local` - Development environment
- `DOMAIN=localhost:8080` - Main domain for home-index
- `LABS_DOMAIN=localhost` - Domain for individual labs
- `MAIN_DOMAIN=pcioasis.com` - Main PCI Oasis domain
- `LABS_PROJECT_ID=labs-prd` - Google Cloud project ID

### Volumes

- **Stolen Data**: Each lab's C2 server has a volume for stolen data
- **Source Code**: Vulnerable sites are mounted as read-only volumes for development

### Networks

All services are connected to the `e-skimming-labs-network` bridge network for inter-service communication.

## 🧪 Testing the Labs

### Lab 1: Basic Magecart Attack
1. Visit http://localhost:9001 (TechGear Store)
2. Complete a checkout with test credit card data
3. Check http://localhost:9002 for stolen data
4. Examine the malicious JavaScript in browser DevTools

### Lab 2: DOM-Based Skimming
1. Visit http://localhost:9003 (SecureBank)
2. Navigate to the transfer section
3. Enter payment information
4. Check http://localhost:9004 for DOM-skimmed data
5. Inspect DOM mutations in browser DevTools

### Lab 3: Browser Extension Hijacking
1. Visit http://localhost:9005 (vulnerable site)
2. Install the malicious browser extension
3. Complete transactions on the site
4. Check http://localhost:9006 for extension-hijacked data

## 📊 Monitoring

### Health Checks

All services include health checks:
- **Home services**: HTTP health endpoint at `/health`
- **Lab services**: Service-specific health checks

### View Service Status

```bash
# Check service health
docker-compose ps

# View health check logs
docker-compose logs | grep health
```

## 🔍 Debugging

### Access Service Shells

```bash
# Access home-index service
docker-compose exec home-index sh

# Access lab1 C2 server
docker-compose exec lab1-c2-server sh
```

### View Service Logs

```bash
# Real-time logs for specific service
docker-compose logs -f lab1-c2-server

# Logs with timestamps
docker-compose logs -t lab1-c2-server
```

### Inspect Networks

```bash
# List networks
docker network ls

# Inspect labs network
docker network inspect e-skimming-labs-network
```

## 🚨 Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 8080-8082 and 9001-9013 are available
2. **Build Failures**: Check Dockerfile syntax and dependencies
3. **Service Not Starting**: Check logs with `docker-compose logs <service>`
4. **Network Issues**: Verify all services are on the same network

### Reset Everything

```bash
# Complete reset
docker-compose down -v --rmi all --remove-orphans
docker system prune -f
docker-compose up -d --build
```

## 📚 Additional Resources

- **MITRE ATT&CK Matrix**: http://localhost:8080/mitre-attack
- **Interactive Threat Model**: http://localhost:8080/threat-model
- **Lab API**: http://localhost:8080/api/labs

## 🔐 Security Notes

⚠️ **Warning**: This setup is for educational purposes only. The labs contain intentionally vulnerable code and should never be deployed to production environments.

- All stolen data is stored locally in Docker volumes
- Services run in isolated containers
- No external network access required for basic functionality
- Use test credit card numbers only (e.g., 4111 1111 1111 1111)

