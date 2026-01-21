# E-Skimming Labs Documentation

## Quick Start

New to E-Skimming Labs? Start here:

| I want to... | Go to |
|--------------|-------|
| **Get started quickly** | [Getting Started](./getting-started/README.md) |
| **Deploy changes** | [Deployment Guide](./deployment/README.md) |
| **Run tests** | [Testing Guide](./testing/README.md) |
| **Fix an issue** | [Troubleshooting](./troubleshooting/README.md) |

## Documentation Structure

```
docs/
├── getting-started/           # How to run the labs
│   ├── README.md             # Overview of all modes
│   ├── LOCAL_SIDECAR.md      # Recommended: proxy to Cloud Run
│   ├── LOCAL_DOCKER.md       # Legacy: all services local
│   └── CLOUD_RUN.md          # Direct Cloud Run access
│
├── deployment/                # How to deploy
│   ├── README.md             # Deployment overview
│   ├── DEPLOY_HOME.md        # Deploy home services
│   ├── DEPLOY_LABS.md        # Deploy lab services
│   └── DEPLOY_TRAEFIK.md     # Deploy Traefik gateway
│
├── testing/                   # How to test
│   ├── README.md             # Testing overview
│   ├── LOCAL_TESTING.md      # Test locally
│   └── STAGING_TESTING.md    # Test in staging
│
├── architecture/              # How it works
│   └── ROUTING.md            # Routing architecture
│
└── troubleshooting/           # When things go wrong
    └── README.md             # Common issues & solutions
```

## Key Concepts

### Routing

All routing is handled by Traefik. Services use relative URLs only.

```
/           → home-index (landing page)
/lab1       → lab-01-basic-magecart
/lab2       → lab-02-dom-skimming
/lab3       → lab-03-extension-hijacking
```

[Learn more →](./architecture/ROUTING.md)

### Environments

| Environment | Gateway Port | Access |
|-------------|--------------|--------|
| Local Sidecar | 9090 | `docker compose -f docker-compose.sidecar-local.yml up -d` |
| Local Docker | 8080 | `docker-compose up -d` |
| Staging | 8082 (proxy) | `gcloud run services proxy traefik-stg ...` |
| Production | N/A | https://labs.pcioasis.com |

### Deploy Scripts

| Script | Purpose |
|--------|---------|
| `deploy-all-stg.sh` | Deploy everything |
| `deploy-home.sh stg` | Deploy home services |
| `deploy-labs.sh stg [01\|02\|03\|all]` | Deploy lab services |
| `traefik/deploy-sidecar.sh stg` | Deploy Traefik gateway |

## Legacy Documentation

The following docs are kept for reference but may be outdated:

- `SETUP.md` - Original setup guide (see `getting-started/` instead)
- `TRAEFIK-QUICKSTART.md` - Original Traefik guide (see `getting-started/` instead)
- `TRAEFIK-ARCHITECTURE.md` - Detailed architecture (see `architecture/` instead)
- `TESTING_TROUBLESHOOTING.md` - Original testing guide (see `testing/` instead)
- `STAGING.md` - Staging guide (see `testing/STAGING_TESTING.md` instead)

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.
