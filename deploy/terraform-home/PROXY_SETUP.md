# Transparent Proxy Setup for Cloud Run Services

This directory contains scripts to set up transparent proxying for all Cloud Run services, using the same port mappings as `docker-compose.yml`.

## Scripts

- **`generate-hosts-file.sh`** - Generates `/etc/hosts` entries for all services
- **`start-multi-service-proxy.sh`** - **RECOMMENDED** - Single proxy for all services with URL rewriting (enables navigation)
- **`start-all-proxies.sh`** - Starts separate proxies for each service (docker-compose ports)
- **`start-transparent-proxy.sh`** - Starts a proxy for a single service

## Port Mappings (from docker-compose.yml)

- `home-index`: port 3000
- `home-seo`: port 3001
- `labs-analytics`: port 3002
- `lab-01-basic-magecart`: port 9001
- `lab-02-dom-skimming`: port 9003
- `lab-03-extension-hijacking`: port 9005

## Quick Start (Multi-Service Proxy - Recommended)

The multi-service proxy allows navigation between services because it rewrites URLs in HTML responses.

### 1. Start multi-service proxy

```bash
cd deploy/terraform-home
./start-multi-service-proxy.sh stg 8080
```

This will:
- Discover all Cloud Run services
- Generate `/etc/hosts` entries (all use port 8080)
- Start a single proxy that routes based on Host header
- Rewrite URLs in HTML to use `.local:8080` domains

### 2. Sync /etc/hosts with proxy

**IMPORTANT:** The hosts file entries MUST match what the proxy discovered. Use the sync script:

```bash
./sync-hosts-with-proxy.sh stg 8080
```

This will:
- Discover all current Cloud Run services
- Remove old proxy entries from `/etc/hosts`
- Add new entries that match the proxy routing
- Flush DNS cache

**OR manually install:**

The script will generate `hosts-multi-proxy-stg.txt`. Install it:

#### macOS / Linux

```bash
# Backup existing hosts file
sudo cp /etc/hosts /etc/hosts.backup

# Append generated entries
cat hosts-entries-stg.txt | sudo tee -a /etc/hosts

# Flush DNS cache (macOS)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Flush DNS cache (Linux)
sudo systemd-resolve --flush-caches  # systemd
# OR
sudo service network-manager restart  # NetworkManager
```

#### Windows

1. Open Notepad as Administrator
2. Open `C:\Windows\System32\drivers\etc\hosts`
3. Copy entries from `hosts-entries-stg.txt` and paste at the end
4. Save the file
5. Flush DNS cache:
   ```cmd
   ipconfig /flushdns
   ```

### 3. Access services

All services use the same port (8080), so navigation between services works:

- `http://home-index-stg-*.local:8080`
- `http://home-seo-stg-*.local:8080`
- `http://labs-analytics-stg-*.local:8080`
- `http://lab-01-basic-magecart-stg-*.local:8080`
- `http://lab-02-dom-skimming-stg-*.local:8080`
- `http://lab-03-extension-hijacking-stg-*.local:8080`

**The proxy automatically rewrites URLs in HTML responses**, so links between services will work correctly!

## Alternative: Docker-Compose Ports (Single-Service Proxies)

If you want to use the exact docker-compose port mappings:

### 1. Generate hosts file

```bash
./generate-hosts-file.sh stg
```

### 2. Install hosts file

(Same as above)

### 3. Start all proxies

```bash
./start-all-proxies.sh stg
```

This starts separate proxies on docker-compose ports (3000, 3001, 3002, 9001, 9003, 9005).

**Note:** With separate proxies, navigation between services won't work because links point to different ports.

## Individual Service Proxy

To start a proxy for a single service:

```bash
./start-transparent-proxy.sh home-index-stg --port 3000
```

## Troubleshooting

### Service "can't be reached" error

If clicking a link gives "can't be reached" or 404:

1. **Check if service is in routing table:**
   ```bash
   ./check-proxy-routing.sh lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.local
   ```

2. **Restart the proxy** - The proxy only discovers services when it starts:
   ```bash
   # Stop the current proxy (Ctrl+C)
   ./start-multi-service-proxy.sh stg 8080
   ```

3. **Check proxy logs** - The proxy prints debug info showing:
   - What Host header it received
   - What routes are available
   - Any matching attempts

4. **Verify /etc/hosts entry exists** - The domain must be in `/etc/hosts`:
   ```bash
   grep "lab-01-basic-magecart" /etc/hosts
   ```

### Services not found

If a service isn't deployed yet, it will be skipped. Deploy the service first, then restart the proxy.

### Port already in use

If a port is already in use, either:
- Stop the conflicting service
- Use a different port (update docker-compose.yml and regenerate)

### DNS not resolving

- Verify `/etc/hosts` entries are correct
- Flush DNS cache (see above)
- Restart browser
- Try `ping <domain>.local` to verify DNS resolution

### Proxy not working

- Check proxy logs: `/tmp/proxy-<service-name>.log`
- Verify `gcloud auth print-identity-token` works
- Ensure service is deployed and accessible

## Notes

- The `.local` domain suffix avoids HSTS issues with `.run.app` domains
- Ports match docker-compose.yml for consistency
- Proxies run in background and log to `/tmp/proxy-*.log`
- Use HTTP (not HTTPS) - the proxy handles authentication
