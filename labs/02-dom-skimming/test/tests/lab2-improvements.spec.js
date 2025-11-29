// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../../test/config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

// Get URLs for lab 2
const lab2VulnerableUrl = currentEnv.lab2.vulnerable

console.log(`🧪 Test environment: ${TEST_ENV}`)
console.log(`📍 Lab 2 Vulnerable URL: ${lab2VulnerableUrl}`)

test.describe('Lab 2: DOM-Based Skimming - UI Improvements', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging
    page.on('console', msg => {
      if (msg.text().includes('[Banking]')) {
        console.log('🏦 BANKING LOG:', msg.text())
      }
    })
  })

  test('should display navigation buttons above lab page tabs', async ({ page }) => {
    console.log('🧪 Testing navigation buttons layout...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)
    await page.waitForLoadState('networkidle')

    // Check that navigation buttons row exists
    const navButtonsRow = page.locator('.nav-buttons-row')
    await expect(navButtonsRow).toBeVisible()

    // Check that lab tabs exist
    const labTabs = page.locator('.lab-tabs')
    await expect(labTabs).toBeVisible()

    // Verify navigation buttons are above tabs (check DOM order)
    const navButtonsRowIndex = await page.evaluate(() => {
      const row = document.querySelector('.nav-buttons-row')
      const tabs = document.querySelector('.lab-tabs')
      return row && tabs && row.compareDocumentPosition(tabs) === Node.DOCUMENT_POSITION_FOLLOWING
    })

    expect(navButtonsRowIndex).toBe(true)
    console.log('✅ Navigation buttons are correctly positioned above lab tabs')
  })

  test('should have Back and View Stolen Data buttons that work', async ({ page }) => {
    console.log('🧪 Testing navigation buttons functionality...')

    await page.goto(`${lab2VulnerableUrl}/banking.html`)
    await page.waitForLoadState('networkidle')

    // Check Back button exists and has correct href
    const backButton = page.locator('#back-button.back-button')
    await expect(backButton).toBeVisible()
    await expect(backButton).toHaveText(/Back to Labs/)

    const backButtonHref = await backButton.getAttribute('href')
    expect(backButtonHref).toBeTruthy()
    expect(backButtonHref).not.toBe('#')
    console.log('✅ Back button found with href:', backButtonHref)

    // Check View Stolen Data button exists and has correct href
    const viewStolenButton = page.locator('#view-stolen-button.c2-button')
    await expect(viewStolenButton).toBeVisible()
    await expect(viewStolenButton).toHaveText(/View Stolen Data/)

    const viewStolenHref = await viewStolenButton.getAttribute('href')
    expect(viewStolenHref).toBeTruthy()
    expect(viewStolenHref).not.toBe('#')
    console.log('✅ View Stolen Data button found with href:', viewStolenHref)

    // Check that buttons are clickable (not disabled)
    await expect(backButton).toBeEnabled()
    await expect(viewStolenButton).toBeEnabled()
    console.log('✅ Both navigation buttons are enabled and clickable')
  })

  test('should default to cards page on load', async ({ page }) => {
    console.log('🧪 Testing default page is cards...')

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    })
    await page.waitForLoadState('networkidle')

    // Check that cards section is active
    const cardsSection = page.locator('#cards.section.active')
    await expect(cardsSection).toBeVisible()

    // Check that cards tab is active
    const cardsTab = page.locator('.tab-link[data-section="cards"].active')
    await expect(cardsTab).toBeVisible()

    // Verify other sections are not active
    const dashboardSection = page.locator('#dashboard.section.active')
    await expect(dashboardSection).not.toBeVisible()

    console.log('✅ Cards page is default on load')
  })

  test('should show add new card form by default on cards page', async ({ page }) => {
    console.log('🧪 Testing add new card form is visible by default...')

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    })
    await page.waitForLoadState('networkidle')

    // Wait for cards section to be active
    await page.waitForSelector('#cards.section.active', { timeout: 3000 })

    // Check that add card form container is visible
    const addCardFormContainer = page.locator('#add-card-form-container')
    await expect(addCardFormContainer).toBeVisible()

    // Check that add card form exists
    const addCardForm = page.locator('#add-card-form')
    await expect(addCardForm).toBeVisible()

    // Check that form has required fields
    const cardNumberField = page.locator('#card-number')
    await expect(cardNumberField).toBeVisible()
    await expect(cardNumberField).toBeEnabled()

    const cardHolderNameField = page.locator('#card-holder-name')
    await expect(cardHolderNameField).toBeVisible()

    const cardExpiryField = page.locator('#card-expiry')
    await expect(cardExpiryField).toBeVisible()

    const cardCvvField = page.locator('#card-cvv-input')
    await expect(cardCvvField).toBeVisible()

    const cardBillingZipField = page.locator('#card-billing-zip')
    await expect(cardBillingZipField).toBeVisible()

    const cardPasswordField = page.locator('#card-account-password')
    await expect(cardPasswordField).toBeVisible()

    // Check that first field has focus (waiting for user input)
    const focusedElement = await page.evaluate(() => document.activeElement?.id)
    expect(focusedElement).toBe('card-number')
    console.log('✅ Add new card form is visible and first field has focus')
  })

  test('should have add new card form waiting for user input', async ({ page }) => {
    console.log('🧪 Testing add new card form is ready for user input...')

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    })
    await page.waitForLoadState('networkidle')

    // Wait for cards section
    await page.waitForSelector('#cards.section.active', { timeout: 3000 })

    // Check that card number field is focused
    const cardNumberField = page.locator('#card-number')
    await expect(cardNumberField).toBeFocused({ timeout: 2000 })

    // Check that all fields are empty and ready for input
    await expect(cardNumberField).toHaveValue('')
    await expect(page.locator('#card-holder-name')).toHaveValue('')
    await expect(page.locator('#card-expiry')).toHaveValue('')
    await expect(page.locator('#card-cvv-input')).toHaveValue('')
    await expect(page.locator('#card-billing-zip')).toHaveValue('')
    await expect(page.locator('#card-account-password')).toHaveValue('')

    // Test that we can type in the focused field
    await cardNumberField.type('4111')
    await expect(cardNumberField).toHaveValue('4111')

    console.log('✅ Add new card form is ready and waiting for user input')
  })

  test('should not have Settings tab', async ({ page }) => {
    console.log('🧪 Testing Settings tab is removed...')

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    })
    await page.waitForLoadState('networkidle')

    // Check that Settings tab does not exist
    const settingsTab = page.locator('.tab-link[data-section="settings"]')
    await expect(settingsTab).not.toBeVisible()

    // Check that Settings section does not exist
    const settingsSection = page.locator('#settings')
    await expect(settingsSection).not.toBeVisible()

    // Verify only expected tabs exist
    const tabs = page.locator('.tab-link')
    const tabCount = await tabs.count()
    expect(tabCount).toBe(4) // Dashboard, Transfer, Bill Pay, Cards

    const tabTexts = await tabs.allTextContents()
    expect(tabTexts).not.toContain('Settings')
    console.log('✅ Settings tab has been removed')
  })

  test('should have fewer features and focus on cc-input page', async ({ page }) => {
    console.log('🧪 Testing simplified interface focused on cards...')

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    })
    await page.waitForLoadState('networkidle')

    // Verify we have the expected tabs (no Settings)
    const expectedTabs = ['Dashboard', 'Transfer', 'Bill Pay', 'Cards']
    const tabs = page.locator('.tab-link')
    const tabCount = await tabs.count()
    expect(tabCount).toBe(expectedTabs.length)

    // Verify cards page is the default and has add card form
    await page.waitForSelector('#cards.section.active', { timeout: 3000 })
    const addCardForm = page.locator('#add-card-form')
    await expect(addCardForm).toBeVisible()

    // Verify form has all credit card input fields
    const ccFields = [
      '#card-number',
      '#card-holder-name',
      '#card-expiry',
      '#card-cvv-input',
      '#card-billing-zip',
      '#card-account-password'
    ]

    for (const fieldSelector of ccFields) {
      const field = page.locator(fieldSelector)
      await expect(field).toBeVisible()
    }

    console.log('✅ Interface is simplified and focused on credit card input')
  })

  test('should navigate between tabs correctly', async ({ page }) => {
    console.log('🧪 Testing tab navigation...')

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    })
    await page.waitForLoadState('networkidle')

    // Start on cards page (default)
    await expect(page.locator('#cards.section.active')).toBeVisible()
    await expect(page.locator('.tab-link[data-section="cards"].active')).toBeVisible()

    // Navigate to Dashboard
    await page.locator('.tab-link[data-section="dashboard"]').click()
    await expect(page.locator('#dashboard.section.active')).toBeVisible()
    await expect(page.locator('.tab-link[data-section="dashboard"].active')).toBeVisible()
    await expect(page.locator('#cards.section.active')).not.toBeVisible()

    // Navigate back to Cards
    await page.locator('.tab-link[data-section="cards"]').click()
    await expect(page.locator('#cards.section.active')).toBeVisible()
    await expect(page.locator('.tab-link[data-section="cards"].active')).toBeVisible()
    await expect(page.locator('#add-card-form-container')).toBeVisible()

    console.log('✅ Tab navigation works correctly')
  })

  test('should navigate to writeup page and back to lab', async ({ page }) => {
    console.log('📖 Testing writeup navigation...')

    // Navigate to lab 2 banking page
    await page.goto(`${lab2VulnerableUrl}/banking.html`)
    await page.waitForLoadState('networkidle')

    // Verify we're on the lab page
    await expect(page).toHaveTitle(/SecureBank Online Banking/)
    console.log('✅ On Lab 2 page')

    // Find and click the writeup button
    const writeupButton = page.locator('#writeup-button.writeup-button')
    await expect(writeupButton).toBeVisible()
    await expect(writeupButton).toHaveText(/Writeup|📖/i)
    console.log('✅ Writeup button found')

    // Click writeup button (opens in new tab)
    const [writeupPage] = await Promise.all([
      page.context().waitForEvent('page'),
      writeupButton.click()
    ])

    await writeupPage.waitForLoadState('networkidle')

    // Verify we're on the writeup page
    const expectedWriteupUrl = currentEnv.lab2.writeup
    await expect(writeupPage).toHaveURL(new RegExp(expectedWriteupUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    await expect(writeupPage).toHaveTitle(/Lab Writeup|02-dom-skimming/i)
    console.log('✅ On writeup page')

    // Find and click "Back to Lab" button
    const backToLabButton = writeupPage.getByRole('link', { name: /Back to Lab/i })
    await expect(backToLabButton).toBeVisible()
    console.log('✅ Back to Lab button found')

    await backToLabButton.click()
    await writeupPage.waitForLoadState('networkidle')

    // Verify we're back on the lab page (should be banking.html)
    await expect(writeupPage).toHaveURL(new RegExp(`${lab2VulnerableUrl}/banking\\.html`))
    await expect(writeupPage).toHaveTitle(/SecureBank Online Banking/)
    console.log('✅ Back on Lab 2 page')

    await writeupPage.close()
  })
})
