/**
 * CHECKOUT.JS - VULNERABLE SITE FUNCTIONALITY
 *
 * This file contains the legitimate checkout functionality for SecureShop.
 * It provides a realistic e-commerce checkout experience that will be
 * targeted by the malicious browser extension.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

(function() {
    'use strict';

    console.log('[SecureShop] Checkout page initializing...');

    // Application state
    let formValidation = {
        customer: false,
        shipping: false,
        payment: false,
        account: false
    };

    let orderData = {
        customer: {},
        shipping: {},
        payment: {},
        account: {},
        items: [
            {
                name: 'Premium Wireless Headphones',
                details: 'Noise Cancelling, Black',
                price: 299.99
            },
            {
                name: 'Bluetooth Speaker',
                details: 'Waterproof, Portable',
                price: 89.99
            }
        ],
        totals: {
            subtotal: 389.98,
            shipping: 9.99,
            tax: 31.20,
            total: 431.17
        }
    };

    /**
     * Initialize Checkout
     */
    function init() {
        console.log('[SecureShop] Initializing checkout functionality...');

        // Setup form handlers
        setupFormHandlers();

        // Setup validation
        setupFormValidation();

        // Setup autofill simulation
        setupAutofillSimulation();

        // Setup order placement
        setupOrderPlacement();

        // Simulate some pre-filled data for testing
        simulateAutofill();

        console.log('[SecureShop] Checkout initialized successfully');
    }

    /**
     * Setup Form Handlers
     */
    function setupFormHandlers() {
        const forms = ['customer-form', 'shipping-form', 'payment-form', 'account-form'];

        forms.forEach(formId => {
            const form = document.getElementById(formId);
            if (form) {
                // Real-time validation
                const inputs = form.querySelectorAll('input, select');
                inputs.forEach(input => {
                    input.addEventListener('input', (e) => {
                        validateField(e.target);
                        updateFormProgress();
                    });

                    input.addEventListener('blur', (e) => {
                        validateField(e.target);
                    });

                    input.addEventListener('focus', (e) => {
                        clearFieldError(e.target);
                    });
                });

                // Form submission
                form.addEventListener('submit', (e) => {
                    e.preventDefault();
                    validateForm(formId);
                });
            }
        });
    }

    /**
     * Setup Form Validation
     */
    function setupFormValidation() {
        // Credit card number formatting
        const cardNumberInput = document.getElementById('cardNumber');
        if (cardNumberInput) {
            cardNumberInput.addEventListener('input', (e) => {
                let value = e.target.value.replace(/\D/g, '');
                value = value.replace(/(\d{4})(?=\d)/g, '$1 ');
                e.target.value = value;

                // Validate card type
                const cardType = detectCardType(value.replace(/\s/g, ''));
                updateCardTypeDisplay(cardType);
            });
        }

        // CVV input restriction
        const cvvInput = document.getElementById('cvv');
        if (cvvInput) {
            cvvInput.addEventListener('input', (e) => {
                e.target.value = e.target.value.replace(/\D/g, '');
            });
        }

        // Phone number formatting
        const phoneInput = document.getElementById('phone');
        if (phoneInput) {
            phoneInput.addEventListener('input', (e) => {
                let value = e.target.value.replace(/\D/g, '');
                if (value.length >= 6) {
                    value = value.replace(/(\d{3})(\d{3})(\d{4})/, '($1) $2-$3');
                } else if (value.length >= 3) {
                    value = value.replace(/(\d{3})(\d{0,3})/, '($1) $2');
                }
                e.target.value = value;
            });
        }

        // Password confirmation
        const passwordInput = document.getElementById('password');
        const confirmPasswordInput = document.getElementById('confirmPassword');
        if (passwordInput && confirmPasswordInput) {
            [passwordInput, confirmPasswordInput].forEach(input => {
                input.addEventListener('input', () => {
                    validatePasswordMatch();
                });
            });
        }
    }

    /**
     * Validate Individual Field
     */
    function validateField(field) {
        const value = field.value.trim();
        const fieldName = field.name || field.id;
        let isValid = true;
        let errorMessage = '';

        // Required field validation
        if (field.hasAttribute('required') && !value) {
            isValid = false;
            errorMessage = 'This field is required';
        }

        // Email validation
        else if (field.type === 'email' && value) {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid email address';
            }
        }

        // Credit card validation
        else if (fieldName === 'cardNumber' && value) {
            const cleanNumber = value.replace(/\s/g, '');
            if (!isValidCreditCard(cleanNumber)) {
                isValid = false;
                errorMessage = 'Please enter a valid credit card number';
            }
        }

        // CVV validation
        else if (fieldName === 'cvv' && value) {
            if (value.length < 3 || value.length > 4) {
                isValid = false;
                errorMessage = 'CVV must be 3 or 4 digits';
            }
        }

        // ZIP code validation
        else if (fieldName === 'zip' && value) {
            const zipRegex = /^\d{5}(-\d{4})?$/;
            if (!zipRegex.test(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid ZIP code';
            }
        }

        // Phone validation
        else if (field.type === 'tel' && value) {
            const phoneRegex = /^\(\d{3}\) \d{3}-\d{4}$/;
            if (!phoneRegex.test(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid phone number';
            }
        }

        // Password strength
        else if (fieldName === 'password' && value) {
            const strength = checkPasswordStrength(value);
            if (strength.score < 3) {
                isValid = false;
                errorMessage = `Weak password: ${strength.feedback}`;
            }
        }

        // Update field appearance
        if (isValid) {
            showFieldSuccess(field);
        } else {
            showFieldError(field, errorMessage);
        }

        return isValid;
    }

    /**
     * Credit Card Validation (Luhn Algorithm)
     */
    function isValidCreditCard(number) {
        if (number.length < 13 || number.length > 19) return false;

        let sum = 0;
        let isEven = false;

        for (let i = number.length - 1; i >= 0; i--) {
            let digit = parseInt(number[i]);

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
     * Detect Credit Card Type
     */
    function detectCardType(number) {
        const patterns = {
            visa: /^4/,
            mastercard: /^5[1-5]/,
            amex: /^3[47]/,
            discover: /^6(?:011|5)/
        };

        for (const [type, pattern] of Object.entries(patterns)) {
            if (pattern.test(number)) {
                return type;
            }
        }

        return 'unknown';
    }

    /**
     * Update Card Type Display
     */
    function updateCardTypeDisplay(cardType) {
        // This would typically update UI to show card type
        console.log('[SecureShop] Detected card type:', cardType);
    }

    /**
     * Check Password Strength
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
     * Validate Password Match
     */
    function validatePasswordMatch() {
        const password = document.getElementById('password');
        const confirmPassword = document.getElementById('confirmPassword');

        if (password && confirmPassword && confirmPassword.value) {
            if (password.value !== confirmPassword.value) {
                showFieldError(confirmPassword, 'Passwords do not match');
                return false;
            } else {
                showFieldSuccess(confirmPassword);
                return true;
            }
        }
        return true;
    }

    /**
     * Show Field Error
     */
    function showFieldError(field, message) {
        field.classList.remove('success');
        field.classList.add('error');

        // Remove existing error message
        const existingError = field.parentNode.querySelector('.error-message');
        if (existingError) {
            existingError.remove();
        }

        // Add new error message
        const errorElement = document.createElement('div');
        errorElement.className = 'error-message';
        errorElement.textContent = message;
        field.parentNode.appendChild(errorElement);
    }

    /**
     * Show Field Success
     */
    function showFieldSuccess(field) {
        field.classList.remove('error');
        field.classList.add('success');
        clearFieldError(field);
    }

    /**
     * Clear Field Error
     */
    function clearFieldError(field) {
        field.classList.remove('error');
        const existingError = field.parentNode.querySelector('.error-message');
        if (existingError) {
            existingError.remove();
        }
    }

    /**
     * Validate Entire Form
     */
    function validateForm(formId) {
        const form = document.getElementById(formId);
        if (!form) return false;

        const inputs = form.querySelectorAll('input[required], select[required]');
        let isValid = true;

        inputs.forEach(input => {
            if (!validateField(input)) {
                isValid = false;
            }
        });

        // Form-specific validation
        const formType = formId.replace('-form', '');
        formValidation[formType] = isValid;

        if (isValid) {
            collectFormData(formId);
            console.log(`[SecureShop] ${formType} form validated successfully`);
        } else {
            console.log(`[SecureShop] ${formType} form validation failed`);
        }

        updateFormProgress();
        return isValid;
    }

    /**
     * Collect Form Data
     */
    function collectFormData(formId) {
        const form = document.getElementById(formId);
        const formType = formId.replace('-form', '');
        const data = {};

        const inputs = form.querySelectorAll('input, select');
        inputs.forEach(input => {
            if (input.type !== 'checkbox' || input.checked) {
                // Use placeholder data if field is empty
                let value = input.value;
                if (!value) {
                    // Set default values based on field type/name
                    switch (input.name || input.id) {
                        case 'firstName':
                        case 'first-name':
                            value = 'John';
                            break;
                        case 'lastName':
                        case 'last-name':
                            value = 'Smith';
                            break;
                        case 'email':
                            value = 'john.smith@email.com';
                            break;
                        case 'phone':
                            value = '(555) 123-4567';
                            break;
                        case 'address':
                            value = '123 Main Street';
                            break;
                        case 'city':
                            value = 'San Francisco';
                            break;
                        case 'state':
                            value = 'CA';
                            break;
                        case 'zip':
                            value = '94105';
                            break;
                        case 'cardNumber':
                            value = '4532 1234 5678 9012';
                            break;
                        case 'expiryMonth':
                            value = '12';
                            break;
                        case 'expiryYear':
                            value = '2026';
                            break;
                        case 'cvv':
                            value = '123';
                            break;
                        case 'cardholderName':
                            value = 'John Smith';
                            break;
                        case 'username':
                            value = 'johnsmith';
                            break;
                        case 'password':
                            value = 'password123';
                            break;
                        case 'confirmPassword':
                            value = 'password123';
                            break;
                    }
                }
                data[input.name || input.id] = value;
            }
        });

        orderData[formType] = data;
        console.log(`[SecureShop] Collected ${formType} data:`, data);
    }

    /**
     * Update Form Progress
     */
    function updateFormProgress() {
        const totalForms = Object.keys(formValidation).length;
        const completedForms = Object.values(formValidation).filter(Boolean).length;
        const progress = (completedForms / totalForms) * 100;

        console.log(`[SecureShop] Form progress: ${completedForms}/${totalForms} (${progress.toFixed(0)}%)`);
    }

    /**
     * Setup Autofill Simulation
     */
    function setupAutofillSimulation() {
        // Simulate browser autofill for testing
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'a') {
                e.preventDefault();
                simulateAutofill();
            }
        });
    }

    /**
     * Simulate Autofill (for testing)
     */
    function simulateAutofill() {
        setTimeout(() => {
            const testData = {
                firstName: 'John',
                lastName: 'Smith',
                email: 'john.smith@email.com',
                phone: '(555) 123-4567',
                address1: '123 Main Street',
                city: 'San Francisco',
                state: 'CA',
                zip: '94105',
                cardNumber: '4532 1234 5678 9012',
                expiryMonth: '12',
                expiryYear: '2026',
                cvv: '123',
                cardholderName: 'John Smith'
            };

            Object.entries(testData).forEach(([fieldName, value]) => {
                const field = document.getElementById(fieldName) ||
                             document.querySelector(`[name="${fieldName}"]`);
                if (field) {
                    field.value = value;
                    field.dispatchEvent(new Event('input', { bubbles: true }));
                    field.dispatchEvent(new Event('change', { bubbles: true }));
                }
            });

            console.log('[SecureShop] Autofill simulation completed');
        }, 500);
    }

    /**
     * Setup Order Placement
     */
    function setupOrderPlacement() {
        const placeOrderBtn = document.getElementById('place-order');
        if (placeOrderBtn) {
            placeOrderBtn.addEventListener('click', handleOrderPlacement);
        }
    }

    /**
     * Handle Order Placement
     */
    async function handleOrderPlacement() {
        const placeOrderBtn = document.getElementById('place-order');

        console.log('[SecureShop] Processing order placement...');

        // Validate all forms
        const requiredForms = ['customer-form', 'shipping-form', 'payment-form'];
        let allValid = true;

        requiredForms.forEach(formId => {
            if (!validateForm(formId)) {
                allValid = false;
            }
        });

        if (!allValid) {
            alert('Please fill in all required fields correctly.');
            return;
        }

        // Show loading state
        placeOrderBtn.classList.add('loading');
        placeOrderBtn.disabled = true;
        placeOrderBtn.querySelector('.btn-text').textContent = 'Processing...';

        try {
            // Simulate order processing
            await new Promise(resolve => setTimeout(resolve, 2000));

            // Collect final order data
            const finalOrderData = {
                ...orderData,
                orderNumber: generateOrderNumber(),
                timestamp: Date.now(),
                total: orderData.totals.total
            };

            console.log('[SecureShop] Final order data:', finalOrderData);

            // Show success
            showOrderSuccess(finalOrderData.orderNumber);

        } catch (error) {
            console.error('[SecureShop] Order processing failed:', error);
            alert('Order processing failed. Please try again.');
        } finally {
            // Reset button state
            placeOrderBtn.classList.remove('loading');
            placeOrderBtn.disabled = false;
            placeOrderBtn.querySelector('.btn-text').textContent = 'Place Order';
        }
    }

    /**
     * Generate Order Number
     */
    function generateOrderNumber() {
        return 'ORD-' + Date.now().toString().slice(-8) + '-' +
               Math.random().toString(36).substr(2, 4).toUpperCase();
    }

    /**
     * Show Order Success
     */
    function showOrderSuccess(orderNumber) {
        const modal = document.getElementById('success-modal');
        const orderNumberElement = document.getElementById('order-number');

        if (modal && orderNumberElement) {
            orderNumberElement.textContent = orderNumber;
            modal.style.display = 'block';
        }

        console.log('[SecureShop] Order placed successfully:', orderNumber);
    }

    /**
     * Close Modal
     */
    window.closeModal = function() {
        const modal = document.getElementById('success-modal');
        if (modal) {
            modal.style.display = 'none';
        }
    };

    /**
     * Setup Modal Event Listeners
     */
    function setupModalListeners() {
        const modal = document.getElementById('success-modal');
        const closeBtn = modal?.querySelector('.modal-close');

        if (closeBtn) {
            closeBtn.addEventListener('click', closeModal);
        }

        if (modal) {
            modal.addEventListener('click', (e) => {
                if (e.target === modal) {
                    closeModal();
                }
            });
        }

        // ESC key to close modal
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeModal();
            }
        });
    }

    /**
     * Setup Development Helpers
     */
    function setupDevelopmentHelpers() {
        // Add development console commands
        window.SecureShop = {
            fillTestData: simulateAutofill,
            validateAllForms: () => {
                ['customer-form', 'shipping-form', 'payment-form', 'account-form'].forEach(validateForm);
            },
            getOrderData: () => orderData,
            clearAllForms: () => {
                document.querySelectorAll('input, select').forEach(field => {
                    field.value = '';
                    clearFieldError(field);
                    field.classList.remove('success', 'error');
                });
            }
        };

        console.log('[SecureShop] Development helpers available: SecureShop.fillTestData(), SecureShop.validateAllForms(), SecureShop.getOrderData(), SecureShop.clearAllForms()');
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            init();
            setupModalListeners();
            setupDevelopmentHelpers();
        });
    } else {
        init();
        setupModalListeners();
        setupDevelopmentHelpers();
    }

})();

/**
 * VULNERABLE SITE ANALYSIS:
 *
 * This checkout page provides a realistic e-commerce experience that serves
 * as an ideal target for browser extension hijacking attacks:
 *
 * TARGET CHARACTERISTICS:
 * - Multiple sensitive forms (customer info, payment, shipping)
 * - Credit card processing with validation
 * - Real-time form validation and user feedback
 * - Autofill support for user convenience
 * - Professional appearance to build user trust
 *
 * VULNERABLE BEHAVIORS:
 * - Stores sensitive data in DOM during form interaction
 * - Uses standard form events that can be intercepted
 * - Relies on client-side validation that can be bypassed
 * - Processes payment information in client-side JavaScript
 * - No protection against extension data harvesting
 *
 * ATTACK SURFACE:
 * - Form input events (input, change, blur, focus)
 * - Form submission handling
 * - Autofill detection and interception
 * - Clipboard paste operations
 * - Local storage and session data
 *
 * This site demonstrates how even security-conscious applications
 * can be vulnerable to browser extension attacks when users install
 * malicious or hijacked extensions.
 */