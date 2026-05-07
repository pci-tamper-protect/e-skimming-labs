/**
 * Global Setup for Playwright Tests - Authentication
 *
 * Signs in once and saves the __session cookie (and localStorage) so all tests
 * can reuse it without re-authenticating.  Supports stg and prd environments.
 *
 * Note: Playwright's storageState persists cookies and localStorage only —
 * sessionStorage is NOT persisted and NOT available to subsequent test pages.
 * Auth is validated by checking the __session cookie after sign-in.
 *
 * Credential resolution order:
 *   1. Env vars TEST_USER_EMAIL_<ENV> / TEST_USER_PASSWORD_<ENV>
 *   2. GCP Secret Manager: secret "e2e-test-user" in the env's labs GCP project
 *      (works in CI via the existing GCP SA key, and locally via gcloud auth login)
 *
 * If no credentials are found, any stale storage state file is removed so tests
 * run unauthenticated and skip auth-gated assertions via skipIfAuthRedirect.
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

function clearStorageState() {
  if (fs.existsSync(STORAGE_STATE_PATH)) {
    fs.unlinkSync(STORAGE_STATE_PATH)
    console.log('🗑️  Removed stale auth state file')
  }
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
    // Remove any stale storage state so tests don't silently reuse old auth.
    clearStorageState()
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

    // Retry loop: the gcloud proxy can return a transient error page in the first
    // few seconds after it passes the /health check but before all routes are fully
    // tunnelled.  Retry up to 3 times with a short pause.
    const MAX_ATTEMPTS = 3
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      if (attempt > 1) {
        console.log(`🔄 Retry ${attempt}/${MAX_ATTEMPTS} — waiting 5s before re-navigating...`)
        await page.waitForTimeout(5000)
      }
      await page.goto(signInUrl, { waitUntil: 'domcontentloaded', timeout: 30000 })
      const landedUrl = page.url()
      const hasEmailField = await page.locator('#email').count() > 0
      if (hasEmailField) {
        console.log(`✅ Sign-in form loaded (attempt ${attempt})`)
        break
      }
      const pageTitle = await page.title()
      console.warn(`⚠️  Sign-in form not found on attempt ${attempt} (url: ${landedUrl}, title: "${pageTitle}")`)
      if (attempt === MAX_ATTEMPTS) {
        const content = await page.content()
        throw new Error(
          `Sign-in page did not render the email form after ${MAX_ATTEMPTS} attempts.\n` +
          `  Final URL: ${landedUrl}\n` +
          `  Page title: "${pageTitle}"\n` +
          `  Body excerpt: ${content.slice(0, 400)}`
        )
      }
    }

    await page.fill('#email', testEmail)
    await page.fill('#password', testPassword)

    // Start waiting for navigation away from /sign-in BEFORE clicking — the
    // click triggers a full-page redirect which destroys the JS execution context,
    // so waitForFunction called after the click can raise TargetClosedError.
    const navigationDone = page.waitForURL(
      url => !url.pathname.startsWith('/sign-in'),
      { timeout: 30000 }
    )
    await page.click('button[type="submit"]')
    await navigationDone
    // Wait for any pending requests (e.g. server-side session cookie exchange) to settle.
    await page.waitForLoadState('networkidle', { timeout: 15000 })

    const currentUrl = page.url()
    if (currentUrl.includes('/sign-in')) {
      throw new Error('Failed to authenticate: still on sign-in page after submit')
    }

    // Validate that the __session cookie was set — this is what storageState
    // persists and what auth-check middleware reads on subsequent requests.
    const cookies = await context.cookies()
    const sessionCookie = cookies.find(c => c.name === '__session')
    if (!sessionCookie) {
      throw new Error('__session cookie not found after sign-in — auth state will not be usable')
    }

    console.log('✅ Auth state established (__session cookie present)')

    await context.storageState({ path: STORAGE_STATE_PATH })
    console.log(`✅ Saved auth state to ${STORAGE_STATE_PATH}`)

    if (!fs.existsSync(STORAGE_STATE_PATH)) {
      throw new Error(`Storage state file was not created at ${STORAGE_STATE_PATH}`)
    }

    console.log('✅ Authentication setup complete!')
  } catch (error) {
    console.error('❌ Authentication setup failed:', error.message)
    clearStorageState()
    throw error
  } finally {
    await browser.close()
  }
}
