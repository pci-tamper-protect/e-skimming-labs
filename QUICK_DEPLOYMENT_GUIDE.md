# E-Skimming Labs Deployment Guide

## 🚀 Quick Start

### Prerequisites

1. **Install gcloud CLI**
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Or download from: https://cloud.google.com/sdk/docs/install
   ```

2. **Authenticate with Google Cloud**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

3. **Install GitHub CLI** (for secrets management)
   ```bash
   # macOS
   brew install gh
   
   # Authenticate
   gh auth login
   ```

## 🏗️ Architecture Overview

The e-skimming-labs uses a **dual-project architecture** for better separation of concerns:

```
labs-home-prd (Landing Page Project)
├── home-index-prd (Main landing page)
├── home-seo-prd (SEO integration)
└── Home page analytics & assets

labs-prd (Individual Labs Project)
├── labs-analytics-prd (Progress tracking)
├── lab1-basic-magecart-prd
├── lab2-dom-skimming-prd
├── lab3-extension-hijacking-prd
└── Lab data & analytics
```

### Benefits
- **Resource Isolation**: Landing page resources separate from lab resources
- **Independent Scaling**: Home page and labs scale independently
- **Enhanced Security**: Reduced blast radius and separate permissions
- **Cost Optimization**: Better cost attribution and management
- **SEO Integration**: Cross-domain benefits with pcioasis.com

## 📁 Project Structure

```
deploy/
├── terraform-home/          # Home page infrastructure
├── terraform-labs/          # Individual labs infrastructure  
├── shared-components/       # Analytics & SEO services
├── deploy-home.sh           # Home deployment script
├── deploy-labs.sh           # Labs deployment script
├── add-all-github-secrets.sh # GitHub secrets automation
└── README.md               # Infrastructure documentation
```

## 🚀 Deployment Steps

### Step 1: Deploy Home Page Infrastructure (labs-home-prd)

```bash
cd deploy
./deploy-home.sh
```

**Expected Output:**
- Service accounts: `home-runtime-sa`, `home-deploy-sa`, `home-seo-sa`
- Artifact Registry: `e-skimming-labs-home`
- Firestore database for home page analytics
- Cloud Storage bucket for home page assets

### Step 2: Deploy Labs Infrastructure (labs-prd)

```bash
cd deploy
./deploy-labs.sh
```

**Expected Output:**
- Service accounts: `labs-runtime-sa`, `labs-deploy-sa`, `labs-analytics-sa`
- Artifact Registry: `e-skimming-labs`
- Firestore database for lab analytics
- Cloud Storage buckets for lab data and logs

### Step 3: Configure GitHub Secrets

**Option A: Automated (Recommended)**
```bash
cd deploy
./add-all-github-secrets.sh
```

**Option B: Manual**
Add these secrets to your GitHub repository:

**Home Page Secrets:**
- `GCP_HOME_PROJECT_ID`: `labs-home-prd`
- `GCP_HOME_SA_KEY`: [Service account key from Step 1]
- `GAR_HOME_LOCATION`: `us-central1`
- `REPOSITORY_HOME`: `e-skimming-labs-home`

**Labs Secrets:**
- `GCP_LABS_PROJECT_ID`: `labs-prd`
- `GCP_LABS_SA_KEY`: [Service account key from Step 2]
- `GAR_LABS_LOCATION`: `us-central1`
- `REPOSITORY_LABS`: `e-skimming-labs`

### Step 4: Deploy Services

Trigger the GitHub Actions workflow:
1. Go to your GitHub repository
2. Navigate to Actions tab
3. Run the "Deploy E-Skimming Labs to Cloud Run" workflow
4. Select environment (stg or prd)

### Step 5: Configure Domain Mapping

Set up custom domain mapping for `labs.pcioasis.com` to point to the home page service.

## 🔧 GitHub Actions Workflow

The workflow includes **three parallel deployment jobs**:

### 1. `deploy-home-components`
- Deploys SEO and Index services to `labs-home-prd`
- Uses home project service account
- Builds and deploys to home project Artifact Registry

### 2. `deploy-labs-components`
- Deploys Analytics service to `labs-prd`
- Uses labs project service account
- Builds and deploys to labs project Artifact Registry

### 3. `deploy-labs`
- Deploys individual lab services to `labs-prd`
- Depends on `deploy-labs-components`
- Uses labs project service account

## 🌐 Domain Structure

```
labs.pcioasis.com/
├── / (home-index-prd service)
├── /lab1-basic-magecart/ (lab1-basic-magecart-prd service)
├── /lab2-dom-skimming/ (lab2-dom-skimming-prd service)
└── /lab3-extension-hijacking/ (lab3-extension-hijacking-prd service)
```

## 🔐 Security Configuration

### Service Account Permissions

**Home Project Service Accounts:**
- `home-runtime-sa`: Run home page services
- `home-deploy-sa`: Deploy home page services
- `home-seo-sa`: SEO service operations

**Labs Project Service Accounts:**
- `labs-runtime-sa`: Run lab services
- `labs-deploy-sa`: Deploy lab services
- `labs-analytics-sa`: Analytics service operations

### Cross-Project Access

Services can communicate across projects using:
- Public Cloud Run endpoints
- Service-to-service authentication
- Shared Firestore databases (if needed)

## 📊 Monitoring and Analytics

### Separate Monitoring

**Home Project Monitoring:**
- Home page performance metrics
- SEO service health
- Index service analytics

**Labs Project Monitoring:**
- Individual lab performance
- Analytics service health
- Lab completion tracking

### Unified Analytics

- Cross-project analytics through shared services
- Unified reporting across both projects
- Combined user journey tracking

## 🎯 Expected Results

After successful deployment:
- **Home Page**: `https://labs.pcioasis.com/`
- **Individual Labs**: `https://labs.pcioasis.com/lab1-basic-magecart/`
- **SEO Integration**: Cross-domain benefits with pcioasis.com
- **Analytics**: Optional progress tracking (no login required)
- **Monitoring**: Cloud Monitoring and logging for all services

## 🔧 Troubleshooting

### Common Issues

1. **"No such file or directory" error**
   - Make sure you're running scripts from the correct directory
   - Use `./validate-setup.sh` to check setup

2. **Permission denied errors**
   - Ensure scripts are executable: `chmod +x *.sh`
   - Check gcloud authentication: `gcloud auth list`

3. **Terraform errors**
   - Check if APIs are enabled: `gcloud services list --enabled`
   - Verify project IDs are correct

4. **GitHub Actions failures**
   - Verify all secrets are set correctly
   - Check service account permissions
   - Review workflow logs for specific errors

5. **"Service account not found"**
   ```bash
   # Make sure Terraform deployment completed first
   cd deploy/terraform-labs && terraform apply -var='deploy_services=false' -auto-approve
   cd deploy/terraform-home && terraform apply -var='deploy_services=false' -auto-approve
   ```

### Useful Commands

```bash
# Check current gcloud configuration
gcloud config list

# List enabled APIs
gcloud services list --enabled

# Check service accounts
gcloud iam service-accounts list

# List Cloud Run services
gcloud run services list

# Check Artifact Registry repositories
gcloud artifacts repositories list

# Verify GitHub secrets
gh secret list --repo pci-tamper-protect/e-skimming-labs
```

## 📚 Additional Resources

- **Infrastructure Overview**: `deploy/README.md`
- **GitHub Secrets Scripts**: `deploy/add-*-github-secrets.sh`
- **Terraform Configurations**: `deploy/terraform-home/` and `deploy/terraform-labs/`

## 🎉 Benefits Achieved

### Technical Benefits
- ✅ **Better Resource Isolation**: Separate projects for different concerns
- ✅ **Independent Scaling**: Home page and labs scale independently
- ✅ **Enhanced Security**: Reduced blast radius and separate permissions
- ✅ **Cost Optimization**: Better cost attribution and management

### Operational Benefits
- ✅ **Simplified Management**: Clear separation of responsibilities
- ✅ **Independent Deployments**: Deploy home page and labs separately
- ✅ **Better Monitoring**: Separate monitoring for each project
- ✅ **Easier Troubleshooting**: Isolated issues and debugging

### Business Benefits
- ✅ **SEO Optimization**: Cross-domain benefits with pcioasis.com
- ✅ **User Experience**: Unified experience across projects
- ✅ **Scalability**: Independent scaling based on usage patterns
- ✅ **Maintainability**: Easier to maintain and update components

The dual-project architecture provides a robust, scalable, and maintainable foundation for the e-skimming-labs platform while maintaining excellent SEO benefits and user experience.