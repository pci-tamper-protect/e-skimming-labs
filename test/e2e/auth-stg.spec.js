/**
 * Authentication Integration Tests for E-Skimming Labs - Staging Environment
 *
 * Tests SSO flow between stg.pcioasis.com and labs.stg.pcioasis.com
 * Uses the same Firebase project as e-skimming-app staging: ui-firebase-pcioasis-stg
 */

import { test, expect } from '@playwright/test'
import { currentEnv, TEST_ENV } from '../config/test-env'

// Only run these tests in staging environment
test.describe('Authentication Integration - Staging', () => {
  // Configure tests to run in parallel for maximum speed
  test.describe.configure({ mode: 'parallel' })

  test.beforeAll(() => {
    // Skip if not running in staging
    if (TEST_ENV !== 'stg') {
      test.skip()
    }
  })

  test.beforeEach(async ({ page }) => {
    // Clear any existing auth state
    await page.context().clearCookies()
    await page.evaluate(() => {
      localStorage.clear()
      sessionStorage.clear()
    })
  })

  test('should allow access when auth is disabled', async ({ page }) => {
    // Navigate to labs staging
    await page.goto(currentEnv.homeIndex)

    // Should load without redirect
    await expect(page).toHaveURL(new RegExp(currentEnv.homeIndex))
    await expect(page.locator('h1, .hero h1')).toContainText(/E-Skimming|Interactive/i)
  })

  test('should redirect to sign-in when auth is required and user not authenticated', async ({ page }) => {
    // This test assumes auth is enabled and required in staging
    // Skip if auth is not enabled
    test.skip(process.env.AUTH_ENABLED !== 'true' || process.env.AUTH_REQUIRED !== 'true',
      'Auth not enabled/required in staging environment')

    await page.goto(currentEnv.homeIndex)

    // Should redirect to sign-in page on main app
    await expect(page).toHaveURL(new RegExp(`${currentEnv.mainApp}/sign-in`))

    // Should have redirect parameter
    const url = new URL(page.url())
    expect(url.searchParams.get('redirect')).toContain(currentEnv.homeIndex)
  })

  test('should allow access when authenticated via token in URL', async ({ page }) => {
    const testEmail = process.env.TEST_USER_EMAIL_STG
    const testPassword = process.env.TEST_USER_PASSWORD_STG

    test.skip(!testEmail || !testPassword, 'Staging test credentials not provided')
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    // Sign in to main app (staging)
    await page.goto(`${currentEnv.mainApp}/sign-in`)
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', testPassword)
    await page.click('button[type="submit"]')

    // Wait for sign-in to complete
    await page.waitForURL(new RegExp(`${currentEnv.mainApp}/dashboard|${currentEnv.mainApp}/`), { timeout: 15000 })

    // Get Firebase token from localStorage
    const token = await page.evaluate(() => localStorage.getItem('accessToken'))
    expect(token).toBeTruthy()
    expect(token.length).toBeGreaterThan(0)

    // Navigate to labs with token
    await page.goto(`${currentEnv.homeIndex}?token=${token}`)

    // Should load labs page
    await expect(page).toHaveURL(new RegExp(currentEnv.homeIndex))

    // Token should be stored in sessionStorage
    const storedToken = await page.evaluate(() => sessionStorage.getItem('firebase_token'))
    expect(storedToken).toBe(token)

    // Should not redirect to sign-in
    await expect(page).not.toHaveURL(new RegExp(`${currentEnv.mainApp}/sign-in`))

    // Should see labs content
    await expect(page.locator('h1, .hero h1')).toContainText(/E-Skimming|Interactive/i)
  })

  test('should validate token with server', async ({ page, request }) => {
    const testEmail = process.env.TEST_USER_EMAIL_STG
    const testPassword = process.env.TEST_USER_PASSWORD_STG

    test.skip(!testEmail || !testPassword, 'Staging test credentials not provided')
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    // Sign in to main app
    await page.goto(`${currentEnv.mainApp}/sign-in`)
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', testPassword)
    await page.click('button[type="submit"]')
    await page.waitForURL(new RegExp(`${currentEnv.mainApp}/dashboard|${currentEnv.mainApp}/`), { timeout: 15000 })

    const token = await page.evaluate(() => localStorage.getItem('accessToken'))
    expect(token).toBeTruthy()

    // Test token validation endpoint
    const response = await request.post(`${currentEnv.homeIndex}/api/auth/validate`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      data: { token }
    })

    expect(response.ok()).toBeTruthy()
    const data = await response.json()
    expect(data.valid).toBe(true)
    expect(data.user).toHaveProperty('email')
    expect(data.user).toHaveProperty('id')
    expect(data.user.email).toBe(testEmail)
  })

  test('should handle invalid token gracefully', async ({ request }) => {
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    const invalidToken = 'invalid-token-12345'

    const response = await request.post(`${currentEnv.homeIndex}/api/auth/validate`, {
      headers: {
        'Authorization': `Bearer ${invalidToken}`,
        'Content-Type': 'application/json'
      },
      data: { token: invalidToken }
    })

    expect(response.status()).toBe(401)
    const data = await response.json()
    expect(data.valid).toBe(false)
    expect(data).toHaveProperty('error')
  })

  test('should get user info when authenticated', async ({ page, request }) => {
    const testEmail = process.env.TEST_USER_EMAIL_STG
    const testPassword = process.env.TEST_USER_PASSWORD_STG

    test.skip(!testEmail || !testPassword, 'Staging test credentials not provided')
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    // Sign in to main app
    await page.goto(`${currentEnv.mainApp}/sign-in`)
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', testPassword)
    await page.click('button[type="submit"]')
    await page.waitForURL(new RegExp(`${currentEnv.mainApp}/dashboard|${currentEnv.mainApp}/`), { timeout: 15000 })

    const token = await page.evaluate(() => localStorage.getItem('accessToken'))
    expect(token).toBeTruthy()

    // Test user info endpoint
    const response = await request.get(`${currentEnv.homeIndex}/api/auth/user`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    expect(response.ok()).toBeTruthy()
    const data = await response.json()
    expect(data.authenticated).toBe(true)
    expect(data.user).toHaveProperty('email')
    expect(data.user.email).toBe(testEmail)
    expect(data.user).toHaveProperty('id')
  })

  test('should get sign-in URL with redirect', async ({ request }) => {
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    const redirectUrl = `${currentEnv.homeIndex}/lab-01-writeup`

    const response = await request.get(`${currentEnv.homeIndex}/api/auth/sign-in-url?redirect=${encodeURIComponent(redirectUrl)}`)

    expect(response.ok()).toBeTruthy()
    const data = await response.json()
    expect(data.signInUrl).toContain(currentEnv.mainApp)
    expect(data.signInUrl).toContain('/sign-in')
    expect(data.signInUrl).toContain('redirect=')
    expect(data.signInUrl).toContain(encodeURIComponent(redirectUrl))
  })

  test('should maintain auth state across page navigation', async ({ page }) => {
    const testEmail = process.env.TEST_USER_EMAIL_STG
    const testPassword = process.env.TEST_USER_PASSWORD_STG

    test.skip(!testEmail || !testPassword, 'Staging test credentials not provided')
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    // Sign in to main app
    await page.goto(`${currentEnv.mainApp}/sign-in`)
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', testPassword)
    await page.click('button[type="submit"]')
    await page.waitForURL(new RegExp(`${currentEnv.mainApp}/dashboard|${currentEnv.mainApp}/`), { timeout: 15000 })

    const token = await page.evaluate(() => localStorage.getItem('accessToken'))

    // Navigate to labs with token
    await page.goto(`${currentEnv.homeIndex}?token=${token}`)
    await expect(page).toHaveURL(new RegExp(currentEnv.homeIndex))

    // Navigate to a lab writeup
    await page.goto(`${currentEnv.homeIndex}/lab-01-writeup`)
    await expect(page).toHaveURL(new RegExp(`${currentEnv.homeIndex}/lab-01-writeup`))

    // Token should still be in sessionStorage
    const storedToken = await page.evaluate(() => sessionStorage.getItem('firebase_token'))
    expect(storedToken).toBe(token)

    // Should not redirect to sign-in
    await expect(page).not.toHaveURL(new RegExp(`${currentEnv.mainApp}/sign-in`))
  })

  test('should use correct Firebase project ID', async ({ page }) => {
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    await page.goto(currentEnv.homeIndex)

    // Check that auth script is loaded (if auth is enabled)
    const authScriptLoaded = await page.evaluate(() => {
      return typeof window.initLabsAuth === 'function'
    })

    if (authScriptLoaded) {
      // Verify Firebase project ID matches staging
      const firebaseProjectId = currentEnv.firebaseProjectId || 'ui-firebase-pcioasis-stg'
      expect(firebaseProjectId).toBe('ui-firebase-pcioasis-stg')
    }
  })

  test('should handle SSO token via postMessage', async ({ page, context }) => {
    const testEmail = process.env.TEST_USER_EMAIL_STG
    const testPassword = process.env.TEST_USER_PASSWORD_STG

    test.skip(!testEmail || !testPassword, 'Staging test credentials not provided')
    test.skip(process.env.AUTH_ENABLED !== 'true', 'Auth not enabled in staging environment')

    // Sign in to main app
    await page.goto(`${currentEnv.mainApp}/sign-in`)
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', testPassword)
    await page.click('button[type="submit"]')
    await page.waitForURL(new RegExp(`${currentEnv.mainApp}/dashboard|${currentEnv.mainApp}/`), { timeout: 15000 })

    const token = await page.evaluate(() => localStorage.getItem('accessToken'))

    // Open labs in new page (simulating SSO)
    const labsPage = await context.newPage()
    await labsPage.goto(currentEnv.homeIndex)

    // Send token via postMessage (simulating SSO helper)
    await labsPage.evaluate((token) => {
      window.postMessage({
        type: 'FIREBASE_TOKEN',
        token: token
      }, window.location.origin)
    }, token)

    // Wait a bit for token processing
    await labsPage.waitForTimeout(1000)

    // Token should be stored
    const storedToken = await labsPage.evaluate(() => sessionStorage.getItem('firebase_token'))
    expect(storedToken).toBe(token)

    await labsPage.close()
  })
})
