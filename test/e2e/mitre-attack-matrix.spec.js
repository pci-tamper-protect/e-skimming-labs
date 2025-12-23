// @ts-check
const { test, expect } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('../config/test-env')

/**
 * Waits for smooth scroll animation to complete
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {string | null} targetSectionId - Optional: ID of target section to wait for
 * @param {number} timeout - Maximum time to wait (default: 2000ms)
 */
async function waitForScrollComplete(page, targetSectionId = null, timeout = 2000) {
  const checks = []

  // Always check if scroll position is stable
  checks.push(
    page.waitForFunction(
      () => {
        return new Promise(resolve => {
          const initialScroll = window.pageYOffset
          setTimeout(() => {
            resolve(window.pageYOffset === initialScroll)
          }, 100)
        })
      },
      { timeout }
    )
  )

  // If target section provided, also wait for it to be in viewport
  if (targetSectionId) {
    checks.push(
      page.waitForFunction(
        sectionId => {
          const element = document.getElementById(sectionId)
          if (!element) return false
          const rect = element.getBoundingClientRect()
          return rect.top >= 0 && rect.top < window.innerHeight * 0.8
        },
        targetSectionId,
        { timeout }
      )
    )
  }

  await Promise.all(checks)
}

test.describe('MITRE ATT&CK Matrix Page', () => {
  // Configure tests to run in parallel for maximum speed
  test.describe.configure({ mode: 'parallel' })

  test.beforeEach(async ({ page }) => {
    // Check if server is running by trying to access health endpoint first
    try {
      const response = await page.goto(currentEnv.homeIndex + '/health', {
        waitUntil: 'networkidle',
        timeout: 5000
      }).catch(() => null)

      if (!response || response.status() !== 200) {
        console.warn('⚠️  Server health check failed. Make sure the server is running on port 3000.')
      }
    } catch (error) {
      console.warn(`⚠️  Could not reach server at ${currentEnv.homeIndex}. Make sure the server is running.`)
    }

    // Navigate to the MITRE ATT&CK page with increased timeout
    try {
      await page.goto('/mitre-attack', {
        waitUntil: 'domcontentloaded',
        timeout: 30000
      })
    } catch (error) {
      console.error('❌ Failed to navigate to /mitre-attack')
      console.error('Error:', error.message)
      throw error
    }

    // Wait for the page to load completely
    try {
      await page.waitForLoadState('networkidle', { timeout: 30000 })
    } catch (error) {
      console.warn('⚠️  networkidle timeout, but continuing with domcontentloaded state')
    }

    // Additional wait to ensure page is fully rendered
    try {
      await page.waitForSelector('.attack-matrix, h1, nav', { timeout: 10000 })
    } catch (error) {
      console.warn('⚠️  Some selectors not found immediately, but continuing...')
      // Log page content for debugging
      const title = await page.title()
      const url = page.url()
      console.log(`Page loaded: ${url}, Title: ${title}`)
    }
  })

  test('should display the page title and header correctly', async ({ page }) => {
    // Check page title
    await expect(page).toHaveTitle('MITRE ATT&CK Matrix - E-Skimming Attacks')

    // Check main heading (use .first() for duplicate h1 and h2)
    await expect(
      page.getByRole('heading', { name: 'MITRE ATT&CK Matrix for E-Skimming' }).first()
    ).toBeVisible()

    // Check version badge
    await expect(page.getByText('v1.0')).toBeVisible()

    // Check subtitle
    await expect(
      page.getByText(
        'Comprehensive framework for understanding, detecting, and defending against e-skimming attacks'
      )
    ).toBeVisible()
  })

  test('should have a functional back button with correct URL', async ({ page }) => {
    // Find the back button
    const backButton = page.getByRole('link', { name: '← Back to Labs' })

    // Check that the back button is visible
    await expect(backButton).toBeVisible()

    // Check that the back button has the correct href for localhost (port 3000)
    await expect(backButton).toHaveAttribute('href', currentEnv.homeIndex)

    // Test clicking the back button
    await backButton.click()

    // Verify we're on the home page
    await expect(page).toHaveURL(currentEnv.homeIndex + '/')
    await expect(page).toHaveTitle('E-Skimming Labs - Interactive Training Platform')

    // Verify we can see the main labs content
    await expect(page.getByRole('heading', { name: 'Interactive E-Skimming Labs' })).toBeVisible()
  })

  test('should display the MITRE ATT&CK matrix table with correct structure', async ({ page }) => {
    // Find the matrix table
    const matrixTable = page.locator('.attack-matrix')
    await expect(matrixTable).toBeVisible()

    // Check that the table has the correct number of columns (12 tactics)
    const headerRow = matrixTable.locator('thead tr').first()
    const headerCells = headerRow.locator('th')
    await expect(headerCells).toHaveCount(12)

    // Verify all expected tactic headers are present
    const expectedTactics = [
      'Initial Access',
      'Execution',
      'Persistence',
      'Privilege Escalation',
      'Defense Evasion',
      'Credential Access',
      'Discovery',
      'Lateral Movement',
      'Collection',
      'Command and Control',
      'Exfiltration',
      'Impact'
    ]

    for (const tactic of expectedTactics) {
      await expect(headerRow.getByText(tactic)).toBeVisible()
    }
  })

  test('should display technique counts correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Check the technique count row
    const countRow = matrixTable.locator('thead tr').nth(1)
    const countCells = countRow.locator('td')

    // Verify we have exactly 12 tactic columns (MITRE ATT&CK standard)
    await expect(countCells).toHaveCount(12)

    // Use index-based selectors for reliable testing (avoids issues with duplicate counts)
    // Each assertion maps directly to a specific tactic column
    await expect(countCells.nth(0)).toHaveText('4 techniques')  // Initial Access
    await expect(countCells.nth(1)).toHaveText('1 technique')   // Execution
    await expect(countCells.nth(2)).toHaveText('4 techniques')  // Persistence
    await expect(countCells.nth(3)).toHaveText('3 techniques')  // Privilege Escalation
    await expect(countCells.nth(4)).toHaveText('9 techniques')  // Defense Evasion
    await expect(countCells.nth(5)).toHaveText('4 techniques')  // Credential Access
    await expect(countCells.nth(6)).toHaveText('6 techniques')  // Discovery
    await expect(countCells.nth(7)).toHaveText('0 techniques')  // Lateral Movement
    await expect(countCells.nth(8)).toHaveText('5 techniques')  // Collection
    await expect(countCells.nth(9)).toHaveText('1 technique')   // Command and Control
    await expect(countCells.nth(10)).toHaveText('4 techniques') // Exfiltration
    await expect(countCells.nth(11)).toHaveText('5 techniques') // Impact
  })

  test('should display techniques and sub-techniques correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Wait for the matrix table to be visible and loaded
    await expect(matrixTable).toBeVisible()
    await page.waitForSelector('.attack-matrix tbody tr td', { state: 'visible' })

    // Check Initial Access techniques
    const initialAccessCell = matrixTable.locator('tbody tr td').first()

    // Wait for content to load
    await initialAccessCell.waitFor({ state: 'visible' })

    // Verify T1190 - Exploit Public-Facing Application
    await expect(initialAccessCell.getByText('T1190')).toBeVisible({ timeout: 10000 })
    await expect(initialAccessCell.getByText('Exploit Public-Facing Application')).toBeVisible({ timeout: 10000 })

    // Verify T1078 - Valid Accounts
    await expect(initialAccessCell.getByText('T1078')).toBeVisible()
    await expect(initialAccessCell.getByText('Valid Accounts')).toBeVisible()

    // Verify T1195 - Supply Chain Compromise with sub-technique (use .first() for duplicates)
    await expect(initialAccessCell.getByText('T1195').first()).toBeVisible()
    await expect(initialAccessCell.getByText('Supply Chain Compromise')).toBeVisible()
    await expect(initialAccessCell.getByText('T1195.002')).toBeVisible()
    await expect(initialAccessCell.getByText('Compromise Software Dependencies')).toBeVisible()

    // Check Execution techniques
    const executionCell = matrixTable.locator('tbody tr td').nth(1)
    await expect(executionCell.getByText('T1059.007')).toBeVisible()
    await expect(executionCell.getByText('JavaScript Execution')).toBeVisible()

    // Check Collection techniques with sub-techniques (use .first() for duplicates)
    const collectionCell = matrixTable.locator('tbody tr td').nth(8)
    await expect(collectionCell.getByText('T1056').first()).toBeVisible()
    // Use specific selector for technique name to avoid matching "GUI Input Capture"
    await expect(collectionCell.locator('.technique-name', { hasText: 'Input Capture' })).toBeVisible()
    await expect(collectionCell.getByText('T1056.001')).toBeVisible()
    await expect(collectionCell.getByText('Keylogging')).toBeVisible()
    await expect(collectionCell.getByText('T1056.002')).toBeVisible()
    // Use specific selector for sub-technique name
    await expect(collectionCell.locator('.sub-technique-name', { hasText: 'GUI Input Capture' })).toBeVisible()
  })

  test('should have horizontal scrolling for the matrix table', async ({ page }) => {
    const matrixContainer = page.locator('.matrix-container')
    const matrixScroll = page.locator('.matrix-scroll')

    // Check that the matrix container exists
    await expect(matrixContainer).toBeVisible()
    await expect(matrixScroll).toBeVisible()

    // Check that the table has a minimum width for scrolling
    const matrixTable = page.locator('.attack-matrix')
    const tableWidth = await matrixTable.evaluate((el) => {
      if (el instanceof HTMLElement) {
        return el.offsetWidth
      }
      return 0
    })
    expect(tableWidth).toBeGreaterThan(1500) // Should be wide enough to require scrolling
  })

  test('should display technique links correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Wait for the matrix table and links to load
    await expect(matrixTable).toBeVisible()
    await page.waitForSelector('.technique-link', { state: 'visible' })

    // Check that technique links have correct styling and attributes
    const techniqueLinks = matrixTable.locator('.technique-link')
    const firstLink = techniqueLinks.first()

    await expect(firstLink).toBeVisible({ timeout: 10000 })
    await expect(firstLink).toHaveClass(/technique-link/, { timeout: 10000 })

    // Check that technique links have the correct color styling
    const linkColor = await firstLink.evaluate(el => getComputedStyle(el).color)
    expect(linkColor).toBeTruthy()
  })

  test('should display sub-technique links correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Wait for the matrix table and sub-technique links to load
    await expect(matrixTable).toBeVisible()
    await page.waitForSelector('.sub-technique-link', { state: 'visible' })

    // Find sub-technique links
    const subTechniqueLinks = matrixTable.locator('.sub-technique-link')
    await expect(subTechniqueLinks.first()).toBeVisible({ timeout: 10000 })

    // Check that sub-technique links have correct styling
    const firstSubLink = subTechniqueLinks.first()
    await expect(firstSubLink).toHaveClass(/sub-technique-link/, { timeout: 10000 })
  })

  test('should display "No techniques" message for empty tactics', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Wait for the matrix table to load
    await expect(matrixTable).toBeVisible()
    await page.waitForSelector('.attack-matrix tbody', { state: 'visible' })

    // Check that tactics with no techniques show the appropriate message
    const noTechniquesMessages = matrixTable.locator('.no-techniques')
    await expect(noTechniquesMessages).toHaveCount(1, { timeout: 10000 }) // Only shows one "No techniques" message in the matrix

    // Verify the message text
    await expect(noTechniquesMessages.first()).toContainText(
      'No techniques commonly used in e-skimming attacks',
      { timeout: 10000 }
    )
  })

  test('should have responsive design for mobile devices', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 })

    // Wait for page to adjust to new viewport
    await waitForScrollComplete(page)

    // Check that the matrix container is still visible
    const matrixContainer = page.locator('.matrix-container')
    await expect(matrixContainer).toBeVisible({ timeout: 10000 })

    // Check that the table is still accessible (should scroll horizontally)
    const matrixTable = page.locator('.attack-matrix')
    await expect(matrixTable).toBeVisible({ timeout: 10000 })

    // Verify that the back button is still visible and functional
    const backButton = page.getByRole('link', { name: '← Back to Labs' })
    await expect(backButton).toBeVisible({ timeout: 10000 })
  })

  test('should have proper navigation menu', async ({ page }) => {
    // Wait for navigation to load
    await page.waitForSelector('nav', { state: 'visible' })

    // Check that all navigation links are present
    const nav = page.locator('nav')
    await expect(nav).toBeVisible({ timeout: 10000 })

    // Check navigation links with increased timeout
    await expect(nav.getByRole('link', { name: '← Back to Labs' })).toBeVisible({ timeout: 10000 })
    await expect(nav.getByRole('link', { name: 'Overview' })).toBeVisible({ timeout: 10000 })
    await expect(nav.getByRole('link', { name: 'Tactics & Techniques' })).toBeVisible({ timeout: 10000 })
    await expect(nav.getByRole('link', { name: 'Detection' })).toBeVisible({ timeout: 10000 })
    await expect(nav.getByRole('link', { name: 'Defense' })).toBeVisible({ timeout: 10000 })
    await expect(nav.getByRole('link', { name: 'Case Studies' })).toBeVisible({ timeout: 10000 })
    await expect(nav.getByRole('link', { name: 'IOCs' })).toBeVisible({ timeout: 10000 })
  })

  test('should have smooth scrolling navigation', async ({ page }) => {
    // Wait for navigation to load
    await page.waitForSelector('nav', { state: 'visible' })

    // Test clicking on navigation links
    const overviewLink = page.getByRole('link', { name: 'Overview' })
    await expect(overviewLink).toBeVisible({ timeout: 10000 })
    await overviewLink.click()

    // Wait for scroll animation
    await waitForScrollComplete(page, 'overview')

    // Check that we scrolled to the overview section
    const overviewSection = page.locator('#overview')
    await expect(overviewSection).toBeVisible({ timeout: 10000 })

    // Test tactics link
    const tacticsLink = page.getByRole('link', { name: 'Tactics & Techniques' })
    await expect(tacticsLink).toBeVisible({ timeout: 10000 })
    await tacticsLink.click()

    // Wait for scroll animation
    await waitForScrollComplete(page, 'tactics')

    // Check that we scrolled to the tactics section
    const tacticsSection = page.locator('#tactics')
    await expect(tacticsSection).toBeVisible({ timeout: 10000 })
  })

  test('should display statistics cards correctly', async ({ page }) => {
    // Check that stats cards are visible
    const statsGrid = page.locator('.stats-grid')
    await expect(statsGrid).toBeVisible()

    // Check specific statistics (use .first() for duplicates)
    await expect(page.getByText('380K').first()).toBeVisible()
    await expect(page.getByText('British Airways Victims')).toBeVisible()

    await expect(page.getByText('£20M').first()).toBeVisible()
    await expect(page.getByText('ICO Fine (British Airways)')).toBeVisible()

    await expect(page.getByText('11K+')).toBeVisible()
    await expect(page.getByText('Sites Compromised (CosmicSting)')).toBeVisible()

    await expect(page.getByText('13+')).toBeVisible()
    await expect(page.getByText('Magecart Groups Active')).toBeVisible()
  })

  test('should have expandable sections that work correctly', async ({ page }) => {
    // Find an expandable section
    const expandableHeader = page.locator('.expandable-header').first()
    await expect(expandableHeader).toBeVisible()

    // Click to expand
    await expandableHeader.click()

    // Check that the content is now visible
    const expandableContent = page.locator('.expandable-content').first()
    await expect(expandableContent).toBeVisible()

    // Click again to collapse
    await expandableHeader.click()

    // The content should still be there but collapsed
    await expect(expandableContent).toBeAttached()
  })

  test('should have proper footer content', async ({ page }) => {
    const footer = page.locator('footer')
    await expect(footer).toBeVisible()

    // Check footer text (use partial text match for flexibility)
    await expect(footer.getByText(/MITRE ATT&CK Matrix/)).toBeVisible()
    await expect(
      footer.getByText(
        'Based on extensive research and analysis of real-world e-skimming campaigns'
      )
    ).toBeVisible()
  })

  test('should have scroll-to-top functionality', async ({ page }) => {
    // Scroll down to make the scroll-to-top button visible
    await page.evaluate(() => window.scrollTo(0, 1000))

    // Check that scroll-to-top button appears
    const scrollTopButton = page.locator('.scroll-top')
    await expect(scrollTopButton).toBeVisible()

    // Click the scroll-to-top button
    await scrollTopButton.click()

    // Wait for scroll animation to complete
    await waitForScrollComplete(page)

    // Check that we scrolled back near the top (allow some margin due to smooth scroll)
    const scrollPosition = await page.evaluate(() => window.pageYOffset)
    expect(scrollPosition).toBeLessThan(200)
  })
})

test.describe('MITRE ATT&CK Matrix - Environment Detection', () => {
  // Configure tests to run in parallel for maximum speed
  test.describe.configure({ mode: 'parallel' })

  test('should detect localhost environment and set correct back button URL', async ({ page }) => {
    // Set up console listener BEFORE navigation
    /** @type {string | null} */
    let consoleLogText = null
    page.on('console', msg => {
      if (msg.type() === 'log' && msg.text().includes('Back button URL set to:')) {
        consoleLogText = msg.text()
      }
    })

    // Navigate to the MITRE ATT&CK page
    await page.goto('/mitre-attack')

    // Wait for JavaScript to execute
    await page.waitForLoadState('networkidle')

    // Find the back button and check its href
    const backButton = page.getByRole('link', { name: '← Back to Labs' })
    await expect(backButton).toHaveAttribute('href', currentEnv.homeIndex)

    // Verify console log was generated (if captured - may not work in all test environments)
    if (consoleLogText) {
      const logText = String(consoleLogText)
      expect(logText.indexOf(currentEnv.homeIndex) >= 0).toBeTruthy()
    } else {
      // If console log doesn't work in test environment, just verify the href is correct
      console.log('Console log not captured, but href is verified correct')
    }
  })
})
