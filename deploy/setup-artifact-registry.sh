#!/bin/bash
# Setup Artifact Registry repositories for labs deployment
# This should be run once during initial infrastructure setup

set -euo pipefail

# Labs project
LABS_PROJECT_ID="labs-prd"
LABS_REGION="us-central1"
LABS_REPOSITORY="labs"
LABS_SA="github-actions@${LABS_PROJECT_ID}.iam.gserviceaccount.com"

# Home project
HOME_PROJECT_ID="labs-home-prd"
HOME_REGION="us-central1"
HOME_REPOSITORY="home"
HOME_SA="github-actions@${HOME_PROJECT_ID}.iam.gserviceaccount.com"

echo "Setting up Artifact Registry repositories..."

# Create Labs repository
echo "Creating Artifact Registry repository in labs-prd..."
gcloud artifacts repositories create "${LABS_REPOSITORY}" \
  --repository-format=docker \
  --location="${LABS_REGION}" \
  --project="${LABS_PROJECT_ID}" \
  --description="Docker images for e-skimming labs" || {
    echo "Repository ${LABS_REPOSITORY} may already exist, skipping..."
}

# Grant the service account necessary permissions for Labs repo
echo "Granting permissions to ${LABS_SA}..."
gcloud artifacts repositories add-iam-policy-binding "${LABS_REPOSITORY}" \
  --location="${LABS_REGION}" \
  --member="serviceAccount:${LABS_SA}" \
  --role="roles/artifactregistry.writer" \
  --project="${LABS_PROJECT_ID}"

gcloud artifacts repositories add-iam-policy-binding "${LABS_REPOSITORY}" \
  --location="${LABS_REGION}" \
  --member="serviceAccount:${LABS_SA}" \
  --role="roles/artifactregistry.reader" \
  --project="${LABS_PROJECT_ID}"

# Create Home repository
echo "Creating Artifact Registry repository in labs-home-prd..."
gcloud artifacts repositories create "${HOME_REPOSITORY}" \
  --repository-format=docker \
  --location="${HOME_REGION}" \
  --project="${HOME_PROJECT_ID}" \
  --description="Docker images for labs-home service" || {
    echo "Repository ${HOME_REPOSITORY} may already exist, skipping..."
}

# Grant the service account necessary permissions for Home repo
echo "Granting permissions to ${HOME_SA}..."
gcloud artifacts repositories add-iam-policy-binding "${HOME_REPOSITORY}" \
  --location="${HOME_REGION}" \
  --member="serviceAccount:${HOME_SA}" \
  --role="roles/artifactregistry.writer" \
  --project="${HOME_PROJECT_ID}"

gcloud artifacts repositories add-iam-policy-binding "${HOME_REPOSITORY}" \
  --location="${HOME_REGION}" \
  --member="serviceAccount:${HOME_SA}" \
  --role="roles/artifactregistry.reader" \
  --project="${HOME_PROJECT_ID}"

# Also grant read access to pcioasis-operations/containers for both service accounts
echo "Granting read access to golden images..."
gcloud artifacts repositories add-iam-policy-binding containers \
  --location=us-central1 \
  --member="serviceAccount:${LABS_SA}" \
  --role="roles/artifactregistry.reader" \
  --project=pcioasis-operations

gcloud artifacts repositories add-iam-policy-binding containers \
  --location=us-central1 \
  --member="serviceAccount:${HOME_SA}" \
  --role="roles/artifactregistry.reader" \
  --project=pcioasis-operations

echo "✅ Artifact Registry setup complete!"
echo ""
echo "Repositories:"
echo "  - labs-prd: us-central1-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}"
echo "  - labs-home-prd: us-central1-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}"
