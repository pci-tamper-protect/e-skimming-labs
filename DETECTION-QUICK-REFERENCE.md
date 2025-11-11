# E-Skimming Detection Quick Reference Guide

## Detection Priority by Attack Type

### LAB 01: Basic Magecart - EASY TO DETECT
**Primary Indicators:**
- Two IIFE blocks in same JavaScript file
- Configuration object with `exfilUrl`
- Form submission event listeners
- POST requests to suspicious endpoints
- Visible in Network DevTools

**Quick Check:**
```bash
grep -n "exfilUrl\|CONFIG\|exfiltrate" *.js
```

**Tools:**
- Browser DevTools Network tab (easiest)
- Code grep for suspicious domains
- File integrity monitoring

---

### LAB 02A: Shadow DOM Skimming - HARD TO DETECT
**Primary Indicators:**
- Zero-sized elements with `z-index: -1`
- Closed shadow DOM: `attachShadow({ mode: 'closed' })`
- Property descriptor overrides: `Object.defineProperty()`
- Prototype modifications: `Element.prototype.addEventListener`
- DevTools detection code

**Quick Check:**
```javascript
// Run in DevTools console
Object.keys(document.body).filter(k => document.body[k]?.shadowRoot)
// Look for closed shadows you didn't create
```

**Tools:**
- DOM inspection (look for hidden elements)
- JavaScript inspector (prototype modifications)
- Console monitoring

---

### LAB 02B: Real-Time DOM Monitoring - MEDIUM DIFFICULTY
**Primary Indicators:**
- MutationObserver on document
- Keystroke event listeners (keydown/keyup)
- Multiple autocomplete attribute patterns
- Periodic exfiltration intervals
- WeakSet for element tracking

**Quick Check:**
```javascript
// Run in DevTools console
document.querySelectorAll('input[autocomplete*="cc-"]').length > 0
// Check for MutationObserver
getEventListeners(document).DOMContentLoaded
```

**Tools:**
- Network tab monitoring
- Event listener inspection
- Performance profiler

---

### LAB 03: Extension Hijacking - VERY HARD TO DETECT
**Primary Indicators:**
- Extension permissions abuse
- Legitimate code + malicious code mixed
- Cookies/localStorage harvesting
- Clipboard monitoring
- Multi-channel C2 exfiltration
- No visible network signatures (extension privileges)

**Quick Check:**
```javascript
// Check for suspicious extension behavior
chrome.runtime.onMessage.addListener(...)
// Look for form data collection patterns
document.querySelectorAll('input[type="password"]')
```

**Tools:**
- Extension manifest audit
- Source code analysis
- Extension storage inspection

---

## Universal Detection Patterns

### Pattern 1: Payment Field Targeting
```javascript
// SUSPICIOUS
'input[name*="card"]'
'input[name*="cvv"]'
'input[autocomplete*="cc-"]'
'input[id*="cardnumber"]'

// Detection: Look for multiple similar selectors
grep -E "card|cvv|cvc|account|routing" malicious-file.js
```

### Pattern 2: Form Submission Hijacking
```javascript
// SUSPICIOUS
form.addEventListener('submit', e => {
  extractFormData()
  exfiltrateData()
})

// Detection: Check event listeners on forms
// Tools → Sources → Event Listeners
```

### Pattern 3: Keystroke Logging
```javascript
// SUSPICIOUS
document.addEventListener('keydown', e => {
  keystrokes.push(e.key)
})

// Detection: Look for keystroke event listeners
getEventListeners(document).keydown
```

### Pattern 4: C2 Communication
```javascript
// SUSPICIOUS ENDPOINTS
'http://localhost:9002/collect'
'http://attacker.com/beacon'
'https://evil-server.com/data'

// Detection: Network tab shows POST requests
// Filter: xhr/fetch to external domains
```

### Pattern 5: Data Exfiltration
```javascript
// SUSPICIOUS PATTERNS
fetch(url, { method: 'POST', body: JSON.stringify(stolenData) })
navigator.sendBeacon(url, data)
new Image().src = url + '?data=' + btoa(data)

// Detection: Monitor network requests
// Look for base64-encoded query parameters
```

---

## Browser DevTools Detection Steps

### Step 1: Network Monitoring
1. Open DevTools → Network tab
2. Add filter: `type:xhr OR type:fetch`
3. Fill out payment form
4. Look for POST requests to suspicious domains
5. Right-click → Copy as cURL to inspect payload

### Step 2: Console Inspection
1. DevTools → Console
2. Type: `getEventListeners(document.forms[0])`
3. Look for unexpected 'submit' listeners
4. Expand and inspect listener code

### Step 3: Element Inspection
1. DevTools → Elements
2. Press Ctrl+H to toggle element picker
3. Look for hidden elements (0 width/height)
4. Check z-index values (negative = hidden)
5. Inspect element styles in Computed panel

### Step 4: Source Code Analysis
1. DevTools → Sources
2. Search for: `exfil`, `config`, `collect`
3. Look at malicious functions
4. Check for event listener attachments
5. Examine timestamps and delays

---

## Memory/Performance Indicators

### Lab 01
- Memory usage: LOW (basic listeners only)
- Network: ~1-2 POST requests per form submission
- CPU: Minimal impact

### Lab 02
- Memory usage: MEDIUM (storing keystroke data)
- Network: Periodic requests every 5-10 seconds
- CPU: Elevated (MutationObserver scanning)

### Lab 03
- Memory usage: HIGH (cookies, localStorage, keystrokes)
- Network: Internal (no visible external traffic)
- CPU: Elevated (multiple data collectors)

---

## Code Signature Cheat Sheet

| Attack | Signature | Detection |
|--------|-----------|-----------|
| Lab 01 | Two IIFE blocks | `grep -c "(function())"` |
| Lab 02A | Shadow DOM | `attachShadow({ mode:` |
| Lab 02A | Prototype hijacking | `prototype.*=` |
| Lab 02B | MutationObserver | `new MutationObserver` |
| Lab 02B | Keystroke logging | `addEventListener.*key` |
| Lab 03 | Form harvesting | `querySelectorAll.*input` |
| Lab 03 | Cookie theft | `document.cookie` |
| All | C2 endpoint | `exfil\|collect\|beacon` |

---

## Tool Recommendations

### 1. Static Analysis
- **grep/ripgrep**: Search for malicious patterns
- **JSUnfuscator**: Deobfuscate malicious code
- **AST Parser**: Analyze JavaScript AST

### 2. Dynamic Analysis
- **Chrome DevTools**: Real-time monitoring
- **Wireshark**: Network packet inspection
- **Burp Suite**: Request/response analysis

### 3. Extension Analysis
- **Extension source viewer**: Download and inspect
- **Manifest checker**: Verify permissions
- **APK/CRX extractor**: Extract files

### 4. Automated Detection
- **CSP reporters**: Monitor content security violations
- **WAF logs**: Detect outbound exfiltration
- **Network IDS**: Flag suspicious communications

---

## Remediation by Lab Type

### Lab 01: File Injection
1. Enable File Integrity Monitoring (FIM)
2. Implement Subresource Integrity (SRI)
3. Restrict admin account access
4. Code review automation

**CSP Header:**
```
Content-Security-Policy: script-src 'self'; connect-src 'self' https://api.trusted.com
```

### Lab 02: DOM Skimming
1. Monitor Shadow DOM creation
2. Restrict Object.defineProperty usage
3. Detect prototype modifications
4. Block DevTools detection code

**Detection Script:**
```javascript
if (window.eval) {
  const originalDefineProperty = Object.defineProperty
  Object.defineProperty = function(obj, prop, desc) {
    console.warn('defineProperty called:', obj, prop)
    return originalDefineProperty.apply(this, arguments)
  }
}
```

### Lab 03: Extension Hijacking
1. Audit extension permissions
2. Inspect source code regularly
3. Monitor background scripts
4. Validate manifest files

**Check Manifest:**
```json
{
  "permissions": ["<all_urls>"],  // RED FLAG
  "host_permissions": ["*://*/*"],  // RED FLAG
  "content_scripts": [...]  // Monitor carefully
}
```

---

## Attack Complexity Comparison

```
Difficulty to Detect:
├─ Lab 01 (Magecart) ........... ███░░░░░░ (3/10 - Very Easy)
├─ Lab 02B (DOM Monitor) ....... ██████░░░ (6/10 - Medium)
├─ Lab 02A (Shadow DOM) ........ ████████░ (8/10 - Hard)
└─ Lab 03 (Extension) .......... █████████ (9/10 - Very Hard)

Sophistication:
├─ Lab 01 ...................... ██░░░░░░░ (2024)
├─ Lab 02B ..................... ████░░░░░ (2023)
├─ Lab 02A ..................... ██████░░░ (2023)
└─ Lab 03 ...................... █████████ (2024+)
```

---

## Key Takeaways

1. **Lab 01**: Look for file injections and form hijacking - easiest to detect
2. **Lab 02A**: Shadow DOM abuse is highly sophisticated - requires deep DOM inspection
3. **Lab 02B**: Keystroke logging patterns are recognizable in network traffic
4. **Lab 03**: Extension trust exploitation is hardest - audit permissions and source code

---

## Emergency Detection Checklist

- [ ] Check Network tab for suspicious POST requests
- [ ] Search code for `exfil`, `collect`, `beacon`
- [ ] Inspect hidden elements (z-index < 0)
- [ ] Look for MutationObserver usage
- [ ] Check for prototype modifications
- [ ] Inspect form event listeners
- [ ] Review extension permissions
- [ ] Analyze CSP headers
- [ ] Check for sendBeacon calls
- [ ] Monitor memory usage spikes

---

Generated: 2024-11-10
Based on: E-Skimming Labs 01-03
