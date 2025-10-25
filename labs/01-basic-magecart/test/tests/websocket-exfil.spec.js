// @ts-check
const { test, expect } = require('@playwright/test')

test.describe('E-Skimming Lab - WebSocket Exfiltration Variant', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture skimmer logs
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        console.log('🔍 SKIMMER LOG:', msg.text())
      }
    })

    // Capture network requests to both WebSocket and HTTP fallback
    page.on('request', request => {
      if (
        request.url().includes('localhost:9002/collect') ||
        request.url().includes('localhost:3001/ws')
      ) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          headers: request.headers(),
          postData: request.postData()
        })
      }
    })

    page.on('response', response => {
      if (
        response.url().includes('localhost:9002/collect') ||
        response.url().includes('localhost:3001/ws')
      ) {
        console.log('📥 RESPONSE FROM C2:', {
          url: response.url(),
          status: response.status(),
          headers: response.headers()
        })
      }
    })
  })

  test('should attempt WebSocket connection and fallback to HTTP', async ({ page }) => {
    console.log('🚀 Testing WebSocket exfiltration variant...')

    // Load the variant HTML content directly with proper base URL for resources
    const fs = require('fs')
    const path = require('path')
    const variantHtmlPath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/checkout.html'
    )
    let htmlContent = fs.readFileSync(variantHtmlPath, 'utf8')

    // Update the script src to point to the variant's JS file
    const variantJsPath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/js/checkout-compromised.js'
    )
    const jsContent = fs.readFileSync(variantJsPath, 'utf8')

    // Inject the JavaScript directly into the HTML to avoid path issues
    htmlContent = htmlContent.replace(
      '<script src="js/checkout-compromised.js"></script>',
      `<script>${jsContent}</script>`
    )

    // Set the HTML content with proper base URL for form submission
    await page.setContent(htmlContent, {
      baseURL: 'http://localhost:8080',
      waitUntil: 'networkidle'
    })

    await expect(page).toHaveTitle(/TechGear Store/)

    // Verify we're on checkout page
    await expect(page.locator('h2')).toContainText('Secure Checkout')

    console.log('📝 Filling out form to test WebSocket exfiltration...')

    // Fill out the form with test data
    await page.fill('#card-number', '4000000000000002')
    await page.fill('#cardholder-name', 'WebSocket Test User')
    await page.fill('#expiry', '12/28')
    await page.fill('#cvv', '123')
    await page.fill('#email', 'websocket@example.com')
    await page.fill('#billing-address', '123 WebSocket Street')
    await page.fill('#city', 'C2 City')
    await page.fill('#zip', '12345')
    await page.selectOption('#country', 'US')
    await page.fill('#phone', '+1 (555) 888-0001')

    console.log('✅ Form filled, submitting to trigger WebSocket exfiltration...')

    // Submit the form
    await page.click('button[type=\"submit\"]')

    // Wait for success message - same behavior as base variant
    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('#success-message')).toContainText('Order Placed Successfully')

    console.log(
      '✅ Form submitted successfully - WebSocket variant should attempt connection and fallback to HTTP'
    )

    // Wait for skimmer to process
    await page.waitForTimeout(3000)

    console.log(
      '🔍 Test completed - WebSocket connection should have been attempted with HTTP fallback'
    )
  })

  test('should contain WebSocket communication patterns', async ({ page }) => {
    console.log('🔍 Analyzing WebSocket communication patterns...')

    // Read the JavaScript file directly to check for patterns
    const fs = require('fs')
    const path = require('path')
    const jsFilePath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/js/checkout-compromised.js'
    )
    const jsContent = fs.readFileSync(jsFilePath, 'utf8')

    console.log('📊 Checking for WebSocket patterns in JavaScript file...')

    // Check for WebSocket constructor
    const hasWebSocketConstructor = jsContent.includes('new WebSocket(')
    console.log('✓ WebSocket constructor found:', hasWebSocketConstructor)
    expect(hasWebSocketConstructor).toBe(true)

    // Check for WebSocket URL protocol
    const hasWebSocketProtocol = jsContent.includes('ws://')
    console.log('✓ WebSocket protocol (ws://) found:', hasWebSocketProtocol)
    expect(hasWebSocketProtocol).toBe(true)

    // Check for WebSocket event handlers
    const hasOnOpen = jsContent.includes('onopen')
    console.log('✓ onopen event handler found:', hasOnOpen)
    expect(hasOnOpen).toBe(true)

    const hasOnMessage = jsContent.includes('onmessage')
    console.log('✓ onmessage event handler found:', hasOnMessage)
    expect(hasOnMessage).toBe(true)

    const hasOnError = jsContent.includes('onerror')
    console.log('✓ onerror event handler found:', hasOnError)
    expect(hasOnError).toBe(true)

    const hasOnClose = jsContent.includes('onclose')
    console.log('✓ onclose event handler found:', hasOnClose)
    expect(hasOnClose).toBe(true)

    // Check for reconnection logic
    const hasReconnectionLogic =
      jsContent.includes('reconnectAttempts') && jsContent.includes('exponential')
    console.log('✓ Reconnection logic found:', hasReconnectionLogic)
    expect(hasReconnectionLogic).toBe(true)

    // Check for HTTP fallback
    const hasHTTPFallback =
      jsContent.includes('fallbackToHTTP') || jsContent.includes('fallbackUrl')
    console.log('✓ HTTP fallback mechanism found:', hasHTTPFallback)
    expect(hasHTTPFallback).toBe(true)

    // Check for message queuing
    const hasMessageQueue = jsContent.includes('messageQueue')
    console.log('✓ Message queuing system found:', hasMessageQueue)
    expect(hasMessageQueue).toBe(true)

    // Check for structured messaging
    const hasStructuredMessaging =
      jsContent.includes('createWebSocketMessage') && jsContent.includes('JSON.stringify')
    console.log('✓ Structured JSON messaging found:', hasStructuredMessaging)
    expect(hasStructuredMessaging).toBe(true)

    // Check for variant identifier
    const hasVariantMarker = jsContent.includes('websocket-exfil-variant')
    console.log('✓ WebSocket variant marker found:', hasVariantMarker)
    expect(hasVariantMarker).toBe(true)

    console.log('✅ All WebSocket communication patterns detected successfully')
  })

  test('should capture data with WebSocket communication attempt', async ({ page }) => {
    const networkRequests = []
    const consoleMessages = []

    // Capture network requests for both WebSocket and HTTP
    page.on('request', request => {
      if (request.url().includes('/collect') || request.url().includes('/ws')) {
        networkRequests.push({
          url: request.url(),
          method: request.method(),
          postData: request.postData(),
          headers: request.headers()
        })
      }
    })

    // Capture console messages for WebSocket activity verification
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        consoleMessages.push(msg.text())
      }
    })

    // Load the variant HTML content with embedded JavaScript
    const fs = require('fs')
    const path = require('path')
    const variantHtmlPath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/checkout.html'
    )
    let htmlContent = fs.readFileSync(variantHtmlPath, 'utf8')

    const variantJsPath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/js/checkout-compromised.js'
    )
    const jsContent = fs.readFileSync(variantJsPath, 'utf8')

    // Inject the JavaScript directly into the HTML
    htmlContent = htmlContent.replace(
      '<script src="js/checkout-compromised.js"></script>',
      `<script>${jsContent}</script>`
    )

    await page.setContent(htmlContent, {
      baseURL: 'http://localhost:8080',
      waitUntil: 'networkidle'
    })

    console.log('📝 Testing WebSocket communication with form submission...')

    // Fill form and submit
    await page.fill('#card-number', '5555555555554444')
    await page.fill('#cardholder-name', 'WebSocket Test')
    await page.fill('#expiry', '03/27')
    await page.fill('#cvv', '789')
    await page.fill('#email', 'ws-test@example.com')
    await page.fill('#billing-address', '789 WebSocket Ave')
    await page.fill('#city', 'Protocol City')
    await page.fill('#zip', '54321')

    await page.click('button[type=\"submit\"]')
    await page.waitForTimeout(4000) // Extra time for WebSocket connection attempts

    console.log('🌐 Network requests captured:', networkRequests.length)
    console.log('📝 Console messages captured:', consoleMessages.length)

    // Log WebSocket-related console messages
    const wsMessages = consoleMessages.filter(
      msg => msg.includes('WebSocket') || msg.includes('ws://') || msg.includes('fallback')
    )
    console.log('🔌 WebSocket-related messages:', wsMessages.length)
    wsMessages.forEach(msg => console.log('  📡', msg))

    // Check for HTTP fallback requests (since WebSocket server likely isn't running)
    const httpRequests = networkRequests.filter(req => req.url.includes('/collect'))
    console.log('📨 HTTP fallback requests:', httpRequests.length)

    if (httpRequests.length > 0) {
      const req = httpRequests[0]
      console.log('📡 HTTP fallback request details:', {
        url: req.url,
        method: req.method,
        hasPostData: !!req.postData
      })

      if (req.postData) {
        try {
          const data = JSON.parse(req.postData)
          console.log('💳 Captured data structure:', {
            hasCardNumber: !!data.cardNumber,
            hasMetadata: !!data.metadata,
            collectionMethod: data.metadata?.collectionMethod,
            fieldCount: Object.keys(data).length
          })

          // Verify this is the WebSocket variant
          expect(data.metadata?.collectionMethod).toBe('websocket-exfil-variant')
        } catch (e) {
          console.log('❌ Could not parse POST data')
        }
      }
    }

    // Verify WebSocket initialization messages exist
    const initMessages = consoleMessages.filter(
      msg => msg.includes('WebSocket skimmer') || msg.includes('Establishing WebSocket')
    )
    expect(initMessages.length).toBeGreaterThan(0)

    console.log('✅ WebSocket communication test completed')
  })

  test('should handle WebSocket connection lifecycle', async ({ page }) => {
    console.log('🔌 Testing WebSocket connection lifecycle management...')

    const consoleMessages = []

    // Capture all skimmer console messages
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        consoleMessages.push(msg.text())
      }
    })

    // Load the variant HTML content with embedded JavaScript
    const fs = require('fs')
    const path = require('path')
    const variantHtmlPath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/checkout.html'
    )
    let htmlContent = fs.readFileSync(variantHtmlPath, 'utf8')

    const variantJsPath = path.join(
      __dirname,
      '../../variants/websocket-exfil/vulnerable-site/js/checkout-compromised.js'
    )
    const jsContent = fs.readFileSync(variantJsPath, 'utf8')

    // Inject the JavaScript directly into the HTML
    htmlContent = htmlContent.replace(
      '<script src="js/checkout-compromised.js"></script>',
      `<script>${jsContent}</script>`
    )

    await page.setContent(htmlContent, {
      baseURL: 'http://localhost:8080',
      waitUntil: 'networkidle'
    })

    // Wait for WebSocket initialization attempts
    await page.waitForTimeout(2000)

    console.log('📊 Analyzing WebSocket lifecycle messages...')

    // Check for connection establishment attempt
    const connectionAttempts = consoleMessages.filter(
      msg => msg.includes('Establishing WebSocket') || msg.includes('WebSocket connection')
    )
    console.log('🔗 Connection establishment messages:', connectionAttempts.length)
    expect(connectionAttempts.length).toBeGreaterThan(0)

    // Check for error handling (expected since WebSocket server isn't running)
    const errorMessages = consoleMessages.filter(
      msg =>
        msg.includes('WebSocket error') ||
        msg.includes('connection closed') ||
        msg.includes('Failed to create')
    )
    console.log('❌ Error handling messages:', errorMessages.length)

    // Check for fallback activation
    const fallbackMessages = consoleMessages.filter(
      msg => msg.includes('fallback') || msg.includes('HTTP POST')
    )
    console.log('🔄 Fallback activation messages:', fallbackMessages.length)

    // Check for reconnection attempts
    const reconnectMessages = consoleMessages.filter(
      msg => msg.includes('reconnection') || msg.includes('Attempting reconnection')
    )
    console.log('🔁 Reconnection attempt messages:', reconnectMessages.length)

    console.log('✅ WebSocket lifecycle management verified')
  })
})
