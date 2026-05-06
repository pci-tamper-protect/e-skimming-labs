/**
 * Global Setup for Playwright Tests - Authentication
 *
 * Signs in once and saves the __session cookie + sessionStorage state so all tests
 * can reuse it without re-authenticating.  Supports stg and prd environments.
 *
 * Credential resolution order:
 *   1. Env vars TEST_USER_EMAIL_<ENV> / TEST_USER_PASSWORD_<ENV>
 *   2. GCP Secret Manager: secret "e2e-test-user" in the env's labs GCP project
 *      (works in CI via the existing GCP SA key, and locally via gcloud auth login)
 *
 * If no credentials are found, setup is skipped silently — tests run unauthenticated
 * and will skip auth-gated assertions via skipIfAuthRedirect.
 */

const { chromium } = require('@playwright/test')
const { execSync } = require('child_process')
const { currentEnv, TEST_ENV } = require('../config/test-env')
const path = require('path')
const fs = require('fs')

const STORAGE_STATE_PATH = path.join(__dirname, '../.auth/storage-state.json')

const GCP_PROJECTS = {
  stg: 'labs-stg',
  prd: 'labs-prd',
}
const SECRET_NAME = 'e2e-test-user'

function getCredentialsFromGcp(env) {
  const project = GCP_PROJECTS[env]
  if (!project) return null

  try {
    const raw = execSync(
      `gcloud secrets versions access latest --secret=${SECRET_NAME} --project=${project}`,
      { encoding: 'utf8', timeout: 15000, stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim()
    const creds = JSON.parse(raw)
    if (creds.email && creds.password) {
      console.log(`🔑 Fetched test credentials from GCP Secret Manager (${project}/${SECRET_NAME})`)
      return creds
    }
  } catch (_) {
    // gcloud not available, secret doesn't exist yet, or no access — fall through
  }
  return null
}

function getCredentials(env) {
  const envSuffix = env.toUpperCase()
  const email = process.env[`TEST_USER_EMAIL_${envSuffix}`]
  const password = process.env[`TEST_USER_PASSWORD_${envSuffix}`]

  if (email && password) {
    return { email, password }
  }

  return getCredentialsFromGcp(env)
}

module.exports = async () => {
  if (TEST_ENV !== 'stg' && TEST_ENV !== 'prd') {
    console.log('⏭️  Skipping auth setup: not stg or prd environment')
    return
  }

  const credentials = getCredentials(TEST_ENV)
  if (!credentials) {
    console.log(
      `⏭️  Skipping auth setup: no credentials found.\n` +
      `   Set TEST_USER_EMAIL_${TEST_ENV.toUpperCase()} / TEST_USER_PASSWORD_${TEST_ENV.toUpperCase()}, ` +
      `or ensure the GCP secret "${SECRET_NAME}" exists in project "${GCP_PROJECTS[TEST_ENV]}" ` +
      `and you have secretmanager.secretVersions.access.`
    )
    return
  }

  const { email: testEmail, password: testPassword } = credentials

  console.log('🔐 Starting authentication setup...')
  console.log(`📧 Test account: ${testEmail}`)

  const authDir = path.dirname(STORAGE_STATE_PATH)
  if (!fs.existsSync(authDir)) {
    fs.mkdirSync(authDir, { recursive: true })
  }

  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  })

  const context = await browser.newContext()
  const page = await context.newPage()

  try {
    const signInUrl = `${currentEnv.homeIndex}/sign-in`
    console.log(`🔗 Signing in at ${signInUrl}`)
    await page.goto(signInUrl, { waitUntil: 'networkidle', timeout: 30000 })

    await page.fill('#email', testEmail)
    await page.fill('#password', testPassword)
    await page.click('button[type="submit"]')

    await page.waitForFunction(
      () => !window.location.pathname.startsWith('/sign-in'),
      { timeout: 30000 }
    )

    const currentUrl = page.url()
    if (currentUrl.includes('/sign-in')) {
      throw new Error('Failed to authenticate: still on sign-in page after submit')
    }

    const storedToken = await page.evaluate(() => sessionStorage.getItem('firebase_token'))
    if (!storedToken) {
      throw new Error('firebase_token not found in sessionStorage after sign-in')
    }

    console.log('✅ Auth state established (session cookie + sessionStorage token)')

    await context.storageState({ path: STORAGE_STATE_PATH })
    console.log(`✅ Saved auth state to ${STORAGE_STATE_PATH}`)

    if (!fs.existsSync(STORAGE_STATE_PATH)) {
      throw new Error(`Storage state file was not created at ${STORAGE_STATE_PATH}`)
    }

    console.log('✅ Authentication setup complete!')
  } catch (error) {
    console.error('❌ Authentication setup failed:', error.message)
    if (fs.existsSync(STORAGE_STATE_PATH)) {
      fs.unlinkSync(STORAGE_STATE_PATH)
    }
    throw error
  } finally {
    await browser.close()
  }
}
