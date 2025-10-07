/**
 * CONTENT.JS - LEGITIMATE EXTENSION CONTENT SCRIPT
 *
 * This file contains the legitimate content script functionality for SecureForm Assistant.
 * It provides form validation, security warnings, and autofill protection.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

(function() {
    'use strict';

    console.log('[SecureForm] Content script initializing...');

    // Extension state
    let extensionSettings = {
        formValidation: true,
        securityWarnings: true,
        autofillProtection: true
    };

    let pageAnalysis = {
        formsFound: 0,
        securityIssues: [],
        lastScan: null
    };

    /**
     * Initialize Content Script
     */
    function init() {
        console.log('[SecureForm] Content script starting on:', window.location.href);

        // Load settings
        loadSettings();

        // Setup form monitoring
        setupFormMonitoring();

        // Setup page analysis
        setupPageAnalysis();

        // Setup message listener
        setupMessageListener();

        // Perform initial scan
        setTimeout(scanPage, 1000);

        console.log('[SecureForm] Content script initialized');
    }

    /**
     * Load Settings
     */
    async function loadSettings() {
        try {
            const result = await chrome.storage.sync.get(['extensionSettings']);
            if (result.extensionSettings) {
                extensionSettings = { ...extensionSettings, ...result.extensionSettings };
                console.log('[SecureForm] Settings loaded:', extensionSettings);
            }
        } catch (error) {
            console.error('[SecureForm] Failed to load settings:', error);
        }
    }

    /**
     * Setup Form Monitoring
     */
    function setupFormMonitoring() {
        if (!extensionSettings.formValidation) return;

        console.log('[SecureForm] Setting up form monitoring...');

        // Monitor existing forms
        const forms = document.querySelectorAll('form');
        forms.forEach(form => attachFormValidation(form));

        // Monitor for new forms
        const observer = new MutationObserver((mutations) => {
            mutations.forEach(mutation => {
                mutation.addedNodes.forEach(node => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        if (node.tagName === 'FORM') {
                            attachFormValidation(node);
                        } else {
                            const forms = node.querySelectorAll ? node.querySelectorAll('form') : [];
                            forms.forEach(form => attachFormValidation(form));
                        }
                    }
                });
            });
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });

        console.log('[SecureForm] Form monitoring setup complete');
    }

    /**
     * Attach Form Validation
     */
    function attachFormValidation(form) {
        if (form.hasAttribute('data-secureform-monitored')) return;
        form.setAttribute('data-secureform-monitored', 'true');

        console.log('[SecureForm] Attaching validation to form:', form);

        // Add validation to input fields
        const inputs = form.querySelectorAll('input, textarea, select');
        inputs.forEach(input => attachInputValidation(input));

        // Monitor form submission
        form.addEventListener('submit', (e) => {
            handleFormSubmission(e);
        });

        pageAnalysis.formsFound++;
    }

    /**
     * Attach Input Validation
     */
    function attachInputValidation(input) {
        if (input.hasAttribute('data-secureform-validated')) return;
        input.setAttribute('data-secureform-validated', 'true');

        // Add real-time validation
        input.addEventListener('input', (e) => {
            validateInput(e.target);
        });

        input.addEventListener('blur', (e) => {
            validateInput(e.target);
        });

        // Autofill protection
        if (extensionSettings.autofillProtection) {
            setupAutofillProtection(input);
        }
    }

    /**
     * Validate Input
     */
    function validateInput(input) {
        clearValidationErrors(input);

        const value = input.value;
        const type = input.type;
        const name = input.name || input.id || '';

        let isValid = true;
        let errorMessage = '';

        // Email validation
        if (type === 'email' || name.toLowerCase().includes('email')) {
            if (value && !isValidEmail(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid email address';
            }
        }

        // Credit card validation
        if (name.toLowerCase().includes('card') || name.toLowerCase().includes('credit')) {
            if (value && !isValidCreditCard(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid credit card number';
            }
        }

        // Password strength
        if (type === 'password' && name.toLowerCase().includes('new')) {
            const strength = checkPasswordStrength(value);
            if (value && strength.score < 3) {
                isValid = false;
                errorMessage = `Weak password: ${strength.feedback}`;
            }
        }

        if (!isValid && extensionSettings.securityWarnings) {
            showValidationError(input, errorMessage);
        }

        return isValid;
    }

    /**
     * Email Validation
     */
    function isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    /**
     * Credit Card Validation (Luhn Algorithm)
     */
    function isValidCreditCard(cardNumber) {
        const cleanNumber = cardNumber.replace(/\D/g, '');
        if (cleanNumber.length < 13 || cleanNumber.length > 19) return false;

        let sum = 0;
        let isEven = false;

        for (let i = cleanNumber.length - 1; i >= 0; i--) {
            let digit = parseInt(cleanNumber[i]);

            if (isEven) {
                digit *= 2;
                if (digit > 9) digit -= 9;
            }

            sum += digit;
            isEven = !isEven;
        }

        return sum % 10 === 0;
    }

    /**
     * Password Strength Check
     */
    function checkPasswordStrength(password) {
        let score = 0;
        let feedback = [];

        if (password.length >= 8) score++;
        else feedback.push('use at least 8 characters');

        if (/[a-z]/.test(password)) score++;
        else feedback.push('include lowercase letters');

        if (/[A-Z]/.test(password)) score++;
        else feedback.push('include uppercase letters');

        if (/\d/.test(password)) score++;
        else feedback.push('include numbers');

        if (/[^a-zA-Z\d]/.test(password)) score++;
        else feedback.push('include special characters');

        return {
            score: score,
            feedback: feedback.join(', ')
        };
    }

    /**
     * Show Validation Error
     */
    function showValidationError(input, message) {
        input.style.borderColor = '#ef4444';

        const errorElement = document.createElement('div');
        errorElement.className = 'secureform-error';
        errorElement.style.cssText = `
            color: #ef4444;
            font-size: 12px;
            margin-top: 4px;
            display: block;
        `;
        errorElement.textContent = message;

        if (input.parentNode) {
            input.parentNode.insertBefore(errorElement, input.nextSibling);
        }
    }

    /**
     * Clear Validation Errors
     */
    function clearValidationErrors(input) {
        input.style.borderColor = '';

        const existingError = input.parentNode?.querySelector('.secureform-error');
        if (existingError) {
            existingError.remove();
        }
    }

    /**
     * Setup Autofill Protection
     */
    function setupAutofillProtection(input) {
        // Monitor for autofill
        const observer = new MutationObserver(() => {
            if (input.value && !input.hasAttribute('data-user-input')) {
                console.log('[SecureForm] Autofill detected on:', input);
                // In a real extension, this might warn about autofill security
            }
        });

        observer.observe(input, {
            attributes: true,
            attributeFilter: ['value']
        });

        // Mark user input
        input.addEventListener('input', () => {
            input.setAttribute('data-user-input', 'true');
        });
    }

    /**
     * Handle Form Submission
     */
    function handleFormSubmission(event) {
        console.log('[SecureForm] Form submission detected:', event.target);

        if (!extensionSettings.formValidation) return;

        // Validate all inputs
        const inputs = event.target.querySelectorAll('input, textarea, select');
        let hasErrors = false;

        inputs.forEach(input => {
            if (!validateInput(input)) {
                hasErrors = true;
            }
        });

        if (hasErrors && extensionSettings.securityWarnings) {
            console.log('[SecureForm] Form validation errors found');
            // Note: We don't prevent submission in this legitimate version
        }

        // Report to background script
        reportFormSubmission(event.target);
    }

    /**
     * Report Form Submission
     */
    function reportFormSubmission(form) {
        try {
            chrome.runtime.sendMessage({
                type: 'FORM_SUBMISSION',
                data: {
                    url: window.location.href,
                    formIndex: Array.from(document.forms).indexOf(form),
                    inputCount: form.querySelectorAll('input, textarea, select').length,
                    timestamp: Date.now()
                }
            });
        } catch (error) {
            console.log('[SecureForm] Failed to report form submission:', error);
        }
    }

    /**
     * Setup Page Analysis
     */
    function setupPageAnalysis() {
        console.log('[SecureForm] Setting up page analysis...');

        // Analyze page security
        analyzePageSecurity();

        // Monitor for changes
        const observer = new MutationObserver(() => {
            // Debounce analysis
            clearTimeout(pageAnalysis.analysisTimeout);
            pageAnalysis.analysisTimeout = setTimeout(analyzePageSecurity, 2000);
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    /**
     * Analyze Page Security
     */
    function analyzePageSecurity() {
        const analysis = {
            secure: window.location.protocol === 'https:',
            status: 'secure',
            message: 'Page analysis complete',
            formsFound: document.forms.length,
            threats: []
        };

        // Check for security issues
        if (!analysis.secure && window.location.hostname !== 'localhost') {
            analysis.status = 'warning';
            analysis.message = 'Insecure connection detected';
            analysis.threats.push('HTTP connection');
        }

        // Check for password fields on insecure pages
        if (!analysis.secure) {
            const passwordFields = document.querySelectorAll('input[type="password"]');
            if (passwordFields.length > 0) {
                analysis.status = 'danger';
                analysis.message = 'Password fields on insecure page';
                analysis.threats.push('Insecure password transmission');
            }
        }

        pageAnalysis = { ...pageAnalysis, ...analysis, lastScan: Date.now() };
        console.log('[SecureForm] Page analysis complete:', analysis);

        // Report to popup
        try {
            chrome.runtime.sendMessage({
                type: 'PAGE_ANALYSIS',
                analysis: analysis
            });
        } catch (error) {
            console.log('[SecureForm] Failed to send page analysis:', error);
        }
    }

    /**
     * Scan Page
     */
    function scanPage() {
        console.log('[SecureForm] Scanning page for security issues...');

        const scanResults = {
            formsCount: document.forms.length,
            issues: [],
            timestamp: Date.now()
        };

        // Scan for common issues
        const passwordFields = document.querySelectorAll('input[type="password"]');
        if (passwordFields.length > 0 && window.location.protocol !== 'https:') {
            scanResults.issues.push({
                type: 'insecure_password',
                message: 'Password fields on insecure page',
                severity: 'high'
            });
        }

        // Scan for autofill issues
        const autofillFields = document.querySelectorAll('input[autocomplete="off"]');
        if (autofillFields.length > 0) {
            scanResults.issues.push({
                type: 'autofill_disabled',
                message: 'Autofill disabled on form fields',
                severity: 'low'
            });
        }

        console.log('[SecureForm] Page scan complete:', scanResults);
        return scanResults;
    }

    /**
     * Setup Message Listener
     */
    function setupMessageListener() {
        chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
            console.log('[SecureForm] Received message:', request.type);

            switch (request.type) {
                case 'UPDATE_SETTINGS':
                    extensionSettings = { ...extensionSettings, ...request.settings };
                    console.log('[SecureForm] Settings updated:', extensionSettings);
                    sendResponse({ success: true });
                    break;

                case 'ANALYZE_SITE':
                    analyzePageSecurity();
                    sendResponse({ analysis: pageAnalysis });
                    break;

                case 'SCAN_PAGE':
                    const scanResults = scanPage();
                    sendResponse({ scanResults: scanResults });
                    break;

                default:
                    console.log('[SecureForm] Unknown message type:', request.type);
                    sendResponse({ error: 'Unknown message type' });
            }

            return true; // Keep message channel open for async response
        });
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();

/**
 * LEGITIMATE CONTENT SCRIPT ANALYSIS:
 *
 * This content script provides legitimate security functionality:
 *
 * 1. **Form Validation**: Real-time validation of form inputs
 * 2. **Security Warnings**: Alerts for insecure pages and practices
 * 3. **Autofill Protection**: Monitoring and warnings for autofill usage
 * 4. **Page Analysis**: Basic security analysis of current page
 * 5. **User Interface**: Clean error messages and validation feedback
 *
 * Key Characteristics:
 * - Standard DOM manipulation for legitimate purposes
 * - Real-time form validation and feedback
 * - Security-focused functionality (password strength, HTTPS checking)
 * - Professional error handling and user feedback
 * - Normal extension messaging patterns
 *
 * This legitimate functionality will be maintained in the malicious version
 * to preserve the extension's cover story while adding hidden malicious
 * capabilities for data harvesting and exfiltration.
 */