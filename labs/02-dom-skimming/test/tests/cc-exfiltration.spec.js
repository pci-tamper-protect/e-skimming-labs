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

    // totalRequests is incremented for every non-noisy event (e.g. form_submission)
    expect(stats.totalRequests).toBeGreaterThan(0)
    console.log('✅ Attack recorded in C2 server (totalRequests:', stats.totalRequests, ')')

    // Verify stolen data is in the api/stolen endpoint
    const stolenResponse = await page.request.get(`${lab2C2Url}/api/stolen`)
    expect(stolenResponse.ok()).toBeTruthy()
    const stolenData = await stolenResponse.json()
    console.log('📊 Stolen data records:', stolenData.length)
    expect(stolenData.length).toBeGreaterThan(0)

    // Navigate to C2 dashboard and verify captured card data is displayed
    console.log('🔍 Navigating to C2 dashboard to verify card display...')
    await page.goto(lab2C2Url)
    await page.waitForLoadState('networkidle')

    // C2 dashboard should show the lab 2 header, not the lab page
    await expect(page.locator('h1')).toContainText('LAB 2')
    console.log('✅ C2 dashboard loaded correctly')

    // Check that at least one captured card entry is displayed
    const captureEntries = page.locator('div:has(h3:has-text("FORM SUBMIT"))')
    const count = await captureEntries.count()
    expect(count).toBeGreaterThan(0)
    console.log('✅ Captured card data visible on C2 dashboard (entries:', count, ')')

    console.log('🔍 Credit card exfiltration test completed')
  })
})



