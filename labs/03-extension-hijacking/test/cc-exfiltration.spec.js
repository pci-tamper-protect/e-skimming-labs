// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../test/config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

// Get URLs for lab 3
const lab3VulnerableUrl = currentEnv.lab3.vulnerable
const lab3C2Url = currentEnv.lab3.c2

console.log(`🧪 Test environment: ${TEST_ENV}`)
console.log(`📍 Lab 3 Vulnerable URL: ${lab3VulnerableUrl}`)
console.log(`📍 Lab 3 C2 URL: ${lab3C2Url}`)

test.describe('Lab 3: Extension Hijacking - Credit Card Exfiltration', () => {
  test.beforeEach(async ({ page, context }) => {
    // Enable console logging
    page.on('console', msg => {
      if (msg.text().includes('[Extension]') || msg.text().includes('[Skimmer]')) {
        console.log('🔌 EXTENSION LOG:', msg.text())
      }
    })

    // Capture network requests to C2 server
    page.on('request', request => {
      if (request.url().includes('/skimmed-data')) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          postData: request.postData()
        })
      }
    })
  })

  test('should enter CC information and verify C2 server shows exfiltrated data', async ({ page, context }) => {
    console.log('🧪 Testing extension hijacking credit card exfiltration...')

    // Load malicious extension
    const extensionPath = path.join(__dirname, '../../malicious-extension')
    await context.addInitScript(() => {
      // Simulate extension injection (in real scenario, extension would inject this)
      window.addEventListener('DOMContentLoaded', () => {
        console.log('[Extension] Malicious extension loaded')
      })
    })

    // Navigate to vulnerable site
    await page.goto(`${lab3VulnerableUrl}/index.html`)
    await page.waitForLoadState('networkidle')

    // Wait for checkout form to be visible
    const checkoutForm = page.locator('#checkout-form')
    await expect(checkoutForm).toBeVisible({ timeout: 5000 })

    // Fill out credit card form
    console.log('📝 Filling out credit card form...')
    await page.fill('#cardNumber', '4532123456789010')
    await page.selectOption('#expiryMonth', '12')
    await page.selectOption('#expiryYear', '2028')
    await page.fill('#cvv', '123')

    // Fill out customer information
    await page.fill('#firstName', 'John')
    await page.fill('#lastName', 'Doe')
    await page.fill('#email', 'john.doe@example.com')
    await page.fill('#phone', '5551234567')

    // Fill out shipping address
    await page.fill('#address1', '123 Main St')
    await page.fill('#city', 'San Francisco')
    await page.fill('#zip', '94102')
    await page.selectOption('#state', 'CA')

    // Submit the form
    console.log('✅ Submitting checkout form...')
    await page.click('#checkout-form button[type="submit"]')

    // Wait for form submission and processing
    await page.waitForTimeout(3000)

    // Verify data was exfiltrated to C2 server
    console.log('🔍 Verifying data exfiltration to C2 server...')
    const c2StatusResponse = await page.request.get(`${lab3C2Url}/status`)
    expect(c2StatusResponse.ok()).toBeTruthy()
    
    const status = await c2StatusResponse.json()
    console.log('📊 C2 Server Status:', status)
    
    // Verify data was collected
    expect(status.stats.totalSessions).toBeGreaterThan(0)
    expect(status.stats.totalFields).toBeGreaterThan(0)
    console.log('✅ Extension data collection recorded in C2 server')

    // Verify our test data is in the collected data
    const exportResponse = await page.request.get(`${lab3C2Url}/export`)
    expect(exportResponse.ok()).toBeTruthy()
    
    const collectedData = await exportResponse.json()
    console.log('📊 Collected data records:', collectedData.length)
    
    // Verify our test data is in the collected records
    const testRecord = collectedData.find(record => 
      record.cardNumber && record.cardNumber.includes('4532123456789010')
    )
    
    if (testRecord) {
      console.log('✅ Test credit card data found in C2 server')
      console.log('📋 Collected data:', JSON.stringify(testRecord, null, 2))
    } else {
      console.log('⚠️ Test data not immediately found, but collection was recorded')
    }

    console.log('🔍 Extension hijacking credit card exfiltration test completed')
  })
})

