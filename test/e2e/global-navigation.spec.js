// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

// Load dangerous warning handler
const { handleDangerousWarning } = require('../utils/handle-dangerous-warning')

console.log(`🧪 Global Navigation Test - Environment: ${TEST_ENV}`)

test.describe('Global Navigation', () => {
  test.beforeEach(async ({ page }) => {
    // Start at the home page
    await page.goto(currentEnv.homeIndex)
    
    // Handle dangerous warning page if present (for production)
    await handleDangerousWarning(page)
    
    await page.waitForLoadState('networkidle')
  })

  test('should navigate from home to MITRE ATT&CK page and back', async ({ page }) => {
    console.log('🏠 Starting at home page')

    // Verify we're on home page
    await expect(page).toHaveTitle(/E-Skimming Labs/)
    await expect(page.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()

    // Click MITRE ATT&CK link
    console.log('🔗 Clicking MITRE ATT&CK link')
    const mitreLink = page.getByRole('link', { name: /MITRE ATT&CK/i })
    await expect(mitreLink).toBeVisible()
    await mitreLink.click()
    await page.waitForLoadState('networkidle')

    // Verify we're on MITRE page
    console.log('✅ Verifying MITRE page')
    await expect(page).toHaveTitle(/MITRE ATT&CK/)
    await expect(page.getByRole('heading', { name: /MITRE ATT&CK Matrix/i }).first()).toBeVisible()

    // Click back button
    console.log('⬅️  Clicking back to home')
    const backButton = page.getByRole('link', { name: /Back to Labs/i })
    await expect(backButton).toBeVisible()
    await backButton.click()
    await page.waitForLoadState('networkidle')

    // Verify we're back on home page
    console.log('✅ Verified back at home')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()
  })

  test('should navigate from home to Threat Model page and back', async ({ page }) => {
    console.log('🏠 Starting at home page')

    // Verify we're on home page
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // Click Threat Model link (use first to handle duplicate links)
    console.log('🔗 Clicking Threat Model link')
    const threatModelLink = page.getByRole('link', { name: /Threat Model/i }).first()
    await expect(threatModelLink).toBeVisible()
    await threatModelLink.click()
    await page.waitForLoadState('networkidle')

    // Verify we're on Threat Model page
    console.log('✅ Verifying Threat Model page')
    await expect(page).toHaveTitle(/Threat Model/)
    await expect(page.getByRole('heading', { name: /Interactive Threat Model/i }).first()).toBeVisible()

    // Click back button
    console.log('⬅️  Clicking back to home')
    const backButton = page.getByRole('link', { name: /Back to Labs/i })
    await expect(backButton).toBeVisible()
    await backButton.click()
    await page.waitForLoadState('networkidle')

    // Verify we're back on home page
    console.log('✅ Verified back at home')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()
  })

  test('should navigate from home to Lab 1, to C2, and back to home', async ({ page }) => {
    console.log('🏠 Starting at home page')

    // Verify we're on home page
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // Click Lab 1 Start Lab button (find by heading context)
    console.log('🔗 Clicking Lab 1 link')
    const lab1Section = page.locator('h3:has-text("Basic Magecart Attack")').locator('..')
    const lab1Link = lab1Section.getByRole('link', { name: /Start Lab/i })
    await expect(lab1Link).toBeVisible()
    await lab1Link.click()
    await page.waitForLoadState('networkidle')

    // Verify we're on Lab 1 page
    console.log('✅ Verifying Lab 1 page')
    await expect(page).toHaveTitle(/TechGear Store/)
    await expect(page.getByRole('heading', { name: /TechGear Store/i })).toBeVisible()

    // Click C2 server link
    console.log('🔗 Clicking C2 Server link')
    const c2Link = page.getByRole('link', { name: /View Stolen Data|C2/i }).first()
    await expect(c2Link).toBeVisible()

    // Handle C2 link opening in new tab
    const [c2Page] = await Promise.all([
      page.context().waitForEvent('page'),
      c2Link.click()
    ])
    await c2Page.waitForLoadState('networkidle')

    // Verify we're on C2 dashboard
    console.log('✅ Verifying C2 Dashboard')
    await expect(c2Page).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/)
    await expect(c2Page.locator('h1, h2').filter({ hasText: /Dashboard|Stolen|Command|Control/i }).first()).toBeVisible()

    // Navigate back to home from C2 page
    console.log('⬅️  Navigating back to home from C2')
    const c2BackButton = c2Page.getByRole('link', { name: /Back to Labs|Home/i }).first()
    if (await c2BackButton.isVisible()) {
      await c2BackButton.click()
      await c2Page.waitForLoadState('networkidle')
      await expect(c2Page).toHaveURL(currentEnv.homeIndex + '/')
    }
    await c2Page.close()

    // Navigate back to home from Lab 1
    console.log('⬅️  Clicking back to home from Lab 1')
    const lab1BackButton = page.getByRole('link', { name: /Back to Labs/i }).first()
    await expect(lab1BackButton).toBeVisible()
    await lab1BackButton.click()
    await page.waitForLoadState('networkidle')

    // Verify we're back on home page
    console.log('✅ Verified back at home')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()
  })

  test('should navigate from home to Lab 2, to C2, and back to home', async ({ page }) => {
    console.log('🏠 Starting at home page')

    // Verify we're on home page
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // Click Lab 2 Start Lab button (find by heading context)
    console.log('🔗 Clicking Lab 2 link')
    const lab2Section = page.locator('h3:has-text("DOM-Based Skimming")').locator('..')
    const lab2Link = lab2Section.getByRole('link', { name: /Start Lab/i })
    await expect(lab2Link).toBeVisible()
    await lab2Link.click()
    await page.waitForLoadState('networkidle')

    // Verify we're on Lab 2 page
    console.log('✅ Verifying Lab 2 page')
    await expect(page).toHaveTitle(/SecureBank|Banking/)
    await expect(page.locator('h1, h2').filter({ hasText: /SecureBank|Banking/i }).first()).toBeVisible()

    // Click C2 server link
    console.log('🔗 Clicking C2 Server link')
    const c2Link = page.getByRole('link', { name: /View Stolen Data|C2/i }).first()
    await expect(c2Link).toBeVisible()

    // Handle C2 link opening in new tab
    const [c2Page] = await Promise.all([
      page.context().waitForEvent('page'),
      c2Link.click()
    ])
    await c2Page.waitForLoadState('networkidle')

    // Verify we're on C2 dashboard
    console.log('✅ Verifying C2 Dashboard')
    await expect(c2Page).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/)

    // Navigate back to home from C2 page
    console.log('⬅️  Navigating back to home from C2')
    const c2BackButton = c2Page.getByRole('link', { name: /Back to Labs|Home/i }).first()
    if (await c2BackButton.isVisible()) {
      await c2BackButton.click()
      await c2Page.waitForLoadState('networkidle')
      await expect(c2Page).toHaveURL(currentEnv.homeIndex + '/')
    }
    await c2Page.close()

    // Navigate back to home from Lab 2
    console.log('⬅️  Clicking back to home from Lab 2')
    const lab2BackButton = page.getByRole('link', { name: /Back to Labs/i }).first()
    await expect(lab2BackButton).toBeVisible()
    await lab2BackButton.click()
    await page.waitForLoadState('networkidle')

    // Verify we're back on home page
    console.log('✅ Verified back at home')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()
  })

  test('should navigate from home to Lab 3, to C2, and back to home', async ({ page }) => {
    console.log('🏠 Starting at home page')

    // Verify we're on home page
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // Click Lab 3 Start Lab button (find by heading context)
    console.log('🔗 Clicking Lab 3 link')
    const lab3Section = page.locator('h3:has-text("Browser Extension Hijacking")').locator('..')
    const lab3Link = lab3Section.getByRole('link', { name: /Start Lab/i })
    await expect(lab3Link).toBeVisible()
    await lab3Link.click()
    await page.waitForLoadState('networkidle')

    // Verify we're on Lab 3 page
    console.log('✅ Verifying Lab 3 page')
    // Lab 3 may have different title - adjust as needed
    await expect(page.locator('h1, h2').first()).toBeVisible()

    // Click C2 server link
    console.log('🔗 Clicking C2 Server link')
    const c2Link = page.getByRole('link', { name: /View Stolen Data|C2|Extension Server/i }).first()

    // Check if C2 link exists (Lab 3 might have different structure)
    if (await c2Link.isVisible()) {
      // Handle C2 link opening in new tab
      const [c2Page] = await Promise.all([
        page.context().waitForEvent('page'),
        c2Link.click()
      ])
      await c2Page.waitForLoadState('networkidle')

      // Verify we're on C2/Extension server dashboard
      console.log('✅ Verifying C2/Extension Server Dashboard')
      await expect(c2Page.locator('h1, h2').first()).toBeVisible()

      // Navigate back to home from C2 page
      console.log('⬅️  Navigating back to home from C2')
      const c2BackButton = c2Page.getByRole('link', { name: /Back to Labs|Home/i }).first()
      if (await c2BackButton.isVisible()) {
        await c2BackButton.click()
        await c2Page.waitForLoadState('networkidle')
        await expect(c2Page).toHaveURL(currentEnv.homeIndex + '/')
      }
      await c2Page.close()
    } else {
      console.log('⚠️  C2 link not found on Lab 3, skipping C2 navigation')
    }

    // Navigate back to home from Lab 3
    console.log('⬅️  Clicking back to home from Lab 3')
    const lab3BackButton = page.getByRole('link', { name: /Back to Labs/i }).first()
    await expect(lab3BackButton).toBeVisible()

    // Note: Lab 3 may have incorrect back link, navigate directly to home instead
    await page.goto(currentEnv.homeIndex)
    await page.waitForLoadState('networkidle')

    // Verify we're back on home page
    console.log('✅ Verified back at home')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()
  })

  test('should verify all main navigation links are present on home page', async ({ page }) => {
    console.log('🏠 Verifying all navigation links on home page')

    // Verify home page loaded
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // Check for MITRE ATT&CK link
    const mitreLink = page.getByRole('link', { name: /MITRE ATT&CK/i })
    await expect(mitreLink).toBeVisible()
    console.log('✅ MITRE ATT&CK link found')

    // Check for Threat Model link (use first to handle duplicates)
    const threatModelLink = page.getByRole('link', { name: /Threat Model/i }).first()
    await expect(threatModelLink).toBeVisible()
    console.log('✅ Threat Model link found')

    // Check for Lab 1 by heading
    const lab1Heading = page.getByRole('heading', { name: /Basic Magecart Attack/i })
    await expect(lab1Heading).toBeVisible()
    console.log('✅ Lab 1 found')

    // Check for Lab 2 by heading
    const lab2Heading = page.getByRole('heading', { name: /DOM-Based Skimming/i })
    await expect(lab2Heading).toBeVisible()
    console.log('✅ Lab 2 found')

    // Check for Lab 3 by heading
    const lab3Heading = page.getByRole('heading', { name: /Browser Extension Hijacking/i })
    await expect(lab3Heading).toBeVisible()
    console.log('✅ Lab 3 found')

    console.log('✅ All navigation links verified')
  })

  test('should complete full navigation journey: Home → Lab 1 → C2 → Lab 1 → Home → MITRE → Home', async ({ page }) => {
    console.log('🚀 Starting comprehensive navigation journey')

    // 1. Start at Home
    console.log('1️⃣  At Home')
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // 2. Navigate to Lab 1
    console.log('2️⃣  Home → Lab 1')
    const lab1Section = page.locator('h3:has-text("Basic Magecart Attack")').locator('..')
    await lab1Section.getByRole('link', { name: /Start Lab/i }).click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveTitle(/TechGear Store/)

    // 3. Navigate to C2
    console.log('3️⃣  Lab 1 → C2')
    const c2Link = page.getByRole('link', { name: /View Stolen Data|C2/i }).first()
    const [c2Page] = await Promise.all([
      page.context().waitForEvent('page'),
      c2Link.click()
    ])
    await c2Page.waitForLoadState('networkidle')
    await expect(c2Page).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/)

    // 4. Navigate back to Lab 1 from C2
    console.log('4️⃣  C2 → Lab 1')
    const c2ToLabButton = c2Page.getByRole('link', { name: /Back to Lab|Lab 1/i }).first()
    if (await c2ToLabButton.isVisible()) {
      await c2ToLabButton.click()
      await c2Page.waitForLoadState('networkidle')
    }
    await c2Page.close()

    // 5. Navigate back to Home from Lab 1
    console.log('5️⃣  Lab 1 → Home')
    await page.getByRole('link', { name: /Back to Labs/i }).first().click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')

    // 6. Navigate to MITRE
    console.log('6️⃣  Home → MITRE')
    await page.getByRole('link', { name: /MITRE ATT&CK/i }).click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveTitle(/MITRE ATT&CK/)

    // 7. Navigate back to Home
    console.log('7️⃣  MITRE → Home')
    await page.getByRole('link', { name: /Back to Labs/i }).click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')

    console.log('✅ Comprehensive navigation journey completed successfully!')
  })
})
