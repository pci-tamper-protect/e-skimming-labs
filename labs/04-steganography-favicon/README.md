# Lab 4: Steganography / Favicon Trojan

This lab demonstrates a sophisticated evasion technique used by Magecart groups: Steganography. By hiding malicious JavaScript payloads inside the pixel data of legitimate-looking image files (like favicon.ico), attackers can bypass static analysis tools, file integrity monitoring, and network security controls that typically inspect scripts but ignore images.

## Attack Overview
Steganography in web attacks involves embedding malicious code within non-executable files, typically images. This lab simulates an attack where a credit card skimmer is hidden inside the website's favicon.

This attack vector leverages:
- **Visual Camouflage**: The malicious image looks identical to the original to the naked eye.
- **Scanner Evasion**: Security tools often skip image files to optimize performance.
- **API Abuse**: Legitimate HTML5 Canvas APIs are used to read pixel data and extract the payload.
- **Obfuscated Loading**: The loader script itself is benign, only serving to decode and execute the hidden logic.

## Key Differences from Previous Labs
**Attack Vector Evolution**
- **Lab 1**: Direct JavaScript injection and form submission interception.
- **Lab 2**: DOM manipulation and real-time field monitoring.
- **Lab 3**: Browser extension privilege escalation.
- **Lab 4**: Binary obfuscation and evasion using steganography.

**Technical Approach**
- **Payload Encoding**: Hiding ASCII code in the Alpha transparency channel of pixels.
- **Payload Decoding**: Using `canvas.getContext('2d').getImageData()` to read raw pixels.
- **Execution**: Reassembling the string and executing it via `Function()` constructor.

## Lab Scenarios
**Scenario 1: Legitimate Asset Compromise**
- Attacker gains write access to the web server.
- Replaces `favicon.ico` with a steganographically modified version.
- Injects a small, benign-looking `loader.js` into the main template.
- Payload remains hidden for months as scanners ignore the .ico file.

**Scenario 2: Third-Party Content Injection**
- Attacker compromises a third-party service providing icons or badges.
- Malicious image is loaded from a trusted domain.
- Loader script on the main site (or injected) decodes the external image.

## ML Training Value
This lab helps detection models learn to identify:
- **Anomalous Canvas Usage**: Reading data from images that are not being edited or manipulated for display.
- **High Entropy in Images**: Statistical analysis of image channels (especially Alpha) revealing non-random data.
- **Unusual Loading Patterns**: `favicons` being fetched via XHR/Fetch API instead of standard browser loading.

## Detection Signatures
**Loader Script Patterns**
```javascript
// Suspicious Canvas usage
document.createElement('canvas')
canvas.getContext('2d')
ctx.drawImage(img, 0, 0)
ctx.getImageData(0, 0, width, height)
```

**Network Anomalies**
- JavaScript initiating requests for `.ico` or `.png` files.
- Image files with unusually large file sizes for their dimensions.

## File Structure
04-steganography-favicon/
├── vulnerable-site/              # Target e-commerce site
│   ├── index.html                # Main entry point with loader reference
│   ├── original-favicon.ico      # The malicious favicon container
│   ├── css/                      # Styles
│   └── js/
│       └── loader.js             # The decoder script
├── malicious-code/
│   ├── stego-generator/          # Tools to create malicious images
│   └── c2-server/                # Command & Control server
│       ├── server.js             # Node.js server handling exfiltration
│       └── dashboard.html        # Attacker dashboard
├── nginx.conf                    # Web server configuration
└── docker-compose.yml            # Container orchestration

## Attack Techniques Demonstrated
1.  **Steganography**: Usage of the Alpha channel to store 8-bit ASCII characters.
2.  **Obfuscation**: Splitting the attack into a benign loader and a hidden payload.
3.  **Persistence**: Browsers aggressively cache favicons, keeping the payload on the client side.
4.  **Data Exfiltration**: Intercepting form submissions and sending data to a C2 server.

## Educational Objectives
**Understanding Evasion**
- Learn how attackers bypass string-based detection signatures.
- Understand the limits of file extension-based whitelisting.

**Browser API Security**
- Explore the capabilities of the HTML5 Canvas API.
- Understand the security implications of `crossOrigin` image access.

**Defense in Depth**
- Learn why multiple layers (CSP, SRI, Monitoring) are necessary.

## Attack Analysis
**Technical Implementation**
The attack consists of two main components:

1.  **The Carrier (favicon.ico)**:
    -   Standard ICO file format.
    -   Payload (ASCII characters) encoded into the Alpha byte of every 4th byte in the pixel array.
    -   Terminated by a NULL byte.

2.  **The Loader (loader.js)**:
    -   Creates an off-screen canvas.
    -   Draws the favicon onto the canvas.
    -   Reads the pixel data using `getImageData`.
    -   Iterates through data extracting every 4th byte (Alpha).
    -   Reassembles the string and executes it.

**Network Traffic Patterns**
-   **Loader Fetch**: Normal GET request for `loader.js`.
-   **Image Fetch**: GET request for `original-favicon.ico`.
-   **Exfiltration**: POST request to the C2 server (e.g., `/lab4/c2/collect`) containing the captured data.

## Detection Guide for Security Tools
**Static Analysis**
Search for combinations of Canvas creation and pixel reading in a single script context.

`grep` / `ripgrep` commands:
```bash
# Search for suspicious canvas operations
grep -r "createElement('canvas')" .
grep -r "getImageData" .

# Search for execution of extracted strings
grep -r "new Function" .
```

**Runtime Behavior Detection**
-   Monitor specific API calls: `CanvasRenderingContext2D.prototype.getImageData`.
-   Flag execution if `getImageData` is called on a small image (like an icon) followed by network activity.
-   Inspect image resources for statistical anomalies in the Alpha channel.

## Defense Strategies
**Content Security Policy (CSP)**
-   `img-src`: Restrict where images can be loaded from.
-   `connect-src`: Strictly limit domains where data can be sent. This prevents the skimmer from reporting back to the C2 server.

**Integrity Checks (SRI)**
-   Use Subresource Integrity (SRI) tags (`integrity="sha384-..."`) for all scripts, including external loaders.

**Image Sanitization**
-   Re-encode all images on the server side using tools like ImageMagick.
-   Converting an image (e.g., PNG to PNG) usually destroys the delicate steganographic encoding in the low-order bits or alpha channel.

**Behavioral Monitoring**
-   Implement RUM (Real User Monitoring) that alerts on unexpected calls to `getImageData` or accessing pixel data of static assets.

## Comparison with Previous Labs
**Lab 1 vs Lab 4**
-   **Lab 1**: Relies on direct injection of script tags. Easily detected by looking for `<script>` tags or `onerror` handlers.
-   **Lab 4**: script tag loads a benign `loader.js`. The malicious logic is inside a binary asset (image), making it invisible to HTML/JS inspectors.

**Lab 2 vs Lab 4**
-   **Lab 2**: Modifies the DOM to add listeners.
-   **Lab 4**: Can operate in memory without modifying the visible DOM structure until the moment of theft.

## Verification (Local Development)
1.  **Open the Lab**: Navigate to `http://localhost:8084/`.
2.  **Inspect Network Traffic**: Open DevTools (F12) -> Network tab. Reload the page. You will see `original-favicon.ico` being loaded.
    
    ![Network Traffic](/static/images/lab4-network.png)

3.  **Observe Execution**: Check the Console tab. You will see logs indicating the loader is extracting data and the skimmer payload is intercepted.
    
    ![Skimmer Execution](/static/images/lab4-execution.png)

4.  **Verify Theft**: Go to the **View Stolen Data** page (`http://localhost:8084/c2/stolen` or `http://localhost:3004/stolen`).
