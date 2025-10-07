/**
 * BANKING.JS - LEGITIMATE BANKING APPLICATION
 *
 * This file contains the legitimate banking interface functionality
 * that will be targeted by DOM-based skimming attacks.
 *
 * Key features:
 * - Section navigation and form handling
 * - Real-time form validation
 * - Dynamic content updates
 * - Modal management
 * - Security prompts
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

(function() {
    'use strict';

    console.log('[Banking] Initializing SecureBank online banking system...');

    // Application state
    const appState = {
        currentSection: 'dashboard',
        user: {
            name: 'John Doe',
            accounts: {
                checking: { number: '****1234', balance: 12485.67 },
                savings: { number: '****5678', balance: 45892.33 },
                credit: { number: '****9012', balance: -2156.78 }
            }
        }
    };

    /**
     * Navigation Management
     */
    function initNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        const sections = document.querySelectorAll('.section');

        navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const targetSection = link.getAttribute('data-section');
                showSection(targetSection);

                // Update active nav link
                navLinks.forEach(nav => nav.classList.remove('active'));
                link.classList.add('active');

                appState.currentSection = targetSection;
                console.log('[Banking] Navigated to section:', targetSection);
            });
        });

        function showSection(sectionId) {
            sections.forEach(section => section.classList.remove('active'));
            const targetSection = document.getElementById(sectionId);
            if (targetSection) {
                targetSection.classList.add('active');
            }
        }
    }

    /**
     * Form Validation Utilities
     */
    function validateEmail(email) {
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailPattern.test(email);
    }

    function validatePhone(phone) {
        const phonePattern = /^\(\d{3}\)\s\d{3}-\d{4}$/;
        return phonePattern.test(phone);
    }

    function validateAmount(amount) {
        const num = parseFloat(amount);
        return !isNaN(num) && num > 0;
    }

    function validatePassword(password) {
        return password && password.length >= 6;
    }

    function validateAccountNumber(accountNumber) {
        return accountNumber && accountNumber.length >= 8;
    }

    /**
     * Real-time Form Validation
     */
    function setupFormValidation() {
        const forms = document.querySelectorAll('.banking-form');

        forms.forEach(form => {
            const inputs = form.querySelectorAll('input, select');

            inputs.forEach(input => {
                // Add real-time validation on input events
                input.addEventListener('input', (e) => {
                    validateField(e.target);
                });

                input.addEventListener('blur', (e) => {
                    validateField(e.target);
                });

                input.addEventListener('change', (e) => {
                    validateField(e.target);
                });
            });
        });

        function validateField(field) {
            clearFieldError(field);

            let isValid = true;
            let errorMessage = '';

            if (field.required && !field.value.trim()) {
                isValid = false;
                errorMessage = 'This field is required';
            } else if (field.value.trim()) {
                switch (field.type) {
                    case 'email':
                        if (!validateEmail(field.value)) {
                            isValid = false;
                            errorMessage = 'Please enter a valid email address';
                        }
                        break;
                    case 'tel':
                        if (!validatePhone(field.value)) {
                            isValid = false;
                            errorMessage = 'Please enter a valid phone number';
                        }
                        break;
                    case 'number':
                        if (!validateAmount(field.value)) {
                            isValid = false;
                            errorMessage = 'Please enter a valid amount';
                        }
                        break;
                    case 'password':
                        if (!validatePassword(field.value)) {
                            isValid = false;
                            errorMessage = 'Password must be at least 6 characters';
                        }
                        break;
                    case 'text':
                        if (field.name === 'accountNumber' && !validateAccountNumber(field.value)) {
                            isValid = false;
                            errorMessage = 'Please enter a valid account number';
                        }
                        break;
                }
            }

            if (!isValid) {
                showFieldError(field, errorMessage);
            }

            return isValid;
        }

        function showFieldError(field, message) {
            field.classList.add('error');
            field.style.borderColor = '#dc2626';

            let errorElement = field.parentNode.querySelector('.field-error');
            if (!errorElement) {
                errorElement = document.createElement('div');
                errorElement.className = 'field-error';
                errorElement.style.color = '#dc2626';
                errorElement.style.fontSize = '0.875rem';
                errorElement.style.marginTop = '0.25rem';
                field.parentNode.appendChild(errorElement);
            }
            errorElement.textContent = message;
        }

        function clearFieldError(field) {
            field.classList.remove('error');
            field.style.borderColor = '';

            const errorElement = field.parentNode.querySelector('.field-error');
            if (errorElement) {
                errorElement.remove();
            }
        }
    }

    /**
     * Transfer Form Handler
     */
    function initTransferForm() {
        const transferForm = document.getElementById('transfer-form');

        if (transferForm) {
            transferForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                console.log('[Banking] Processing transfer...');

                const formData = new FormData(transferForm);
                const transferData = {
                    fromAccount: formData.get('fromAccount'),
                    toAccount: formData.get('toAccount'),
                    amount: parseFloat(formData.get('amount')),
                    memo: formData.get('memo'),
                    password: formData.get('password')
                };

                // Validate transfer data
                if (!transferData.fromAccount || !transferData.toAccount || !transferData.amount || !transferData.password) {
                    showMessage('error', 'Please fill in all required fields');
                    return;
                }

                if (transferData.amount <= 0) {
                    showMessage('error', 'Transfer amount must be greater than zero');
                    return;
                }

                // Simulate processing
                const submitBtn = transferForm.querySelector('.submit-btn');
                const originalText = submitBtn.textContent;
                submitBtn.textContent = 'Processing...';
                submitBtn.disabled = true;

                try {
                    await simulateTransaction('transfer', transferData);
                    showMessage('success', `Transfer of $${transferData.amount.toFixed(2)} completed successfully`);
                    transferForm.reset();
                } catch (error) {
                    console.error('[Banking] Transfer error:', error);
                    showMessage('error', 'Transfer failed. Please try again.');
                } finally {
                    submitBtn.textContent = originalText;
                    submitBtn.disabled = false;
                }
            });
        }
    }

    /**
     * Payment Form Handler
     */
    function initPaymentForm() {
        const paymentForm = document.getElementById('payment-form');

        if (paymentForm) {
            paymentForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                console.log('[Banking] Processing bill payment...');

                const formData = new FormData(paymentForm);
                const paymentData = {
                    payee: formData.get('payee'),
                    accountNumber: formData.get('accountNumber'),
                    amount: parseFloat(formData.get('amount')),
                    paymentDate: formData.get('paymentDate'),
                    password: formData.get('password')
                };

                // Validate payment data
                if (!paymentData.payee || !paymentData.accountNumber || !paymentData.amount || !paymentData.password) {
                    showMessage('error', 'Please fill in all required fields');
                    return;
                }

                // Simulate processing
                const submitBtn = paymentForm.querySelector('.submit-btn');
                const originalText = submitBtn.textContent;
                submitBtn.textContent = 'Scheduling...';
                submitBtn.disabled = true;

                try {
                    await simulateTransaction('payment', paymentData);
                    showMessage('success', `Payment of $${paymentData.amount.toFixed(2)} scheduled successfully`);
                    paymentForm.reset();
                } catch (error) {
                    console.error('[Banking] Payment error:', error);
                    showMessage('error', 'Payment scheduling failed. Please try again.');
                } finally {
                    submitBtn.textContent = originalText;
                    submitBtn.disabled = false;
                }
            });
        }
    }

    /**
     * Settings Form Handler
     */
    function initSettingsForm() {
        const settingsForm = document.getElementById('settings-form');

        if (settingsForm) {
            settingsForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                console.log('[Banking] Updating account settings...');

                const formData = new FormData(settingsForm);
                const settingsData = {
                    email: formData.get('email'),
                    phone: formData.get('phone'),
                    currentPassword: formData.get('currentPassword'),
                    newPassword: formData.get('newPassword'),
                    confirmPassword: formData.get('confirmPassword')
                };

                // Validate password change if attempted
                if (settingsData.newPassword) {
                    if (!settingsData.currentPassword) {
                        showMessage('error', 'Current password is required to change password');
                        return;
                    }
                    if (settingsData.newPassword !== settingsData.confirmPassword) {
                        showMessage('error', 'New passwords do not match');
                        return;
                    }
                }

                // Simulate processing
                const submitBtn = settingsForm.querySelector('.submit-btn');
                const originalText = submitBtn.textContent;
                submitBtn.textContent = 'Updating...';
                submitBtn.disabled = true;

                try {
                    await simulateTransaction('settings', settingsData);
                    showMessage('success', 'Account settings updated successfully');
                } catch (error) {
                    console.error('[Banking] Settings update error:', error);
                    showMessage('error', 'Settings update failed. Please try again.');
                } finally {
                    submitBtn.textContent = originalText;
                    submitBtn.disabled = false;
                }
            });
        }
    }

    /**
     * Card Action Modal Management
     */
    function initCardActions() {
        const cardActionForm = document.getElementById('card-action-form');

        if (cardActionForm) {
            cardActionForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                console.log('[Banking] Processing card action...');

                const formData = new FormData(cardActionForm);
                const actionData = {
                    password: formData.get('password'),
                    cvv: formData.get('cvv'),
                    action: window.currentCardAction
                };

                if (!actionData.password || !actionData.cvv) {
                    showMessage('error', 'Please fill in all security fields');
                    return;
                }

                // Simulate processing
                const submitBtn = cardActionForm.querySelector('.submit-btn');
                const originalText = submitBtn.textContent;
                submitBtn.textContent = 'Verifying...';
                submitBtn.disabled = true;

                try {
                    await simulateTransaction('card-action', actionData);
                    showMessage('success', `Card ${actionData.action} completed successfully`);
                    closePasswordModal();
                    cardActionForm.reset();
                } catch (error) {
                    console.error('[Banking] Card action error:', error);
                    showMessage('error', 'Card action failed. Please try again.');
                } finally {
                    submitBtn.textContent = originalText;
                    submitBtn.disabled = false;
                }
            });
        }
    }

    /**
     * Modal Management
     */
    window.showPasswordPrompt = function(action) {
        console.log('[Banking] Showing password prompt for action:', action);
        window.currentCardAction = action;
        const modal = document.getElementById('password-modal');
        if (modal) {
            modal.style.display = 'flex';
            const passwordField = document.getElementById('card-password');
            if (passwordField) {
                passwordField.focus();
            }
        }
    };

    window.closePasswordModal = function() {
        console.log('[Banking] Closing password modal');
        const modal = document.getElementById('password-modal');
        if (modal) {
            modal.style.display = 'none';
        }
        window.currentCardAction = null;
    };

    /**
     * Message System
     */
    function showMessage(type, text) {
        console.log(`[Banking] Showing ${type} message:`, text);

        const messageElement = document.getElementById(`${type}-message`);
        if (messageElement) {
            const textElement = messageElement.querySelector('.message-text');
            if (textElement) {
                textElement.textContent = text;
            }
            messageElement.style.display = 'flex';

            // Auto-hide after 5 seconds
            setTimeout(() => {
                closeMessage(type);
            }, 5000);
        }
    }

    window.closeMessage = function(type) {
        const messageElement = document.getElementById(`${type}-message`);
        if (messageElement) {
            messageElement.style.display = 'none';
        }
    };

    /**
     * Transaction Simulation
     */
    async function simulateTransaction(type, data) {
        console.log(`[Banking] Simulating ${type} transaction:`, data);

        // Simulate network delay
        await new Promise(resolve => setTimeout(resolve, 1500 + Math.random() * 1000));

        // Simulate occasional failures (10% chance)
        if (Math.random() < 0.1) {
            throw new Error('Simulated transaction failure');
        }

        console.log(`[Banking] ${type} transaction completed successfully`);
        return { success: true, transactionId: 'TXN-' + Date.now() };
    }

    /**
     * Dynamic Content Updates
     */
    function updateAccountBalances() {
        // Simulate real-time balance updates
        setInterval(() => {
            const balanceElements = document.querySelectorAll('.account-balance');
            balanceElements.forEach(element => {
                // Small random fluctuations to simulate real banking
                const currentText = element.textContent;
                if (currentText.includes('$') && !currentText.includes('-')) {
                    const value = parseFloat(currentText.replace(/[$,]/g, ''));
                    const fluctuation = (Math.random() - 0.5) * 10; // ±$5 fluctuation
                    const newValue = Math.max(0, value + fluctuation);
                    element.textContent = `$${newValue.toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
                }
            });
        }, 30000); // Update every 30 seconds
    }

    /**
     * Security Monitoring
     */
    function initSecurityMonitoring() {
        console.log('[Banking] Initializing security monitoring...');

        // Monitor for suspicious activity patterns
        let passwordAttempts = 0;
        let lastPasswordAttempt = 0;

        document.addEventListener('input', (e) => {
            if (e.target.type === 'password') {
                const now = Date.now();
                if (now - lastPasswordAttempt < 1000) {
                    passwordAttempts++;
                    if (passwordAttempts > 10) {
                        console.warn('[Banking] Suspicious password input activity detected');
                    }
                } else {
                    passwordAttempts = 0;
                }
                lastPasswordAttempt = now;
            }
        });

        // Monitor for rapid form submissions
        let formSubmissions = [];
        document.addEventListener('submit', (e) => {
            const now = Date.now();
            formSubmissions.push(now);

            // Clean old submissions (older than 60 seconds)
            formSubmissions = formSubmissions.filter(time => now - time < 60000);

            if (formSubmissions.length > 5) {
                console.warn('[Banking] Suspicious form submission activity detected');
            }
        });
    }

    /**
     * Application Initialization
     */
    function init() {
        console.log('[Banking] Starting application initialization...');

        try {
            initNavigation();
            setupFormValidation();
            initTransferForm();
            initPaymentForm();
            initSettingsForm();
            initCardActions();
            updateAccountBalances();
            initSecurityMonitoring();

            console.log('[Banking] Application initialized successfully');

            // Show welcome message
            setTimeout(() => {
                showMessage('success', `Welcome back, ${appState.user.name}!`);
            }, 1000);

        } catch (error) {
            console.error('[Banking] Application initialization failed:', error);
            showMessage('error', 'Application failed to initialize properly');
        }
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();

/**
 * LEGITIMATE BANKING APPLICATION ANALYSIS:
 *
 * This banking application provides multiple attack surfaces for DOM-based skimming:
 *
 * 1. **Rich Form Structure**: Multiple forms with sensitive data (passwords, account numbers, CVV)
 * 2. **Real-time Validation**: Input/change/blur event listeners that could be monitored
 * 3. **Dynamic Content**: DOM updates that could be intercepted or modified
 * 4. **Modal Systems**: Password prompts that could be overlaid or replaced
 * 5. **State Management**: Application state that could be accessed or modified
 *
 * Attack Vectors Available:
 * - Real-time field monitoring via event listener attachment
 * - Form overlay injection over existing forms
 * - Shadow DOM manipulation for stealth operations
 * - Dynamic content injection and modification
 * - Event interception and data capture
 *
 * This legitimate application serves as the target for DOM-based skimming attacks
 * while maintaining realistic banking functionality for training purposes.
 */