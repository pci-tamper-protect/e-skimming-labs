# E-Skimming Labs - Setup Guide

Complete setup instructions for running the E-Skimming Labs locally and
understanding the system architecture.

---

## 🚀 Quick Start (30 Seconds)

### Option A: Local Sidecar Simulation (Recommended)

Proxies to remote Cloud Run services - best for development and testing.

```bash
# Clone the repository
git clone https://github.com/yourorg/e-skimming-labs.git
cd e-skimming-labs

# Prerequisites: Authenticate with Google Cloud
gcloud auth application-default login

# Start the sidecar simulation
docker compose -f docker-compose.sidecar-local.yml up -d

# Open your browser
open http://localhost:9090
```

### Option B: Legacy Local Docker

Runs all services locally in Docker containers.

```bash
# Clone the repository
git clone https://github.com/yourorg/e-skimming-labs.git
cd e-skimming-labs

# Start everything
docker-compose up -d

# Open your browser
open http://localhost:8080
```

That's it! 🎉

**Port Summary:**
- Sidecar simulation: `localhost:9090` (gateway), `localhost:9091` (dashboard)
- Local Docker: `localhost:8080` (gateway), `localhost:8081` (dashboard)

---

## 📍 Access Points

### Sidecar Simulation (Recommended - `docker-compose.sidecar-local.yml`)

All services accessible through Traefik at `http://localhost:9090`:

| Page | URL |
|------|-----|
| 🏠 Landing Page | http://localhost:9090/ |
| 📊 MITRE Matrix | http://localhost:9090/mitre-attack |
| 🕸️ Threat Model | http://localhost:9090/threat-model |
| 🔬 Lab 1 (Magecart) | http://localhost:9090/lab1 |
| 🔬 Lab 2 (DOM Skimming) | http://localhost:9090/lab2 |
| 🔬 Lab 3 (Extension Hijack) | http://localhost:9090/lab3 |
| Lab 1 C2 | http://localhost:9090/lab1/c2 |
| Lab 2 C2 | http://localhost:9090/lab2/c2 |
| Lab 3 Extension | http://localhost:9090/lab3/extension |
| Traefik Dashboard | http://localhost:9091/dashboard/ |

### Local Docker (`docker-compose.yml`)

All services accessible through Traefik at `http://localhost:8080`:

| Page | URL |
|------|-----|
| 🏠 Landing Page | http://localhost:8080/ |
| 📊 MITRE Matrix | http://localhost:8080/mitre-attack |
| 🔬 Lab 1 | http://localhost:8080/lab1 |
| 🔬 Lab 2 | http://localhost:8080/lab2 |
| 🔬 Lab 3 | http://localhost:8080/lab3 |
| Traefik Dashboard | http://localhost:8081/dashboard/ |

---

## 🔐 Private Data Setup (Optional)

If you have access to `private-e-skimming-attacks` repo:

### Step 1: Clone Both Repositories

```bash
cd ~/projectos  # or your preferred directory

# Clone public repo
git clone https://github.com/yourorg/e-skimming-labs.git

# Clone private repo (requires access)
git clone https://github.com/yourorg/private-e-skimming-attacks.git

# Verify both repos are in same parent directory
ls
# Should show:
#   e-skimming-labs/
#   private-e-skimming-attacks/
```

### Step 2: Create Symbolic Link

```bash
cd e-skimming-labs

# Create symlink to private repo
ln -s ../private-e-skimming-attacks private-data

# Verify symlink was created
ls -la | grep private-data
# Should show:
#   lrwxr-xr-x ... private-data -> ../private-e-skimming-attacks
```

**Why a symlink?**

- HTTP servers don't serve files from parent directories (`../`) for security
- Symlink makes private data accessible at `./private-data/`
- Keeps repos separate while enabling local testing
- Symlink is in `.gitignore` (won't be committed)

### Step 3: Restart Services

```bash
# If already running, restart
docker-compose restart home-index

# Or if not running, start
docker-compose up -d
```

### Step 4: Verify Private Data Loads

Open http://localhost:8080/docs/test-private-loader.html

**You should see:**

- ✅ Status: "Private data loaded successfully!"
- ✅ Private attacks listed
- ✅ Private threat model nodes displayed
- ✅ Full JSON data visible

**If you see errors:**

- ⚠️ "Failed to load private data" → Symlink missing or broken
- Run: `cd e-skimming-labs && ln -s ../private-e-skimming-attacks private-data`

---

## 🛠️ Common Commands

### Start Services

```bash
docker-compose up -d              # Start in background
docker-compose up                 # Start with logs
```

### Stop Services

```bash
docker-compose down               # Stop all
docker-compose stop home-index    # Stop specific service
```

### View Logs

```bash
docker-compose logs -f            # All logs (follow)
docker-compose logs -f home-index # Specific service
docker-compose logs -f traefik    # Traefik logs
```

### Rebuild

```bash
docker-compose build              # Rebuild all
docker-compose build home-index   # Rebuild specific
docker-compose up -d --build      # Rebuild and restart
```

### Check Status

```bash
docker-compose ps                 # Show all containers
docker-compose ps | grep Up       # Show running only
```

---

## 🔧 Troubleshooting
### Traefik Docker Provider Issues on macOS (Apple Silicon)

#### Symptoms

When running the labs on macOS using Docker Desktop (especially on Apple Silicon), Traefik may repeatedly log errors such as:

Failed to retrieve information of the docker client and server host

Common effects include:

- Traefik dashboard showing no services or unhealthy routers
- 404 errors when accessing lab routes
- Containers starting successfully but not being discovered by Traefik

---

#### Cause

On macOS, Docker Desktop exposes the Docker socket as a symlink:

```bash
/var/run/docker.sock -> /Users/<username>/.docker/run/docker.sock
Additionally, Docker Desktop restricts filesystem mounts unless explicitly allowed via:
Docker Desktop → Settings → Resources → File Sharing
```

If these paths are not shared, Traefik cannot communicate with the Docker API even if containers are running.
Resolution

# 1. Enable Required File Sharing Paths

```bash
In Docker Desktop, add:
/var
/var/run
/var/run/docker.sock
/Users/<your-username>/.docker/run
Apply changes and restart Docker Desktop.
```

# 2. Ensure Docker Socket Is Mounted in docker-compose.yml
The Traefik service should mount the Docker socket:
```
traefik:
  image: traefik:v2.11   # alter version if necessary
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./deploy/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
    - ./deploy/traefik/dynamic:/etc/traefik/dynamic:ro
```


⚠️ Note: The image: traefik:v2.11 may need to be changed to a different version (e.g., v2.10, v2.12, or v2.9) if compatibility issues persist with your Docker Desktop version. After changing the image, rebuild with:
```
docker compose down
docker compose pull
docker compose up --build
```
On some macOS setups, mounting the symlink target directly may also be required:
```
- /Users/<your-username>/.docker/run/docker.sock:/var/run/docker.sock
```

# 3. Verify Socket Access Inside the Traefik Container
Run:
```
docker exec -it e-skimming-labs-traefik ls -la /var/run/docker.sock
Expected output:
srw-rw---- 1 root root /var/run/docker.sock
```
This confirms Traefik can communicate with the Docker daemon.

# 4. Confirm Docker Provider Configuration
Your static Traefik configuration should include the Docker provider:
```
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: e-skimming-labs-network
    watch: true
```

Traefik will only route containers labeled with traefik.enable=true and that pass their health checks.
Result

After fixing file sharing permissions, mounting the correct Docker socket, and verifying the provider configuration:
Traefik connects successfully to Docker

Services dynamically register via labels
All routers appear healthy in the Traefik dashboard
Lab routes function correctly without 404 errors
Notes

This issue is specific to macOS Docker Desktop due to socket symlinking and filesystem security
Linux environments typically do not encounter this problem
Disabling the Docker provider is not required once socket access is configured correctly
Always try different Traefik image versions if socket errors or API compatibility issues persist

### Port Already in Use

```bash
# Find what's using a port
lsof -i :8080

# Kill it
lsof -ti :8080 | xargs kill -9

# Restart services
docker-compose up -d
```

### Page Shows 404

```bash
# Check services are running
docker-compose ps

# Check home-index logs
docker-compose logs home-index

# Check Traefik logs
docker-compose logs traefik

# Restart if needed
docker-compose restart home-index
```

### Private Data Not Loading

```bash
# 1. Check symlink exists
ls -la | grep private-data
# Should show: private-data -> ../private-e-skimming-attacks

# 2. If missing, create it
ln -s ../private-e-skimming-attacks private-data

# 3. Check browser console (F12)
# Look for: "[Private Data Loader] Initializing..."

# 4. Hard refresh browser
# Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
```

### Docker Issues

```bash
# Clean everything and restart
docker-compose down -v
docker-compose up -d --build

# Remove all containers and images (nuclear option)
docker system prune -a
docker-compose up -d --build
```

---

## 📊 Port Configuration

### Default Setup (Recommended - `docker-compose.yml` with Traefik)

All services are accessible through Traefik on port **8080**:

| Service            | Path                    | URL                              | Description        |
| ------------------ | ----------------------- | -------------------------------- | ------------------ |
| **Traefik**        | -                       | http://localhost:8080            | Main entry point   |
| **Traefik Dashboard** | -                    | http://localhost:8081/dashboard/ | Traefik dashboard  |
| **home-index**     | `/`                     | http://localhost:8080/           | Main landing page  |
| **home-seo**       | `/api/seo`              | http://localhost:8080/api/seo    | SEO service        |
| **labs-analytics** | `/api/analytics`        | http://localhost:8080/api/analytics | Analytics tracking |
| **Lab 1**          | `/lab1`                 | http://localhost:8080/lab1       | Basic Magecart Attack |
| **Lab 1 C2**       | `/lab1/c2`              | http://localhost:8080/lab1/c2    | Lab 1 C2 server    |
| **Lab 2**          | `/lab2`                 | http://localhost:8080/lab2       | DOM-Based Skimming |
| **Lab 2 C2**       | `/lab2/c2`              | http://localhost:8080/lab2/c2    | Lab 2 C2 server    |
| **Lab 3**          | `/lab3`                 | http://localhost:8080/lab3       | Extension Hijacking |
| **Lab 3 Extension** | `/lab3/extension`      | http://localhost:8080/lab3/extension | Lab 3 extension server |

**Benefits:**
- ✅ Single entry point (port 8080)
- ✅ Path-based routing (matches production)
- ✅ Consistent URLs across environments
- ✅ No port juggling

**Change Ports:** Edit `docker-compose.yml` and update port mappings.

---

## 🌍 Staging & Production Deployment

### Staging Environment

For staging environment setup, testing, and E2E testing, see:
- **[docs/STAGING.md](STAGING.md)** - Complete staging environment guide

**Quick access:**
- Staging URL: `https://labs.stg.pcioasis.com`
- Proxy: `gcloud run services proxy traefik-stg --region=us-central1 --project=labs-stg --port=8081`
- **Important:** Restart proxy after deploying changes to Traefik or home-index-service

### Production Deployment

In production (Cloud Run), services use environment-aware URLs:

### Environment Detection

All HTML files include JavaScript that detects the environment:

```javascript
const hostname = window.location.hostname

if (hostname === 'localhost' || hostname === '127.0.0.1') {
  // Local: http://localhost:8080
} else if (hostname.includes('labs.stg.pcioasis.com')) {
  // Staging: https://labs.stg.pcioasis.com
} else if (hostname.includes('labs.pcioasis.com')) {
  // Production: https://labs.pcioasis.com
}
```

### Cloud Run Configuration

- **Internal Port:** 8080 (all Cloud Run services)
- **External URLs:** Domain-based routing (e.g., `labs.pcioasis.com/lab1`)
- **Environment Variables:** Set via GitHub Actions workflow

See [docs/ARCHITECTURE.md](ARCHITECTURE.md) for deployment details.

---

## 🎯 What You Get

### Public Users (Everyone)

- ✅ Interactive MITRE ATT&CK matrix
- ✅ Threat model visualization
- ✅ 3 hands-on labs with variants
- ✅ C2 servers for testing
- ✅ Comprehensive documentation

### Private Users (Licensed)

- ✅ Everything above, PLUS:
- ✅ Novel attack techniques (e.g., WASM skimmer)
- ✅ Advanced detection rules
- ✅ Proof-of-concept code
- ✅ Private threat model nodes

---

## 🎓 Learning Path

1. **Start Here:** http://localhost:8080
2. **Understand Threats:** MITRE Matrix & Threat Model
3. **Hands-On Practice:**
   - Lab 1: Basic Magecart (http://localhost:8080/lab1)
   - Lab 2: DOM Skimming (http://localhost:8080/lab2)
   - Lab 3: Extension Hijacking (http://localhost:8080/lab3)
4. **Review C2 Dashboards:**
   - Lab 1 C2: http://localhost:8080/lab1/c2
   - Lab 2 C2: http://localhost:8080/lab2/c2
   - Lab 3 Extension: http://localhost:8080/lab3/extension

---

## 🔐 Security Note

This is a **training environment** for cybersecurity education:

- ✅ Safe to run locally
- ✅ All attacks are simulated
- ✅ No real data at risk
- ⚠️ DO NOT use techniques on live systems without authorization

---

## 🆘 Need Help?

1. **Check logs:** `docker-compose logs -f`
2. **Test page:** http://localhost:8080/docs/test-private-loader.html
3. **Console:** Press F12 and check for errors
4. **Documentation:** 
   - [Traefik Quick Start](./TRAEFIK-QUICKSTART.md) - Traefik setup guide
   - [README.md](../README.md) - Overview

---

**Last Updated:** 2025-10-21 **Version:** 2.0
