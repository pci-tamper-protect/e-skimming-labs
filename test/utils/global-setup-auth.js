/**
 * Global Setup for Playwright Tests - Authentication
 *
 * Authenticates once for staging tests and saves auth state to be reused across all tests.
 * This prevents the need to authenticate in every test, improving performance and reliability.
 *
 * Only runs when:
 * - TEST_ENV === 'stg'
 * - AUTH_ENABLED === 'true'
 * - TEST_USER_EMAIL_STG and TEST_USER_PASSWORD_STG are provided
 */

const { chromium } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('../config/test-env')
const path = require('path')
const fs = require('fs')

const STORAGE_STATE_PATH = path.join(__dirname, '../.auth/storage-state.json')

module.exports = async () => {
  // Only run for staging environment
  if (TEST_ENV !== 'stg') {
    console.log('⏭️  Skipping auth setup: not staging environment')
    return
  }

  // Check if auth is enabled
  if (process.env.AUTH_ENABLED !== 'true') {
    console.log('⏭️  Skipping auth setup: AUTH_ENABLED is not true')
    return
  }

  // Check if test credentials are provided
  const testEmail = process.env.TEST_USER_EMAIL_STG
  const testPassword = process.env.TEST_USER_PASSWORD_STG

  if (!testEmail || !testPassword) {
    console.log('⏭️  Skipping auth setup: TEST_USER_EMAIL_STG or TEST_USER_PASSWORD_STG not provided')
    return
  }

  console.log('🔐 Starting authentication setup for staging tests...')
  console.log(`📧 Test account: ${testEmail}`)

  // Create .auth directory if it doesn't exist
  const authDir = path.dirname(STORAGE_STATE_PATH)
  if (!fs.existsSync(authDir)) {
    fs.mkdirSync(authDir, { recursive: true })
  }

  // Launch browser
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  })

  const context = await browser.newContext()
  const page = await context.newPage()

  try {
    // Step 1: Sign in to main app (stg.pcioasis.com)
    console.log(`🔗 Signing in to ${currentEnv.mainApp}/sign-in`)
    await page.goto(`${currentEnv.mainApp}/sign-in`, { waitUntil: 'networkidle', timeout: 30000 })

    // Fill in credentials
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', testPassword)
    await page.click('button[type="submit"]')

    // Wait for sign-in to complete
    await page.waitForURL(
      new RegExp(`${currentEnv.mainApp}/dashboard|${currentEnv.mainApp}/`),
      { timeout: 30000 }
    )

    console.log('✅ Signed in to main app')

    // Step 2: Get Firebase token from localStorage
    const token = await page.evaluate(() => {
      return localStorage.getItem('accessToken')
    })

    if (!token) {
      throw new Error('Failed to get access token from localStorage after sign-in')
    }

    console.log('✅ Retrieved Firebase access token')

    // Step 3: Navigate to labs with token to establish auth state
    console.log(`🔗 Establishing auth state at ${currentEnv.homeIndex}`)
    await page.goto(`${currentEnv.homeIndex}?token=${token}`, {
      waitUntil: 'networkidle',
      timeout: 30000
    })

    // Verify we're authenticated (not redirected to sign-in)
    const currentUrl = page.url()
    if (currentUrl.includes('/sign-in')) {
      throw new Error('Failed to authenticate: redirected to sign-in page')
    }

    // Verify token is stored in sessionStorage
    const storedToken = await page.evaluate(() => {
      return sessionStorage.getItem('firebase_token')
    })

    if (storedToken !== token) {
      throw new Error('Token not properly stored in sessionStorage')
    }

    console.log('✅ Auth state established on labs domain')

    // Step 4: Save storage state (cookies, localStorage, sessionStorage)
    await context.storageState({ path: STORAGE_STATE_PATH })
    console.log(`✅ Saved auth state to ${STORAGE_STATE_PATH}`)

    // Verify the file was created
    if (!fs.existsSync(STORAGE_STATE_PATH)) {
      throw new Error(`Storage state file was not created at ${STORAGE_STATE_PATH}`)
    }

    console.log('✅ Authentication setup complete!')
  } catch (error) {
    console.error('❌ Authentication setup failed:', error.message)
    // Clean up on failure
    if (fs.existsSync(STORAGE_STATE_PATH)) {
      fs.unlinkSync(STORAGE_STATE_PATH)
    }
    throw error
  } finally {
    await browser.close()
  }
}
