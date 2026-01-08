#!/bin/bash
# Start a multi-service proxy that routes to different Cloud Run services
# based on Host header. This allows navigation between services to work.
# All services use the same port, so links in HTML will work correctly.

set -euo pipefail

ENVIRONMENT="${1:-stg}"
PROJECT_ID_HOME="${HOME_PROJECT_ID:-labs-home-$ENVIRONMENT}"
PROJECT_ID_LABS="${LABS_PROJECT_ID:-labs-$ENVIRONMENT}"
REGION="${REGION:-us-central1}"

# Load STG_PROXY_PORT from .env.stg for staging, otherwise use provided port or default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ "$ENVIRONMENT" = "stg" ] && [ -f "$PROJECT_ROOT/.env.stg" ]; then
  # Source .env.stg and extract STG_PROXY_PORT
  if command -v dotenvx &> /dev/null && [ -f "$PROJECT_ROOT/.env.keys.stg" ]; then
    STG_PROXY_PORT=$(cd "$PROJECT_ROOT" && dotenvx run -f .env.stg -fk .env.keys.stg -- sh -c 'echo "$STG_PROXY_PORT"' 2>/dev/null | tail -n 1 | tr -d '\n\r' | xargs || echo "")
  else
    # Fallback: try to extract without dotenvx (may fail if encrypted)
    STG_PROXY_PORT=$(grep "^STG_PROXY_PORT=" "$PROJECT_ROOT/.env.stg" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | xargs || echo "")
  fi
  # Use command line argument, then STG_PROXY_PORT from .env.stg, then default to 8082
  PROXY_PORT="${2:-${STG_PROXY_PORT:-8082}}"
else
  # For non-staging environments, use provided port or default to 8080
  PROXY_PORT="${2:-8080}"
fi

echo "🚀 Starting multi-service proxy for $ENVIRONMENT environment"
echo "   Proxy port: $PROXY_PORT"
echo "   Home Project: $PROJECT_ID_HOME"
echo "   Labs Project: $PROJECT_ID_LABS"
echo ""

# Function to get service URL
get_service_url() {
  local service_name=$1
  local project_id=$2
  
  gcloud run services describe "$service_name" \
    --region="$REGION" \
    --project="$project_id" \
    --format="value(status.url)" 2>/dev/null || echo ""
}

# Discover all services and build routing map
echo "🔍 Discovering Cloud Run services..."
echo ""

declare -a SERVICE_ROUTES=()

# Home project services
for service_base in "home-index" "home-seo"; do
  service="$service_base-$ENVIRONMENT"
  url=$(get_service_url "$service" "$PROJECT_ID_HOME")
  if [ -n "$url" ]; then
    domain=$(echo "$url" | sed -E 's|^https?://||' | sed -E 's|/.*$||')
    # Handle both .run.app and .a.run.app domains
    local_domain=$(echo "$domain" | sed 's|\.a\.run\.app|\.a\.local|' | sed 's|\.run\.app|\.local|')
    SERVICE_ROUTES+=("$local_domain|$url|$service")
    echo "   ✅ $service -> $local_domain -> $url"
  fi
done

# Labs project services
for service_base in "labs-analytics"; do
  service="$service_base-$ENVIRONMENT"
  url=$(get_service_url "$service" "$PROJECT_ID_LABS")
  if [ -n "$url" ]; then
    domain=$(echo "$url" | sed -E 's|^https?://||' | sed -E 's|/.*$||')
    # Handle both .run.app and .a.run.app domains
    local_domain=$(echo "$domain" | sed 's|\.a\.run\.app|\.a\.local|' | sed 's|\.run\.app|\.local|')
    SERVICE_ROUTES+=("$local_domain|$url|$service")
    echo "   ✅ $service -> $local_domain -> $url"
  fi
done

# Lab services
for lab_num in "01-basic-magecart" "02-dom-skimming" "03-extension-hijacking"; do
  service="lab-$lab_num-$ENVIRONMENT"
  url=$(get_service_url "$service" "$PROJECT_ID_LABS")
  if [ -n "$url" ]; then
    domain=$(echo "$url" | sed -E 's|^https?://||' | sed -E 's|/.*$||')
    # Handle both .run.app and .a.run.app domains
    local_domain=$(echo "$domain" | sed 's|\.a\.run\.app|\.a\.local|' | sed 's|\.run\.app|\.local|')
    SERVICE_ROUTES+=("$local_domain|$url|$service")
    echo "   ✅ $service -> $local_domain -> $url"
  fi
done

if [ ${#SERVICE_ROUTES[@]} -eq 0 ]; then
  echo "❌ No services found. Please deploy services first."
  exit 1
fi

echo ""
echo "📝 Generating /etc/hosts entries..."
echo ""

# Generate hosts file entries (all use same port)
HOSTS_ENTRIES="# Multi-service proxy entries for $ENVIRONMENT
# All services use port $PROXY_PORT
# Generated: $(date)
# 
# IMPORTANT: These domains MUST match what's in the proxy routing table!
# If services are redeployed, restart the proxy and update /etc/hosts
"

for route in "${SERVICE_ROUTES[@]}"; do
  IFS='|' read -r local_domain target_url service_name <<< "$route"
  HOSTS_ENTRIES+="127.0.0.1 $local_domain  # $service_name"$'\n'
done

HOSTS_FILE="hosts-multi-proxy-$ENVIRONMENT.txt"
echo "$HOSTS_ENTRIES" > "$HOSTS_FILE"
echo "✅ Generated: $HOSTS_FILE"
echo ""
echo "📋 REQUIRED: Add these entries to /etc/hosts (they must match the proxy routing):"
cat "$HOSTS_FILE"
echo ""
echo "💡 To update /etc/hosts automatically, run:"
echo "   sudo bash -c 'cat $HOSTS_FILE >> /etc/hosts'"
echo "   (macOS/Linux) sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
echo ""

# Create Python multi-service proxy
PROXY_DIR="$HOME/.cloud-run-proxy"
mkdir -p "$PROXY_DIR"
PROXY_SCRIPT="$PROXY_DIR/multi-proxy.py"

# Build routing configuration for Python (using JSON-like format to avoid quote issues)
ROUTING_LINES=()
for route in "${SERVICE_ROUTES[@]}"; do
  IFS='|' read -r local_domain target_url service_name <<< "$route"
  # Escape single quotes in values
  local_domain_escaped=$(echo "$local_domain" | sed "s/'/\\\\'/g")
  target_url_escaped=$(echo "$target_url" | sed "s/'/\\\\'/g")
  ROUTING_LINES+=("    '${local_domain_escaped}': '${target_url_escaped}',")
done

cat > "$PROXY_SCRIPT" <<PYTHON_EOF
#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import subprocess
import sys
import os
import re

PORT = int(os.environ.get('PROXY_PORT', '$PROXY_PORT'))

# Service routing configuration
ROUTING = {
$(printf '%s\n' "${ROUTING_LINES[@]}")
}

def get_auth_token():
    try:
        result = subprocess.run(
            ['gcloud', 'auth', 'print-identity-token'],
            capture_output=True,
            text=True,
            check=True,
            timeout=5
        )
        return result.stdout.strip()
    except Exception as e:
        print(f"[ERROR] Error getting token: {e}", file=sys.stderr, flush=True)
        return None

def rewrite_urls(content, content_type, local_domain, proxy_port):
    """Rewrite URLs in HTML/JS/CSS to use local domains"""
    if not content_type or 'text/html' not in content_type:
        return content
    
    try:
        text = content.decode('utf-8', errors='ignore')
        
        # Rewrite https://*.run.app URLs to http://*.local:PORT
        # Pattern: https://domain.run.app/path -> http://domain.local:PORT/path
        # Also handles .a.run.app domains
        def replace_url(match):
            original = match.group(0)
            domain = match.group(1)
            path = match.group(2) if match.group(2) else ''
            # Replace .run.app or .a.run.app with .local
            local_domain_new = domain.replace('.a.run.app', '.a.local').replace('.run.app', '.local')
            return f'http://{local_domain_new}:{proxy_port}{path}'
        
        # Match https://domain.run.app/path or https://domain.a.run.app/path
        text = re.sub(
            r'https://([a-zA-Z0-9.-]+\.(a\.)?run\.app)([^\s"\'<>]*)?',
            replace_url,
            text
        )
        
        # Also rewrite http://*.run.app (though less common)
        text = re.sub(
            r'http://([a-zA-Z0-9.-]+\.(a\.)?run\.app)([^\s"\'<>]*)?',
            replace_url,
            text
        )
        
        return text.encode('utf-8')
    except Exception as e:
        print(f"[WARN] URL rewriting failed: {e}", file=sys.stderr, flush=True)
        return content

class MultiServiceProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request()
    
    def do_POST(self):
        self.proxy_request()
    
    def do_PUT(self):
        self.proxy_request()
    
    def do_DELETE(self):
        self.proxy_request()
    
    def do_PATCH(self):
        self.proxy_request()
    
    def proxy_request(self):
        host_header = self.headers.get('Host', '')
        host = host_header.split(':')[0]  # Remove port if present
        path = self.path
        
        # Debug logging
        print(f"[DEBUG] Host header: {host_header}, extracted host: {host}", flush=True)
        
        # Find target URL based on Host header
        target_url = ROUTING.get(host)
        
        if not target_url:
            print(f"[ERROR] No route found for host: '{host}'", file=sys.stderr, flush=True)
            print(f"[DEBUG] Host header was: '{host_header}'", file=sys.stderr, flush=True)
            print(f"[DEBUG] Available hosts in routing: {sorted(ROUTING.keys())}", file=sys.stderr, flush=True)
            # Try to find a partial match (in case of slight domain differences)
            # Match by service name (e.g., "lab-01-basic-magecart" in domain)
            for route_host, route_url in ROUTING.items():
                # Extract service identifier from domain (e.g., "lab-01-basic-magecart-stg" from full domain)
                route_service = route_host.split('-')[0:3]  # Get first 3 parts
                host_service = host.split('-')[0:3]
                if route_service == host_service:
                    print(f"[DEBUG] Found service match: {route_host} -> {route_url}", file=sys.stderr, flush=True)
                    target_url = route_url
                    break
                # Also try substring match
                if host in route_host or route_host in host:
                    print(f"[DEBUG] Found substring match: {route_host} -> {route_url}", file=sys.stderr, flush=True)
                    target_url = route_url
                    break
            if not target_url:
                # Last resort: try to construct URL from host pattern
                if '.local' in host:
                    # Handle both .local and .a.local domains
                    original_domain = host.replace('.a.local', '.a.run.app').replace('.local', '.run.app')
                    # Try to find any service with similar pattern
                    for route_host, route_url in ROUTING.items():
                        if original_domain in route_url:
                            print(f"[DEBUG] Found URL pattern match: {route_host} -> {route_url}", file=sys.stderr, flush=True)
                            target_url = route_url
                            break
                if not target_url:
                    self.send_error(404, f"No route for host: {host}. Restart proxy to discover new services.")
                    return
        
        # Build full target URL
        full_target = target_url.rstrip('/') + path
        if path == '/':
            full_target = target_url
        
        print(f"[REQUEST] {self.command} {host}{path} -> {full_target}", flush=True)
        
        token = get_auth_token()
        if not token:
            self.send_error(500, "Failed to get auth token")
            return
        
        try:
            req = urllib.request.Request(full_target)
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'connection', 'content-length', 'transfer-encoding']:
                    req.add_header(header, value)
            req.add_header('Authorization', f'Bearer {token}')
            
            request_body = None
            if self.command in ['POST', 'PUT', 'PATCH']:
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    request_body = self.rfile.read(content_length)
                    req.add_header('Content-Length', str(len(request_body)))
                    req.data = request_body
            
            with urllib.request.urlopen(req, timeout=30) as response:
                status_code = response.getcode()
                content_type = response.headers.get('Content-Type', '')
                
                print(f"[RESPONSE] {status_code} from {full_target}", flush=True)
                
                # Read response body
                response_body = response.read()
                
                # Rewrite URLs in HTML content
                if 'text/html' in content_type:
                    response_body = rewrite_urls(response_body, content_type, host, PORT)
                
                # Send response
                self.send_response(status_code)
                
                # Copy headers
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding', 'content-encoding', 'content-length']:
                        self.send_header(header, value)
                
                self.send_header('Content-Length', str(len(response_body)))
                self.end_headers()
                self.wfile.write(response_body)
                self.wfile.flush()
                
        except urllib.error.HTTPError as e:
            print(f"[HTTP_ERROR] {e.code} {e.reason} from {full_target}", flush=True)
            self.send_response(e.code)
            for header, value in e.headers.items():
                if header.lower() not in ['connection', 'transfer-encoding']:
                    self.send_header(header, value)
            self.end_headers()
            error_body = e.read() if hasattr(e, 'read') else str(e).encode()
            self.wfile.write(error_body)
            self.wfile.flush()
        except Exception as e:
            import traceback
            print(f"[ERROR] Proxy error: {str(e)}", file=sys.stderr, flush=True)
            print(f"[TRACEBACK] {traceback.format_exc()}", file=sys.stderr, flush=True)
            self.send_error(500, f"Proxy error: {str(e)}")
    
    def log_message(self, format, *args):
        pass  # We handle logging ourselves

if __name__ == '__main__':
    if not ROUTING:
        print("[ERROR] No services configured", file=sys.stderr, flush=True)
        sys.exit(1)
    
    socketserver.TCPServer.allow_reuse_address = True
    
    try:
        with socketserver.TCPServer(("", PORT), MultiServiceProxyHandler) as httpd:
            print(f"✅ Multi-service proxy running on port {PORT}", flush=True)
            print(f"   Routing {len(ROUTING)} services:", flush=True)
            for local_domain in ROUTING.keys():
                print(f"     - {local_domain}", flush=True)
            print(f"", flush=True)
            print(f"📋 Access services at:", flush=True)
            print(f"   http://<service-domain>.local:{PORT}", flush=True)
            print(f"", flush=True)
            print(f"⚠️  Use HTTP (not HTTPS)!", flush=True)
            print(f"   Press Ctrl+C to stop", flush=True)
            print(f"", flush=True)
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\n👋 Shutting down...", flush=True)
    except OSError as e:
        if e.errno == 48 or "Address already in use" in str(e):
            print(f"❌ Port {PORT} is already in use", file=sys.stderr, flush=True)
            print(f"   Check with: lsof -i :{PORT}", file=sys.stderr, flush=True)
        else:
            print(f"❌ Error starting proxy: {e}", file=sys.stderr, flush=True)
        sys.exit(1)
PYTHON_EOF

chmod +x "$PROXY_SCRIPT"

echo "🚀 Starting multi-service proxy..."
echo ""
echo "💡 TIP: If you add new services, restart this proxy to discover them"
echo ""

# Set environment variables and run proxy
export PROXY_PORT="$PROXY_PORT"
python3 "$PROXY_SCRIPT"

