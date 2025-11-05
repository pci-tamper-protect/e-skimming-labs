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
    await page.waitForTimeout(3000)

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')
    const c2Response = await page.request.get('http://localhost:9002/api/stolen')
    expect(c2Response.ok()).toBeTruthy()
    
    const stolenData = await c2Response.json()
    console.log('📊 Stolen data records:', stolenData.length)
    
    // Verify our test data is in the stolen records
    const testRecord = stolenData.find(record => 
      record.cardNumber && record.cardNumber.includes('4000000000000002')
    )
    expect(testRecord).toBeTruthy()
    console.log('✅ Test credit card data found in C2 server:', testRecord ? 'Yes' : 'No')
    
    console.log('🔍 Test completed - data successfully exfiltrated to C2 server')
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
    await page.fill('#expiry', '03/27')
    await page.fill('#cvv', '789')

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

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')
    const c2Response = await page.request.get('http://localhost:9002/api/stolen')
    expect(c2Response.ok()).toBeTruthy()
    
    const stolenData = await c2Response.json()
    const testRecord = stolenData.find(record => 
      record.cardNumber && record.cardNumber.includes('5555555555554444')
    )
    expect(testRecord).toBeTruthy()
    console.log('✅ Network test data found in C2 server:', testRecord ? 'Yes' : 'No')
  })
})
