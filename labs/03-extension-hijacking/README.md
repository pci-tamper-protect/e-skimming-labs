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

### Detection Signatures

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
