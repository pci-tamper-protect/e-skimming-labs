/**
 * BACKGROUND.JS - LEGITIMATE EXTENSION BACKGROUND SCRIPT
 *
 * This file contains the legitimate background functionality for SecureForm Assistant.
 * It manages extension lifecycle, storage, and communication between components.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */

;(function () {
  'use strict'

  console.log('[SecureForm] Background script initializing...')

  // Extension state
  let extensionStats = {
    totalFormsProtected: 0,
    totalThreatsBlocked: 0,
    lastActivity: null
  }

  let activeTabAnalysis = new Map()

  /**
   * Extension Installation
   */
  chrome.runtime.onInstalled.addListener(details => {
    console.log('[SecureForm] Extension installed:', details.reason)

    if (details.reason === 'install') {
      // Set default settings
      chrome.storage.sync.set({
        extensionSettings: {
          formValidation: true,
          securityWarnings: true,
          autofillProtection: true
        }
      })

      // Initialize stats
      chrome.storage.local.set({
        extensionStats: extensionStats
      })

      console.log('[SecureForm] Default settings initialized')
    }

    if (details.reason === 'update') {
      console.log('[SecureForm] Extension updated from version:', details.previousVersion)
    }
  })

  /**
   * Extension Startup
   */
  chrome.runtime.onStartup.addListener(() => {
    console.log('[SecureForm] Extension startup')
    loadExtensionStats()
  })

  /**
   * Load Extension Stats
   */
  async function loadExtensionStats() {
    try {
      const result = await chrome.storage.local.get(['extensionStats'])
      if (result.extensionStats) {
        extensionStats = { ...extensionStats, ...result.extensionStats }
      }
      console.log('[SecureForm] Extension stats loaded:', extensionStats)
    } catch (error) {
      console.error('[SecureForm] Failed to load extension stats:', error)
    }
  }

  /**
   * Save Extension Stats
   */
  async function saveExtensionStats() {
    try {
      await chrome.storage.local.set({ extensionStats })
      console.log('[SecureForm] Extension stats saved')
    } catch (error) {
      console.error('[SecureForm] Failed to save extension stats:', error)
    }
  }

  /**
   * Message Listener
   */
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log(
      '[SecureForm] Background received message:',
      request.type,
      'from tab:',
      sender.tab?.id
    )

    switch (request.type) {
      case 'FORM_SUBMISSION':
        handleFormSubmission(request.data, sender.tab)
        sendResponse({ success: true })
        break

      case 'PAGE_ANALYSIS':
        handlePageAnalysis(request.analysis, sender.tab)
        sendResponse({ success: true })
        break

      case 'THREAT_DETECTED':
        handleThreatDetection(request.threat, sender.tab)
        sendResponse({ success: true })
        break

      case 'GET_STATS':
        sendResponse({ stats: extensionStats })
        break

      case 'GET_TAB_ANALYSIS':
        const analysis = activeTabAnalysis.get(sender.tab?.id)
        sendResponse({ analysis: analysis || null })
        break

      default:
        console.log('[SecureForm] Unknown message type:', request.type)
        sendResponse({ error: 'Unknown message type' })
    }

    return true // Keep message channel open for async response
  })

  /**
   * Handle Form Submission
   */
  function handleFormSubmission(data, tab) {
    console.log('[SecureForm] Form submission on tab:', tab.id, data)

    // Update stats
    extensionStats.totalFormsProtected++
    extensionStats.lastActivity = Date.now()

    // Update daily stats
    updateDailyStats('formsProtected', 1)

    // Store submission data for analysis
    const submission = {
      url: data.url,
      formIndex: data.formIndex,
      inputCount: data.inputCount,
      timestamp: data.timestamp,
      tabId: tab.id
    }

    // Log for legitimate extension (would be used maliciously in hijacked version)
    console.log('[SecureForm] Form submission logged:', submission)

    saveExtensionStats()
  }

  /**
   * Handle Page Analysis
   */
  function handlePageAnalysis(analysis, tab) {
    console.log('[SecureForm] Page analysis for tab:', tab.id, analysis)

    // Store analysis for the tab
    activeTabAnalysis.set(tab.id, {
      ...analysis,
      tabId: tab.id,
      url: tab.url,
      timestamp: Date.now()
    })

    // Update badge based on analysis
    updateBadge(tab.id, analysis)

    // Notify popup if it's open
    try {
      chrome.runtime.sendMessage({
        type: 'SITE_ANALYSIS_UPDATE',
        analysis: analysis,
        tabId: tab.id
      })
    } catch (error) {
      // Popup not open, ignore
    }
  }

  /**
   * Handle Threat Detection
   */
  function handleThreatDetection(threat, tab) {
    console.log('[SecureForm] Threat detected on tab:', tab.id, threat)

    // Update stats
    extensionStats.totalThreatsBlocked++
    extensionStats.lastActivity = Date.now()

    // Update daily stats
    updateDailyStats('threatsBlocked', 1)

    // Log threat for analysis
    const threatData = {
      ...threat,
      url: tab.url,
      tabId: tab.id,
      timestamp: Date.now()
    }

    console.log('[SecureForm] Threat logged:', threatData)

    // Update badge to show threat
    chrome.action.setBadgeText({
      text: '!',
      tabId: tab.id
    })

    chrome.action.setBadgeBackgroundColor({
      color: '#ef4444',
      tabId: tab.id
    })

    saveExtensionStats()
  }

  /**
   * Update Badge
   */
  function updateBadge(tabId, analysis) {
    if (analysis.status === 'danger') {
      chrome.action.setBadgeText({
        text: '!',
        tabId: tabId
      })
      chrome.action.setBadgeBackgroundColor({
        color: '#ef4444',
        tabId: tabId
      })
    } else if (analysis.status === 'warning') {
      chrome.action.setBadgeText({
        text: '?',
        tabId: tabId
      })
      chrome.action.setBadgeBackgroundColor({
        color: '#f59e0b',
        tabId: tabId
      })
    } else {
      chrome.action.setBadgeText({
        text: '',
        tabId: tabId
      })
    }
  }

  /**
   * Update Daily Stats
   */
  async function updateDailyStats(metric, increment) {
    try {
      const today = new Date().toDateString()
      const result = await chrome.storage.local.get([`dailyStats_${today}`])

      let dailyStats = result[`dailyStats_${today}`] || {
        formsProtected: 0,
        threatsBlocked: 0
      }

      dailyStats[metric] = (dailyStats[metric] || 0) + increment

      await chrome.storage.local.set({
        [`dailyStats_${today}`]: dailyStats
      })

      // Notify popup to update display
      try {
        chrome.runtime.sendMessage({
          type: 'STATS_UPDATE',
          stats: dailyStats
        })
      } catch (error) {
        // Popup not open, ignore
      }

      console.log('[SecureForm] Daily stats updated:', dailyStats)
    } catch (error) {
      console.error('[SecureForm] Failed to update daily stats:', error)
    }
  }

  /**
   * Tab Events
   */
  chrome.tabs.onRemoved.addListener(tabId => {
    // Clean up tab-specific data
    activeTabAnalysis.delete(tabId)
    console.log('[SecureForm] Cleaned up data for closed tab:', tabId)
  })

  chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.status === 'complete') {
      // Reset badge when page loads
      chrome.action.setBadgeText({
        text: '',
        tabId: tabId
      })

      // Clear previous analysis
      activeTabAnalysis.delete(tabId)

      console.log('[SecureForm] Tab updated:', tabId, tab.url)
    }
  })

  /**
   * Context Menu Setup
   */
  chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
      id: 'analyze-form',
      title: 'Analyze Form Security',
      contexts: ['all']
    })

    chrome.contextMenus.create({
      id: 'check-page',
      title: 'Check Page Security',
      contexts: ['page']
    })
  })

  /**
   * Context Menu Click Handler
   */
  chrome.contextMenus.onClicked.addListener((info, tab) => {
    console.log('[SecureForm] Context menu clicked:', info.menuItemId)

    switch (info.menuItemId) {
      case 'analyze-form':
        chrome.tabs.sendMessage(tab.id, {
          type: 'ANALYZE_ELEMENT',
          element: info.selectionText || 'clicked element'
        })
        break

      case 'check-page':
        chrome.tabs.sendMessage(tab.id, {
          type: 'SCAN_PAGE'
        })
        break
    }
  })

  /**
   * Alarm for Periodic Tasks
   */
  chrome.alarms.onAlarm.addListener(alarm => {
    console.log('[SecureForm] Alarm triggered:', alarm.name)

    switch (alarm.name) {
      case 'cleanup-stats':
        cleanupOldStats()
        break

      case 'health-check':
        performHealthCheck()
        break
    }
  })

  /**
   * Setup Periodic Tasks
   */
  chrome.runtime.onInstalled.addListener(() => {
    // Cleanup old stats daily
    chrome.alarms.create('cleanup-stats', {
      periodInMinutes: 24 * 60 // 24 hours
    })

    // Health check every hour
    chrome.alarms.create('health-check', {
      periodInMinutes: 60
    })
  })

  /**
   * Cleanup Old Stats
   */
  async function cleanupOldStats() {
    try {
      console.log('[SecureForm] Cleaning up old statistics...')

      const result = await chrome.storage.local.get()
      const cutoffDate = new Date()
      cutoffDate.setDate(cutoffDate.getDate() - 30) // Keep 30 days

      const keysToRemove = []
      for (const key in result) {
        if (key.startsWith('dailyStats_')) {
          const dateStr = key.replace('dailyStats_', '')
          const statDate = new Date(dateStr)
          if (statDate < cutoffDate) {
            keysToRemove.push(key)
          }
        }
      }

      if (keysToRemove.length > 0) {
        await chrome.storage.local.remove(keysToRemove)
        console.log('[SecureForm] Removed old stats:', keysToRemove.length)
      }
    } catch (error) {
      console.error('[SecureForm] Failed to cleanup old stats:', error)
    }
  }

  /**
   * Health Check
   */
  function performHealthCheck() {
    console.log('[SecureForm] Performing health check...')

    // Check if content scripts are responsive
    chrome.tabs.query({ active: true }, tabs => {
      tabs.forEach(tab => {
        if (tab.url && !tab.url.startsWith('chrome://')) {
          chrome.tabs.sendMessage(
            tab.id,
            {
              type: 'HEALTH_CHECK'
            },
            response => {
              if (chrome.runtime.lastError) {
                console.log('[SecureForm] Content script not responsive on tab:', tab.id)
              } else {
                console.log('[SecureForm] Content script healthy on tab:', tab.id)
              }
            }
          )
        }
      })
    })
  }

  // Initialize
  loadExtensionStats()

  console.log('[SecureForm] Background script initialized')
})()

/**
 * LEGITIMATE BACKGROUND SCRIPT ANALYSIS:
 *
 * This background script provides standard extension functionality:
 *
 * 1. **Lifecycle Management**: Installation, startup, and update handling
 * 2. **Statistics Tracking**: Form protection and threat blocking metrics
 * 3. **Message Handling**: Communication hub between popup and content scripts
 * 4. **Tab Management**: Analysis data storage and badge updates
 * 5. **Context Menus**: User-accessible security analysis features
 * 6. **Periodic Tasks**: Cleanup and health checking
 *
 * Key Characteristics:
 * - Standard Chrome extension patterns and APIs
 * - Legitimate security-focused functionality
 * - Professional error handling and logging
 * - Reasonable data collection (form counts, not content)
 * - Clean separation of concerns
 *
 * This legitimate functionality will be maintained in the malicious version
 * while adding hidden data exfiltration capabilities that leverage the
 * extension's privileged position and trusted appearance.
 */
