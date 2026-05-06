/**
 * Global Setup for Playwright Tests - Authentication
 *
 * Signs in once and saves the __session cookie + sessionStorage state so all tests
 * can reuse it without re-authenticating.  Supports stg and prd environments.
 *
 * Only runs when:
 * - TEST_ENV is 'stg' or 'prd'
 * - AUTH_ENABLED === 'true'
 * - TEST_USER_EMAIL_<ENV> and TEST_USER_PASSWORD_<ENV> are set
 */

const { chromium } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('../config/test-env')
const path = require('path')
const fs = require('fs')

const STORAGE_STATE_PATH = path.join(__dirname, '../.auth/storage-state.json')

module.exports = async () => {
  // Only run for stg or prd
  if (TEST_ENV !== 'stg' && TEST_ENV !== 'prd') {
    console.log('⏭️  Skipping auth setup: not stg or prd environment')
    return
  }

  if (process.env.AUTH_ENABLED !== 'true') {
    console.log('⏭️  Skipping auth setup: AUTH_ENABLED is not true')
    return
  }

  const testEmail = TEST_ENV === 'prd'
    ? process.env.TEST_USER_EMAIL_PRD
    : process.env.TEST_USER_EMAIL_STG
  const testPassword = TEST_ENV === 'prd'
    ? process.env.TEST_USER_PASSWORD_PRD
    : process.env.TEST_USER_PASSWORD_STG

  if (!testEmail || !testPassword) {
    const envSuffix = TEST_ENV.toUpperCase()
    console.log(`⏭️  Skipping auth setup: TEST_USER_EMAIL_${envSuffix} or TEST_USER_PASSWORD_${envSuffix} not provided`)
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
    // Step 1: Sign in via the labs sign-in page (home-index-service serves /sign-in).
    // After sign-in the service sets an HttpOnly __session cookie (5-day lifetime)
    // which is what Traefik ForwardAuth checks.
    const signInUrl = `${currentEnv.homeIndex}/sign-in`
    console.log(`🔗 Signing in at ${signInUrl}`)
    await page.goto(signInUrl, { waitUntil: 'networkidle', timeout: 30000 })

    // Fill in credentials and submit
    await page.fill('#email', testEmail)
    await page.fill('#password', testPassword)
    await page.click('button[type="submit"]')

    // Wait for redirect away from sign-in page (to home or originally-requested page)
    await page.waitForFunction(
      () => !window.location.pathname.startsWith('/sign-in'),
      { timeout: 30000 }
    )

    console.log('✅ Signed in successfully')

    // Step 2: Verify we are authenticated (not redirected back to sign-in)
    const currentUrl = page.url()
    if (currentUrl.includes('/sign-in')) {
      throw new Error('Failed to authenticate: still on sign-in page after submit')
    }

    // Step 3: Verify Firebase token is in sessionStorage (set by sign-in page JS)
    const storedToken = await page.evaluate(() => sessionStorage.getItem('firebase_token'))
    if (!storedToken) {
      throw new Error('firebase_token not found in sessionStorage after sign-in')
    }

    console.log('✅ Auth state established (session cookie + sessionStorage token)')

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
