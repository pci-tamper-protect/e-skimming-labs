# Lab 4: Steganography / Favicon Trojan

## 🚩 Objective
Demonstrate how attackers can hide malicious JavaScript payloads inside seemingly innocent image files (like `favicon.ico`) to bypass security scanners and achieve persistence.

## 🏗️ Architecture
- **Vulnerable Site**: `http://localhost:8084`
  - A secure-looking checkout page.
  - Includes a "loader" script (`js/loader.js`) that looks like a standard icon handler.
  - Serves a malicious `favicon.ico` containing the hidden skimmer.
- **C2 Server**: `http://localhost:3004` (Shared with Lab 1)
  - Receives stolen credit card data.
  - Dashboard at `http://localhost:3004/stolen`.

## ⚔️ The Attack Flow
1. **Injection**: Attacker replaces the legitimate `favicon.ico` with a malicious one containing hidden code in the Alpha channel.
2. **Execution**: The `loader.js` script reads the favicon using the HTML Canvas API, extracts the hidden code, and executes it.
3. **Exfiltration**: The extracted skimmer intercepts the payment form and sends data to the C2 server.

## 🚀 How to Run
```bash
# Start the lab
cd labs/04-steganography-favicon
docker-compose up -d --build
```

## 🕵️ verification via Browser
1. Open `http://localhost:8084/checkout.html`
2. Open Network Tab (F12) to see `favicon.ico` loading.
3. Enter fake credit card details and click **Pay Now**.
4. Check the C2 Dashboard at `http://localhost:3004/stolen`. You should see your stolen data!

## 🛡️ Defenses
- **Content Security Policy (CSP)**: Restrict `img-src` and `connect-src`.
- **Subresource Integrity (SRI)**: Impossible for favicons, but useful for scripts.
- **Image Sanitization**: Re-encode all images on the server to destroy hidden data.
- **Behavioral Monitoring**: Detect unexpected Canvas API usage (`getImageData`).

## ⚠️ Educational Purpose Only
This lab is for educational and testing purposes. Do not use these techniques on systems you do not own.
