#!/usr/bin/env node

/**
 * MANUAL TEST SCRIPT FOR LAB 2
 *
 * This script demonstrates the DOM-based skimming attacks
 * by injecting them into a browser automation context.
 */

const puppeteer = require('puppeteer')
const fs = require('fs').promises
const path = require('path')

async function testLab2() {
  console.log('🧪 Starting Lab 2: DOM-Based Skimming Manual Test')
  console.log('═'.repeat(60))

  const browser = await puppeteer.launch({
    headless: false,
    defaultViewport: { width: 1280, height: 800 }
  })

  const page = await browser.newPage()

  // Monitor network requests
  let requests = []
  page.on('request', request => {
    if (request.url().includes('localhost:3001') || request.url().includes('collect')) {
      requests.push({
        url: request.url(),
        method: request.method(),
        timestamp: Date.now()
      })
      console.log(`📡 Network Request: ${request.method()} ${request.url()}`)
    }
  })

  // Monitor console logs
  page.on('console', msg => {
    if (
      msg.text().includes('[DOM-Monitor]') ||
      msg.text().includes('[Form-Overlay]') ||
      msg.text().includes('[Shadow-Skimmer]')
    ) {
      console.log(`🕵️  Attack Log: ${msg.text()}`)
    }
  })

  try {
    // Load the banking page
    console.log('\n📱 Loading vulnerable banking site...')
    await page.goto('http://localhost:8080/banking.html')
    await page.waitForTimeout(2000)

    // Test DOM Monitor Attack
    console.log('\n🔍 Testing DOM Monitor Attack...')

    // Update the port in the attack script to match our server
    const domMonitorCode = (
      await fs.readFile(path.join(__dirname, 'malicious-code/dom-monitor.js'), 'utf8')
    ).replace('http://localhost:9004/collect', 'http://localhost:9004/collect')

    // Inject the attack script
    await page.evaluate(domMonitorCode)
    await page.waitForTimeout(3000)

    console.log('\n💳 Simulating user form interaction...')

    // Switch to transfer section and fill form
    await page.click('[data-section="transfer"]')
    await page.waitForTimeout(1000)

    // Fill transfer form fields
    await page.selectOption('#from-account', 'checking')
    await page.fill('#to-account', '555666777')
    await page.fill('#amount', '1000')
    await page.fill('#transfer-password', 'MySecretPassword123!')

    console.log('✅ Transfer form filled')
    await page.waitForTimeout(2000)

    // Switch to payment section and fill form
    await page.click('[data-section="payment"]')
    await page.waitForTimeout(1000)

    await page.fill('#payment-account', '888999111')
    await page.fill('#payment-amount', '500')
    await page.fill('#payment-password', 'AnotherPassword456!')

    console.log('✅ Payment form filled')
    await page.waitForTimeout(2000)

    // Test Form Overlay Attack
    console.log('\n🎭 Testing Form Overlay Attack...')

    const formOverlayCode = (
      await fs.readFile(path.join(__dirname, 'malicious-code/form-overlay.js'), 'utf8')
    ).replace('http://localhost:9004/collect', 'http://localhost:9004/collect')

    await page.evaluate(formOverlayCode)
    await page.waitForTimeout(3000)

    // Test Shadow DOM Attack
    console.log('\n👻 Testing Shadow DOM Attack...')

    const shadowSkimmerCode = (
      await fs.readFile(path.join(__dirname, 'malicious-code/shadow-skimmer.js'), 'utf8')
    ).replace('http://localhost:9004/collect', 'http://localhost:9004/collect')

    await page.evaluate(shadowSkimmerCode)
    await page.waitForTimeout(5000)

    // Check if data was captured
    console.log('\n📊 Test Results Summary:')
    console.log('─'.repeat(40))
    console.log(`Network Requests Captured: ${requests.length}`)

    if (requests.length > 0) {
      console.log('✅ Data exfiltration successful')
      requests.forEach((req, i) => {
        console.log(`  ${i + 1}. ${req.method} ${req.url}`)
      })
    } else {
      console.log('⚠️  No data exfiltration detected')
    }

    // Check C2 server stats
    console.log('\n📡 Checking C2 Server Status...')
    const response = await fetch('http://localhost:3001/stats')
    const stats = await response.json()

    console.log('📈 C2 Server Statistics:')
    console.log(`  Total Requests: ${stats.totalRequests}`)
    console.log(`  DOM Monitor Sessions: ${stats.domMonitorSessions}`)
    console.log(`  Form Overlay Captures: ${stats.formOverlayCaptues}`)
    console.log(`  Shadow DOM Captures: ${stats.shadowDomCaptures}`)
    console.log(`  Unique Victims: ${stats.uniqueVictims}`)

    console.log('\n✅ Lab 2 Manual Test Completed')
    console.log('   Keep browser open for manual inspection...')

    // Keep browser open for manual inspection
    await new Promise(resolve => {
      console.log('\n🔍 Browser will remain open for manual inspection.')
      console.log('   Press Ctrl+C to close when done.')
      process.on('SIGINT', () => {
        console.log('\n👋 Closing browser...')
        browser.close().then(resolve)
      })
    })
  } catch (error) {
    console.error('❌ Test failed:', error)
    await browser.close()
  }
}

// Run if called directly
if (require.main === module) {
  testLab2().catch(console.error)
}

module.exports = testLab2
