# Routing Architecture

## Core Principle

**Services MUST NOT contain routing logic. All routing belongs to Traefik.**

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                         Traefik Gateway                          │
│                    (Port 9090 local, 8080 Cloud Run)            │
├─────────────────────────────────────────────────────────────────┤
│  /           → home-index-stg     (labs home page)              │
│  /lab1       → lab-01-basic-magecart-stg                        │
│  /lab1/c2    → lab1-c2-stg        (C2 dashboard)                │
│  /lab2       → lab-02-dom-skimming-stg                          │
│  /lab2/c2    → lab2-c2-stg        (C2 dashboard)                │
│  /lab3       → lab-03-extension-hijacking-stg                   │
│  /lab3/extension → lab3-extension-stg (extension server)        │
│  /mitre-attack → home-index-stg   (MITRE ATT&CK matrix)         │
│  /api/seo    → home-seo-stg       (SEO service)                 │
│  /api/analytics → labs-analytics-stg                            │
└─────────────────────────────────────────────────────────────────┘
```

## Relative URLs

Services should **ALWAYS** return relative URLs for navigation:

```html
<!-- Correct -->
<a href="/lab1">Lab 1</a>
<a href="/lab2/c2">View Stolen Data</a>
<a href="/">Home</a>

<!-- Wrong -->
<a href="https://lab-01-basic-magecart-stg.run.app/">Lab 1</a>
<a href="http://localhost:8080/lab1">Lab 1</a>
```

## What NOT to Do

**DO NOT** add logic to:
- Detect if service is behind Traefik
- Conditionally use relative vs absolute URLs
- Check `X-Forwarded-Host` for routing decisions
- Generate different URLs based on environment
- Check hostname in client-side JavaScript

## Exception: SEO Metadata

Absolute URLs are **ONLY** allowed for SEO metadata:

```html
<link rel="canonical" href="https://labs.pcioasis.com/">
<meta property="og:url" content="https://labs.pcioasis.com/">
```

## Multi-Process Container Architecture

Labs 1, 2, and 3 run **two processes** in a single container:

```
┌─────────────────────────────────────────┐
│         Lab Container (e.g., lab2)      │
├─────────────────────────────────────────┤
│  Nginx (port 8080)                      │
│    /          → vulnerable site HTML    │
│    /c2/*      → proxy to localhost:3000 │
├─────────────────────────────────────────┤
│  Node.js C2 (port 3000)                 │
│    /          → C2 dashboard            │
│    /api/*     → C2 API endpoints        │
└─────────────────────────────────────────┘
```

The `init.sh` script starts both processes:

```bash
# C2 server on port 3000 (NOT Cloud Run's PORT)
C2_PORT=3000
cd /app/c2-server && PORT=$C2_PORT node c2-server.js &

# Nginx on port 8080 (Cloud Run's PORT)
nginx -g "daemon off;"
```

**Important:** The C2 server must use port 3000, not 8080. If it binds to 8080, it serves C2 content at the root instead of the vulnerable site.

## Standalone C2 Services

Each lab also has a standalone C2 service for direct access via Traefik:

| Service | Environment Variable |
|---------|---------------------|
| `lab1-c2-stg` | `C2_STANDALONE=true` |
| `lab2-c2-stg` | `C2_STANDALONE=true` |
| `lab3-extension-stg` | `C2_STANDALONE=true` |

When `C2_STANDALONE=true`, the server binds to port 8080 instead of 3000.

## Traefik Middlewares

### Strip Prefix

Traefik strips path prefixes before forwarding to services:

```yaml
middlewares:
  strip-lab1-prefix:
    stripPrefix:
      prefixes:
        - /lab1
```

Request `/lab1/index.html` → Service receives `/index.html`

### Authentication

Identity tokens are injected via middleware:

```yaml
middlewares:
  lab1-auth:
    headers:
      customRequestHeaders:
        X-Serverless-Authorization: "Bearer eyJ..."
```

## Benefits

- **Simpler code** - No conditional logic based on environment
- **No proxy awareness** - Services don't need to know about Traefik
- **Consistent behavior** - Works the same everywhere
- **Easier maintenance** - No port-specific checks
- **Traefik handles routing** - Path-based routing is centralized

## If You Find Routing Logic

If you find yourself adding routing logic to a service, **STOP** and ask:

> "Why can't Traefik handle this routing?"

The answer is almost always: **Traefik can handle it. Use relative URLs.**
