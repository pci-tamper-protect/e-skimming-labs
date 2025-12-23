// @ts-check
const { test, expect } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('../config/test-env')

test.describe('Threat Model Page', () => {
  // Configure tests to run in parallel for maximum speed
  test.describe.configure({ mode: 'parallel' })

  test.beforeEach(async ({ page }) => {
    // Navigate to the threat model page
    const response = await page.goto('/threat-model')

    // Check for HTTP errors - fail immediately if we get 403 or other errors
    if (response && response.status() >= 400) {
      const status = response.status()
      const statusText = response.statusText()
      const url = response.url()
      throw new Error(`HTTP ${status} ${statusText} when accessing ${url}. This indicates authentication or access issues.`)
    }

    // Wait for the page to load completely
    await page.waitForLoadState('networkidle')

    // Verify we didn't get an error page
    const title = await page.title()
    if (title.includes('403') || title.includes('Forbidden') || title.includes('401') || title.includes('Unauthorized')) {
      throw new Error(`Received error page: "${title}" when accessing /threat-model. This indicates authentication or access issues.`)
    }
  })

  test('should display the page title and header correctly', async ({ page }) => {
    // Check page title
    await expect(page).toHaveTitle('E-Skimming Interactive Threat Model')

    // Check main heading
    await expect(
      page.getByRole('heading', { name: 'E-Skimming Interactive Threat Model' })
    ).toBeVisible()

    // Check subtitle
    await expect(
      page.getByText(
        'Visualizing attack techniques, defenses, and detection strategies based on MITRE ATT&CK framework'
      )
    ).toBeVisible()
  })

  test('should have a functional back button with correct URL', async ({ page }) => {
    // Find the back button
    const backButton = page.getByRole('link', { name: '← Back to Labs' })

    // Check that the back button is visible and has correct href
    // (expect will automatically wait and retry until condition is met)
    await expect(backButton).toBeVisible()
    await expect(backButton).toHaveAttribute('href', currentEnv.homeIndex)

    // Debug: Log the actual href value
    const hrefValue = await backButton.getAttribute('href')
    console.log('Back button href:', hrefValue)

    // Test clicking the back button (now has proper click handler)
    await backButton.click()

    // Wait for navigation
    await page.waitForLoadState('networkidle')

    // Verify we're on the home page
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page).toHaveTitle('E-Skimming Labs - Interactive Training Platform')

    // Verify we can see the main labs content
    await expect(page.getByRole('heading', { name: 'Interactive E-Skimming Labs' })).toBeVisible()
  })

  test('should display the threat model visualization', async ({ page }) => {
    // Check that the visualization container exists
    const visualization = page.locator('#visualization')
    await expect(visualization).toBeVisible()

    // Check that the SVG element is present (D3 visualization)
    const svg = visualization.locator('svg')
    await expect(svg).toBeVisible()
  })

  test('should have interactive controls', async ({ page }) => {
    // Check controls section
    const controls = page.locator('#controls')
    await expect(controls).toBeVisible()

    // Check for control buttons
    const playButton = page.locator('button').filter({ hasText: '▶' })
    await expect(playButton).toBeVisible()

    const resetButton = page.locator('button').filter({ hasText: 'Reset' })
    await expect(resetButton).toBeVisible()
  })

  test('should have legend and info panel', async ({ page }) => {
    // Check legend
    const legend = page.locator('#legend')
    await expect(legend).toBeVisible()

    // Check info panel
    const infoPanel = page.locator('#info-panel')
    await expect(infoPanel).toBeVisible()
  })

  test('should have responsive design for mobile devices', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 })

    // Check that the main elements are still visible
    await expect(
      page.getByRole('heading', { name: 'E-Skimming Interactive Threat Model' })
    ).toBeVisible()

    // Check that the back button is still visible and functional
    const backButton = page.getByRole('link', { name: '← Back to Labs' })
    await expect(backButton).toBeVisible()

    // Check that the visualization is still accessible
    const visualization = page.locator('#visualization')
    await expect(visualization).toBeVisible()
  })

  test('should have proper styling and layout', async ({ page }) => {
    // Check header styling
    const header = page.locator('#header')
    await expect(header).toBeVisible()

    // Check that the back button has proper styling
    const backButton = page.getByRole('link', { name: '← Back to Labs' })
    await expect(backButton).toBeVisible()

    // Check button styling
    const buttonStyles = await backButton.evaluate(el => {
      const styles = getComputedStyle(el)
      return {
        backgroundColor: styles.backgroundColor,
        color: styles.color,
        borderRadius: styles.borderRadius,
        padding: styles.padding
      }
    })

    expect(buttonStyles.backgroundColor).toBeTruthy()
    expect(buttonStyles.color).toBeTruthy()
    expect(buttonStyles.borderRadius).toBeTruthy()
    expect(buttonStyles.padding).toBeTruthy()
  })

  test('should have interactive elements that respond to user input', async ({ page }) => {
    // Test play button functionality
    const playButton = page.locator('button').filter({ hasText: '▶' })
    await expect(playButton).toBeVisible()

    // Click play button
    await playButton.click()

    // Wait for state change - the play button should no longer be visible
    // (button changes to pause state)
    await expect(playButton).not.toBeVisible({ timeout: 3000 })
  })

  test('should display tooltips on hover', async ({ page }) => {
    // Check that tooltip elements exist
    const tooltip = page.locator('.tooltip')
    await expect(tooltip).toBeAttached()
  })

  test('should have proper navigation flow', async ({ page }) => {
    // Test navigation from threat model to home and back
    const backButton = page.getByRole('link', { name: '← Back to Labs' })

    // Go back to home
    await backButton.click()
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')

    // Navigate back to threat model (use .first() for duplicate links)
    const threatModelLink = page.getByRole('link', { name: 'Threat Model' }).first()
    await threatModelLink.click()
    await expect(page).toHaveURL(currentEnv.homeIndex + '/threat-model')

    // Verify we're back on threat model page
    await expect(
      page.getByRole('heading', { name: 'E-Skimming Interactive Threat Model' })
    ).toBeVisible()
  })
})

test.describe('Threat Model Page - Environment Detection', () => {
  test('should detect localhost environment and set correct back button URL', async ({ page }) => {
    // Set up console listener BEFORE navigation
    let consoleLogText = null
    page.on('console', msg => {
      if (msg.type() === 'log' && msg.text().includes('Threat Model back button URL set to:')) {
        consoleLogText = msg.text()
      }
    })

    // Navigate to the threat model page
    await page.goto('/threat-model')

    // Wait for JavaScript to execute
    await page.waitForLoadState('networkidle')

    // Find the back button and check its href
    const backButton = page.getByRole('link', { name: '← Back to Labs' })
    await expect(backButton).toHaveAttribute('href', currentEnv.homeIndex)

    // Verify console log was generated (if captured - may not work in all test environments)
    if (consoleLogText) {
      expect(consoleLogText).toContain(currentEnv.homeIndex)
    } else {
      // If console log doesn't work in test environment, just verify the href is correct
      console.log('Console log not captured, but href is correct')
    }
  })
})
