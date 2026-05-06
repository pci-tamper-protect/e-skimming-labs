# Lab 2 C2 Server - Cloud Storage Deployment Guide

## Quick Deploy Options

### 1. Local Development (Persistent Volumes)
```bash
# Use volume mounts - no cloud storage needed
docker-compose -f c2-server/docker-compose.persistent.yml up lab2-c2-persistent
```

### 2. Cloud Run with Smart Aggregation
```bash
cd c2-server/
gcloud run deploy lab2-c2-server \
  --source . \
  --region us-central1 \
  --set-env-vars "\
STORAGE_MODE=cloud,\
C2_STORAGE_BUCKET=e-skimming-labs-c2-data,\
LAB_ID=lab2-dom-skimming,\
BATCH_WINDOW_MINUTES=60,\
MAX_BATCH_SIZE=500,\
CACHE_TTL_MINUTES=5"
```

### 3. Test Smart Aggregation Locally  
```bash
# Test cloud storage behavior locally (requires GCP credentials)
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
export STORAGE_MODE=cloud
export C2_STORAGE_BUCKET=your-test-bucket
npm run start:enhanced
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `STORAGE_MODE` | `auto` | `local` or `cloud` (auto-detects Cloud Run) |
| `C2_STORAGE_BUCKET` | `e-skimming-labs-c2-data` | Cloud Storage bucket name |
| `LAB_ID` | `lab2-dom-skimming` | Lab identifier for multi-tenant storage |
| `BATCH_WINDOW_MINUTES` | `60` | Time window for batching (60 = hourly batches) |
| `MAX_BATCH_SIZE` | `500` | Maximum attacks per batch file |
| `CACHE_TTL_MINUTES` | `5` | Dashboard cache duration |
| `C2_STANDALONE` | `auto` | `true` for Cloud Run, `false` for nginx proxy |
| `GOOGLE_CLOUD_PROJECT` | - | GCP project ID (auto-detected on Cloud Run) |

## Deployment Performance Tuning

### Development/Testing (Fast feedback)
```bash
BATCH_WINDOW_MINUTES=15     # 15-minute batches
MAX_BATCH_SIZE=100          # Smaller batches  
CACHE_TTL_MINUTES=1         # Shorter cache for testing
```

### Production (Cost optimized)  
```bash
BATCH_WINDOW_MINUTES=60     # 1-hour batches
MAX_BATCH_SIZE=500          # Larger batches
CACHE_TTL_MINUTES=5         # Longer cache duration
```

### High-Volume Labs (Performance optimized)
```bash
BATCH_WINDOW_MINUTES=30     # 30-minute batches
MAX_BATCH_SIZE=1000         # Very large batches
CACHE_TTL_MINUTES=10        # Extended cache
```

## Storage Cost Estimates

**Typical Lab Usage (1000 attack events):**
- Individual files: ~$2.00/month (1000 × $0.002 per operation)
- Smart aggregation: ~$0.05/month (2 batch files × $0.002 + storage)
- **95% cost reduction**

**API Call Reduction:**
- Before: 1000+ list operations + 1000+ downloads = 2000+ API calls
- After: 2-4 list operations + 2-4 downloads = 4-8 API calls  
- **99%+ API call reduction**
