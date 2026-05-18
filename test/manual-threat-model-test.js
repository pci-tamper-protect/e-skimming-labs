#!/usr/bin/env node

// Simple manual test for threat model back button
const { chromium } = require('playwright')
const { navLink } = require('./utils/nav')

async function testThreatModelBackButton() {
  console.log('🚀 Starting threat model back button test...')

  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  })

  try {
    const page = await browser.newPage()

    console.log('📱 Navigating to threat model page...')
    await page.goto('http://localhost:8080/threat-model')
    await page.waitForLoadState('networkidle')

    console.log('🔍 Looking for back button...')
    const backButton = navLink(page, 'labsHome')

    const isVisible = await backButton.isVisible()
    console.log('✅ Back button visible:', isVisible)

    if (isVisible) {
      const href = await backButton.getAttribute('href')
      console.log('🔗 Back button href:', href)

      console.log('👆 Clicking back button...')
      try {
        await backButton.click()
      } catch (error) {
        console.log('⚠️ Normal click failed, trying force click...')
        await backButton.click({ force: true })
      }

      await page.waitForLoadState('networkidle')

      const currentUrl = page.url()
      const pageTitle = await page.title()

      console.log('📍 Current URL:', currentUrl)
      console.log('📄 Page title:', pageTitle)

      const success = currentUrl === 'http://localhost:8080/'
      console.log(
        success ? '✅ SUCCESS: Back button works!' : '❌ FAILED: Back button did not navigate'
      )

      return success
    } else {
      console.log('❌ Back button not visible')
      return false
    }
  } finally {
    await browser.close()
    console.log('🧹 Browser closed')
  }
}

// Run the test
testThreatModelBackButton()
  .then(success => {
    process.exit(success ? 0 : 1)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
