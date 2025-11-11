# Training Versions Implementation - Complete ✅

## Summary

All training versions have been created and environment-based serving has been configured. The labs now serve:
- **Lab versions** (with warnings) in **production** (`labs.pcioasis.com` or `APP_ENV=PRD`)
- **Training versions** (without warnings, benign names) in **staging** (`labs.stg.pcioasis.com` or `APP_ENV=STG`)

## Completed Implementation

### Lab 1: Basic Magecart ✅
- ✅ `checkout.html` - Lab version with warnings
- ✅ `checkout-train.html` - Training version without warnings
- ✅ `js/checkout-process-train.js` - Training JS with benign function names:
  - `extractCardData()` → `processPaymentData()`
  - `exfiltrateData()` → `sendPaymentData()`
  - `getFieldValue()` → `getFormFieldValue()`
  - `log()` → `logPaymentEvent()`
  - `initSkimmer()` → `initPaymentProcessor()`
  - `hasValidCardData()` → `validatePaymentData()`
- ✅ Nginx config updated for environment-based routing

### Lab 2: DOM-Based Skimming ✅
- ✅ `banking.html` - Lab version with warnings
- ✅ `banking-train.html` - Training version without warnings
- ✅ `js/banking-process-train.js` - Training JS with benign function names:
  - `processFormData()` - Processes form data
  - `sendFormData()` - Sends data to API
  - `getFormFieldValue()` - Gets field values
  - `validateFormData()` - Validates form data
  - `initFormProcessor()` - Initializes processor
  - `logProcessingEvent()` - Logs processing events
- ✅ Nginx config updated in Dockerfile for environment-based routing

### Lab 3: Extension Hijacking ✅
- ✅ `index.html` - Lab version with warnings
- ✅ `index-train.html` - Training version without warnings
- ✅ `js/checkout-process-train.js` - Training JS (copy of legitimate code, malicious code is in extension)
- ✅ Nginx config updated in Dockerfile for environment-based routing

## Environment-Based Serving

### Production Environment
- **Hostname**: `labs.pcioasis.com` or Cloud Run production URLs
- **Serves**: Lab versions with warnings
  - `checkout.html` (Lab 1)
  - `banking.html` (Lab 2)
  - `index.html` (Lab 3)

### Staging Environment
- **Hostname**: `labs.stg.pcioasis.com`
- **Serves**: Training versions without warnings
  - `checkout-train.html` (Lab 1)
  - `banking-train.html` (Lab 2)
  - `index-train.html` (Lab 3)

### Nginx Configuration
All nginx configs now include hostname-based routing:
```nginx
location = /checkout.html {
    if ($host ~* "stg\.pcioasis\.com") {
        rewrite ^/checkout.html$ /checkout-train.html last;
    }
    try_files $uri =404;
}
```

## File Structure

```
labs/
├── 01-basic-magecart/
│   └── vulnerable-site/
│       ├── checkout.html (lab version)
│       ├── checkout-train.html (training version)
│       ├── js/
│       │   ├── checkout-compromised.js (lab JS)
│       │   └── checkout-process-train.js (training JS)
│       └── nginx.conf (updated with routing)
├── 02-dom-skimming/
│   └── vulnerable-site/
│       ├── banking.html (lab version)
│       ├── banking-train.html (training version)
│       ├── js/
│       │   ├── banking.js (legitimate code)
│       │   └── banking-process-train.js (training JS)
│       └── Dockerfile (updated nginx config)
└── 03-extension-hijacking/
    └── vulnerable-site/
        ├── index.html (lab version)
        ├── index-train.html (training version)
        ├── js/
        │   ├── checkout.js (legitimate code)
        │   └── checkout-process-train.js (training JS)
        └── Dockerfile (updated nginx config)
```

## Function Name Mapping (Training → Lab)

### Lab 1
- `processPaymentData()` → `extractCardData()`
- `sendPaymentData()` → `exfiltrateData()`
- `getFormFieldValue()` → `getFieldValue()`
- `logPaymentEvent()` → `log()`
- `initPaymentProcessor()` → `initSkimmer()`
- `validatePaymentData()` → `hasValidCardData()`

### Lab 2
- `processFormData()` → Similar to malicious form processing
- `sendFormData()` → Similar to data exfiltration
- `getFormFieldValue()` → Field value extraction
- `validateFormData()` → Data validation
- `initFormProcessor()` → Initialization
- `logProcessingEvent()` → Logging

### Lab 3
- Training JS is a copy of legitimate code (malicious code is in browser extension)

## Testing

To test the environment-based serving:

1. **Production**: Access `https://labs.pcioasis.com/01-basic-magecart/checkout.html`
   - Should show warnings and use `checkout-compromised.js`

2. **Staging**: Access `https://labs.stg.pcioasis.com/01-basic-magecart/checkout.html`
   - Should redirect to `checkout-train.html` (no warnings) and use `checkout-process-train.js`

## Next Steps

1. Deploy updated Dockerfiles to staging and production
2. Test environment-based routing in both environments
3. Verify training versions are served correctly in staging
4. Verify lab versions are served correctly in production

