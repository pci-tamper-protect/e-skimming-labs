#!/bin/bash
# Sync /etc/hosts with the proxy's discovered services
# This ensures the hosts file matches what the proxy knows about

set -euo pipefail

ENVIRONMENT="${1:-stg}"
PROXY_PORT="${2:-8080}"
PROJECT_ID_HOME="${HOME_PROJECT_ID:-labs-home-$ENVIRONMENT}"
PROJECT_ID_LABS="${LABS_PROJECT_ID:-labs-$ENVIRONMENT}"
REGION="${REGION:-us-central1}"

echo "🔄 Syncing /etc/hosts with proxy routing..."
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

# Discover all services (same logic as start-multi-service-proxy.sh)
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
  fi
done

if [ ${#SERVICE_ROUTES[@]} -eq 0 ]; then
  echo "❌ No services found"
  exit 1
fi

echo "📋 Found ${#SERVICE_ROUTES[@]} services:"
for route in "${SERVICE_ROUTES[@]}"; do
  IFS='|' read -r local_domain target_url service_name <<< "$route"
  echo "   - $local_domain"
done
echo ""

# Remove old entries from /etc/hosts
echo "🧹 Removing old proxy entries from /etc/hosts..."
TEMP_HOSTS=$(mktemp)
# Keep everything except our proxy entries
grep -v "# Multi-service proxy entries for $ENVIRONMENT" /etc/hosts | \
  grep -v "127.0.0.1.*\.local.*#.*stg\|127.0.0.1.*\.local.*#.*prd" > "$TEMP_HOSTS" || true

# Add new entries
echo "" >> "$TEMP_HOSTS"
echo "# Multi-service proxy entries for $ENVIRONMENT" >> "$TEMP_HOSTS"
echo "# All services use port $PROXY_PORT" >> "$TEMP_HOSTS"
echo "# Updated: $(date)" >> "$TEMP_HOSTS"
echo "" >> "$TEMP_HOSTS"

for route in "${SERVICE_ROUTES[@]}"; do
  IFS='|' read -r local_domain target_url service_name <<< "$route"
  echo "127.0.0.1 $local_domain  # $service_name" >> "$TEMP_HOSTS"
done

# Backup current hosts file
HOSTS_BACKUP="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
echo "💾 Backing up /etc/hosts to $HOSTS_BACKUP"
sudo cp /etc/hosts "$HOSTS_BACKUP"

# Install new hosts file
echo "📝 Installing updated /etc/hosts..."
sudo cp "$TEMP_HOSTS" /etc/hosts
rm "$TEMP_HOSTS"

# Flush DNS cache
if [[ "$(uname)" == "Darwin" ]]; then
  echo "🔄 Flushing DNS cache (macOS)..."
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder || true
elif command -v systemd-resolve &>/dev/null; then
  echo "🔄 Flushing DNS cache (Linux)..."
  sudo systemd-resolve --flush-caches
fi

echo ""
echo "✅ /etc/hosts updated!"
echo ""
echo "📋 New entries:"
grep "\.local.*#.*$ENVIRONMENT" /etc/hosts | tail -${#SERVICE_ROUTES[@]}
echo ""
echo "💡 Restart the proxy if it's running: ./start-multi-service-proxy.sh $ENVIRONMENT $PROXY_PORT"

