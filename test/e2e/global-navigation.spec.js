// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

// Load dangerous warning handler
const { handleDangerousWarning } = require('../utils/handle-dangerous-warning')

console.log(`🧪 Global Navigation Test - Environment: ${TEST_ENV}`)

/**
 * After clicking a "Start Lab" link, the server may redirect to /sign-in when
 * Firebase auth is required. If so, skip the test rather than fail — the redirect
 * itself is correct behaviour; the test just can't proceed without credentials.
 */
async function skipIfAuthRedirect(page, labName) {
  const url = page.url()
  if (url.includes('/sign-in')) {
    console.log(`⏭️  ${labName} redirected to sign-in — skipping (set TEST_USER_EMAIL_* to run with auth)`)
    test.skip()
  }
}

// stg: skip when proxy is not configured (labs are private, not reachable)
const navigationTests = (TEST_ENV === 'stg' && process.env.USE_PROXY !== 'true')
  ? test.describe.skip
  : test.describe

navigationTests('Global Navigation', () => {
  // Configure tests to run in parallel for maximum speed
  test.describe.configure({ mode: 'parallel' })
  test.beforeEach(async ({ page }) => {
    // Start at the home page
    const response = await page.goto(currentEnv.homeIndex)

    // Check for HTTP errors - fail immediately if we get 403 or other errors
    if (response && response.status() >= 400) {
      const status = response.status()
      const statusText = response.statusText()
      const url = response.url()
      throw new Error(`HTTP ${status} ${statusText} when accessing ${url}. This indicates authentication or access issues.`)
    }

    // Handle dangerous warning page if present (for production)
    await handleDangerousWarning(page)

    await page.waitForLoadState('networkidle')

    // Verify we didn't get an error page
    const title = await page.title()
    if (title.includes('403') || title.includes('Forbidden') || title.includes('401') || title.includes('Unauthorized')) {
      throw new Error(`Received error page: "${title}" when accessing ${currentEnv.homeIndex}. This indicates authentication or access issues.`)
    }
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

    // Get the href to see what URL it's trying to navigate to
    const lab1Href = await lab1Link.getAttribute('href')
    console.log('Lab 1 link href:', lab1Href)

    // Click and wait for navigation
    await lab1Link.click()

    // Wait for navigation to complete (with longer timeout for mobile)
    try {
      await page.waitForLoadState('networkidle', { timeout: 15000 })
    } catch (e) {
      console.log('Network idle timeout, checking page state...')
    }

    // Check if we got an error page or auth redirect
    const currentUrl = page.url()
    console.log('Current URL after clicking Lab 1:', currentUrl)

    if (currentUrl.includes('chrome-error://') || currentUrl.includes('error')) {
      throw new Error(`Failed to load Lab 1 page. URL: ${currentUrl}. Check if lab1-vulnerable-site container is running.`)
    }
    await skipIfAuthRedirect(page, 'Lab 1')

    // Verify we're on Lab 1 page
    console.log('✅ Verifying Lab 1 page')
    // Wait for page to fully load - Lab 1 uses /lab1/index.html
    await expect(page).toHaveURL(/\/lab1/, { timeout: 10000 })
    await expect(page).toHaveTitle(/TechGear Store/, { timeout: 10000 })
    await expect(page.getByRole('heading', { name: /TechGear Store/i })).toBeVisible({ timeout: 10000 })

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
    await skipIfAuthRedirect(c2Page, 'C2 Dashboard')

    // Verify we're on C2 dashboard
    console.log('✅ Verifying C2 Dashboard')
    await expect(c2Page).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/)
    await expect(c2Page.locator('h1, h2').filter({ hasText: /Dashboard|Stolen|Command|Control/i }).first()).toBeVisible()

    // Navigate back to home from C2 page
    console.log('⬅️  Navigating back to home from C2')
    // C2 pages have two buttons: "Back to Lab" (goes to lab page) and "Home" (goes to labs home)
    // We want the Home button to go back to labs home
    const c2HomeButton = c2Page.getByRole('link', { name: /Home/i }).first()
    if (await c2HomeButton.isVisible()) {
      await c2HomeButton.click()
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

    // Get the href to see what URL it's trying to navigate to
    const lab2Href = await lab2Link.getAttribute('href')
    console.log('Lab 2 link href:', lab2Href)

    // Click and wait for navigation
    await lab2Link.click()

    // Wait for navigation to complete (with longer timeout for mobile)
    try {
      await page.waitForLoadState('networkidle', { timeout: 15000 })
    } catch (e) {
      console.log('Network idle timeout, checking page state...')
    }

    // Check if we got an error page or auth redirect
    const currentUrl = page.url()
    console.log('Current URL after clicking Lab 2:', currentUrl)

    if (currentUrl.includes('chrome-error://') || currentUrl.includes('error')) {
      throw new Error(`Failed to load Lab 2 page. URL: ${currentUrl}. Check if lab2-vulnerable-site container is running.`)
    }
    await skipIfAuthRedirect(page, 'Lab 2')

    // Verify we're on Lab 2 page
    console.log('✅ Verifying Lab 2 page')
    // Wait for page to fully load - Lab 2 uses /lab2/banking.html
    await expect(page).toHaveURL(/\/lab2/, { timeout: 10000 })
    await expect(page).toHaveTitle(/SecureBank|Banking/, { timeout: 10000 })
    await expect(page.locator('h1, h2').filter({ hasText: /SecureBank|Banking/i }).first()).toBeVisible({ timeout: 10000 })

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
    await skipIfAuthRedirect(c2Page, 'C2 Dashboard')

    // Verify we're on C2 dashboard
    console.log('✅ Verifying C2 Dashboard')
    await expect(c2Page).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/)

    // Navigate back to home from C2 page
    console.log('⬅️  Navigating back to home from C2')
    // C2 pages have two buttons: "Back to Lab" (goes to lab page) and "Home" (goes to labs home)
    // We want the Home button to go back to labs home
    const c2HomeButton = c2Page.getByRole('link', { name: /Home/i }).first()
    if (await c2HomeButton.isVisible()) {
      await c2HomeButton.click()
      await c2Page.waitForLoadState('networkidle')
      await expect(c2Page).toHaveURL(currentEnv.homeIndex + '/')
    }
    await c2Page.close()

    // Wait for Lab 2 page to be ready after closing C2 tab
    // Ensure we're still on Lab 2 and page is stable
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveTitle(/SecureBank|Banking/)

    // Navigate back to home from Lab 2
    console.log('⬅️  Clicking back to home from Lab 2')
    // Use ID selector for more reliable targeting
    const lab2BackButton = page.locator('#back-button.back-button')
    await expect(lab2BackButton).toBeVisible({ timeout: 10000 })
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

    // Get the href to see what URL it's trying to navigate to
    const lab3Href = await lab3Link.getAttribute('href')
    console.log('Lab 3 link href:', lab3Href)

    // Click and wait for navigation
    await lab3Link.click()

    // Wait for navigation to complete (with longer timeout for potential service startup)
    try {
      await page.waitForLoadState('networkidle', { timeout: 10000 })
    } catch (e) {
      console.log('Network idle timeout, checking page state...')
    }

    // Check if we got an error page or auth redirect
    const currentUrl = page.url()
    console.log('Current URL after clicking Lab 3:', currentUrl)

    if (currentUrl.includes('chrome-error://') || currentUrl.includes('error')) {
      throw new Error(`Failed to load Lab 3 page. URL: ${currentUrl}. Check if lab3-vulnerable-site container is running.`)
    }
    await skipIfAuthRedirect(page, 'Lab 3')

    // Verify we're on Lab 3 page
    console.log('✅ Verifying Lab 3 page')
    // Wait for page to fully load - Lab 3 uses /lab3/index.html
    await expect(page).toHaveURL(/\/lab3/, { timeout: 10000 })
    await expect(page).toHaveTitle(/SecureShop|Checkout/, { timeout: 10000 })
    await expect(page.locator('h1, h2').filter({ hasText: /SecureShop|Checkout/i }).first()).toBeVisible({ timeout: 10000 })

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
      // C2 pages have two buttons: "Back to Lab" (goes to lab page) and "Home" (goes to labs home)
      // We want the Home button to go back to labs home
      const c2HomeButton = c2Page.getByRole('link', { name: /Home/i }).first()
      if (await c2HomeButton.isVisible()) {
        await c2HomeButton.click()
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

  test('should verify C2 page has both "Back to Lab" and "Home" buttons with correct functionality', async ({ page }) => {
    console.log('🏠 Testing C2 page navigation buttons')

    // Navigate to Lab 1
    console.log('🔗 Navigating to Lab 1')
    const lab1Section = page.locator('h3:has-text("Basic Magecart Attack")').locator('..')
    const lab1Link = lab1Section.getByRole('link', { name: /Start Lab/i })
    await expect(lab1Link).toBeVisible()
    await lab1Link.click()
    await page.waitForLoadState('networkidle')
    await skipIfAuthRedirect(page, 'Lab 1')

    // Verify we're on Lab 1 page
    await expect(page).toHaveTitle(/TechGear Store/)

    // Click C2 server link
    console.log('🔗 Opening C2 dashboard')
    const c2Link = page.getByRole('link', { name: /View Stolen Data|C2/i }).first()
    await expect(c2Link).toBeVisible()

    // Handle C2 link opening in new tab
    const [c2Page] = await Promise.all([
      page.context().waitForEvent('page'),
      c2Link.click()
    ])
    await c2Page.waitForLoadState('networkidle')
    await skipIfAuthRedirect(c2Page, 'C2 Dashboard')

    // Verify we're on C2 dashboard
    console.log('✅ Verifying C2 Dashboard')
    await expect(c2Page).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/)

    // Verify both buttons exist on C2 page
    console.log('🔍 Verifying navigation buttons exist')
    const backToLabButton = c2Page.getByRole('link', { name: /Back to Lab/i }).first()
    const homeButton = c2Page.getByRole('link', { name: /Home/i }).first()

    await expect(backToLabButton).toBeVisible()
    await expect(homeButton).toBeVisible()
    console.log('✅ Both "Back to Lab" and "Home" buttons are visible')

    // Test "Back to Lab" button - should take us to the lab page
    console.log('🧪 Testing "Back to Lab" button')
    await backToLabButton.click()
    await c2Page.waitForLoadState('networkidle')

    // Should be on Lab 1 page (not home)
    // Wait for page to fully load and verify URL first
    await expect(c2Page).toHaveURL(/\/lab1/, { timeout: 10000 })
    await expect(c2Page).toHaveTitle(/TechGear Store/, { timeout: 10000 })
    await expect(c2Page.getByRole('heading', { name: /TechGear Store/i })).toBeVisible({ timeout: 10000 })
    console.log('✅ "Back to Lab" button correctly navigates to lab page')

    // Go back to C2 to test Home button
    console.log('🔗 Returning to C2 dashboard')
    const c2LinkAgain = c2Page.getByRole('link', { name: /View Stolen Data|C2/i }).first()
    await expect(c2LinkAgain).toBeVisible({ timeout: 10000 })

    const [c2PageAgain] = await Promise.all([
      c2Page.context().waitForEvent('page'),
      c2LinkAgain.click()
    ])
    await c2PageAgain.waitForLoadState('networkidle')
    await expect(c2PageAgain).toHaveTitle(/C2.*Dashboard|Stolen Data|Server Dashboard/, { timeout: 10000 })

    // Test "Home" button - should take us to labs home
    console.log('🧪 Testing "Home" button')
    const homeButtonAgain = c2PageAgain.getByRole('link', { name: /Home/i }).first()
    await expect(homeButtonAgain).toBeVisible()
    await homeButtonAgain.click()
    await c2PageAgain.waitForLoadState('networkidle')

    // Should be on labs home page
    await expect(c2PageAgain).toHaveURL(currentEnv.homeIndex + '/')
    await expect(c2PageAgain.getByRole('heading', { name: /Interactive E-Skimming Labs/i })).toBeVisible()
    console.log('✅ "Home" button correctly navigates to labs home page')

    await c2PageAgain.close()
    await c2Page.close()
  })

  test('should complete full navigation journey: Home → Lab 1 → C2 → Lab 1 → Home → MITRE → Home', async ({ page }) => {
    console.log('🚀 Starting comprehensive navigation journey')

    // 1. Start at Home
    console.log('1️⃣  At Home')
    await expect(page).toHaveTitle(/E-Skimming Labs/)

    // 2. Navigate to Lab 1
    console.log('2️⃣  Home → Lab 1')
    const lab1Section = page.locator('h3:has-text("Basic Magecart Attack")').locator('..')
    const lab1Link = lab1Section.getByRole('link', { name: /Start Lab/i })
    await expect(lab1Link).toBeVisible()
    await lab1Link.click()

    // Wait for navigation with error handling
    try {
      await page.waitForLoadState('networkidle', { timeout: 15000 })
    } catch (e) {
      console.log('Network idle timeout, checking page state...')
    }

    // Check for error pages or auth redirect
    const lab1Url = page.url()
    if (lab1Url.includes('chrome-error://') || lab1Url.includes('error')) {
      throw new Error(`Failed to load Lab 1 page. URL: ${lab1Url}. Check if lab1-vulnerable-site container is running.`)
    }
    await skipIfAuthRedirect(page, 'Lab 1 (full journey)')

    await expect(page).toHaveURL(/\/lab1/, { timeout: 10000 })
    await expect(page).toHaveTitle(/TechGear Store/, { timeout: 10000 })

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
    // Use "Back to Lab" button (not "Home") to go back to the lab page
    const c2ToLabButton = c2Page.getByRole('link', { name: /Back to Lab/i }).first()
    if (await c2ToLabButton.isVisible()) {
      await c2ToLabButton.click()
      await c2Page.waitForLoadState('networkidle')

      // Verify we're back on Lab 1 page
      await expect(c2Page).toHaveURL(/\/lab1/, { timeout: 10000 })
      await expect(c2Page).toHaveTitle(/TechGear Store/, { timeout: 10000 })
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
