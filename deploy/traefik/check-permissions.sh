#!/bin/bash
# Check permissions for the labs deployment:
#   - Artifact Registry: current user can push images
#   - Cloud Run credentials: Traefik SA can invoke private backends
#
# Usage: ./check-permissions.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
REPOSITORY="e-skimming-labs"
TRAEFIK_SA="traefik-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"
LABS_DEPLOY_SA="labs-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔍 Checking Labs Permissions"
echo "   Project     : ${PROJECT_ID}"
echo "   Home project: ${HOME_PROJECT_ID}"
echo "   Repository  : ${REPOSITORY}"
echo "   Region      : ${REGION}"
echo ""

# Get current authenticated user
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -z "${CURRENT_USER}" ]; then
  echo "❌ No active gcloud authentication found"
  echo "   Run: gcloud auth login"
  exit 1
fi

echo "👤 Current authenticated user: ${CURRENT_USER}"
echo ""

# Check if repository exists
echo "📦 Checking if repository exists..."
if gcloud artifacts repositories describe "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" &>/dev/null; then
  echo "   ✅ Repository exists"
else
  echo "   ❌ Repository does not exist!"
  echo "   Create it with:"
  echo "   gcloud artifacts repositories create ${REPOSITORY} \\"
  echo "     --repository-format=docker \\"
  echo "     --location=${REGION} \\"
  echo "     --project=${PROJECT_ID}"
  exit 1
fi

# Check IAM permissions on repository
echo ""
echo "🔐 Checking IAM permissions on repository..."
echo ""

# Check if user has writer role
if gcloud artifacts repositories get-iam-policy "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(bindings)" 2>/dev/null | grep -q "${CURRENT_USER}"; then
  echo "   ✅ User found in IAM policy"
  gcloud artifacts repositories get-iam-policy "${REPOSITORY}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --format="table(bindings.role,bindings.members)" | grep -A 10 "${CURRENT_USER}" || true
else
  echo "   ❌ User NOT found in repository IAM policy"
fi

# Check project-level permissions
echo ""
echo "🔐 Checking project-level IAM permissions..."
PROJECT_ROLES=$(gcloud projects get-iam-policy "${PROJECT_ID}" \
  --flatten="bindings[].members" \
  --filter="bindings.members:${CURRENT_USER}" \
  --format="value(bindings.role)" 2>/dev/null || echo "")

if [ -n "${PROJECT_ROLES}" ]; then
  echo "   ✅ User has project-level roles:"
  echo "${PROJECT_ROLES}" | sed 's/^/      - /'
  
  # Check for artifactregistry.writer
  if echo "${PROJECT_ROLES}" | grep -q "artifactregistry.writer\|artifactregistry.admin"; then
    echo "   ✅ User has Artifact Registry writer permissions at project level"
  else
    echo "   ⚠️  User does NOT have artifactregistry.writer at project level"
  fi
else
  echo "   ❌ User has no project-level roles"
fi

# Check Docker authentication
echo ""
echo "🐳 Checking Docker authentication..."
if docker pull "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/test:latest" &>/dev/null 2>&1; then
  echo "   ✅ Docker can authenticate (read test)"
else
  echo "   ⚠️  Docker authentication may not be configured"
  echo "   Run: gcloud auth configure-docker ${REGION}-docker.pkg.dev"
fi

echo ""
echo "💡 To grant AR permissions, run:"
echo ""
echo "   # Grant repository-level writer role:"
echo "   gcloud artifacts repositories add-iam-policy-binding ${REPOSITORY} \\"
echo "     --location=${REGION} \\"
echo "     --project=${PROJECT_ID} \\"
echo "     --member=\"user:${CURRENT_USER}\" \\"
echo "     --role=\"roles/artifactregistry.writer\""
echo ""
echo "   # OR grant project-level role (broader):"
echo "   gcloud projects add-iam-policy-binding ${PROJECT_ID} \\"
echo "     --member=\"user:${CURRENT_USER}\" \\"
echo "     --role=\"roles/artifactregistry.writer\""
echo ""

# ── Cloud Run service-to-service credentials ──────────────────────────────────
CR_PASS=0
CR_FAIL=0

check_project_role() {
  local project="$1" member="$2" role="$3" label="$4"
  if gcloud projects get-iam-policy "${project}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${member} AND bindings.role:${role}" \
    --format="value(bindings.role)" 2>/dev/null | grep -q "${role}"; then
    echo "   ✅ ${label}"
    CR_PASS=$((CR_PASS + 1))
  else
    echo "   ❌ MISSING: ${label}"
    echo "      Fix: gcloud projects add-iam-policy-binding ${project} --member=serviceAccount:${member} --role=${role} --condition=None"
    CR_FAIL=$((CR_FAIL + 1))
  fi
}

check_service_role() {
  local svc_name="${1}-${ENVIRONMENT}" project="$2" member="$3" role="$4"
  if ! gcloud run services describe "${svc_name}" --region="${REGION}" --project="${project}" &>/dev/null; then
    echo "   ⚠️  SKIP: ${svc_name} (service not found)"
    return
  fi
  if gcloud run services get-iam-policy "${svc_name}" \
    --region="${REGION}" --project="${project}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${member} AND bindings.role:${role}" \
    --format="value(bindings.role)" 2>/dev/null | grep -q "${role}"; then
    echo "   ✅ ${svc_name}"
    CR_PASS=$((CR_PASS + 1))
  else
    echo "   ❌ MISSING: ${svc_name}"
    echo "      Fix: gcloud run services add-iam-policy-binding ${svc_name} --region=${REGION} --project=${project} --member=serviceAccount:${member} --role=${role} --quiet"
    CR_FAIL=$((CR_FAIL + 1))
  fi
}

echo "🔐 Checking Cloud Run service-to-service credentials"
echo "   Traefik SA : ${TRAEFIK_SA}"
echo "   Deploy SA  : ${LABS_DEPLOY_SA}"
echo ""

echo "   run.viewer – Traefik SA on labs project (route discovery):"
check_project_role "${PROJECT_ID}" "${TRAEFIK_SA}" "roles/run.viewer" \
  "${TRAEFIK_SA} → roles/run.viewer on ${PROJECT_ID}"

echo "   run.viewer – Traefik SA on home project (ForwardAuth URL):"
check_project_role "${HOME_PROJECT_ID}" "${TRAEFIK_SA}" "roles/run.viewer" \
  "${TRAEFIK_SA} → roles/run.viewer on ${HOME_PROJECT_ID}"

echo "   run.viewer – Deploy SA on home project (GHA HOME_INDEX_URL):"
check_project_role "${HOME_PROJECT_ID}" "${LABS_DEPLOY_SA}" "roles/run.viewer" \
  "${LABS_DEPLOY_SA} → roles/run.viewer on ${HOME_PROJECT_ID}"

echo "   run.invoker – Traefik SA on private backends:"
check_service_role "lab1-c2"        "${PROJECT_ID}" "${TRAEFIK_SA}" "roles/run.invoker"
check_service_role "lab2-c2"        "${PROJECT_ID}" "${TRAEFIK_SA}" "roles/run.invoker"
check_service_role "lab3-extension" "${PROJECT_ID}" "${TRAEFIK_SA}" "roles/run.invoker"
check_service_role "lab4-c2"        "${PROJECT_ID}" "${TRAEFIK_SA}" "roles/run.invoker"

echo ""
if [ "${CR_FAIL}" -eq 0 ]; then
  echo "✅ All Cloud Run credential checks passed (${CR_PASS}/${CR_PASS})"
else
  echo "❌ ${CR_FAIL} Cloud Run credential check(s) failed"
  echo "   To fix all at once: ./deploy/traefik/APPLY_PERMISSIONS.sh ${ENVIRONMENT}"
fi
echo ""
