# E-Skimming Labs 🎓🔒

> **⚠️ EDUCATIONAL PURPOSE ONLY**  
> This repository contains working examples of e-skimming attacks for
> educational and research purposes. All code is provided to help security
> professionals, researchers, and developers understand these attacks and build
> better defenses. **DO NOT use this code for malicious purposes.**

An interactive educational platform for learning about e-skimming (web skimming,
formjacking, Magecart) attacks through hands-on labs with real-world scenarios.

## 🎯 Project Overview

E-skimming attacks have caused billions in damages and affected millions of
customers worldwide. This repository provides:

- **Working demonstrations** of major e-skimming attack types
- **Real-world compromise scenarios** (supply chain attacks, compromised
  credentials, vulnerability exploitation)
- **Technical analysis** of attack mechanisms
- **Detection techniques** and defensive measures
- **Historical context** from actual breaches

## 📚 What is E-Skimming?

E-skimming (also called web skimming, formjacking, or Magecart attacks) involves
injecting malicious JavaScript code into e-commerce websites to steal customer
payment information during checkout. These attacks:

- Operate client-side in the victim's browser
- Bypass traditional server-side security (WAFs)
- Often go undetected for weeks or months
- Can steal credit card data, CVV codes, and personal information
- Cost businesses millions in fines and lost customer trust

## 🏗️ Repository Structure

`*` Planned  

```
e-skimming-labs/
├── README.md                          # This file
├── labs/                              # Hands-on attack demonstrations
│   ├── 01-basic-magecart/            # Simple credit card skimmer
│   ├── 02-localstorage-scraper/      # Multi-form data collection
│   ├── 03-supply-chain-attack/       # Third-party script compromise
│   ├── 04-gtm-disguise/*              # Google Tag Manager masquerading
│   ├── 05-websocket-exfiltration/*    # WebSocket-based C2
│   ├── 06-404-page-injection/*        # Error page hiding technique
│   ├── 07-image-steganography/*       # Code hidden in images
│   ├── 08-woocommerce-skimmers/*      # WooTheme, Slect, Gateway variants
│   ├── 09-cosmicstingel*o**it/       # CVE-2024-34102 Magento XXE
│   └── 10-advanced-vas**ion/          # Anti-debugging & geofencing
├── detection/                         # Detection tools and techniques
│   ├── semgrep-rules/                # Static analysis rules
│   ├── browser-extensions/           # Runtime detection demos
│   └── csp-examples/                 # Content Security Policy configs
├── defense/                           # Defensive measures
│   ├── monitoring/                   # Logging and alerting examples
│   ├── integrity-checks/             # Subresource Integrity (SRI)
│   └── best-practices.md             # Security recommendations
└── docs/                              # Additional documentation
    ├── attack-timeline.md            # Historical attacks
    ├── techniques.md                 # Technical deep-dives
    └── references.md                 # Research papers and articles
```

## 🔬 Lab Structure

Each lab contains:

```
lab-name/
├── README.md                 # Lab overview and learning objectives
├── scenario.md              # Real-world compromise scenario
├── vulnerable-site/         # Victim e-commerce website
│   ├── docker-compose.yml   # Easy deployment
│   ├── index.html          # Product pages
│   ├── checkout.html       # Payment form
│   └── static/             # CSS, JS, images
├── malicious-code/         # Attack payloads
│   ├── skimmer.js          # Obfuscated version
│   ├── skimmer-clean.js    # Commented, readable version
│   └── c2-server/          # Data collection server
├── analysis/               # Technical breakdown
│   ├── deobfuscation.md    # How to analyze the code
│   ├── network-trace.pcap  # Captured traffic
│   └── detection.md        # How to detect this attack
└── exercises/              # Hands-on challenges
    ├── detect.md           # Find the skimmer
    ├── prevent.md          # Implement defenses
    └── solutions/          # Answer key
```

## 📖 Major Attack Types Covered

### 1. Magecart (Multiple Variants)

The most well-documented e-skimming operation, consisting of at least 13
different hacker groups active since 2015.

**Key Attacks:**

- **British Airways (2018)**: 380,000 victims via 22-line JavaScript skimmer
  that modified the Modernizr library, listening to mouseup/touchend events and
  exfiltrating data to baways.com
- **Ticketmaster (2018)**: 40,000 victims through compromised Inbenta chatbot
  third-party service
- **Newegg (2018)**: Direct injection into payment page source code

**Technical Characteristics:**

- Multi-form data collection using localStorage
- Support for various payment processors (Stripe, Adyen, PayPal)
- Sophisticated obfuscation techniques
- Supply chain targeting

### 2. WooCommerce-Specific Skimmers

Three distinct skimmers targeting the WooCommerce WordPress plugin (29% of top
e-commerce sites):

**a) WooTheme Skimmer**

- Simple, easily understood functions
- Typically obfuscated
- Exploits hacked WooCommerce themes

**b) Slect Skimmer**

- Named after intentional misspelling of "select"
- Variation of Grelos skimmer
- Exploits spelling typos to evade detection

**c) Gateway Skimmer**

- Multiple obfuscation layers
- Checks for Firebug debugger
- Highly complex code

### 3. Inter/SnifFall Skimmer Kit

Commercial skimmer-as-a-service developed by threat actor "Sochi":

- Originally $5,000 (2016), later $1,300 with profit-sharing (2018)
- Dashboard for generating/deploying skimmers
- Automated duplicate detection (MD5, cookies)
- Fake payment form creation
- Affected ~1,500 sites since 2018

### 4. Advanced Techniques

**Google Tag Manager Disguise:**

- Inline scripts resembling legitimate GTM snippets
- Base64 encoding for URL obfuscation
- WebSocket C2 communication

**404 Error Page Manipulation:**

- Hiding malicious code in default error pages
- Difficult to detect as errors are rarely inspected

**Image Steganography:**

- JavaScript encoded in PHP within image EXIF data
- Favicon-based code storage
- Data hidden in JPEG files

**Kritec Skimmer:**

- Multi-stage Base64-encoded loading
- Heavy obfuscation (obfuscator.io)
- Dual exfiltration (WebSocket + POST)

### 5. CosmicSting (CVE-2024-34102)

Critical XXE vulnerability in Adobe Commerce/Magento:

- **CVSS Score**: 9.8/10
- **Affected**: Magento 2.4.7 and earlier
- **Impact**: Remote code execution via XML External Entity exploitation
- **Result**: 3x increase in Magecart infections (11,000 domains in 2024)
- **Published Exploits**: Multiple PoC implementations available

## 🎭 Attack Evasion Techniques

Modern skimmers employ sophisticated evasion:

**Geofencing:**

- Serve malicious code only to specific countries
- Use VPN detection to avoid security researchers

**Environment Detection:**

- Browser fingerprinting (avoiding IE, detecting dev tools)
- Device type filtering (preferring mobile)
- OS detection (hiding from Linux users)
- Virtual machine detection via WebGL API (checking for "swiftshader",
  "llvmpipe", "virtualbox")

**Code Obfuscation:**

- Multiple encoding layers (Base64, hex, custom algorithms)
- Dynamic code execution (eval, Function constructor)
- Dead code injection
- Control flow flattening

**Anti-Debugging:**

- Firebug/DevTools detection
- Debugger statement traps
- Timing-based detection
- Console manipulation

## 🛡️ Detection & Defense

### Detection Tools Included

1. **Semgrep Rules** - Static analysis patterns for:
   - Obfuscated JavaScript
   - Credit card extraction patterns
   - Data exfiltration techniques
   - localStorage/sessionStorage abuse
   - Anti-debugging code

2. **Browser Extensions** - Runtime monitoring for:
   - Unexpected form data access
   - Suspicious network requests
   - Dynamic script injection

3. **Network Analysis** - PCAP files showing:
   - Exfiltration patterns
   - C2 communication
   - WebSocket abuse

### Defense Strategies

**Content Security Policy (CSP):**

- Restrict script sources
- Block inline scripts
- Report violations

**Subresource Integrity (SRI):**

- Cryptographic hashes for third-party scripts
- Prevent unauthorized modifications

**Behavioral Monitoring:**

- Track script execution patterns
- Alert on form data access
- Monitor network exfiltration

**Supply Chain Security:**

- Vendor security audits
- Dependency scanning
- Change monitoring

## 🚀 Getting Started

### Development Workflow

This repository uses PR-based deployment with branch protection:

- Create feature branches for changes
- Submit PRs to main branch for review
- GitHub Actions deploys to production on PR creation
- Manual workflow dispatch available for staging deployment

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for some labs)
- Python 3.8+ (for analysis tools)
- Modern browser (Chrome/Firefox recommended)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/e-skimming-labs.git
cd e-skimming-labs

# Start with Lab 01 - Basic Magecart
cd labs/01-basic-magecart
docker-compose up

# Visit http://localhost:3000
# Follow the README.md in the lab folder
```

### Recommended Learning Path

1. **Basics** (Labs 1-2): Understand fundamental skimming techniques
2. **Supply Chain** (Lab 3): Learn third-party compromise scenarios
3. **Evasion** (Labs 4-7): Study obfuscation and hiding techniques
4. **Platform-Specific** (Labs 8-9): Explore CMS vulnerabilities
5. **Advanced** (Lab 10): Master anti-detection methods

## 📊 Notable Real-World Breaches

| Attack          | Date     | Victims  | Method                          | Fine/Cost     |
| --------------- | -------- | -------- | ------------------------------- | ------------- |
| British Airways | Aug 2018 | 380,000  | Modified Modernizr library      | £20M ICO fine |
| Ticketmaster    | Jun 2018 | 40,000   | Compromised Inbenta chatbot     | £1.25M fine   |
| Newegg          | Sep 2018 | Unknown  | Direct payment page injection   | Undisclosed   |
| Forbes          | May 2019 | Unknown  | Third-party via fontsawesome.gq | Undisclosed   |
| Segway          | 2022     | 600,000+ | Code hidden in images           | Undisclosed   |
| ESA Store       | Dec 2024 | Unknown  | Checkout page injection         | Ongoing       |

## 📚 Research & Resources

### Academic Papers

- **"Formjacking attack: Are we safe?"** (Journal of Financial Crime, 2020)  
  Analysis of attack modus operandi and ML-based defense mechanisms

- **Palo Alto Networks Unit 42**: Anatomy of Formjacking Attacks  
  Detailed deobfuscation examples and anti-debug analysis

### Industry Reports

- **Recorded Future**: Annual Payment Fraud Intelligence Report 2024  
  11,000 domains compromised, CosmicSting impact analysis

- **RiskIQ & Flashpoint**: Inside Magecart (2018)  
  Profiling of attacker groups and infrastructure

- **Sansec**: What is Magecart?  
  Comprehensive taxonomy and 70,000+ compromised stores database

- **Microsoft Security**: Beneath the Surface - Web Skimming Evolution  
  Image-based hiding and modern obfuscation techniques

- **Akamai Security Research**: Multiple Magecart Campaign Reports  
  404 page manipulation, GTM disguise, WebSocket exfiltration

### Detection Tools

- **Santander Security Research**:
  [e-Skimming-Detection](https://github.com/Santandersecurityresearch/e-Skimming-Detection)  
  Semgrep
  rules for pattern detection

- **RapidSpike**: Magecart Attack Detection System  
  Commercial monitoring solution research

### Code Samples

- **GitHub Gist by gwillem**: Sophisticated CC Skimming Malware  
  Real-world example with localStorage scraping

- **CVE-2024-34102 Exploits**: Multiple PoC implementations  
  CosmicSting XXE exploitation

## ⚖️ Legal & Ethical Considerations

### Educational Use Only

This repository is provided for:

- ✅ Security research and education
- ✅ Training security professionals
- ✅ Developing defensive measures
- ✅ Understanding attacker techniques
- ✅ Academic study

### Prohibited Uses

- ❌ Attacking systems without authorization
- ❌ Stealing payment card data
- ❌ Deploying on production systems
- ❌ Violating computer fraud laws
- ❌ Any illegal activity

### Responsible Disclosure

If you discover a real vulnerability:

1. Do NOT exploit it
2. Document your findings responsibly
3. Contact the affected party privately
4. Follow coordinated disclosure timelines
5. Report to relevant bug bounty programs

### Legal Frameworks

Be aware of laws in your jurisdiction:

- **US**: Computer Fraud and Abuse Act (CFAA)
- **UK**: Computer Misuse Act
- **EU**: Directive on attacks against information systems
- **Payment Card Industry**: PCI DSS compliance requirements

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[Setup Guide](docs/SETUP.md)** - Complete installation and configuration
  instructions
- **[Architecture](docs/ARCHITECTURE.md)** - Technical architecture, plugin
  system, and deployment
- **[Research](docs/RESEARCH.md)** - Attack research and real-world case studies
- **[Contributing](docs/CONTRIBUTING.md)** - How to contribute to the project

### Quick Links

- 🏠 **Landing Page:** http://localhost:3000
- 📊 **MITRE ATT&CK Matrix:** http://localhost:3000/mitre-attack
- 🕸️ **Threat Model:** http://localhost:3000/threat-model
- 🔬 **Interactive Labs:** Ports 9001, 9003, 9005

## 🤝 Contributing

We welcome contributions! Please see
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for:

- New lab ideas
- Detection techniques
- Defense strategies
- Documentation improvements
- Bug fixes

### Code of Conduct

- Respect ethical boundaries
- Focus on education and defense
- No malicious use discussion
- Professional collaboration

## 📄 License

This project is licensed under the MIT License for educational purposes. See
[LICENSE](LICENSE) for details.

**Disclaimer**: The authors and contributors are not responsible for misuse of
this code. All code is provided AS-IS for educational purposes only.

## 🙏 Acknowledgments

- **Sansec** - Extensive Magecart research and malware database
- **RiskIQ** - Magecart profiling and infrastructure analysis
- **Akamai Security Intelligence Group** - Campaign documentation
- **Santander Security Research** - Detection rule contributions
- **All security researchers** who have documented these attacks

## 📞 Contact

For questions, suggestions, or security concerns:

- Open an issue on GitHub
- Email: [your-email]
- Twitter: [@yourhandle]

---

**Remember**: The best defense is understanding the attack. Use this knowledge
to build better, more secure e-commerce systems. 🛡️

_Last Updated: [Current Date]_
