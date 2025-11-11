# Training Versions Implementation Status

## ✅ Completed

### Lab 1: Basic Magecart
- ✅ Added warning sections to `checkout.html` (lab version)
- ✅ Created `checkout-train.html` (training version - no warnings)
- ✅ Created `js/checkout-process-train.js` (training JS with benign function names)
  - `extractCardData()` → `processPaymentData()`
  - `exfiltrateData()` → `sendPaymentData()`
  - `getFieldValue()` → `getFormFieldValue()`
  - `log()` → `logPaymentEvent()`
  - `initSkimmer()` → `initPaymentProcessor()`
  - `hasValidCardData()` → `validatePaymentData()`

### Lab 2: DOM-Based Skimming
- ✅ Added warning sections to `banking.html` (lab version)
- ✅ Created `banking-train.html` (training version - no warnings)
- ✅ Updated JS reference in `banking-train.html` to use `js/banking-process-train.js`
- ⚠️ **TODO**: Create `js/banking-process-train.js` with benign function names

### Lab 3: Extension Hijacking
- ✅ Added warning sections to `index.html` (lab version)
- ⚠️ **TODO**: Create `index-train.html` (training version - no warnings)
- ⚠️ **TODO**: Create training JS files with benign function names

## 🔄 Remaining Tasks

### Lab 2 Training JS Files
Need to create training versions of malicious code files with benign names:
- `malicious-code/form-overlay.js` → `js/form-overlay-train.js`
- `malicious-code/dom-monitor.js` → `js/dom-monitor-train.js`
- `malicious-code/shadow-skimmer.js` → `js/shadow-skimmer-train.js`

Then create `js/banking-process-train.js` that loads these training versions instead of the malicious ones.

### Lab 3 Training Files
- Create `index-train.html` (remove warnings, update JS references)
- Create training versions of extension code with benign names
- Update JS references to use training versions

### Environment-Based Serving
Update nginx/server configurations to:
- **Production** (`labs.pcioasis.com` or `APP_ENV=PRD`):
  - Serve `checkout.html`, `banking.html`, `index.html` (lab versions with warnings)
- **Staging** (`labs.stg.pcioasis.com` or `APP_ENV=STG`):
  - Serve `checkout-train.html`, `banking-train.html`, `index-train.html` (training versions without warnings)

## Implementation Pattern

### For Lab 2 and Lab 3:
1. Copy the malicious code files
2. Rename functions to benign equivalents:
   - `captureData()` → `processFormData()`
   - `steal()` → `send()`
   - `exfiltrate()` → `transmit()`
   - `skimmer` → `processor`
   - `attack` → `handler`
3. Update variable names:
   - `malicious` → `handler`
   - `steal` → `process`
   - `exfil` → `transmit`
4. Update file references in training HTML files

## Next Steps

1. Complete Lab 2 training JS files
2. Complete Lab 3 training files
3. Set up nginx/server environment-based routing
4. Test both versions in their respective environments

