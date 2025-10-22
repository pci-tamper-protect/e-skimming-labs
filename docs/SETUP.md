# E-Skimming Labs - Setup Guide

Complete setup instructions for running the E-Skimming Labs locally and understanding the system architecture.

---

## 🚀 Quick Start (30 Seconds)

```bash
# Clone the repository
git clone https://github.com/yourorg/e-skimming-labs.git
cd e-skimming-labs

# Start everything
docker-compose up -d

# Open your browser
open http://localhost:3000
```

That's it! 🎉

---

## 📍 Access Points

### Main Pages
- 🏠 **Landing Page:** http://localhost:3000
- 📊 **MITRE Matrix:** http://localhost:3000/mitre-attack
- 🕸️ **Threat Model:** http://localhost:3000/threat-model

### Interactive Labs
- 🔬 **Lab 1 (Magecart):** http://localhost:9001
- 🔬 **Lab 2 (DOM Skimming):** http://localhost:9003
- 🔬 **Lab 3 (Extension Hijack):** http://localhost:9005

### Lab Variants
- **Event Listener Variant:** http://localhost:9011
- **Obfuscated Variant:** http://localhost:9012
- **WebSocket Variant:** http://localhost:9013

### C2 Dashboards (View Stolen Data)
- **Lab 1 C2:** http://localhost:9002
- **Lab 2 C2:** http://localhost:9004
- **Lab 3 C2:** http://localhost:9006

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

Open http://localhost:3000/docs/test-private-loader.html

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

### Port Already in Use

```bash
# Find what's using a port (e.g., 3000)
lsof -i :3000

# Kill it
lsof -ti :3000 | xargs kill -9

# Restart services
docker-compose up -d
```

### Page Shows 404

```bash
# Check services are running
docker-compose ps

# Check home-index logs
docker-compose logs home-index

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

### Why These Ports?

We avoid `8080-8082` as they're commonly used by proxy servers and development tools. Instead:
- **3000-3999:** Core services
- **9000-9999:** Labs and C2 servers

### Core Services (3000-3999)

| Service | Host Port | URL | Description |
|---------|-----------|-----|-------------|
| **home-index** | **3000** | http://localhost:3000 | Main landing page |
| **home-seo** | **3001** | http://localhost:3001 | SEO service |
| **labs-analytics** | **3002** | http://localhost:3002 | Analytics tracking |

### Lab Services (9000-9999)

| Lab | Vulnerable Site | C2 Server | Description |
|-----|----------------|-----------|-------------|
| **Lab 1** | 9001 | 9002 | Basic Magecart Attack |
| **Lab 2** | 9003 | 9004 | DOM-Based Skimming |
| **Lab 3** | 9005 | 9006 | Extension Hijacking |

### Lab 1 Variants

| Variant | Port | Description |
|---------|------|-------------|
| **Event Listener** | 9011 | Event-driven skimmer |
| **Obfuscated** | 9012 | Base64 obfuscation |
| **WebSocket** | 9013 | WebSocket exfiltration |

**Change Ports:** Edit `docker-compose.yml` and update port mappings.

---

## 🌍 Production Deployment

In production (Cloud Run), services use environment-aware URLs:

### Environment Detection

All HTML files include JavaScript that detects the environment:

```javascript
const hostname = window.location.hostname;

if (hostname === 'localhost' || hostname === '127.0.0.1') {
    // Local: http://localhost:3000
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

1. **Start Here:** http://localhost:3000
2. **Understand Threats:** MITRE Matrix & Threat Model
3. **Hands-On Practice:**
   - Lab 1: Basic Magecart (9001)
   - Lab 2: DOM Skimming (9003)
   - Lab 3: Extension Hijacking (9005)
4. **Explore Variants:** Ports 9011, 9012, 9013
5. **Review C2 Dashboards:** Ports 9002, 9004, 9006

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
2. **Test page:** http://localhost:3000/docs/test-private-loader.html
3. **Console:** Press F12 and check for errors
4. **Documentation:** See [README.md](../README.md) for overview

---

**Last Updated:** 2025-10-21
**Version:** 2.0
