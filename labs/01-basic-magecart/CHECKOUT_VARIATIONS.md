# Checkout Page Variations - Educational Comparison

This lab includes **two different checkout page variations** to demonstrate
different attack methodologies.

## 📁 Files Included

```
vulnerable-site/
├── checkout-separate.html          # Uses 2 separate JS files
├── checkout-single.html            # Uses 1 compromised JS file
└── js/
    ├── checkout.js                 # Legitimate checkout code only
    ├── skimmer-clean.js            # Malicious skimmer only
    └── checkout-compromised.js     # Both legitimate + malicious
```

## 🎯 Learning Objectives

Understanding the difference between:

1. **Adding a new malicious file** (less common, easier to detect)
2. **Modifying an existing file** (more realistic, harder to detect)

---

## Variation 1: Separate Script Files

**File:** `checkout-separate.html`

### How It Works

```html
<!-- Loads TWO JavaScript files -->
<script src="js/checkout.js"></script>
<!-- Legitimate -->
<script src="js/skimmer-clean.js"></script>
<!-- Malicious -->
```

### Attack Scenario

The attacker **added a new script tag** to the HTML by:

- Compromising a CMS admin panel
- Exploiting a third-party script (supply chain attack)
- Modifying HTML template files
- Injecting via vulnerable plugin

### Real-World Examples

- **Ticketmaster (2018)**: Third-party Inbenta chatbot was compromised
- **Supply Chain Attacks**: Compromised CDN adds new script references
- **Plugin Vulnerabilities**: Malicious WordPress plugins inject new scripts

### Detection Methods

✅ **Easier to Detect:**

- New script tag in HTML source
- Unfamiliar script file in file system
- Additional HTTP request in Network tab
- File Integrity Monitoring (FIM) catches new file
- Content Security Policy (CSP) blocks unauthorized domain

### Educational Value

Good for:

- Beginners learning about script injection
- Understanding supply chain attacks
- Practicing CSP implementation
- Learning HTML-based detection

---

## Variation 2: Single Compromised File (MORE REALISTIC)

**File:** `checkout-single.html`

### How It Works

```html
<!-- Loads ONE JavaScript file (that's been modified) -->
<script src="js/checkout-compromised.js"></script>
```

### File Structure

```javascript
// checkout-compromised.js

// Lines 1-250: LEGITIMATE CODE
;(function () {
  'use strict'
  // Original checkout functionality
  // Form validation
  // Payment processing
  // etc.
})()

// Lines 251+: MALICIOUS CODE (appended by attacker)
;(function () {
  'use strict'
  // Credit card skimmer
  // Data exfiltration
  // etc.
})()
```

### Attack Scenario - British Airways Style

The attacker **modified an existing file** by:

- Using stolen admin/developer credentials (no MFA)
- Accessing the web server via SSH/FTP
- Appending malicious code to `checkout.js`
- Making changes outside business hours
- Blending code to look legitimate

**Timeline:**

- August 21, 2018, 22:58 BST - File modified
- September 5, 2018, 21:45 BST - Attack discovered
- **Duration: 15 days undetected**
- **Victims: 380,000 customers**

### Real-World Examples

- **British Airways (2018)**: Modified Modernizr library
- **Newegg (2018)**: Modified payment page JavaScript
- **MyPillow (2019)**: Modified LiveChat script

### Detection Methods

❌ **Harder to Detect:**

- No new files created
- Same filename as legitimate code
- Same HTTP request (no new domains initially)
- Requires code review or file hash comparison
- FIM only works if checksums/hashes are monitored

✅ **Detection Strategies:**

- File Integrity Monitoring with hash verification
- Git-based version control and diffs
- Regular security audits
- Anomaly detection (file modified outside deploy window)
- Network monitoring for new exfiltration endpoints
- Browser DevTools inspection

### Educational Value

**Best for:**

- Advanced students
- Understanding real-world attack patterns
- Practicing code review skills
- Learning file integrity monitoring
- Understanding why CSP alone isn't enough

---

## 🔄 Switching Between Variations

### In Docker Compose

Edit `docker-compose.yml` to copy the desired HTML file:

```yaml
# For Variation 1 (Separate Files)
volumes:
  - ./vulnerable-site:/usr/share/nginx/html:ro
  # Rename checkout-separate.html to checkout.html before starting

# For Variation 2 (Single Compromised File)
volumes:
  - ./vulnerable-site:/usr/share/nginx/html:ro
  # Rename checkout-single.html to checkout.html before starting
```

### Quick Switch Script

```bash
#!/bin/bash
# Switch between checkout variations

cd $HOME/projectos/e-skimming-labs/labs/01-basic-magecart/vulnerable-site

case "$1" in
  separate)
    cp checkout-separate.html checkout.html
```
