# E-Skimming Labs - Architecture Documentation

Complete technical architecture, plugin system, and deployment information.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Private Data Plugin System](#private-data-plugin-system)
3. [Environment-Aware URLs](#environment-aware-urls)
4. [Deployment Architecture](#deployment-architecture)
5. [Directory Structure](#directory-structure)

---

## System Architecture

### Overview

E-Skimming Labs is a multi-service architecture built for:

- **Education**: Interactive labs for learning about e-skimming attacks
- **Research**: Testing and developing detection techniques
- **Dual Licensing**: Public core + optional private advanced content

### Service Components

```
┌─────────────────────────────────────────────────────────────┐
│                     User Browser                            │
│   http://localhost:3000 or https://labs.pcioasis.com       │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐          ┌─────────▼────────┐
│  home-index    │          │   Labs (1-3)     │
│  Port: 3000    │          │   Ports: 9001+   │
│  Go Server     │          │   Nginx Static   │
└────────┬───────┘          └─────────┬────────┘
         │                            │
    ┌────▼────┐                  ┌────▼────┐
    │ docs/   │                  │  C2     │
    │ *.html  │                  │Servers  │
    └─────────┘                  └─────────┘
```

### Core Services

**home-index (Port 3000)**

- Go HTTP server
- Serves: Landing page, MITRE matrix, threat model
- Handles: Environment detection, private data serving
- Location: `deploy/shared-components/home-index-service/`

**home-seo (Port 3001)**

- SEO optimization service
- Generates meta tags, sitemaps
- Location: `deploy/shared-components/seo-service/`

**labs-analytics (Port 3002)**

- Analytics and tracking
- User interaction monitoring

### Lab Services

Each lab consists of:

1. **Vulnerable Website** (Nginx, Port 900X)
2. **C2 Server** (Node.js, Port 900X+1)
3. **Variants** (Optional, Ports 9011+)

**Lab 1: Basic Magecart**

- Vulnerable Site: TechGear Store (9001)
- C2 Server: Attack dashboard (9002)
- Variants: Event listener (9011), Obfuscated (9012), WebSocket (9013)

**Lab 2: DOM Skimming**

- Vulnerable Site: SecureBank (9003)
- C2 Server: DOM skimmer dashboard (9004)

**Lab 3: Extension Hijacking**

- Vulnerable Site: SecureShop (9005)
- C2 Server: Extension data collector (9006)

---

## Private Data Plugin System

### Architecture

The plugin system allows **seamless integration of private attack data** without
modifying public repository code.

```
Public Repo (e-skimming-labs)
├── docs/
│   ├── mitre-attack-visual.html      ← Displays attacks
│   ├── interactive-threat-model.html ← Displays threat model
│   └── private-data-loader.js        ← Plugin loader
│
└── private-data/ → symlink to ../private-e-skimming-attacks
                    (local only, gitignored)

Private Repo (private-e-skimming-attacks)
├── attacks-index.json                ← Attack definitions
├── threat-model-data.json            ← Threat model extensions
└── attacks/
    └── wasm-skimmer/
        ├── attack.yaml
        ├── proof-of-concept/
        └── detection/
```

### How It Works

**1. Data Plugin Files**

`private-data/attacks-index.json`:

```json
{
  "attacks": [
    {
      "id": "wasm-001",
      "name": "WebAssembly Execution",
      "tactic": "Execution",
      "technique_id": "CUSTOM-WASM-001",
      "description": "Novel WASM-based skimmer",
      "has_lab": true
    }
  ]
}
```

`private-data/threat-model-data.json`:

```json
{
  "nodes": [
    {
      "id": "wasm-exec",
      "label": "WASM\\nExecution",
      "group": "execution",
      "private": true
    }
  ],
  "links": [
    { "source": "execution", "target": "wasm-exec" },
    { "source": "wasm-exec", "target": "collection" }
  ]
}
```

**2. Loader Script**

`docs/private-data-loader.js`:

```javascript
class PrivateDataLoader {
  static async init() {
    // Try to load private data (fails gracefully if not available)
    const attacks = await this.fetchJSON('../private-data/attacks-index.json')
    const threatModel = await this.fetchJSON(
      '../private-data/threat-model-data.json'
    )

    if (attacks) {
      window.PRIVATE_ATTACKS = attacks.attacks
    }
    if (threatModel) {
      window.PRIVATE_THREAT_MODEL = threatModel
    }
  }

  static async fetchJSON(url) {
    try {
      const response = await fetch(url)
      if (!response.ok) return null
      return await response.json()
    } catch (error) {
      console.warn(`Private data not available: ${url}`)
      return null
    }
  }
}
```

**3. HTML Integration**

Pages check for private data and merge it:

```javascript
// Load private data plugin
await PrivateDataLoader.init()

// Merge with public attacks
const allAttacks = [...publicAttacks, ...(window.PRIVATE_ATTACKS || [])]

// Render combined data
renderAttackMatrix(allAttacks)
```

### Benefits

✅ **Separation of Concerns**: Private code stays in private repo ✅ **Graceful
Degradation**: Works without private data ✅ **No Code Duplication**: Single
codebase, dual licensing ✅ **Easy Updates**: Update either repo independently
✅ **Local Testing**: Symlink enables seamless local development

---

## Environment-Aware URLs

### The Problem

Services need different URLs depending on environment:

- **Local:** `http://localhost:3000`, `http://localhost:9002`
- **Staging:** `https://labs.stg.pcioasis.com`,
  `https://labs.stg.pcioasis.com/c2`
- **Production:** `https://labs.pcioasis.com`, `https://labs.pcioasis.com/c2`
- **Cloud Run:** All services on port 8080 internally, domain routing externally

### The Solution

JavaScript environment detection in every HTML file:

```javascript
;(function () {
  const hostname = window.location.hostname
  const isLocal = hostname === 'localhost' || hostname === '127.0.0.1'

  let homeUrl, c2Url

  if (isLocal) {
    // Local development
    homeUrl = 'http://localhost:3000'
    c2Url = 'http://localhost:9002'
  } else if (hostname.includes('labs.stg.pcioasis.com')) {
    // Staging environment
    homeUrl = 'https://labs.stg.pcioasis.com'
    c2Url = 'https://labs.stg.pcioasis.com/01-basic-magecart-c2'
  } else if (hostname.includes('labs.pcioasis.com')) {
    // Production environment
    homeUrl = 'https://labs.pcioasis.com'
    c2Url = 'https://labs.pcioasis.com/01-basic-magecart-c2'
  } else {
    // Fallback for unknown environments
    homeUrl = window.location.protocol + '//' + hostname
    c2Url = window.location.protocol + '//' + hostname + '/c2'
  }

  // Update navigation links
  document.querySelector('.back-button').href = homeUrl
  document.querySelector('.c2-button').href = c2Url
})()
```

### Files with Environment Detection

- ✅ `docs/mitre-attack-visual.html`
- ✅ `docs/interactive-threat-model.html`
- ✅ `labs/01-basic-magecart/vulnerable-site/index.html`
- ✅ `labs/01-basic-magecart/vulnerable-site/checkout_single.html`
- ✅ `labs/02-dom-skimming/vulnerable-site/banking.html`
- ✅ `labs/03-extension-hijacking/vulnerable-site/index.html`

---

## Deployment Architecture

### Local Development

```bash
docker-compose up -d
```

- **Ports:** 3000-3002 (core), 9001-9013 (labs)
- **Networking:** Bridge network
- **Data:** Volume mounts from local filesystem
- **Private Data:** Symlink to `../private-e-skimming-attacks`

### Cloud Run (Production)

**GitHub Actions Workflow:** `.github/workflows/deploy_labs.yml`

```yaml
env:
  HOME_PROJECT_ID: labs-home-prd
  LABS_PROJECT_ID: labs-prd

deploy:
  - Build Docker images
  - Push to Artifact Registry
  - Deploy to Cloud Run
  - Configure domain mapping
```

**Service Configuration:**

```bash
gcloud run deploy home-index-prd \
  --image=gcr.io/labs-home-prd/index:latest \
  --port=8080 \                              # Internal port
  --set-env-vars="ENVIRONMENT=prd,DOMAIN=labs.pcioasis.com"
```

**URL Routing:**

- Home: `labs.pcioasis.com` → `home-index-prd:8080`
- Lab 1: `labs.pcioasis.com/lab1` → `lab-01-basic-magecart-prd:8080`
- C2: `labs.pcioasis.com/01-basic-magecart-c2` → `lab1-c2-prd:8080`

### Environment Variables

**Injected by Cloud Run:**

```
ENVIRONMENT=prd|stg|local
DOMAIN=labs.pcioasis.com|labs.stg.pcioasis.com|localhost:3000
LAB_NAME=01-basic-magecart
```

**Used by Go Server:**

```go
environment := os.Getenv("ENVIRONMENT")
domain := os.Getenv("DOMAIN")

scheme := "https"
if environment == "local" || strings.Contains(domain, "localhost") {
    scheme = "http"
}
```

---

## Directory Structure

```
e-skimming-labs/
├── README.md                          # Main documentation
├── docker-compose.yml                 # Local dev orchestration
│
├── docs/                              # Documentation & visualizations
│   ├── SETUP.md                       # Setup guide (you are here!)
│   ├── ARCHITECTURE.md                # This file
│   ├── RESEARCH.md                    # Attack research
│   ├── CONTRIBUTING.md                # Contribution guidelines
│   ├── mitre-attack-visual.html       # MITRE matrix visualization
│   ├── interactive-threat-model.html  # Threat model visualization
│   ├── private-data-loader.js         # Plugin system
│   └── test-private-loader.html       # Test private data loading
│
├── labs/                              # Interactive labs
│   ├── 01-basic-magecart/
│   │   ├── vulnerable-site/           # TechGear Store (Nginx)
│   │   ├── malicious-code/c2-server/  # C2 dashboard (Node.js)
│   │   └── variants/                  # Lab variants
│   ├── 02-dom-skimming/
│   └── 03-extension-hijacking/
│
├── deploy/                            # Deployment configs
│   ├── shared-components/
│   │   ├── home-index-service/        # Main Go server
│   │   └── seo-service/               # SEO Go server
│   └── Dockerfile.*                   # Container definitions
│
├── test/                              # Playwright tests
│   ├── tests/
│   │   ├── mitre-attack-matrix.spec.js
│   │   └── threat-model.spec.js
│   └── playwright.config.js
│
├── private-data/ → ../private-e-skimming-attacks  # Symlink (local only)
│
└── .github/workflows/                 # CI/CD
    └── deploy_labs.yml                # Cloud Run deployment
```

---

## Integration Flow

### 1. Development Workflow

```bash
# Clone repos
git clone https://github.com/org/e-skimming-labs.git
git clone https://github.com/org/private-e-skimming-attacks.git

# Link private data
cd e-skimming-labs
ln -s ../private-e-skimming-attacks private-data

# Start services
docker-compose up -d

# Test
open http://localhost:3000
```

### 2. Public User Flow

```
User visits → No private data → Shows only public attacks
```

### 3. Private User Flow

```
User visits → Symlink exists → Loads private data → Merges with public
```

### 4. Production Deployment

```
PR merged → GitHub Actions → Build → Deploy to Cloud Run → Update DNS
```

---

## Technical Decisions

### Why Symlinks?

**Problem:** HTTP servers can't serve `../` parent directories **Solution:**
Symlink makes `../private-repo/` accessible as `./private-data/` **Benefits:**

- Keeps repos separate
- Enables local testing
- Gitignored (won't be committed)

### Why JavaScript Plugin System?

**Problem:** Need to support both public-only and public+private users
**Solution:** Client-side fetch with graceful fallback **Benefits:**

- No server-side logic needed
- Works in static environments
- Zero impact on public users
- Easy to extend

### Why Environment Detection?

**Problem:** Different URLs for local/staging/production **Solution:**
JavaScript hostname detection **Benefits:**

- Single codebase
- No build-time configuration
- Works in all environments
- Fallback for unknown hosts

---

## Security Considerations

### Private Data Protection

1. **Repository Access:** Private repo requires authentication
2. **Gitignore:** `private-data/` never committed to public repo
3. **API Access:** Production uses API with license key validation
4. **Client-Side:** Private data served only to authenticated users

### Attack Simulation Safety

1. **Isolated Environment:** All labs run in containers
2. **No Real Data:** Simulated payment info only
3. **Local Network:** Labs accessible only on localhost by default
4. **Documentation:** Clear warnings about authorized use only

---

## Performance Optimization

### Docker Multi-Stage Builds

```dockerfile
FROM golang:1.24-alpine AS builder
RUN go build -o main .

FROM alpine:latest
COPY --from=builder /app/main .
```

**Benefits:**

- Smaller image size
- Faster deployments
- Reduced attack surface

### Cloud Run Scaling

```yaml
--min-instances=0      # Scale to zero when idle
--max-instances=10     # Burst capacity
--memory=512Mi         # Right-sized for workload
```

---

## Future Enhancements

### Planned Features

1. **API-Based Private Data**
   - Replace symlinks with authenticated API calls
   - License key validation
   - Usage tracking

2. **Additional Labs**
   - Web3/crypto wallet skimming
   - Mobile app skimming
   - IoT payment terminal attacks

3. **Enhanced Analytics**
   - User progress tracking
   - Lab completion metrics
   - Attack pattern analysis

4. **Interactive Tutorials**
   - Step-by-step guides
   - Hints system
   - Automated checking

---

## Troubleshooting

### Private Data Not Loading

**Symptom:** Test page shows "Private data not available"

**Diagnosis:**

```bash
# Check symlink
ls -la | grep private-data
# Should show: private-data -> ../private-e-skimming-attacks

# Test fetch
curl http://localhost:3000/private-data/attacks-index.json
# Should return JSON (not 404)
```

**Fix:**

```bash
# Recreate symlink
rm private-data
ln -s ../private-e-skimming-attacks private-data

# Restart server
docker-compose restart home-index
```

### Environment Detection Not Working

**Symptom:** URLs point to wrong environment

**Diagnosis:**

- Check browser console (F12)
- Look for: "Back button URL set to: ..."
- Verify hostname detection logic

**Fix:**

- Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
- Clear browser cache
- Rebuild container: `docker-compose build home-index`

---

## References

- **Docker Compose:** https://docs.docker.com/compose/
- **Cloud Run:** https://cloud.google.com/run/docs
- **MITRE ATT&CK:** https://attack.mitre.org/
- **Playwright:** https://playwright.dev/

---

**Last Updated:** 2025-10-21 **Version:** 2.0
