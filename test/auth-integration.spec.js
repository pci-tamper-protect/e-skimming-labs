/**
 * Authentication Integration Tests for E-Skimming Labs
 * 
 * Tests SSO flow between www.pcioasis.com and labs.pcioasis.com
 */

import { test, expect } from '@playwright/test'

const MAIN_APP_URL = process.env.MAIN_APP_URL || 'https://www.pcioasis.com'
const LABS_URL = process.env.LABS_URL || 'https://labs.pcioasis.com'
const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL
const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD

test.describe('Authentication Integration', () => {
  test.beforeEach(async ({ page }) => {
    // Clear any existing auth state
    await page.context().clearCookies()
    await page.evaluate(() => {
      localStorage.clear()
      sessionStorage.clear()
    })
  })

  test('should allow access when auth is disabled', async ({ page }) => {
    // This test assumes auth is disabled in the test environment
    await page.goto(LABS_URL)
    
    // Should load without redirect
    await expect(page).toHaveURL(new RegExp(LABS_URL))
    await expect(page.locator('h1, .hero h1')).toContainText(/E-Skimming|Interactive/i)
  })

  test('should redirect to sign-in when auth is required and user not authenticated', async ({ page }) => {
    // Skip if auth is not enabled/required in test environment
    test.skip(!process.env.AUTH_REQUIRED, 'Auth not required in test environment')
    
    await page.goto(LABS_URL)
    
    // Should redirect to sign-in page
    await expect(page).toHaveURL(new RegExp(`${MAIN_APP_URL}/sign-in`))
  })

  test('should allow access when authenticated via token in URL', async ({ page }) => {
    test.skip(!TEST_USER_EMAIL || !TEST_USER_PASSWORD, 'Test credentials not provided')
    test.skip(!process.env.AUTH_ENABLED, 'Auth not enabled in test environment')
    
    // Sign in to main app
    await page.goto(`${MAIN_APP_URL}/sign-in`)
    await page.fill('input[type="email"]', TEST_USER_EMAIL)
    await page.fill('input[type="password"]', TEST_USER_PASSWORD)
    await page.click('button[type="submit"]')
    
    // Wait for sign-in to complete
    await page.waitForURL(new RegExp(`${MAIN_APP_URL}/dashboard|${MAIN_APP_URL}/`))
    
    // Get Firebase token from localStorage
    const token = await page.evaluate(() => localStorage.getItem('accessToken'))
    expect(token).toBeTruthy()
    
    // Navigate to labs with token
    await page.goto(`${LABS_URL}?token=${token}`)
    
    // Should load labs page
    await expect(page).toHaveURL(new RegExp(LABS_URL))
    
    // Token should be stored in sessionStorage
    const storedToken = await page.evaluate(() => sessionStorage.getItem('firebase_token'))
    expect(storedToken).toBe(token)
    
    // Should not redirect to sign-in
    await expect(page).not.toHaveURL(new RegExp(`${MAIN_APP_URL}/sign-in`))
  })

  test('should validate token with server', async ({ page, request }) => {
    test.skip(!TEST_USER_EMAIL || !TEST_USER_PASSWORD, 'Test credentials not provided')
    test.skip(!process.env.AUTH_ENABLED, 'Auth not enabled in test environment')
    
    // Sign in to main app
    await page.goto(`${MAIN_APP_URL}/sign-in`)
    await page.fill('input[type="email"]', TEST_USER_EMAIL)
    await page.fill('input[type="password"]', TEST_USER_PASSWORD)
    await page.click('button[type="submit"]')
    await page.waitForURL(new RegExp(`${MAIN_APP_URL}/dashboard|${MAIN_APP_URL}/`))
    
    const token = await page.evaluate(() => localStorage.getItem('accessToken'))
    
    // Test token validation endpoint
    const response = await request.post(`${LABS_URL}/api/auth/validate`, {
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
  })

  test('should handle invalid token gracefully', async ({ page, request }) => {
    test.skip(!process.env.AUTH_ENABLED, 'Auth not enabled in test environment')
    
    const invalidToken = 'invalid-token-12345'
    
    const response = await request.post(`${LABS_URL}/api/auth/validate`, {
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
    test.skip(!TEST_USER_EMAIL || !TEST_USER_PASSWORD, 'Test credentials not provided')
    test.skip(!process.env.AUTH_ENABLED, 'Auth not enabled in test environment')
    
    // Sign in to main app
    await page.goto(`${MAIN_APP_URL}/sign-in`)
    await page.fill('input[type="email"]', TEST_USER_EMAIL)
    await page.fill('input[type="password"]', TEST_USER_PASSWORD)
    await page.click('button[type="submit"]')
    await page.waitForURL(new RegExp(`${MAIN_APP_URL}/dashboard|${MAIN_APP_URL}/`))
    
    const token = await page.evaluate(() => localStorage.getItem('accessToken'))
    
    // Test user info endpoint
    const response = await request.get(`${LABS_URL}/api/auth/user`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })
    
    expect(response.ok()).toBeTruthy()
    const data = await response.json()
    expect(data.authenticated).toBe(true)
    expect(data.user).toHaveProperty('email')
    expect(data.user.email).toBe(TEST_USER_EMAIL)
  })
})

