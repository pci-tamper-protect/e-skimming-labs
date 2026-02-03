# Development Hot-Reload Setup (Optional)

This guide explains how to use hot-reload for faster development without rebuilding containers.

**Note:** This is **optional**. If you prefer, you can continue using `docker-compose up --build` to rebuild containers when making changes. The hot-reload setup is tested and working, but requires additional setup.

## Quick Decision

- **Want hot-reload?** → Use `DEV_MODE=true ./docker-compose.local.sh up`
- **Prefer rebuilds?** → Use `./docker-compose.local.sh up --build` (default)

## Quick Start

```bash
# Start with hot-reload enabled
DEV_MODE=true ./docker-compose.local.sh up

# Or explicitly use dev compose file
./docker-compose.local.sh -f docker-compose.dev.yml up
```

## What Gets Hot-Reloaded

### ✅ Automatically Reloaded (No Rebuild Needed)

1. **home-index-service (Go)**
   - Source code changes (`main.go`, `auth/*.go`)
   - Template strings in Go code (embedded HTML)
   - Uses [Air](https://github.com/cosmtrek/air) for auto-rebuild

2. **lab1-c2-server (Node.js)**
   - `server.js` changes
   - `dashboard.html` changes
   - Uses `nodemon` for auto-reload

3. **lab1 vulnerable-site (Nginx)**
   - HTML/CSS/JS files (already mounted)
   - Nginx serves files directly, changes reflected immediately

4. **Traefik**
   - `traefik.yml` changes
   - `dynamic/routes.yml` changes
   - Traefik auto-reloads config on file changes

### 📁 Watched Directories

**home-index-service watches:**
- `/app/src` - Go source code
- `/app/docs` - Documentation files (for writeup pages)
- `/app/labs` - Lab README files (for writeup pages)

**File types watched:**
- `.go` - Go source files
- `.html` - HTML templates
- `.md` - Markdown files (READMEs)
- `.yaml`, `.yml` - YAML config files
- `.sh` - Shell scripts
- `.tpl`, `.tmpl` - Template files

## How It Works

### Go Service (home-index)

1. **Air** watches mounted source directory (`/app/src`)
2. On file change, Air:
   - Rebuilds Go binary: `go build -o /app/tmp/main`
   - Runs `entrypoint.dev.sh` which:
     - Sets up `.env` symlink
     - Loads dotenvx keys
     - Wraps binary with `dotenvx run`
   - Restarts the service

**Note:** Templates are embedded as strings in `main.go`, so changes to template HTML require editing `main.go` and will trigger a rebuild.

### Node.js Service (lab1-c2)

1. **nodemon** watches `server.js` and `dashboard.html`
2. On file change, nodemon restarts the Node.js process
3. No rebuild needed - changes are immediate

### Nginx Service (lab1)

1. Files are mounted as read-only volume
2. Nginx serves files directly from mounted volume
3. Changes are reflected immediately (just refresh browser)

### Traefik

1. Config files are mounted as volumes
2. Traefik watches for file changes
3. Automatically reloads configuration

## Usage

### Start Development Mode

```bash
# Option 1: Use DEV_MODE environment variable
DEV_MODE=true ./docker-compose.local.sh up

# Option 2: Explicitly specify dev compose file
./docker-compose.local.sh -f docker-compose.dev.yml up

# Option 3: Use docker-compose directly (if no .env.stg needed)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

### Watch Logs

```bash
# Watch home-index rebuilds
docker logs -f e-skimming-labs-home-index

# Watch lab1-c2 reloads
docker logs -f lab1-attacker-c2

# Watch Traefik config reloads
docker logs -f e-skimming-labs-traefik
```

### Make Changes

1. **Edit Go files:**
   ```bash
   # Edit any file in deploy/shared-components/home-index-service/
   vim deploy/shared-components/home-index-service/main.go
   
   # Air will detect change and rebuild automatically
   # Check logs: docker logs -f e-skimming-labs-home-index
   ```

2. **Edit C2 server:**
   ```bash
   # Edit server.js
   vim labs/01-basic-magecart/malicious-code/c2-server/server.js
   
   # nodemon will detect change and restart automatically
   ```

3. **Edit HTML templates:**
   ```bash
   # Templates are in main.go as strings
   # Edit the HTML strings in main.go
   vim deploy/shared-components/home-index-service/main.go
   
   # Air will rebuild on save
   ```

4. **Edit Traefik config:**
   ```bash
   # Edit config files
   vim deploy/traefik/traefik.yml
   vim deploy/traefik/dynamic/routes.yml
   
   # Traefik auto-reloads (check logs for confirmation)
   ```

## Troubleshooting

### Air Not Detecting Changes

1. **Check volume mounts:**
   ```bash
   docker exec e-skimming-labs-home-index ls -la /app/src
   ```

2. **Check Air is running:**
   ```bash
   docker exec e-skimming-labs-home-index ps aux | grep air
   ```

3. **Check Air logs:**
   ```bash
   docker logs e-skimming-labs-home-index | grep -i air
   ```

4. **Verify file permissions:**
   ```bash
   # Files should be readable
   docker exec e-skimming-labs-home-index ls -la /app/src/main.go
   ```

### Build Errors

1. **Check build logs:**
   ```bash
   docker logs e-skimming-labs-home-index | tail -50
   ```

2. **Check for syntax errors:**
   ```bash
   # Test build locally
   cd deploy/shared-components/home-index-service
   go build .
   ```

3. **Check Go module cache:**
   ```bash
   # Clear cache if needed
   docker exec e-skimming-labs-home-index rm -rf /tmp/go-cache /tmp/go-mod-cache
   ```

### Nodemon Not Reloading

1. **Check nodemon is running:**
   ```bash
   docker exec lab1-attacker-c2 ps aux | grep nodemon
   ```

2. **Check file is being watched:**
   ```bash
   docker exec lab1-attacker-c2 ls -la /app/server.js
   ```

3. **Manually trigger reload:**
   ```bash
   # Touch the file to trigger change
   touch labs/01-basic-magecart/malicious-code/c2-server/server.js
   ```

## Performance Tips

1. **Exclude unnecessary directories:**
   - `.air.toml` already excludes `tmp`, `vendor`, `testdata`
   - Add more exclusions if needed

2. **Use Go build cache:**
   - Cache is stored in `/tmp/go-cache` (not in mounted volume)
   - Speeds up subsequent builds

3. **Watch only necessary files:**
   - Air watches by extension (`.go`, `.html`, `.md`, etc.)
   - Adjust `include_ext` in `.air.toml` if needed

## Switching Back to Production Mode

```bash
# Just use normal docker-compose (without dev override)
./docker-compose.local.sh up

# Or rebuild to ensure latest code
./docker-compose.local.sh up --build
```

## Files Modified for Hot-Reload

- `docker-compose.dev.yml` - Development override with volume mounts
- `deploy/shared-components/home-index-service/Dockerfile.dev` - Dev Dockerfile with Air
- `deploy/shared-components/home-index-service/.air.toml` - Air configuration
- `deploy/shared-components/home-index-service/entrypoint.dev.sh` - Dev entrypoint wrapper
- `labs/01-basic-magecart/malicious-code/c2-server/Dockerfile.dev` - Dev Dockerfile with nodemon
- `docker-compose.local.sh` - Updated to support dev mode
