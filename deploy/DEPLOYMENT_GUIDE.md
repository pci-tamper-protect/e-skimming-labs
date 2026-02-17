# E-Skimming Labs Deployment Guide

## Overview

This guide covers two deployment methods:
1. **Local Docker Compose** - Quick local development and testing
2. **Google Cloud Run** - Production deployment using Terraform

## Local Docker Compose Deployment

The fastest way to run the e-skimming labs locally is using Docker Compose.

### Prerequisites

- Docker and Docker Compose installed
- Node.js 18+ (for running tests)

### Quick Start (No Authentication)

Run all services without authentication:

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down
```

This starts:
- **Traefik** reverse proxy on `http://localhost:8080`
- **Home page** at `/`
- **Lab 1** (Basic Magecart) at `/lab1`
- **Lab 2** (DOM Skimming) at `/lab2`
- **Lab 3** (Extension Hijacking) at `/lab3`
- **C2 servers** for each lab at `/lab*/c2`

### Starting Individual Labs

To start only specific services:

```bash
# Start just Lab 1
docker compose up -d traefik home-index lab1-vulnerable-site lab1-c2-server

# Start just Lab 2
docker compose up -d traefik home-index lab2-vulnerable-site lab2-c2-server

# Start just Lab 3
docker compose up -d traefik home-index lab3-vulnerable-site lab3-extension-server
```

### Running Tests

```bash
# From the test/ directory
cd test
npm install
npm run test:e2e
```

### Service URLs

| Service | URL |
|---------|-----|
| Home Page | http://localhost:8080/ |
| MITRE ATT&CK Mapping | http://localhost:8080/mitre-attack |
| Threat Model | http://localhost:8080/threat-model |
| Lab 1 - Basic Magecart | http://localhost:8080/lab1 |
| Lab 1 - C2 Dashboard | http://localhost:8080/lab1/c2 |
| Lab 2 - DOM Skimming | http://localhost:8080/lab2 |
| Lab 2 - C2 Dashboard | http://localhost:8080/lab2/c2 |
| Lab 3 - Extension Hijacking | http://localhost:8080/lab3 |
| Traefik Dashboard | http://localhost:8081 |

---

## Deploying with Authentication

For local development with Firebase authentication enabled.

### Prerequisites

- Firebase project with Authentication enabled
- Firebase Admin SDK service account key (JSON)
- Firebase Web API key
- `dotenvx` CLI installed (`npm install -g @dotenvx/dotenvx`)

### Environment Variables

Authentication requires these environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `FIREBASE_PROJECT_ID` | Firebase project ID | `ui-firebase-pcioasis-stg` |
| `FIREBASE_API_KEY` | Web API key (client-side) | `AIzaSy...` |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Service account JSON (server-side) | `{"type":"service_account",...}` |
| `ENABLE_AUTH` | Enable auth system | `true` |
| `REQUIRE_AUTH` | Require auth for labs | `true` |

### Setup Steps

1. **Create `.env.stg` file** with your Firebase credentials:

```bash
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_API_KEY=your-web-api-key
FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"..."}'
```

2. **Encrypt the file** using dotenvx:

```bash
# Generate encryption keys
dotenvx encrypt --env-file=.env.stg

# This creates .env.keys.stg with the private key
```

3. **Run with authentication**:

```bash
./deploy/docker-compose-auth.sh up
```

The helper script:
- Decrypts `.env.stg` using `.env.keys.stg`
- Exports Firebase credentials as environment variables
- Starts docker-compose with the auth overlay

### Auth Behavior

With authentication enabled:

| Route | Auth Required |
|-------|---------------|
| `/` (home) | No |
| `/mitre-attack` | No |
| `/threat-model` | No |
| `/lab1`, `/lab2`, `/lab3` | Yes |
| `/lab*-writeup` | Yes |
| `/lab*/c2` (dashboard) | Yes |
| `/lab*/c2/collect` | No (skimmer endpoint) |

### Manual Authentication Setup

If you prefer not to use the helper script:

```bash
# 1. Export the dotenvx private key
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"

# 2. Run with dotenvx decrypt
dotenvx run --env-file=.env.stg -- \
  docker compose -f docker-compose.yml -f docker-compose.auth.yml up
```

### Troubleshooting Authentication

**Redirect goes to wrong hostname (e.g., `home-index:8080`)**:
- Ensure the home-index service has the latest code with absolute URL redirects
- Rebuild: `docker compose build home-index`

**Skimmer can't POST to C2**:
- The `/lab*/c2/collect` endpoints don't require auth
- Check that Traefik has the correct route priorities

**"dotenvx not found" error**:
```bash
npm install -g @dotenvx/dotenvx
```

**".env.keys.stg not found" error**:
- This file contains the decryption key
- Get it from a team member or generate new encrypted credentials

---

## Google Cloud Run Deployment

Production deployment using Terraform and Google Cloud Run.

### Prerequisites

Before running any deployment scripts or Terraform commands, authenticate with Google Cloud:

```bash
gcloud auth application-default login
```

This will open a browser for you to authenticate with your Google account.

### Infrastructure Overview

The e-skimming-labs infrastructure is split across three separate Terraform modules:

1. **`terraform/`** - Legacy infrastructure (analytics service only)
2. **`terraform-labs/`** - Labs project infrastructure (analytics service)
3. **`terraform-home/`** - Home page project infrastructure (SEO and Index services)

### Deployment Scripts

#### 1. Deploy Labs Infrastructure (`deploy-labs.sh`)

Deploys infrastructure for the **labs project** (`labs-stg` or `labs-prd`):
- Artifact Registry repository (`e-skimming-labs`)
- Firestore database
- Cloud Storage buckets
- Service accounts
- **Analytics service** (when `deploy_services=true`)

```bash
./deploy/deploy-labs.sh
```

This script:
- Uses `terraform-labs/` directory
- Sets `deploy_services=true` automatically
- Builds and pushes Docker images before Terraform

#### 2. Deploy Home Infrastructure (`deploy-home.sh`)

Deploys infrastructure for the **home project** (`labs-home-stg` or `labs-home-prd`):
- Artifact Registry repository (`e-skimming-labs-home`)
- Service accounts
- **SEO service** (when `deploy_services=true`)
- **Index service** (when `deploy_services=true`)

```bash
./deploy/deploy-home.sh
```

This script:
- Uses `terraform-home/` directory
- Sets `deploy_services=true` automatically
- Builds and pushes Docker images before Terraform

#### 3. Legacy Deploy (`deploy.sh`)

**DEPRECATED**: This script uses the legacy `terraform/` directory and only deploys the analytics service. Use `deploy-labs.sh` instead.

### Complete Deployment Sequence

To deploy everything for staging:

```bash
# 1. Deploy labs infrastructure (analytics service)
./deploy/deploy-labs.sh

# 2. Deploy home infrastructure (SEO and Index services)
./deploy/deploy-home.sh
```

### Individual Lab Services

The individual lab services (Lab 1: Basic Magecart, Lab 2: DOM Skimming, Lab 3: Extension Hijacking) are **not currently defined in Terraform**. They need to be deployed separately, likely via:

1. **Cloud Build** - Automated deployment via GitHub Actions
2. **Manual deployment** - Using `gcloud run deploy` commands
3. **Future Terraform** - Add lab service definitions to `terraform-labs/`

#### Lab Service Locations

- **Lab 1**: `labs/01-basic-magecart/`
- **Lab 2**: `labs/02-dom-skimming/`
- **Lab 3**: `labs/03-extension-hijacking/`

Each lab has its own `Dockerfile` and can be built and deployed independently.

### Service Dependencies

```
┌─────────────────┐
│  Index Service  │ (home project)
│  (Landing Page) │
└────────┬────────┘
         │
         ├──► SEO Service (home project)
         │
         └──► Analytics Service (labs project)
                  │
                  └──► Firestore Database (labs project)
```

### Environment Variables

All deploy scripts read from `.env` files:
- `.env.prd` - Production configuration
- `.env.stg` - Staging configuration
- `.env` - Symlink to either `.env.prd` or `.env.stg`

Required variables:
```bash
LABS_PROJECT_ID=labs-stg          # or labs-prd
LABS_REGION=us-central1
HOME_PROJECT_ID=labs-home-stg     # or labs-home-prd
```

### Troubleshooting Cloud Run

#### Only analytics service deployed

If you only see the analytics service, you need to:
1. Run `./deploy/deploy-home.sh` to deploy SEO and Index services
2. Check that `deploy_services=true` is set (it should be automatic)

#### Services not deploying

Check that:
- Docker images are built and pushed (run `build-images.sh` first)
- `deploy_services` variable is set to `true` in Terraform
- Service accounts have correct permissions
- Artifact Registry repositories exist

#### Individual labs not deployed

Individual lab services are not managed by Terraform yet. They need to be deployed separately via Cloud Build or manual `gcloud` commands.
