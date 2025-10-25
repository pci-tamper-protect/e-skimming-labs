// @ts-check
const { test, expect } = require('@playwright/test')

test.describe('E-Skimming Lab - Checkout Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture skimmer logs
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        console.log('🔍 SKIMMER LOG:', msg.text())
      }
    })

    // Capture network requests to C2 server
    page.on('request', request => {
      if (request.url().includes('localhost:9002/collect')) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          headers: request.headers(),
          postData: request.postData()
        })
      }
    })

    page.on('response', response => {
      if (response.url().includes('localhost:9002/collect')) {
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
    await page.fill('#cardholder-name', 'John Doe Test')
    await page.fill('#expiry', '12/28')
    await page.fill('#cvv', '123')

    // Billing Information
    await page.fill('#email', 'john.doe@example.com')
    await page.fill('#billing-address', '123 Test Street')
    await page.fill('#city', 'Test City')
    await page.fill('#zip', '12345')
    await page.selectOption('#country', 'US')
    await page.fill('#phone', '+1 (555) 123-4567')

    console.log('✅ Form filled, submitting...')

    // Submit the form
    await page.click('button[type="submit"]')

    // Wait for success message
    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('#success-message')).toContainText('Order Placed Successfully')

    console.log('✅ Form submitted successfully')

    // Wait a bit for skimmer to process
    await page.waitForTimeout(2000)

    console.log('🔍 Test completed - check logs above for skimmer activity')
  })

  test('should capture console logs from skimmer', async ({ page }) => {
    const consoleMessages = []

    page.on('console', msg => {
      consoleMessages.push(msg.text())
    })

    // Navigate and submit form
    await page.goto('/checkout.html')

    // Fill minimal required fields
    await page.fill('#card-number', '4000000000000002')
    await page.fill('#cardholder-name', 'Test User')
    await page.fill('#expiry', '06/29')
    await page.fill('#cvv', '456')
    await page.fill('#email', 'test@example.com')
    await page.fill('#billing-address', '456 Test Ave')
    await page.fill('#city', 'Test Town')
    await page.fill('#zip', '67890')

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

    // Navigate and submit
    await page.goto('/checkout.html')

    await page.fill('#card-number', '5555555555554444')
    await page.fill('#cardholder-name', 'Network Test')
    await page.fill('#expiry', '03/27')
    await page.fill('#cvv', '789')
    await page.fill('#email', 'network@test.com')
    await page.fill('#billing-address', '789 Network St')
    await page.fill('#city', 'Network City')
    await page.fill('#zip', '54321')

    await page.click('button[type="submit"]')
    await page.waitForTimeout(3000)

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
  })
})
