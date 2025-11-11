# Training Versions Implementation Plan

## Overview
Create training versions of all lab checkout/payment pages for AI training. Training versions should:
- Remove all warning/explanation sections (only show the form)
- Use benign function names (not obfuscated)
- Have random word suffix in filenames (e.g., `checkout-train.html`)
- Be served in staging environment (labs.stg.pcioasis.com or APP_ENV=STG)
- Lab versions served in production (labs.pcioasis.com or APP_ENV=PRD)

## File Structure

### Lab 1: Basic Magecart
- **Lab version**: `checkout.html` (with warnings) → served in PRD
- **Training version**: `checkout-train.html` (no warnings) → served in STG
- **Lab JS**: `js/checkout-compromised.js` (obfuscated names)
- **Training JS**: `js/checkout-process-train.js` (benign names: `processPaymentData`, `sendPaymentData`, etc.)

### Lab 2: DOM-Based Skimming
- **Lab version**: `banking.html` (with warnings) → served in PRD
- **Training version**: `banking-train.html` (no warnings) → served in STG
- **Lab JS**: `js/banking.js` + malicious code (obfuscated)
- **Training JS**: `js/banking-process-train.js` (benign names)

### Lab 3: Extension Hijacking
- **Lab version**: `index.html` (with warnings) → served in PRD
- **Training version**: `index-train.html` (no warnings) → served in STG
- **Lab JS**: `js/checkout.js` + extension code (obfuscated)
- **Training JS**: `js/checkout-process-train.js` (benign names)

## Environment Detection

Environment detection is done via hostname:
- `labs.pcioasis.com` or Cloud Run production → Serve lab versions
- `labs.stg.pcioasis.com` or APP_ENV=STG → Serve training versions

## Implementation Steps

1. ✅ Add warning sections to Lab 2 and Lab 3 (completed)
2. Create training HTML files (remove warnings, update JS references)
3. Create training JS files (benign function names)
4. Update nginx/server configs to serve correct version based on environment
5. Update index pages to link to correct checkout version

## Function Name Mapping (Training Versions)

### Lab 1
- `extractCardData()` → `processPaymentData()`
- `exfiltrateData()` → `sendPaymentData()`
- `getFieldValue()` → `getFormFieldValue()`
- `log()` → `logPaymentEvent()`

### Lab 2
- Malicious function names → Benign equivalents
- `form-overlay.js` → `form-overlay-train.js` with benign names
- `dom-monitor.js` → `dom-monitor-train.js` with benign names
- `shadow-skimmer.js` → `shadow-skimmer-train.js` with benign names

### Lab 3
- Extension malicious functions → Benign equivalents
- `background.js` → `background-train.js` with benign names
- `content.js` → `content-train.js` with benign names

## Nginx/Server Configuration

Update nginx configs to:
- Check hostname or APP_ENV
- Serve `checkout.html` in PRD, `checkout-train.html` in STG
- Serve `banking.html` in PRD, `banking-train.html` in STG
- Serve `index.html` in PRD, `index-train.html` in STG

