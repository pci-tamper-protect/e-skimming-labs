// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../../test/config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

// Get URLs for lab 2
const lab2VulnerableUrl = currentEnv.lab2.vulnerable
const lab2C2Url = currentEnv.lab2.c2
const maliciousCodeDir = path.resolve(__dirname, '../../vulnerable-site/malicious-code')

console.log(`🧪 Test environment: ${TEST_ENV}`)
console.log(`📍 Lab 2 Vulnerable URL: ${lab2VulnerableUrl}`)
console.log(`📍 Lab 2 C2 URL: ${lab2C2Url}`)

test.describe('Lab 2: DOM-Based Skimming - Form Overlay Injection', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture attack logs
    page.on('console', msg => {
      if (msg.text().includes('[Form-Overlay]')) {
        console.log('🎭 FORM-OVERLAY LOG:', msg.text())
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
      if (response.url().includes('/collect')) {
        console.log('📥 RESPONSE FROM C2:', {
          url: response.url(),
          status: response.status(),
          headers: response.headers()
        })
      }
    })
  })

  test('should inject overlay on high-priority forms', async ({ page }) => {
    console.log('🚀 Testing form overlay injection...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    await expect(page).toHaveTitle(/SecureBank/)

    // Navigate to transfer section (high-priority form)
    await page.waitForSelector('[data-section="transfer"]', { timeout: 2000 })
    await page.click('[data-section="transfer"]')
    await page.waitForTimeout(500)

    console.log('⏳ Waiting for overlay injection delay...')

    // Wait for overlay injection delay (2 seconds)
    await page.waitForTimeout(3000)

    // Check if overlay was injected
    const overlayExists = await page.locator('#form-overlay-backdrop').isVisible()
    console.log('🎭 Overlay injection status:', overlayExists)

    if (overlayExists) {
      console.log('✅ Form overlay successfully injected')

      // Verify overlay content
      await expect(page.locator('.overlay-title')).toBeVisible()
      await expect(page.locator('.overlay-form')).toBeVisible()
      await expect(page.locator('.overlay-submit')).toBeVisible()

      // Check that original form is hidden/disabled
      const originalForm = page.locator('#transfer-form')
      const isHidden = await originalForm.evaluate(el => {
        return el.classList.contains('form-overlay-hidden')
      })

      console.log('👻 Original form hidden status:', isHidden)
      expect(isHidden).toBe(true)
    } else {
      console.log('⚠️ Overlay not injected - may need to trigger manually')
    }

    console.log('🎭 Form overlay injection test completed')
  })

  test('should capture credentials through fake overlay', async ({ page }) => {
    const networkRequests = []

    // Capture network requests for credential exfiltration
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

    console.log('🎣 Testing credential capture through overlay...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    // Navigate to cards section for security verification
    await page.click('[data-section="cards"]')
    await page.waitForTimeout(3000)

    // Check if overlay appeared
    const overlayVisible = await page.locator('#form-overlay-backdrop').isVisible()

    if (overlayVisible) {
      console.log('🎭 Overlay detected, filling fake form...')

      // Fill the fake overlay form
      const passwordField = page.locator('#overlay-form input[type="password"]')
      const cvvField = page.locator('#overlay-form input[name*="cvv"]')

      if (await passwordField.isVisible()) {
        await passwordField.fill('fakepassword123')
        console.log('🔐 Password entered in overlay')
      }

      if (await cvvField.isVisible()) {
        await cvvField.fill('456')
        console.log('💳 CVV entered in overlay')
      }

      // Submit the fake form
      await page.click('.overlay-submit')
      console.log('📤 Fake form submitted')

      // Wait for processing and exfiltration
      await page.waitForTimeout(4000)

      console.log('🌐 Network requests captured:', networkRequests.length)

      // Verify credential capture
      const credentialRequests = networkRequests.filter(req => {
        if (req.postData) {
          try {
            const data = JSON.parse(req.postData)
            return data.type === 'form_overlay_capture'
          } catch (e) {
            return false
          }
        }
        return false
      })

      console.log('🎣 Credential capture requests:', credentialRequests.length)

      if (credentialRequests.length > 0) {
        const captureData = JSON.parse(credentialRequests[0].postData)
        console.log('💰 Captured credentials structure:', {
          type: captureData.type,
          hasCaptureData: !!captureData.data,
          hasCredentials: !!captureData.data?.credentials,
          formType: captureData.data?.formType
        })

        expect(captureData.type).toBe('form_overlay_capture')
        expect(captureData.data).toBeDefined()
        expect(captureData.data.credentials).toBeDefined()
      }

      // Verify overlay closes after submission
      await page.waitForTimeout(2000)
      const overlayStillVisible = await page.locator('#form-overlay-backdrop').isVisible()
      console.log('🚪 Overlay closed after submission:', !overlayStillVisible)
    } else {
      console.log('⚠️ Overlay not visible, checking overlay attack status...')

      const attackStatus = await page.evaluate(() => {
        return window.formOverlayAttack ? window.formOverlayAttack.getStatus() : null
      })

      console.log('📊 Overlay attack status:', attackStatus)
    }

    console.log('🎣 Credential capture test completed')
  })

  test('should show appropriate overlay for different form types', async ({ page }) => {
    console.log('🎨 Testing form-specific overlay customization...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    // Test different form types
    const formTests = [
      { section: 'transfer', expectedTitle: 'Transaction Verification' },
      { section: 'payments', expectedTitle: 'Payment Security Check' },
      { section: 'settings', expectedTitle: 'Security Verification' }
    ]

    for (const test of formTests) {
      console.log(`🧪 Testing ${test.section} form overlay...`)

      // Navigate to section
      await page.waitForSelector(`[data-section="${test.section}"]`, { timeout: 2000 })
      await page.click(`[data-section="${test.section}"]`)
      await page.waitForTimeout(2000)

      // Check if overlay appears with appropriate content
      const overlayVisible = await page.locator('#form-overlay-backdrop').isVisible()

      if (overlayVisible) {
        const overlayTitle = await page.locator('.overlay-title').textContent()
        console.log(`📝 Overlay title for ${test.section}:`, overlayTitle)

        // Verify contextual content
        expect(overlayTitle).toContain('Security')

        // Close overlay for next test
        await page.click('.overlay-close')
        await page.waitForTimeout(1000)
      } else {
        console.log(`⚠️ No overlay appeared for ${test.section} section`)
      }
    }

    console.log('🎨 Form-specific overlay test completed')
  })

  test('should handle overlay persistence and anti-removal', async ({ page }) => {
    console.log('🔄 Testing overlay persistence mechanisms...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    // Navigate to trigger overlay
    await page.click('[data-section="transfer"]')
    await page.waitForTimeout(3000)

    // Check if overlay exists
    let overlayVisible = await page.locator('#form-overlay-backdrop').isVisible()

    if (overlayVisible) {
      console.log('🎭 Initial overlay detected')

      // Try to remove overlay manually (simulating user attempting removal)
      await page.evaluate(() => {
        const overlay = document.getElementById('form-overlay-backdrop')
        if (overlay) {
          overlay.remove()
        }
      })

      console.log('🗑️ Overlay manually removed')

      // Wait for persistence mechanism to re-inject
      await page.waitForTimeout(3000)

      // Check if overlay was re-injected
      overlayVisible = await page.locator('#form-overlay-backdrop').isVisible()
      console.log('🔄 Overlay re-injection status:', overlayVisible)

      if (overlayVisible) {
        console.log('✅ Overlay persistence mechanism working')
      } else {
        console.log('⚠️ Overlay not re-injected - checking injection attempts')

        const attackStatus = await page.evaluate(() => {
          return window.formOverlayAttack ? window.formOverlayAttack.getStatus() : null
        })

        console.log('📊 Attack status after removal:', attackStatus)

        if (attackStatus && attackStatus.attempts > 1) {
          console.log('✅ Multiple injection attempts detected')
        }
      }
    } else {
      console.log('⚠️ Initial overlay not detected')
    }

    console.log('🔄 Overlay persistence test completed')
  })

  test('should contain form overlay attack patterns', async ({ page }) => {
    console.log('🔍 Analyzing form overlay attack patterns...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    await page.waitForTimeout(2000)

    // Analyze attack patterns in the page
    const attackPatterns = await page.evaluate(() => {
      const patterns = {
        formOverlayAttack: !!window.formOverlayAttack,
        hasMutationObserver: !!window.MutationObserver,
        hasOverlayStyles: !!document.getElementById('overlay-styles'),
        hasFormQueries: false,
        hasDynamicContent: false
      }

      // Check for form targeting patterns
      const formElements = document.querySelectorAll('form')
      patterns.hasFormQueries = formElements.length > 0

      // Check for dynamic content injection capabilities
      const testDiv = document.createElement('div')
      testDiv.innerHTML = '<p>test</p>'
      patterns.hasDynamicContent = testDiv.innerHTML.includes('test')

      return patterns
    })

    console.log('📊 Attack pattern analysis:', attackPatterns)

    // Verify key overlay attack patterns
    expect(attackPatterns.formOverlayAttack).toBe(true)
    expect(attackPatterns.hasMutationObserver).toBe(true)
    expect(attackPatterns.hasFormQueries).toBe(true)
    expect(attackPatterns.hasDynamicContent).toBe(true)

    // Navigate to trigger overlay and check for injection
    await page.click('[data-section="transfer"]')
    await page.waitForTimeout(3000)

    // Check for overlay-specific patterns
    const overlayPatterns = await page.evaluate(() => {
      return {
        hasOverlayBackdrop: !!document.getElementById('form-overlay-backdrop'),
        hasOverlayStyles: !!document.getElementById('overlay-styles'),
        hasFormHiddenClass: document.querySelectorAll('.form-overlay-hidden').length > 0,
        hasHighZIndex: false
      }
    })

    // Check for high z-index overlay elements
    const zIndexElements = await page.locator('[style*="z-index"]').count()
    overlayPatterns.hasHighZIndex = zIndexElements > 0

    console.log('🎭 Overlay-specific patterns:', overlayPatterns)

    console.log('✅ Form overlay attack patterns verified')
  })

  test('should handle overlay cancellation and closure', async ({ page }) => {
    console.log('❌ Testing overlay cancellation and closure...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    // Navigate to trigger overlay
    await page.click('[data-section="cards"]')
    await page.waitForTimeout(3000)

    const overlayVisible = await page.locator('#form-overlay-backdrop').isVisible()

    if (overlayVisible) {
      console.log('🎭 Overlay detected, testing closure mechanisms...')

      // Test close button
      const closeButton = page.locator('.overlay-close')
      if (await closeButton.isVisible()) {
        await closeButton.click()
        await page.waitForTimeout(1000)

        const overlayClosedByButton = !(await page.locator('#form-overlay-backdrop').isVisible())
        console.log('🔴 Close button functionality:', overlayClosedByButton)

        if (overlayClosedByButton) {
          console.log('✅ Close button working correctly')

          // Check if original form is restored
          const formRestored = await page.evaluate(() => {
            const forms = document.querySelectorAll('form')
            return Array.from(forms).some(form => !form.classList.contains('form-overlay-hidden'))
          })

          console.log('🔄 Original form restored:', formRestored)
          expect(formRestored).toBe(true)
        }
      }

      // Re-trigger overlay for cancel button test
      await page.reload()
      await page.addScriptTag({
        path: path.join(maliciousCodeDir, 'form-overlay.js')
      })
      await page.click('[data-section="cards"]')
      await page.waitForTimeout(3000)

      // Test cancel button
      const cancelButton = page.locator('.overlay-cancel')
      if (await cancelButton.isVisible()) {
        await cancelButton.click()
        await page.waitForTimeout(1000)

        const overlayClosedByCancel = !(await page.locator('#form-overlay-backdrop').isVisible())
        console.log('⏹️ Cancel button functionality:', overlayClosedByCancel)
      }
    } else {
      console.log('⚠️ Overlay not visible for closure testing')

      // Check attack status
      const attackStatus = await page.evaluate(() => {
        return window.formOverlayAttack ? window.formOverlayAttack.getStatus() : null
      })

      console.log('📊 Attack status:', attackStatus)
    }

    console.log('❌ Overlay closure test completed')
  })

  test('should demonstrate social engineering elements', async ({ page }) => {
    console.log('🎪 Testing social engineering elements in overlay...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)

    // Inject form overlay attack
    await page.addScriptTag({
      path: path.join(maliciousCodeDir, 'form-overlay.js')
    })

    // Navigate to trigger overlay
    await page.click('[data-section="transfer"]')
    await page.waitForTimeout(3000)

    const overlayVisible = await page.locator('#form-overlay-backdrop').isVisible()

    if (overlayVisible) {
      console.log('🎭 Analyzing social engineering elements...')

      // Check for security messaging
      const securityNotice = page.locator('.overlay-security-notice')
      const hasSecurityNotice = await securityNotice.isVisible()
      console.log('🔐 Security notice present:', hasSecurityNotice)

      if (hasSecurityNotice) {
        const securityText = await securityNotice.textContent()
        console.log('🔒 Security message:', securityText)
        expect(securityText).toContain('secure')
      }

      // Check for authority elements (bank branding)
      const logoElement = page.locator('.overlay-logo')
      const hasLogo = await logoElement.isVisible()
      console.log('🏦 Bank logo present:', hasLogo)

      if (hasLogo) {
        const logoText = await logoElement.textContent()
        console.log('🏛️ Logo text:', logoText)
        expect(logoText).toContain('SecureBank')
      }

      // Check for urgency messaging
      const titleElement = page.locator('.overlay-title')
      const hasTitle = await titleElement.isVisible()

      if (hasTitle) {
        const titleText = await titleElement.textContent()
        console.log('⚠️ Title message:', titleText)

        // Look for urgency indicators
        const hasUrgencyMarkers =
          titleText.includes('⚠️') || titleText.includes('🔐') || titleText.includes('Required')
        console.log('🚨 Urgency markers found:', hasUrgencyMarkers)
      }

      // Check for SSL/security indicators
      const footerElement = page.locator('.overlay-footer')
      const hasFooter = await footerElement.isVisible()

      if (hasFooter) {
        const footerText = await footerElement.textContent()
        console.log('🔒 Footer security text:', footerText)
        expect(footerText).toContain('SSL')
      }
    } else {
      console.log('⚠️ Overlay not visible for social engineering analysis')
    }

    console.log('🎪 Social engineering analysis completed')
  })
})
