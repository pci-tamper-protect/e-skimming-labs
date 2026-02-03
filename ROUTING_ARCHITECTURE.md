# Routing Architecture Principle

## ⚠️ CRITICAL: DO NOT REGRESS

**Services MUST NOT contain routing logic. All routing belongs to Traefik.**

## Core Principle

Services should **ALWAYS** return relative URLs for navigation:
- Lab URLs: `/lab1`, `/lab2`, `/lab3`
- Navigation: `/mitre-attack`, `/threat-model`, `/sign-in`
- Writeups: `/lab-01-writeup`, `/lab-02-writeup`, `/lab-03-writeup`

Traefik handles all routing based on path prefixes:
- `/lab1` → routes to lab1 service
- `/lab2` → routes to lab2 service
- `/lab3` → routes to lab3 service
- `/mitre-attack` → routes to home-index service
- `/sign-in` → routes to appropriate service

## What NOT to Do

**DO NOT** add logic to:
- Detect if service is behind Traefik (`isBehindTraefik`, `isProxyHost`, etc.)
- Conditionally use relative vs absolute URLs (`useRelativeURLs`)
- Check `X-Forwarded-Host` or `X-Forwarded-For` for routing decisions
- Generate different URLs based on environment (local vs staging vs production)
- Check hostname in client-side JavaScript for routing

## Exception: SEO Metadata

Absolute URLs are **ONLY** allowed for SEO metadata:
- Canonical tags: `<link rel="canonical" href="https://domain.com/">`
- Open Graph tags: `<meta property="og:url" content="https://domain.com/">`

## Services with Documentation

The following services have prominent documentation comments to prevent regression:

### Backend Services (Go)
- `deploy/shared-components/home-index-service/main.go` - Header comment + function-level comments
- `deploy/shared-components/seo-service/main.go` - Header comment
- `deploy/shared-components/analytics-service/main.go` - Header comment

### Frontend Services (HTML/JavaScript)
- `labs/02-dom-skimming/vulnerable-site/banking.html` - Script comment
- `labs/02-dom-skimming/vulnerable-site/banking-train.html` - Script comment
- `labs/03-extension-hijacking/vulnerable-site/index.html` - Script comment
- `labs/03-extension-hijacking/vulnerable-site/index-train.html` - Script comment
- `labs/02-dom-skimming/malicious-code/c2-server/dashboard.html` - Script comment
- `labs/03-extension-hijacking/test-server/dashboard.html` - Script comment

## If You Find Routing Logic

If you find yourself adding routing logic to a service, **STOP** and ask:
> "Why can't Traefik handle this routing?"

The answer is almost always: **Traefik can handle it. Use relative URLs.**

## Benefits

- **Simpler code** - No conditional logic based on environment
- **No proxy awareness** - Services don't need to know about Traefik
- **Consistent behavior** - Works the same whether accessed directly or through Traefik
- **Easier maintenance** - No port-specific checks (8081, 8082, 9090, etc.)
- **Traefik handles routing** - Path-based routing (`/lab1` → lab1 service)

## Migration Status

- ✅ `home-index-service` - Removed all routing logic, always uses relative URLs
- ✅ `seo-service` - Uses relative URLs
- ✅ `analytics-service` - Uses relative URLs
- ✅ Lab 1 (`lab-01-basic-magecart`) - Uses relative URLs for navigation
- ✅ Lab 2 (`lab-02-dom-skimming`) - Uses relative URLs for navigation
- ✅ Lab 3 (`lab-03-extension-hijacking`) - Uses relative URLs for navigation
- ✅ All C2 dashboards - Use relative URLs for back/home navigation
- ✅ MITRE ATT&CK page - Uses relative URL for "Back to Labs"

## Multi-Process Container Architecture

Labs 1, 2, and 3 run **two processes** in a single container:
- **Nginx** on port 8080 (Cloud Run's PORT) - serves the vulnerable site
- **Node.js C2 server** on port 3000 - handles C2 API requests

The `init.sh` script starts both processes:
```bash
# C2 server on port 3000 (NOT Cloud Run's PORT)
C2_PORT=3000
cd /app/c2-server && PORT=$C2_PORT node c2-server.js &

# Nginx on port 8080 (Cloud Run's PORT)
nginx -g "daemon off;"
```

**Important**: The C2 server must use port 3000, not Cloud Run's PORT (8080). If the C2 server binds to 8080, it will serve C2 content at the root path instead of the vulnerable site.

## Standalone C2 Services

Each lab also has a standalone C2 service (e.g., `lab2-c2-stg`) for direct access via Traefik. These use `C2_STANDALONE=true` to bind to port 8080.
