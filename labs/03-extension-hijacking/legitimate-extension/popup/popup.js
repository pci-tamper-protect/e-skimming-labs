/**
 * POPUP.JS - LEGITIMATE EXTENSION POPUP
 *
 * This file contains the legitimate popup functionality for SecureForm Assistant.
 * It provides a clean interface for users to control security features.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

;(function () {
  'use strict'

  console.log('[SecureForm] Popup initializing...')

  // Application state
  let currentTab = null
  let extensionSettings = {
    formValidation: true,
    securityWarnings: true,
    autofillProtection: true
  }

  let dailyStats = {
    formsProtected: 0,
    threatsBlocked: 0
  }

  /**
   * DOM Elements
   */
  const elements = {
    statusIndicator: document.getElementById('status-indicator'),
    statusText: document.getElementById('status-text'),
    formValidationToggle: document.getElementById('form-validation'),
    securityWarningsToggle: document.getElementById('security-warnings'),
    autofillProtectionToggle: document.getElementById('autofill-protection'),
    formsProtectedCount: document.getElementById('forms-protected'),
    threatsBlockedCount: document.getElementById('threats-blocked'),
    currentSite: document.getElementById('current-site'),
    siteStatus: document.getElementById('site-status'),
    siteAnalysis: document.getElementById('site-analysis'),
    scanPageBtn: document.getElementById('scan-page'),
    settingsBtn: document.getElementById('settings')
  }

  /**
   * Initialization
   */
  async function init() {
    try {
      console.log('[SecureForm] Initializing popup...')

      // Get current tab
      await getCurrentTab()

      // Load settings
      await loadSettings()

      // Load daily stats
      await loadDailyStats()

      // Setup event listeners
      setupEventListeners()

      // Update UI
      updateUI()

      // Analyze current site
      await analyzeSite()

      console.log('[SecureForm] Popup initialized successfully')
    } catch (error) {
      console.error('[SecureForm] Popup initialization failed:', error)
      showError('Failed to initialize extension popup')
    }
  }

  /**
   * Get Current Tab
   */
  async function getCurrentTab() {
    try {
      const tabs = await chrome.tabs.query({ active: true, currentWindow: true })
      currentTab = tabs[0]
      console.log('[SecureForm] Current tab:', currentTab.url)
    } catch (error) {
      console.error('[SecureForm] Failed to get current tab:', error)
    }
  }

  /**
   * Load Settings
   */
  async function loadSettings() {
    try {
      const result = await chrome.storage.sync.get(['extensionSettings'])
      if (result.extensionSettings) {
        extensionSettings = { ...extensionSettings, ...result.extensionSettings }
      }
      console.log('[SecureForm] Settings loaded:', extensionSettings)
    } catch (error) {
      console.error('[SecureForm] Failed to load settings:', error)
    }
  }

  /**
   * Save Settings
   */
  async function saveSettings() {
    try {
      await chrome.storage.sync.set({ extensionSettings })
      console.log('[SecureForm] Settings saved')
    } catch (error) {
      console.error('[SecureForm] Failed to save settings:', error)
    }
  }

  /**
   * Load Daily Stats
   */
  async function loadDailyStats() {
    try {
      const today = new Date().toDateString()
      const result = await chrome.storage.local.get([`dailyStats_${today}`])
      if (result[`dailyStats_${today}`]) {
        dailyStats = result[`dailyStats_${today}`]
      }
      console.log('[SecureForm] Daily stats loaded:', dailyStats)
    } catch (error) {
      console.error('[SecureForm] Failed to load daily stats:', error)
    }
  }

  /**
   * Update Daily Stats
   */
  async function updateDailyStats() {
    try {
      const today = new Date().toDateString()
      await chrome.storage.local.set({ [`dailyStats_${today}`]: dailyStats })
      console.log('[SecureForm] Daily stats updated')
    } catch (error) {
      console.error('[SecureForm] Failed to update daily stats:', error)
    }
  }

  /**
   * Setup Event Listeners
   */
  function setupEventListeners() {
    // Feature toggles
    elements.formValidationToggle.addEventListener('change', e => {
      extensionSettings.formValidation = e.target.checked
      saveSettings()
      updateContentScripts()
    })

    elements.securityWarningsToggle.addEventListener('change', e => {
      extensionSettings.securityWarnings = e.target.checked
      saveSettings()
      updateContentScripts()
    })

    elements.autofillProtectionToggle.addEventListener('change', e => {
      extensionSettings.autofillProtection = e.target.checked
      saveSettings()
      updateContentScripts()
    })

    // Action buttons
    elements.scanPageBtn.addEventListener('click', scanCurrentPage)
    elements.settingsBtn.addEventListener('click', openSettings)

    console.log('[SecureForm] Event listeners setup complete')
  }

  /**
   * Update UI
   */
  function updateUI() {
    // Update toggles
    elements.formValidationToggle.checked = extensionSettings.formValidation
    elements.securityWarningsToggle.checked = extensionSettings.securityWarnings
    elements.autofillProtectionToggle.checked = extensionSettings.autofillProtection

    // Update stats
    elements.formsProtectedCount.textContent = dailyStats.formsProtected
    elements.threatsBlockedCount.textContent = dailyStats.threatsBlocked

    // Update current site
    if (currentTab) {
      try {
        const url = new URL(currentTab.url)
        elements.currentSite.textContent = url.hostname
      } catch (error) {
        elements.currentSite.textContent = 'Unknown'
      }
    }

    console.log('[SecureForm] UI updated')
  }

  /**
   * Analyze Current Site
   */
  async function analyzeSite() {
    if (!currentTab) return

    try {
      elements.siteAnalysis.textContent = 'Analyzing site security...'
      elements.siteAnalysis.classList.add('loading')

      // Send message to content script for analysis
      const response = await chrome.tabs.sendMessage(currentTab.id, {
        type: 'ANALYZE_SITE',
        settings: extensionSettings
      })

      if (response && response.analysis) {
        updateSiteAnalysis(response.analysis)
      } else {
        // Fallback analysis
        performBasicAnalysis()
      }
    } catch (error) {
      console.log('[SecureForm] Content script not ready, performing basic analysis')
      performBasicAnalysis()
    }
  }

  /**
   * Perform Basic Analysis
   */
  function performBasicAnalysis() {
    if (!currentTab) return

    try {
      const url = new URL(currentTab.url)
      const isSecure = url.protocol === 'https:'
      const isLocalhost = url.hostname === 'localhost' || url.hostname === '127.0.0.1'

      let status = 'secure'
      let message = 'Site appears secure'

      if (!isSecure && !isLocalhost) {
        status = 'warning'
        message = 'Insecure connection (HTTP)'
      }

      updateSiteAnalysis({
        secure: isSecure || isLocalhost,
        status: status,
        message: message,
        formsFound: 0,
        threats: []
      })
    } catch (error) {
      updateSiteAnalysis({
        secure: false,
        status: 'unknown',
        message: 'Unable to analyze site',
        formsFound: 0,
        threats: []
      })
    }
  }

  /**
   * Update Site Analysis
   */
  function updateSiteAnalysis(analysis) {
    elements.siteAnalysis.classList.remove('loading')

    // Update status indicator
    elements.statusIndicator.className = `status-indicator status-${analysis.status}`
    elements.statusText.textContent = analysis.secure ? 'Site Secure' : 'Security Issues'

    // Update site status icon
    if (analysis.secure) {
      elements.siteStatus.textContent = '🔒'
    } else {
      elements.siteStatus.textContent = '⚠️'
    }

    // Update analysis text
    elements.siteAnalysis.textContent = analysis.message

    console.log('[SecureForm] Site analysis updated:', analysis)
  }

  /**
   * Scan Current Page
   */
  async function scanCurrentPage() {
    if (!currentTab) return

    try {
      elements.scanPageBtn.textContent = 'Scanning...'
      elements.scanPageBtn.disabled = true

      // Send scan request to content script
      const response = await chrome.tabs.sendMessage(currentTab.id, {
        type: 'SCAN_PAGE',
        settings: extensionSettings
      })

      if (response && response.scanResults) {
        handleScanResults(response.scanResults)
      } else {
        showMessage('Scan completed - no issues found')
      }
    } catch (error) {
      console.error('[SecureForm] Page scan failed:', error)
      showError('Failed to scan page')
    } finally {
      elements.scanPageBtn.textContent = 'Scan Page'
      elements.scanPageBtn.disabled = false
    }
  }

  /**
   * Handle Scan Results
   */
  function handleScanResults(results) {
    console.log('[SecureForm] Scan results:', results)

    let message = `Found ${results.formsCount} forms`
    if (results.issues.length > 0) {
      message += `, ${results.issues.length} security issues`
      dailyStats.threatsBlocked += results.issues.length
    }

    dailyStats.formsProtected += results.formsCount
    updateDailyStats()
    updateUI()

    showMessage(message)
  }

  /**
   * Update Content Scripts
   */
  async function updateContentScripts() {
    if (!currentTab) return

    try {
      await chrome.tabs.sendMessage(currentTab.id, {
        type: 'UPDATE_SETTINGS',
        settings: extensionSettings
      })
      console.log('[SecureForm] Content script settings updated')
    } catch (error) {
      console.log('[SecureForm] Content script not available for settings update')
    }
  }

  /**
   * Open Settings
   */
  function openSettings() {
    chrome.runtime.openOptionsPage()
  }

  /**
   * Show Message
   */
  function showMessage(message) {
    console.log('[SecureForm] Message:', message)
    // In a real extension, this might show a toast or update the UI
    elements.siteAnalysis.textContent = message
    setTimeout(() => {
      if (currentTab) {
        analyzeSite()
      }
    }, 3000)
  }

  /**
   * Show Error
   */
  function showError(error) {
    console.error('[SecureForm] Error:', error)
    elements.statusIndicator.className = 'status-indicator status-danger'
    elements.statusText.textContent = 'Error'
    elements.siteAnalysis.textContent = error
  }

  /**
   * Message Listener
   */
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'STATS_UPDATE':
        if (request.stats) {
          dailyStats = { ...dailyStats, ...request.stats }
          updateDailyStats()
          updateUI()
        }
        break

      case 'SITE_ANALYSIS_UPDATE':
        if (request.analysis) {
          updateSiteAnalysis(request.analysis)
        }
        break

      default:
        console.log('[SecureForm] Unknown message type:', request.type)
    }
  })

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})()

/**
 * LEGITIMATE POPUP ANALYSIS:
 *
 * This popup provides standard extension functionality:
 *
 * 1. **User Interface**: Clean, professional interface for extension control
 * 2. **Settings Management**: Toggle security features on/off
 * 3. **Statistics Display**: Show daily protection statistics
 * 4. **Site Analysis**: Basic security analysis of current site
 * 5. **Content Script Communication**: Normal message passing with content scripts
 *
 * Key Characteristics:
 * - Standard Chrome extension APIs usage
 * - Reasonable permissions and functionality
 * - Professional appearance to build user trust
 * - Clear value proposition (form security)
 * - Normal statistics and monitoring features
 *
 * This legitimate popup will be maintained in the malicious version
 * to preserve the appearance of legitimacy while hiding malicious
 * functionality in the background and content scripts.
 */
