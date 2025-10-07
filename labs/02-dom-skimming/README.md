# Lab 2: DOM-Based Skimming

This lab demonstrates **DOM-based credit card skimming** attacks that manipulate the Document Object Model to capture payment data through real-time field monitoring and dynamic form injection.

## Attack Overview

Unlike traditional form submission interception (Lab 1), DOM-based skimming attacks operate by:

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

## Detection Signatures

### DOM API Abuse
```javascript
// MutationObserver for payment form detection
new MutationObserver(callback).observe(document, {
  childList: true,
  subtree: true,
  attributes: true
});

// Shadow DOM creation for stealth
element.attachShadow({mode: 'closed'});

// Dynamic element injection
document.createElement('form');
element.innerHTML = maliciousForm;
```

### Event Listener Patterns
```javascript
// Real-time field monitoring
element.addEventListener('input', captureData);
element.addEventListener('change', captureData);
element.addEventListener('keyup', captureData);

// Payment-specific targeting
document.querySelectorAll('[type="password"], [autocomplete*="cc"]');
```

### DOM Traversal Signatures
```javascript
// Payment field discovery
document.querySelectorAll('[name*="card"], [id*="credit"]');
document.querySelector('[data-payment], [class*="payment"]');

// Form overlay injection
parentElement.insertBefore(fakeForm, realForm);
realForm.style.display = 'none';
```

## File Structure

```
02-dom-skimming/
├── vulnerable-site/           # Target banking/payment website
│   ├── banking.html          # Main banking interface
│   ├── payment.html          # Payment form page
│   ├── js/
│   │   ├── banking.js        # Legitimate banking code
│   │   └── payment.js        # Legitimate payment processing
│   ├── css/
│   │   ├── banking.css       # Banking interface styles
│   │   └── payment.css       # Payment form styles
│   └── images/               # Banking UI assets
├── malicious-code/           # Attack implementations
│   ├── dom-monitor.js        # Real-time field monitoring
│   ├── form-overlay.js       # Dynamic form injection
│   ├── shadow-skimmer.js     # Shadow DOM attack
│   └── c2-server.js          # C2 for DOM-based exfiltration
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

This lab provides comprehensive training data for detecting modern DOM-based skimming attacks that operate through page structure manipulation rather than traditional code injection.