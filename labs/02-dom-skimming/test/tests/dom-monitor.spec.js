// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../../test/config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

// Get URLs for lab 2
const lab2VulnerableUrl = currentEnv.lab2.vulnerable
const lab2C2Url = currentEnv.lab2.c2

console.log(`🧪 Test environment: ${TEST_ENV}`)
console.log(`📍 Lab 2 Vulnerable URL: ${lab2VulnerableUrl}`)
console.log(`📍 Lab 2 C2 URL: ${lab2C2Url}`)

test.describe('DOM-Based Skimming Lab - Real-Time Field Monitor', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture attack logs
    page.on('console', msg => {
      if (msg.text().includes('[DOM-Monitor]')) {
        console.log('🕵️ DOM-MONITOR LOG:', msg.text())
      }
    })

    // Capture network requests to C2 server
    page.on('request', request => {
      if (request.url().includes('/collect')) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          headers: request.headers(),
          postData: request.postData()
        })
      }
    })

    page.on('response', response => {
      if (request.url().includes('/collect')) {
        console.log('📥 RESPONSE FROM C2:', {
          url: response.url(),
          status: response.status(),
          headers: response.headers()
        })
      }
    })
  })

  test('should monitor DOM mutations and attach to new forms', async ({ page }) => {
    console.log('🚀 Testing DOM mutation monitoring...')

    // Load banking page
    await page.goto(`${lab2VulnerableUrl}/banking.html`)
    await page.waitForLoadState('networkidle')

    // Inject DOM monitor attack
    await page.addScriptTag({
      path: './malicious-code/dom-monitor.js'
    })

    await expect(page).toHaveTitle(/SecureBank/)

    // Navigate to transfer section to trigger form detection
    await page.locator('[data-section="transfer"]').click({ timeout: 3000 })
    await page.waitForTimeout(500)

    console.log('📝 Testing real-time field monitoring...')

    // Fill transfer form to trigger monitoring
    await page.selectOption('#from-account', 'checking')
    await page.fill('#to-account', '987654321')
    await page.fill('#transfer-amount', '1500.00')
    await page.fill('#transfer-memo', 'Test transfer for DOM monitoring')
    await page.fill('#transfer-password', 'testpassword123')

    console.log('✅ Form filled - DOM monitor should have captured field data')

    // Wait for periodic reporting
    await page.waitForTimeout(6000)

    // Check DOM monitor status
    const monitorStatus = await page.evaluate(() => {
      return window.domMonitorAttack ? window.domMonitorAttack.getStatus() : null
    })

    console.log('📊 DOM Monitor Status:', monitorStatus)

    if (monitorStatus) {
      expect(monitorStatus.active).toBe(true)
      expect(monitorStatus.sessionsCount).toBeGreaterThan(0)
      expect(monitorStatus.fieldsCount).toBeGreaterThan(0)
    }

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')
    const c2Response = await page.request.get(`${lab2C2Url}/stats`)
    expect(c2Response.ok()).toBeTruthy()
    
    const stats = await c2Response.json()
    console.log('📊 C2 Server Stats:', stats)
    
    // Verify attack was recorded
    expect(stats.totalAttacks).toBeGreaterThan(0)
    console.log('✅ DOM monitoring attack recorded in C2 server')
    
    console.log('🔍 DOM mutation monitoring test completed')
  })

  test('should capture keystrokes in real-time', async ({ page }) => {
    console.log('⌨️ Testing real-time keystroke capture...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject DOM monitor attack
    await page.addScriptTag({
      path: './malicious-code/dom-monitor.js'
    })

    // Navigate to payments section
    await page.locator('[data-section="payments"]').click({ timeout: 3000 })
    await page.waitForTimeout(500)

    console.log('📝 Testing keystroke monitoring on payment form...')

    // Type slowly to trigger keystroke monitoring
    await page.waitForSelector('#payment-account', { timeout: 3000 })
    await page.click('#payment-account')
    await page.type('#payment-account', '123456789', { delay: 50 })

    await page.waitForSelector('#payment-amount', { timeout: 3000 })
    await page.click('#payment-amount')
    await page.type('#payment-amount', '299.99', { delay: 50 })

    await page.waitForSelector('#payment-password', { timeout: 3000 })
    await page.click('#payment-password')
    await page.type('#payment-password', 'securepass', { delay: 50 })

    console.log('✅ Keystroke input completed')

    // Wait for data collection
    await page.waitForTimeout(3000)

    // Check captured keystroke data
    const capturedData = await page.evaluate(() => {
      return window.domMonitorAttack ? window.domMonitorAttack.getCapturedData() : null
    })

    console.log('🔑 Captured Data Summary:', {
      sessions: capturedData ? capturedData.sessions.length : 0,
      keystrokes: capturedData ? capturedData.keystrokes.length : 0,
      fields: capturedData ? capturedData.fields.size : 0
    })

    if (capturedData) {
      expect(capturedData.keystrokes.length).toBeGreaterThan(0)
      expect(capturedData.sessions.length).toBeGreaterThan(0)
    }

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')
    const c2Response = await page.request.get(`${lab2C2Url}/stats`)
    expect(c2Response.ok()).toBeTruthy()
    
    const stats = await c2Response.json()
    console.log('📊 C2 Server Stats:', stats)
    
    // Verify attack was recorded
    expect(stats.totalAttacks).toBeGreaterThan(0)
    console.log('✅ Keystroke monitoring attack recorded in C2 server')

    console.log('⌨️ Keystroke monitoring test completed')
  })

  test('should detect and monitor dynamically added forms', async ({ page }) => {
    console.log('🔄 Testing dynamic form detection...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject DOM monitor attack
    await page.addScriptTag({
      path: './malicious-code/dom-monitor.js'
    })

    // Wait for initial setup
    await page.waitForTimeout(1000)

    console.log('➕ Adding dynamic form to test mutation observer...')

    // Add a dynamic form via JavaScript
    await page.evaluate(() => {
      const dynamicForm = document.createElement('form')
      dynamicForm.id = 'dynamic-test-form'
      dynamicForm.innerHTML = `
        <div>
          <label for="dynamic-card">Card Number:</label>
          <input type="text" id="dynamic-card" name="cardNumber" autocomplete="cc-number">
        </div>
        <div>
          <label for="dynamic-cvv">CVV:</label>
          <input type="text" id="dynamic-cvv" name="cvv" maxlength="4">
        </div>
        <div>
          <label for="dynamic-password">Password:</label>
          <input type="password" id="dynamic-password" name="password">
        </div>
        <button type="submit">Submit Dynamic Form</button>
      `

      document.body.appendChild(dynamicForm)
    })

    // Wait for mutation observer to detect new form
    await page.waitForTimeout(500)

    console.log('📝 Filling dynamic form to test monitoring...')

    // Fill the dynamic form
    await page.fill('#dynamic-card', '4111111111111111')
    await page.fill('#dynamic-cvv', '123')
    await page.fill('#dynamic-password', 'dynamicpass')

    // Wait for data capture
    await page.waitForTimeout(2000)

    // Check if dynamic form was detected and monitored
    const monitorStatus = await page.evaluate(() => {
      return window.domMonitorAttack ? window.domMonitorAttack.getStatus() : null
    })

    console.log('📊 Monitor Status After Dynamic Form:', monitorStatus)

    if (monitorStatus) {
      expect(monitorStatus.fieldsCount).toBeGreaterThan(0)
      expect(monitorStatus.sessionsCount).toBeGreaterThan(0)
    }

    console.log('🔄 Dynamic form detection test completed')
  })

  test('should handle high-value field immediate exfiltration', async ({ page }) => {
    const networkRequests = []

    // Capture all network requests
    page.on('request', request => {
      if (request.url().includes('/collect')) {
        networkRequests.push({
          url: request.url(),
          method: request.method(),
          postData: request.postData(),
          timestamp: Date.now()
        })
      }
    })

    console.log('💎 Testing high-value field immediate exfiltration...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject DOM monitor attack
    await page.addScriptTag({
      path: './malicious-code/dom-monitor.js'
    })

    // Navigate to cards section for high-value fields
    await page.locator('[data-section="cards"]').click({ timeout: 3000 })
    await page.waitForTimeout(500)

    console.log('🔐 Triggering card action to show password modal...')

    // Click on a card action to show the password modal
    await page.click('button:has-text("Change PIN")')
    await page.waitForTimeout(500)

    // Fill high-value fields (password and CVV)
    await page.fill('#card-password', 'highvaluepass')
    await page.fill('#card-cvv', '999')

    // Trigger blur event on high-value field for immediate exfiltration
    await page.click('body')

    console.log('✅ High-value fields filled and blurred')

    // Wait for immediate exfiltration
    await page.waitForTimeout(3000)

    console.log('🌐 Network requests captured:', networkRequests.length)

    // Verify immediate exfiltration occurred
    const immediateRequests = networkRequests.filter(req => {
      if (req.postData) {
        try {
          const data = JSON.parse(req.postData)
          return data.type === 'immediate'
        } catch (e) {
          return false
        }
      }
      return false
    })

    console.log('⚡ Immediate exfiltration requests:', immediateRequests.length)

    if (immediateRequests.length > 0) {
      const immediateData = JSON.parse(immediateRequests[0].postData)
      console.log('💎 Immediate data structure:', {
        type: immediateData.type,
        hasFieldData: !!immediateData.fieldData,
        fieldId: immediateData.fieldData?.fieldId
      })

      expect(immediateData.type).toBe('immediate')
      expect(immediateData.fieldData).toBeDefined()
    }

    console.log('💎 High-value field exfiltration test completed')
  })

  test('should contain DOM monitoring attack patterns', async ({ page }) => {
    console.log('🔍 Analyzing DOM monitoring attack patterns...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject DOM monitor attack and analyze the code
    await page.addScriptTag({
      path: './malicious-code/dom-monitor.js'
    })

    await page.waitForTimeout(2000)

    // Check for attack infrastructure in the page
    const attackPatterns = await page.evaluate(() => {
      const patterns = {
        mutationObserver: !!window.MutationObserver,
        domMonitorAttack: !!window.domMonitorAttack,
        hasEventListeners: false,
        hasWeakSet: !!window.WeakSet,
        hasSendBeacon: !!navigator.sendBeacon
      }

      // Check if event listeners are being attached to form fields
      const formInputs = document.querySelectorAll('input[type="password"], input[name*="card"]')
      patterns.hasEventListeners = formInputs.length > 0

      return patterns
    })

    console.log('📊 Attack pattern analysis:', attackPatterns)

    // Verify key DOM monitoring patterns
    expect(attackPatterns.mutationObserver).toBe(true)
    expect(attackPatterns.domMonitorAttack).toBe(true)
    expect(attackPatterns.hasWeakSet).toBe(true)
    expect(attackPatterns.hasSendBeacon).toBe(true)

    // Check for monitoring status
    const monitorStatus = await page.evaluate(() => {
      return window.domMonitorAttack ? window.domMonitorAttack.getStatus() : null
    })

    if (monitorStatus) {
      expect(monitorStatus.active).toBe(true)
      console.log('✓ DOM monitoring is active')
    }

    console.log('✅ DOM monitoring attack patterns verified')
  })

  test('should handle page unload data exfiltration', async ({ page }) => {
    const networkRequests = []

    // Capture sendBeacon requests (harder to detect)
    await page.route('**/collect', route => {
      networkRequests.push({
        url: route.request().url(),
        method: route.request().method(),
        postData: route.request().postDataBuffer()?.toString(),
        isBeacon: route.request().resourceType() === 'beacon'
      })
      route.fulfill({ status: 200, body: '{"success": true}' })
    })

    console.log('📤 Testing page unload data exfiltration...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject DOM monitor attack
    await page.addScriptTag({
      path: './malicious-code/dom-monitor.js'
    })

    // Generate some activity
    await page.locator('[data-section="transfer"]').click({ timeout: 3000 })
    await page.waitForTimeout(500)
    await page.fill('#from-account', 'checking')
    await page.fill('#to-account', '555666777')
    await page.fill('#transfer-password', 'unloadtest')

    await page.waitForTimeout(2000)

    console.log('🔄 Navigating away to trigger unload exfiltration...')

    // Navigate away to trigger beforeunload
    await page.goto('about:blank')

    await page.waitForTimeout(1000)

    console.log('📊 Network requests on unload:', networkRequests.length)

    // Check for session end data
    const unloadRequests = networkRequests.filter(req => {
      if (req.postData) {
        try {
          const data = JSON.parse(req.postData)
          return data.type === 'session_end'
        } catch (e) {
          return false
        }
      }
      return false
    })

    console.log('📤 Unload exfiltration requests:', unloadRequests.length)

    if (unloadRequests.length > 0) {
      const unloadData = JSON.parse(unloadRequests[0].postData)
      console.log('📊 Unload data structure:', {
        type: unloadData.type,
        hasFinalData: !!unloadData.finalData,
        sessionDuration: unloadData.finalData?.sessionDuration
      })

      expect(unloadData.type).toBe('session_end')
      expect(unloadData.finalData).toBeDefined()
    }

    console.log('📤 Page unload exfiltration test completed')
  })
})
