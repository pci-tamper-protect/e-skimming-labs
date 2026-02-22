#!/bin/bash
# Verify PRD deployment versions - run when debugging 404 on lab2/lab3
# Usage: ./deploy/traefik/verify-prd-versions.sh
# Requires: gcloud auth + project access to labs-prd

PROJECT_ID="labs-prd"
REGION="us-central1"

echo "=== PRD Deployment Verification ==="
echo ""

echo "1. Traefik - provider sidecar image (and digest):"
gcloud run services describe traefik-prd \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="table(spec.template.spec.containers[1].image,spec.template.metadata.name)" 2>/dev/null || \
gcloud run services describe traefik-prd \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="yaml(spec.template.spec.containers)" 2>/dev/null | head -30
echo ""

echo "2. Lab2 - Traefik labels (must include traefik_http_routers_lab2-main_*):"
gcloud run services describe lab-02-dom-skimming-prd \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="yaml(metadata.labels)" 2>/dev/null
echo ""

echo "3. If lab2 labels are missing/incomplete, redeploy:"
echo "   ln -sf .env.prd .env && ./deploy/deploy-all.sh prd"
echo ""
echo "4. If provider was updated (lab2-main in ruleMap), force new Traefik revision:"
echo "   ./deploy/traefik/deploy-sidecar-traefik-3.0.sh prd"
echo ""
