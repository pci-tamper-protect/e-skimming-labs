#!/bin/bash
echo "🔍 Verifying Traefik-stg service account permissions..."
echo ""

echo "1. Home-index-stg permissions:"
if gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --format="value(bindings.members)" 2>/dev/null | grep -q "traefik-stg@labs-stg.iam.gserviceaccount.com"; then
  echo "   ✅ Traefik has access"
else
  echo "   ❌ Traefik missing"
fi

echo "2. Home-seo-stg permissions:"
if gcloud run services get-iam-policy home-seo-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --format="value(bindings.members)" 2>/dev/null | grep -q "traefik-stg@labs-stg.iam.gserviceaccount.com"; then
  echo "   ✅ Traefik has access"
else
  echo "   ❌ Traefik missing"
fi

echo "3. Labs-stg project permissions:"
if gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com AND bindings.role:roles/run.invoker" \
  --format="value(bindings.role)" 2>/dev/null | grep -q "roles/run.invoker"; then
  echo "   ✅ Traefik has project-level invoker"
else
  echo "   ❌ Traefik missing project-level invoker"
fi

echo ""
echo "4. Lab services permissions (via project-level invoker):"
LAB_SERVICES=("lab-01-basic-magecart-stg" "lab-02-dom-skimming-stg" "lab-03-extension-hijacking-stg" "labs-analytics-stg" "labs-index-stg")
for service in "${LAB_SERVICES[@]}"; do
  if gcloud run services describe "$service" \
    --region=us-central1 \
    --project=labs-stg &>/dev/null; then
    echo "   ✅ $service exists (accessible via project-level invoker)"
  else
    echo "   ⚠️  $service not found (may not be deployed yet)"
  fi
done

echo ""
echo "5. Backend services are private:"
if gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --format="value(bindings.members)" 2>/dev/null | grep -q "^allUsers$"; then
  echo "   ⚠️  home-index-stg is PUBLIC (should be private)"
else
  echo "   ✅ home-index-stg is private"
fi

# Check lab services are private
for service in "${LAB_SERVICES[@]}"; do
  if gcloud run services describe "$service" --region=us-central1 --project=labs-stg &>/dev/null; then
    if gcloud run services get-iam-policy "$service" \
      --region=us-central1 \
      --project=labs-stg \
      --format="value(bindings.members)" 2>/dev/null | grep -q "^allUsers$"; then
      echo "   ⚠️  $service is PUBLIC (should be private)"
    else
      echo "   ✅ $service is private"
    fi
  fi
done

echo ""
echo "6. Note: /mitre-attack and /threat-model are routes on home-index-stg, not separate services"

echo ""
echo "7. Checking Traefik service account exists:"
if gcloud iam service-accounts describe traefik-stg@labs-stg.iam.gserviceaccount.com \
  --project=labs-stg &>/dev/null; then
  echo "   ✅ Traefik service account exists"
else
  echo "   ❌ Traefik service account not found"
fi

echo ""
echo "✅ Verification complete!"
