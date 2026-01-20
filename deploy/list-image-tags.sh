#!/bin/bash
# List all Docker image tags for a specific container/service
# Usage: ./list-image-tags.sh <image-name-or-pattern>
# Example: ./list-image-tags.sh seo
# Example: ./list-image-tags.sh us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/seo

set -e

IMAGE_PATTERN="${1:-}"

if [ -z "$IMAGE_PATTERN" ]; then
  echo "Usage: $0 <image-name-or-pattern>"
  echo ""
  echo "Examples:"
  echo "  $0 seo"
  echo "  $0 us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/seo"
  echo "  $0 lab1"
  echo ""
  echo "Available images matching common patterns:"
  docker images --format "{{.Repository}}" | grep -E "(seo|index|analytics|lab|traefik)" | sort -u | head -10
  exit 1
fi

echo "🔍 Searching for images matching: $IMAGE_PATTERN"
echo ""

# Method 1: Exact repository match
if docker images "$IMAGE_PATTERN" --format "{{.Repository}}" 2>/dev/null | grep -q .; then
  echo "📦 Tags for exact match '$IMAGE_PATTERN':"
  docker images "$IMAGE_PATTERN" --format "table {{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -20
  echo ""
fi

# Method 2: Pattern match in repository name
echo "📦 All images matching pattern '$IMAGE_PATTERN':"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | \
  grep -i "$IMAGE_PATTERN" | head -20
echo ""

# Method 3: Show only content hash tags (64 char hex)
echo "🔑 Content hash tags (64 character hex):"
docker images --format "{{.Repository}}:{{.Tag}}" | \
  grep -i "$IMAGE_PATTERN" | \
  grep -E ':[0-9a-f]{64}$' | \
  sed 's/:/ -> /' | \
  sort
echo ""

# Method 4: Show tags grouped by repository
echo "📋 Tags grouped by repository:"
docker images --format "{{.Repository}}" | \
  grep -i "$IMAGE_PATTERN" | \
  sort -u | \
  while read -r repo; do
    echo ""
    echo "  $repo:"
    docker images "$repo" --format "    - {{.Tag}} ({{.Size}}, {{.CreatedAt}})" | head -10
  done
