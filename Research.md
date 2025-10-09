# Major E-Skimming Attack Types & Published Code

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



