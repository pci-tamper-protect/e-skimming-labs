// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../../test/config/test-env.js')
const { getC2ApiEndpoint, getC2CollectEndpoint, currentEnv, TEST_ENV } = require(testEnvPath)

// Get C2 endpoints for lab 1
const c2ApiUrl = getC2ApiEndpoint(1)
const c2CollectUrl = getC2CollectEndpoint(1)

console.log(`🧪 Test environment: ${TEST_ENV}`)
console.log(`📍 C2 API URL: ${c2ApiUrl}`)
console.log(`📍 C2 Collect URL: ${c2CollectUrl}`)

test.describe('Lab 1: Basic Magecart - Checkout Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture skimmer logs
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        console.log('🔍 SKIMMER LOG:', msg.text())
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

  test('should complete checkout and trigger skimmer', async ({ page }) => {
    console.log('🚀 Starting checkout test...')

    // Navigate to main page
    await page.goto('/')
    await expect(page).toHaveTitle(/TechGear Store/)

    // Click on a "Buy Now" button to go to checkout
    await page.click('text=Buy Now')
    await expect(page).toHaveURL(/checkout/)

    // Verify we're on checkout page
    await expect(page.locator('h2')).toContainText('Secure Checkout')

    // Fill out the form with test data
    console.log('📝 Filling out checkout form...')

    // Payment Information
    await page.fill('#card-number', '4000000000000002')
    await page.fill('#expiry', '12/28')
    await page.fill('#cvv', '123')

    console.log('✅ Form filled, submitting...')

    // Submit the form
    await page.click('button[type="submit"]')

    // Wait for success message
    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('#success-message')).toContainText('Order Placed Successfully')

    console.log('✅ Form submitted successfully')

    // Wait for skimmer to process and exfiltrate data
    // Poll for data to appear in C2 server (with retries)
    console.log('🔍 Waiting for data to be exfiltrated to C2 server...')
    let testRecord = null
    const maxRetries = 10
    const retryDelay = 1000 // 1 second

    for (let i = 0; i < maxRetries; i++) {
      await page.waitForTimeout(retryDelay)

      const c2Response = await page.request.get(c2ApiUrl)
      if (!c2Response.ok()) {
        console.log(`⏳ Attempt ${i + 1}/${maxRetries}: C2 server not responding yet...`)
        continue
      }

      const stolenData = await c2Response.json()
      console.log(`📊 Attempt ${i + 1}/${maxRetries}: Found ${stolenData.length} stolen data records`)

      // Normalize card number comparison (remove spaces, dashes, etc.)
      const normalizeCardNumber = (card) => {
        if (!card) return ''
        return card.replace(/[\s-]/g, '')
      }

      const testCardNumber = '4000000000000002'
      testRecord = stolenData.find(record => {
        if (!record.cardNumber) return false
        const normalized = normalizeCardNumber(record.cardNumber)
        return normalized === testCardNumber || normalized.includes(testCardNumber)
      })

      if (testRecord) {
        console.log('✅ Test credit card data found in C2 server!')
        break
      }

      // Log what card numbers we found for debugging
      if (stolenData.length > 0) {
        const foundCards = stolenData
          .map(r => r.cardNumber ? normalizeCardNumber(r.cardNumber) : 'N/A')
          .slice(0, 5)
        console.log(`📋 Sample card numbers found: ${foundCards.join(', ')}`)
      }
    }

    expect(testRecord).toBeTruthy()
    if (testRecord) {
      console.log('✅ Test credit card data verified:', {
        cardNumber: testRecord.cardNumber,
        cvv: testRecord.cvv ? '***' : 'N/A',
        expiry: testRecord.expiry
      })
    } else {
      console.error('❌ Test credit card data NOT found after', maxRetries, 'attempts')
      // Get final state for debugging
      const c2Response = await page.request.get(c2ApiUrl)
      if (c2Response.ok()) {
        const stolenData = await c2Response.json()
        console.error('📊 Final stolen data records:', JSON.stringify(stolenData.slice(0, 3), null, 2))
      }
    }

    console.log('🔍 Test completed - data successfully exfiltrated to C2 server')
  })

  test('should capture console logs from skimmer', async ({ page }) => {
    const consoleMessages = []

    page.on('console', msg => {
      consoleMessages.push(msg.text())
    })

    // Navigate and submit form
    await page.goto('/checkout.html')

    // Wait for checkout form to be visible
    await expect(page.locator('#payment-form')).toBeVisible()
    await expect(page.locator('h2')).toContainText('Secure Checkout')

    // Wait for form fields to be visible before filling
    await expect(page.locator('#card-number')).toBeVisible()
    await expect(page.locator('#expiry')).toBeVisible()
    await expect(page.locator('#cvv')).toBeVisible()

    // Fill minimal required fields
    await page.fill('#card-number', '4000000000000002')
    await page.fill('#expiry', '06/29')
    await page.fill('#cvv', '456')

    // Submit form
    await page.click('button[type="submit"]')

    // Wait for processing
    await page.waitForTimeout(3000)

    // Check that skimmer logs were captured
    const skimmerLogs = consoleMessages.filter(msg => msg.includes('[SKIMMER]'))
    console.log('📊 Captured skimmer logs:', skimmerLogs.length)

    skimmerLogs.forEach(log => {
      console.log('🔍', log)
    })

    // Verify skimmer was active
    expect(skimmerLogs.length).toBeGreaterThan(0)
  })

  test('should make network request to C2 server', async ({ page }) => {
    const networkRequests = []
    const networkResponses = []

    // Set up listeners before navigation
    page.on('request', request => {
      if (request.url().includes('/collect')) {
        networkRequests.push({
          url: request.url(),
          method: request.method(),
          postData: request.postData(),
          headers: request.headers()
        })
      }
    })

    page.on('response', response => {
      if (response.url().includes('/collect')) {
        networkResponses.push({
          url: response.url(),
          status: response.status(),
          statusText: response.statusText()
        })
      }
    })

    // Navigate and submit
    await page.goto('/checkout.html')

    // Wait for checkout form to be visible
    await expect(page.locator('#payment-form')).toBeVisible()
    await expect(page.locator('h2')).toContainText('Secure Checkout')

    // Wait for form fields to be visible before filling
    await expect(page.locator('#card-number')).toBeVisible()
    await expect(page.locator('#expiry')).toBeVisible()
    await expect(page.locator('#cvv')).toBeVisible()

    await page.fill('#card-number', '5555555555554444')
    await page.fill('#expiry', '03/27')
    await page.fill('#cvv', '789')

    // Wait for the network request/response after form submission
    // The skimmer uses setTimeout with CONFIG.delay, so we wait for the actual request
    const responsePromise = page.waitForResponse(
      response => response.url().includes('/collect'),
      { timeout: 10000 }
    ).catch(() => null)

    await page.click('button[type="submit"]')

    // Wait for the response to ensure the request was actually sent
    const response = await responsePromise
    if (response) {
      console.log('✅ Network response received:', response.status())
    } else {
      console.warn('⚠️ No response received, but checking captured requests...')
    }

    console.log('🌐 Network requests captured:', networkRequests.length)

    networkRequests.forEach(req => {
      console.log('📡 Request:', {
        url: req.url,
        method: req.method,
        hasPostData: !!req.postData,
        postDataLength: req.postData ? req.postData.length : 0
      })
    })

    // Verify network request was made
    expect(networkRequests.length).toBeGreaterThan(0)

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')

    // Poll for data to appear in C2 server (with retries)
    let testRecord = null
    const maxRetries = 10
    const retryDelay = 1000 // 1 second

    for (let i = 0; i < maxRetries; i++) {
      await page.waitForTimeout(retryDelay)

      const c2Response = await page.request.get(c2ApiUrl)
      if (!c2Response.ok()) {
        console.log(`⏳ Attempt ${i + 1}/${maxRetries}: C2 server not responding yet...`)
        continue
      }

      const stolenData = await c2Response.json()

      // Normalize card number comparison (remove spaces, dashes, etc.)
      const normalizeCardNumber = (card) => {
        if (!card) return ''
        return card.replace(/[\s-]/g, '')
      }

      const testCardNumber = '5555555555554444'
      testRecord = stolenData.find(record => {
        if (!record.cardNumber) return false
        const normalized = normalizeCardNumber(record.cardNumber)
        return normalized === testCardNumber || normalized.includes(testCardNumber)
      })

      if (testRecord) {
        console.log('✅ Network test data found in C2 server!')
        break
      }
    }

    expect(testRecord).toBeTruthy()
    if (testRecord) {
      console.log('✅ Network test data verified:', {
        cardNumber: testRecord.cardNumber,
        cvv: testRecord.cvv ? '***' : 'N/A',
        expiry: testRecord.expiry
      })
    } else {
      console.error('❌ Network test data NOT found after', maxRetries, 'attempts')
    }
  })

  test('should navigate to writeup page and back to lab', async ({ page }) => {
    console.log('📖 Testing writeup navigation...')

    // Navigate to lab 1 main page
    const lab1Url = currentEnv.lab1.vulnerable
    await page.goto(lab1Url)
    await page.waitForLoadState('networkidle')

    // Verify we're on the lab page
    await expect(page).toHaveTitle(/TechGear Store/)
    console.log('✅ On Lab 1 page')

    // Find and click the writeup button
    const writeupButton = page.getByRole('link', { name: /Writeup|📖/i })
    await expect(writeupButton).toBeVisible()
    console.log('✅ Writeup button found')

    // Click writeup button (opens in new tab)
    const [writeupPage] = await Promise.all([
      page.context().waitForEvent('page'),
      writeupButton.click()
    ])

    await writeupPage.waitForLoadState('networkidle')

    // Verify we're on the writeup page
    const expectedWriteupUrl = currentEnv.lab1.writeup
    await expect(writeupPage).toHaveURL(new RegExp(expectedWriteupUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    await expect(writeupPage).toHaveTitle(/Lab Writeup|01-basic-magecart/i)
    console.log('✅ On writeup page')

    // Find and click "Back to Lab" button
    const backToLabButton = writeupPage.getByRole('link', { name: /Back to Lab/i })
    await expect(backToLabButton).toBeVisible()
    console.log('✅ Back to Lab button found')

    await backToLabButton.click()
    await writeupPage.waitForLoadState('networkidle')

    // Verify we're back on the lab page
    await expect(writeupPage).toHaveURL(new RegExp(lab1Url.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    await expect(writeupPage).toHaveTitle(/TechGear Store/)
    console.log('✅ Back on Lab 1 page')

    await writeupPage.close()
  })
})
