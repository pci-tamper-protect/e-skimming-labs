# Storage Strategy for E-Skimming Labs C2 Server

## Overview

The C2 server manages all data persistence for e-skimming attacks. Labs simply POST attack data via simple HTTP requests - the C2 server handles storage abstraction, aggregation, and optimization transparently.

## Architecture Principles

### 1. **C2 Server Owns Storage Complexity**
- Labs send simple HTTP POST requests to `/collect`
- C2 server handles storage mode detection (local vs cloud)
- Storage implementation is completely transparent to attack code
- No storage logic in attack scripts or vulnerable sites

### 2. **Environment-Based Storage Selection**
- **Local Development**: File-based storage with volume mounts
- **Cloud Run**: Automatic Cloud Storage with smart aggregation
- **Staging**: Configurable batch windows for faster testing
- **Production**: Cost-optimized aggregation settings

### 3. **Smart Aggregation for Cloud Storage**
- Time-based batch files instead of individual attack records
- Pre-computed summary indexes for fast dashboard queries
- Multi-level caching to minimize Cloud Storage API calls
- Automatic batch flushing based on size and time limits

## Storage Modes

### Local Storage Mode
```bash
# Development with persistent volume mounts
STORAGE_MODE=local
# Data stored in: ./stolen-data/stolen.json
# Analysis stored in: ./analysis/analysis_*.json
```

**Benefits:**
- Zero cloud dependencies for development
- Instant writes with no network latency
- Simple JSON file format for debugging
- Volume mounts preserve data across container restarts

### Cloud Storage Mode (Smart Aggregation)
```bash
# Production with intelligent batching
STORAGE_MODE=cloud
C2_STORAGE_BUCKET=e-skimming-labs-c2-data
BATCH_WINDOW_MINUTES=60        # 1-hour batch windows
MAX_BATCH_SIZE=500             # Max attacks per batch file
CACHE_TTL_MINUTES=5            # Dashboard cache duration
```

**Benefits:**
- 95% cost reduction vs naive individual files
- 99% reduction in Cloud Storage API calls
- Sub-second dashboard loading with caching
- Automatic batch optimization and retry logic

## File Organization Strategy

### Local Mode Structure
```
./stolen-data/
├── stolen.json                 # All attacks in single file
└── analysis/
    └── analysis_*.json         # Individual analysis files
```

### Cloud Storage Structure (Hierarchical Aggregation)
```
gs://e-skimming-labs-c2-data/
├── lab2-dom-skimming/
│   ├── attacks/                     # Time-organized attack batches
│   │   ├── 2026-03-07-14/          # Hourly batch windows  
│   │   │   ├── batch_001.json      # ~500 attacks per batch
│   │   │   └── batch_002.json      # Automatic splitting
│   │   ├── 2026-03-07-15/
│   │   │   └── batch_001.json
│   │   └── 2026-03-08-09/
│   │       ├── batch_001.json
│   │       └── batch_002.json
│   ├── index/                       # Pre-computed aggregations
│   │   ├── daily-summary.json      # Fast dashboard stats
│   │   └── weekly-summary.json     # Historical trends
│   └── analysis/
│       └── YYYY-MM-DD/             # Daily analysis batches
└── lab3-extension-hijacking/       # Multi-lab isolation
    └── attacks/...
```

## Batch File Format

### Attack Batch Structure
```json
{
  "batchId": "instance_1709834400000",
  "batchWindow": "2026-03-07-14",
  "timestamp": 1709834400000,
  "batchSize": 247,
  "attacks": [
    {
      "type": "form_submission",
      "formData": { "..." },
      "serverTimestamp": 1709834380000,
      "attackType": "dom-monitor",
      "labId": "lab2-dom-skimming",
      "instanceId": "abc123-def456"
    }
  ],
  "summary": {
    "totalAttacks": 247,
    "cardDataCount": 18,
    "formSubmissionCount": 15,
    "attackTypes": ["dom-monitor", "form-overlay"],
    "timeRange": {
      "start": 1709834340000,
      "end": 1709834399000
    },
    "uniqueVictims": 7
  }
}
```

### Daily Summary Index
```json
{
  "2026-03-07": {
    "totalAttacks": 1250,
    "cardDataCount": 89,
    "formSubmissionCount": 76,
    "uniqueVictims": 23,
    "batchWindows": ["2026-03-07-09", "2026-03-07-14", "2026-03-07-20"],
    "uniqueVictimsCount": 23
  },
  "2026-03-08": {
    "totalAttacks": 892,
    "cardDataCount": 67,
    "formSubmissionCount": 54,
    "uniqueVictims": 19,
    "batchWindows": ["2026-03-08-10", "2026-03-08-15"],
    "uniqueVictimsCount": 19
  }
}
```

## API Interface

### Attack Collection (Labs → C2 Server)
```javascript
// Labs send simple POST requests with attack data
POST /collect
Content-Type: application/json

{
  "type": "form_submission",
  "formId": "add-card-form", 
  "formData": {
    "card-number": { "fieldType": "text", "valueLength": 16, "isHighValue": true },
    "cvv": { "fieldType": "text", "valueLength": 3, "isHighValue": true }
  },
  "metadata": {
    "url": "https://lab2.local/banking.html",
    "userAgent": "Mozilla/5.0...",
    "startTime": 1709834380000
  }
}

// C2 server handles all storage complexity transparently
Response:
{
  "success": true,
  "sessionId": "session_1709834400_abc123",
  "timestamp": 1709834400000,
  "analysis": {
    "severity": "high",
    "riskScore": 75
  }
}
```

### Dashboard Queries (Dashboard → C2 Server)
```javascript
// Fast aggregated statistics (uses summary indexes)
GET /stats
Response: {
  "totalAttacks": 2142,
  "cardDataCaptures": 156,
  "uniqueVictims": 42,
  "activeDays": 7,
  "cacheStatus": "optimized",
  "storageMode": "cloud"
}

// Recent attack data with caching
GET /api/stolen?limit=100
Response: [
  { "type": "form_submission", "formData": {...}, "serverTimestamp": 1709834380000 },
  { "type": "dom_monitor", "summary": {...}, "serverTimestamp": 1709834370000 }
]

// Time-windowed queries for analysis
GET /api/stolen?window=2026-03-07-14&limit=500
GET /api/stolen?days=7&attackType=form_submission
```

## Performance Characteristics

### Dashboard Loading Performance
| Storage Mode | Initial Load | Cached Load | API Calls | Cost/Month |
|--------------|--------------|-------------|-----------|------------|
| Local Mode | 50-200ms | 10-50ms | 0 | $0 |
| Cloud (Naive) | 15-30s | 15-30s | 1000+ | $50+ |
| **Cloud (Smart)** | **500ms-2s** | **100-300ms** | **2-8** | **$2-5** |

### Batch Performance Characteristics
```bash
# Typical batch sizes by configuration
BATCH_WINDOW_MINUTES=15  →  ~125 attacks/batch  →  Fast feedback for testing
BATCH_WINDOW_MINUTES=60  →  ~500 attacks/batch  →  Cost-optimized for production
BATCH_WINDOW_MINUTES=240 → ~2000 attacks/batch  →  High-volume scenarios
```

## Configuration Management

### Environment Variable Hierarchy
```bash
# Storage mode (auto-detects Cloud Run environment)
STORAGE_MODE=cloud|local|auto         # Default: auto

# Cloud Storage settings
C2_STORAGE_BUCKET=bucket-name         # Required for cloud mode
GOOGLE_CLOUD_PROJECT=project-id       # Auto-detected on Cloud Run
LAB_ID=lab2-dom-skimming             # Multi-lab isolation

# Performance tuning
BATCH_WINDOW_MINUTES=60              # Batch time window
MAX_BATCH_SIZE=500                   # Max attacks per batch file  
CACHE_TTL_MINUTES=5                  # In-memory cache duration
MAX_BATCH_SIZE_BYTES=5242880         # 5MB max per batch file

# Legacy compatibility
C2_STANDALONE=true|false             # Port selection for Cloud Run
```

### Deployment Configurations
```yaml
# Development (docker-compose.persistent.yml)
environment:
  - STORAGE_MODE=local
volumes:
  - ./data/stolen-data:/app/stolen-data
  - ./data/analysis:/app/analysis

# Staging (faster feedback)
environment:
  - STORAGE_MODE=cloud
  - BATCH_WINDOW_MINUTES=15
  - CACHE_TTL_MINUTES=1
  - C2_STORAGE_BUCKET=staging-bucket

# Production (cost optimized)  
environment:
  - STORAGE_MODE=cloud
  - BATCH_WINDOW_MINUTES=60
  - CACHE_TTL_MINUTES=5
  - C2_STORAGE_BUCKET=production-bucket
```

## Implementation Architecture

### Storage Adapter Interface
```javascript
// All storage modes implement this interface
class StorageAdapter {
  async saveAttackData(attackType, data)     // Store attack with enrichment
  async getRecentAttacks(limit)              // Dashboard recent data
  async getStatsSummary()                    // Dashboard aggregated stats  
  async saveAnalysis(analysis)               // Store threat analysis
  async healthCheck()                        // Storage connectivity status
  async cleanup()                            // Graceful shutdown
}
```

### Automatic Mode Detection
```javascript
function detectStorageMode() {
  // Auto-detect based on environment
  if (process.env.K_SERVICE && CloudStorageAdapter) {
    return 'cloud'  // Cloud Run environment
  }
  return 'local'    // Local/container environment
}
```

## Cost Analysis

### Cloud Storage Cost Breakdown
```bash
# Typical lab session: 1000 attack events

## Naive Individual Files (❌)
- 1000 individual writes:     1000 × $0.002 = $2.00
- Dashboard list operations:  1000 × $0.0004 = $0.40  
- Dashboard downloads:        1000 × $0.0004 = $0.40
- Storage (1000 × 5KB):       5MB × $0.02/GB = $0.0001
- Total per session:          $2.80

## Smart Aggregation (✅)
- 2 batch writes:             2 × $0.002 = $0.004
- Dashboard list operations:  2 × $0.0004 = $0.0008
- Dashboard downloads:        2 × $0.0004 = $0.0008
- Storage (2 × 2.5MB):        5MB × $0.02/GB = $0.0001
- Summary index updates:      1 × $0.002 = $0.002
- Total per session:          $0.008

## Cost Reduction: 99.7% savings ($2.80 → $0.008)
```

### Performance Comparison
```bash
# Dashboard loading times (1000 attack events)
Local Mode:           50-200ms    (File system read)
Cloud Naive:          15-30s      (1000+ API calls)
Cloud Smart (cold):   500ms-2s    (2-4 API calls)
Cloud Smart (cached): 100-300ms   (Memory cache hit)
```

## Monitoring and Observability

### Health Check Endpoints
```javascript
GET /health
Response: {
  "status": "healthy",
  "timestamp": 1709834400000,
  "storageMode": "cloud", 
  "environment": "cloud-run",
  "storage": {
    "status": "connected",
    "bucket": "e-skimming-labs-c2-data"
  },
  "cache": {
    "summary": "cached",
    "recentData": "500 items"  
  }
}
```

### Application Metrics
```bash
# Built-in performance metrics
- Batch flush frequency and size
- Cache hit/miss rates  
- Storage operation latency
- API call reduction percentage
- Cost tracking (estimated)
```

### Logging Strategy
```bash
# Structured logging for operational visibility
[SmartAggregation] Flushed batch: 247 attacks to window 2026-03-07-14
[SmartAggregation] Cache hit: summary (5min TTL remaining)
[SmartAggregation] Loaded 1250 attacks from 4 windows (cache miss)
[C2-Server] HIGH SEVERITY ATTACK: form_submission (risk: 85)
```

## Migration and Rollback Strategy

### Container Image Approach
```dockerfile
# Support both storage modes in single image
COPY server.js server-enhanced.js cloud-storage-adapter.js smart-aggregation-adapter.js ./

# Runtime mode selection via environment variables
CMD ["node", "server-enhanced.js"]
```

### Development Workflow
```bash
# Local development (no cloud dependencies)
docker-compose -f docker-compose.persistent.yml up

# Test cloud storage locally  
export STORAGE_MODE=cloud GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
npm run start:enhanced

# Deploy to staging
gcloud run deploy lab2-c2-staging --set-env-vars "BATCH_WINDOW_MINUTES=15"

# Deploy to production  
gcloud run deploy lab2-c2-server --set-env-vars "BATCH_WINDOW_MINUTES=60"
```

### Rollback Capability
```bash
# Immediate rollback to local mode (emergency)
gcloud run services update lab2-c2-server --set-env-vars "STORAGE_MODE=local"

# Gradual migration via feature flags
STORAGE_MODE=local              # 100% local mode
STORAGE_MODE=hybrid             # Write to both, read from local  
STORAGE_MODE=cloud              # 100% cloud mode
```

## Security Considerations

### Data Isolation
- **Multi-tenancy**: Each lab gets isolated storage path (`LAB_ID`)
- **Instance isolation**: Each container instance gets unique ID  
- **Time partitioning**: Batch windows prevent data mixing

### Access Control
```bash
# Minimal Cloud Storage permissions
- storage.objects.create    # Write batch files
- storage.objects.get       # Read for aggregation
- storage.objects.list      # List batch files in time windows
- storage.buckets.get       # Health check bucket access
```

### Data Retention
```bash 
# Automatic cleanup policies (Cloud Storage lifecycle)
- Delete batch files > 30 days old
- Archive summary indexes > 90 days old  
- Retain analysis files for 1 year
```

## Conclusion

This storage strategy provides:
- **Zero storage complexity** for labs (simple HTTP POST)
- **Optimal performance** for each deployment environment  
- **95%+ cost reduction** for cloud deployments
- **Sub-second dashboard loading** with intelligent caching
- **Transparent migration** between local and cloud modes
- **Production-ready** scalability and reliability

The C2 server abstracts all storage complexity, allowing labs to focus purely on attack simulation while providing excellent dashboard performance and minimal operational costs.
