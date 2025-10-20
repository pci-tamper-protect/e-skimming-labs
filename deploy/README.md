# E-Skimming Labs Infrastructure

This directory contains Terraform infrastructure for deploying the e-skimming-labs to Google Cloud.

## Project Structure

```
deploy/
├── terraform/
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── service-accounts.tf     # Service account definitions
│   ├── cloud-run.tf           # Cloud Run services
│   ├── firestore.tf            # Firestore database
│   ├── storage.tf              # Cloud Storage buckets
│   ├── networking.tf            # VPC and networking
│   └── monitoring.tf           # Monitoring and logging
├── shared-components/          # Shared services
│   ├── analytics-service/      # Analytics and progress tracking
│   ├── seo-service/            # SEO integration service
│   └── common-utils/           # Common utilities
└── README.md                   # This file
```

## Deployment

The infrastructure deploys to:
- **Project**: `labs-prd` (ID: 747803540613)
- **Region**: `us-central1`
- **Domain**: `labs.pcioasis.com`

## Service Accounts

1. **labs-runtime-sa**: Service account for running Cloud Run services
2. **labs-deploy-sa**: Service account for GitHub Actions deployment
3. **labs-analytics-sa**: Service account for analytics service
4. **labs-seo-sa**: Service account for SEO service

## Components

### Core Services
- **Lab Services**: Individual Cloud Run services for each lab
- **Index Service**: Main landing page and lab hub
- **Analytics Service**: Progress tracking and usage analytics
- **SEO Service**: Integration with main pcioasis.com for SEO benefits

### Data Persistence
- **Firestore**: User progress, analytics data, lab completion tracking
- **Cloud Storage**: Lab-specific data, C2 server logs, test results

### Monitoring
- **Cloud Monitoring**: Service health and performance metrics
- **Cloud Logging**: Centralized logging for all services
- **Error Reporting**: Error tracking and alerting

