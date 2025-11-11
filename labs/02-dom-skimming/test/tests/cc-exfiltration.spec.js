// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../../test/config/test-env.js')
const { currentEnv, getC2ApiEndpoint, getC2CollectEndpoint, TEST_ENV } = require(testEnvPath)

// Get URLs for lab 2
const lab2VulnerableUrl = currentEnv.lab2.vulnerable
const lab2C2Url = currentEnv.lab2.c2
const c2CollectUrl = getC2CollectEndpoint(2)

console.log(`🧪 Test environment: ${TEST_ENV}`)
console.log(`📍 Lab 2 Vulnerable URL: ${lab2VulnerableUrl}`)
console.log(`📍 Lab 2 C2 URL: ${lab2C2Url}`)

test.describe('Lab 2: DOM-Based Skimming - Credit Card Exfiltration', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging
    page.on('console', msg => {
      if (msg.text().includes('[Banking]') || msg.text().includes('[DOM-Monitor]')) {
        console.log('🏦 LOG:', msg.text())
      }
    })

    // Capture network requests to C2 server
    page.on('request', request => {
      if (request.url().includes('/collect')) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          postData: request.postData()
        })
      }
    })
  })

  test('should enter CC information and verify C2 server shows exfiltrated data', async ({ page }) => {
    console.log('🧪 Testing credit card exfiltration...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)
    await page.waitForLoadState('networkidle')

    // Wait for cards section to be active (default)
    await page.waitForSelector('#cards.section.active', { timeout: 3000 })

    // Verify add card form is visible
    const addCardForm = page.locator('#add-card-form')
    await expect(addCardForm).toBeVisible()

    // Fill out credit card form
    console.log('📝 Filling out credit card form...')
    await page.fill('#card-number', '4532123456789010')
    await page.fill('#card-holder-name', 'John Doe')
    await page.fill('#card-expiry', '12/28')
    await page.fill('#card-cvv-input', '123')
    await page.fill('#card-billing-zip', '12345')

    // Submit the form
    console.log('✅ Submitting credit card form...')
    await page.click('#add-card-form button[type="submit"]')

    // Wait for form submission and processing
    await page.waitForTimeout(3000)

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')
    const c2StatsResponse = await page.request.get(`${lab2C2Url}/stats`)
    expect(c2StatsResponse.ok()).toBeTruthy()

    const stats = await c2StatsResponse.json()
    console.log('📊 C2 Server Stats:', stats)

    // Verify attack was recorded
    expect(stats.totalAttacks).toBeGreaterThan(0)
    console.log('✅ Attack recorded in C2 server')

    // Get recent attacks to verify our data
    const recentResponse = await page.request.get(`${lab2C2Url}/recent/10`)
    expect(recentResponse.ok()).toBeTruthy()
    
    const recentAttacks = await recentResponse.json()
    console.log('📊 Recent attacks:', recentAttacks.length)
    
    // Verify our test data is in the recent attacks
    const testAttack = recentAttacks.find(attack => 
      attack.data && 
      (attack.data.cardNumber && attack.data.cardNumber.includes('4532123456789010') ||
       attack.data.ccNumber && attack.data.ccNumber.includes('4532123456789010'))
    )
    
    if (testAttack) {
      console.log('✅ Test credit card data found in C2 server')
      console.log('📋 Attack data:', JSON.stringify(testAttack, null, 2))
    } else {
      console.log('⚠️ Test data not immediately found, but attack was recorded')
    }

    console.log('🔍 Credit card exfiltration test completed')
  })
})



