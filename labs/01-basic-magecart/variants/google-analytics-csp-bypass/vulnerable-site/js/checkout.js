/**
 * LEGITIMATE CHECKOUT FUNCTIONALITY
 *
 * This is the normal, non-malicious checkout code
 * that handles form validation and submission.
 *
 * In a real attack, the skimmer code would be
 * appended to this file or injected via a
 * compromised third-party script.
 */

;(function () {
  'use strict'

  console.log('[Checkout] Initializing legitimate checkout system...')

  /**
   * Validate credit card number using Luhn algorithm
   */
  function validateCardNumber(cardNumber) {
    const digits = cardNumber.replace(/\D/g, '')

    if (digits.length < 15 || digits.length > 16) {
      return false
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

    return sum % 10 === 0
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
   * In a real system, this would communicate with a payment processor
   */
  function processPayment(formData) {
    console.log('[Checkout] Processing payment...')
    console.log('[Checkout] IMPORTANT: This is a simulated transaction')

    // Simulate API call to payment processor
    return new Promise(resolve => {
      setTimeout(() => {
        // In reality, this would be sent to Stripe, PayPal, etc.
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
    const cardholderName = document.getElementById('cardholder-name').value

    // Validate card number
    if (!validateCardNumber(cardNumber)) {
      showError('card-number', 'Invalid card number')
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
      // Collect form data
      const formData = new FormData(event.target)
      const data = Object.fromEntries(formData.entries())

      // Process payment
      const result = await processPayment(data)

      if (result.success) {
        // Hide form
        event.target.style.display = 'none'

        // Show success message
        const successMessage = document.getElementById('success-message')
        successMessage.classList.add('show')

        console.log('[Checkout] Order completed successfully')
        console.log('[Checkout] ✅ Customer sees: Order confirmed')
        console.log('[Checkout] ❌ Customer DOES NOT see: Data stolen by skimmer')
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
      console.log('[Checkout] ⚠️ WARNING: This page is compromised with a skimmer')
      console.log('[Checkout] 💡 TIP: Open DevTools → Network tab to see the malicious request')
    }
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})()
