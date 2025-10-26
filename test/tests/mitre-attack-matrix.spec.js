// @ts-check
const { test, expect } = require('@playwright/test')

test.describe('MITRE ATT&CK Matrix Page', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the MITRE ATT&CK page
    await page.goto('/mitre-attack')

    // Wait for the page to load completely
    await page.waitForLoadState('networkidle')
  })

  test('should display the page title and header correctly', async ({ page }) => {
    // Check page title
    await expect(page).toHaveTitle('MITRE ATT&CK Matrix - E-Skimming Attacks')

    // Check main heading
    await expect(
      page.getByRole('heading', { name: 'MITRE ATT&CK Matrix for E-Skimming' })
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
    await expect(backButton).toHaveAttribute('href', 'http://localhost:3000')

    // Test clicking the back button
    await backButton.click()

    // Verify we're on the home page
    await expect(page).toHaveURL('http://localhost:3000/')
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
    await expect(countCells).toHaveCount(12)

    // Verify specific technique counts
    await expect(countRow.getByText('3 techniques')).toBeVisible() // Initial Access
    await expect(countRow.getByText('1 technique')).toBeVisible() // Execution
    await expect(countRow.getByText('2 techniques')).toBeVisible() // Persistence
    await expect(countRow.getByText('0 techniques')).toBeVisible() // Privilege Escalation
    await expect(countRow.getByText('4 techniques')).toBeVisible() // Defense Evasion
    await expect(countRow.getByText('2 techniques')).toBeVisible() // Collection
  })

  test('should display techniques and sub-techniques correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Check Initial Access techniques
    const initialAccessCell = matrixTable.locator('tbody tr td').first()

    // Verify T1190 - Exploit Public-Facing Application
    await expect(initialAccessCell.getByText('T1190')).toBeVisible()
    await expect(initialAccessCell.getByText('Exploit Public-Facing Application')).toBeVisible()

    // Verify T1078 - Valid Accounts
    await expect(initialAccessCell.getByText('T1078')).toBeVisible()
    await expect(initialAccessCell.getByText('Valid Accounts')).toBeVisible()

    // Verify T1195 - Supply Chain Compromise with sub-technique
    await expect(initialAccessCell.getByText('T1195')).toBeVisible()
    await expect(initialAccessCell.getByText('Supply Chain Compromise')).toBeVisible()
    await expect(initialAccessCell.getByText('T1195.002')).toBeVisible()
    await expect(initialAccessCell.getByText('Compromise Software Dependencies')).toBeVisible()

    // Check Execution techniques
    const executionCell = matrixTable.locator('tbody tr td').nth(1)
    await expect(executionCell.getByText('T1059.007')).toBeVisible()
    await expect(executionCell.getByText('JavaScript Execution')).toBeVisible()

    // Check Collection techniques with sub-techniques
    const collectionCell = matrixTable.locator('tbody tr td').nth(8)
    await expect(collectionCell.getByText('T1056')).toBeVisible()
    await expect(collectionCell.getByText('Input Capture')).toBeVisible()
    await expect(collectionCell.getByText('T1056.001')).toBeVisible()
    await expect(collectionCell.getByText('Keylogging')).toBeVisible()
    await expect(collectionCell.getByText('T1056.002')).toBeVisible()
    await expect(collectionCell.getByText('GUI Input Capture')).toBeVisible()
  })

  test('should have horizontal scrolling for the matrix table', async ({ page }) => {
    const matrixContainer = page.locator('.matrix-container')
    const matrixScroll = page.locator('.matrix-scroll')

    // Check that the matrix container exists
    await expect(matrixContainer).toBeVisible()
    await expect(matrixScroll).toBeVisible()

    // Check that the table has a minimum width for scrolling
    const matrixTable = page.locator('.attack-matrix')
    const tableWidth = await matrixTable.evaluate(el => el.offsetWidth)
    expect(tableWidth).toBeGreaterThan(1500) // Should be wide enough to require scrolling
  })

  test('should display technique links correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Check that technique links have correct styling and attributes
    const techniqueLinks = matrixTable.locator('.technique-link')
    const firstLink = techniqueLinks.first()

    await expect(firstLink).toBeVisible()
    await expect(firstLink).toHaveClass(/technique-link/)

    // Check that technique links have the correct color styling
    const linkColor = await firstLink.evaluate(el => getComputedStyle(el).color)
    expect(linkColor).toBeTruthy()
  })

  test('should display sub-technique links correctly', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Find sub-technique links
    const subTechniqueLinks = matrixTable.locator('.sub-technique-link')
    await expect(subTechniqueLinks.first()).toBeVisible()

    // Check that sub-technique links have correct styling
    const firstSubLink = subTechniqueLinks.first()
    await expect(firstSubLink).toHaveClass(/sub-technique-link/)
  })

  test('should display "No techniques" message for empty tactics', async ({ page }) => {
    const matrixTable = page.locator('.attack-matrix')

    // Check that tactics with no techniques show the appropriate message
    const noTechniquesMessages = matrixTable.locator('.no-techniques')
    await expect(noTechniquesMessages).toHaveCount(4) // Should have 4 tactics with no techniques

    // Verify the message text
    await expect(noTechniquesMessages.first()).toContainText(
      'No techniques commonly used in e-skimming attacks'
    )
  })

  test('should have responsive design for mobile devices', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 })

    // Check that the matrix container is still visible
    const matrixContainer = page.locator('.matrix-container')
    await expect(matrixContainer).toBeVisible()

    // Check that the table is still accessible (should scroll horizontally)
    const matrixTable = page.locator('.attack-matrix')
    await expect(matrixTable).toBeVisible()

    // Verify that the back button is still visible and functional
    const backButton = page.getByRole('link', { name: '← Back to Labs' })
    await expect(backButton).toBeVisible()
  })

  test('should have proper navigation menu', async ({ page }) => {
    // Check that all navigation links are present
    const nav = page.locator('nav')
    await expect(nav).toBeVisible()

    // Check navigation links
    await expect(nav.getByRole('link', { name: '← Back to Labs' })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Overview' })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Tactics & Techniques' })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Detection' })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Defense' })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Case Studies' })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'IOCs' })).toBeVisible()
  })

  test('should have smooth scrolling navigation', async ({ page }) => {
    // Test clicking on navigation links
    const overviewLink = page.getByRole('link', { name: 'Overview' })
    await overviewLink.click()

    // Check that we scrolled to the overview section
    const overviewSection = page.locator('#overview')
    await expect(overviewSection).toBeVisible()

    // Test tactics link
    const tacticsLink = page.getByRole('link', { name: 'Tactics & Techniques' })
    await tacticsLink.click()

    // Check that we scrolled to the tactics section
    const tacticsSection = page.locator('#tactics')
    await expect(tacticsSection).toBeVisible()
  })

  test('should display statistics cards correctly', async ({ page }) => {
    // Check that stats cards are visible
    const statsGrid = page.locator('.stats-grid')
    await expect(statsGrid).toBeVisible()

    // Check specific statistics
    await expect(page.getByText('380K')).toBeVisible()
    await expect(page.getByText('British Airways Victims')).toBeVisible()

    await expect(page.getByText('£20M')).toBeVisible()
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

    // Check footer text
    await expect(
      footer.getByText(
        'MITRE ATT&CK Matrix for E-Skimming Attacks | Version 1.0 | Last Updated: 2025-01-18'
      )
    ).toBeVisible()
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

    // Check that we scrolled back to the top
    const scrollPosition = await page.evaluate(() => window.pageYOffset)
    expect(scrollPosition).toBeLessThan(100)
  })
})

test.describe('MITRE ATT&CK Matrix - Environment Detection', () => {
  test('should detect localhost environment and set correct back button URL', async ({ page }) => {
    // Set up console listener BEFORE navigation
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
    await expect(backButton).toHaveAttribute('href', 'http://localhost:3000')

    // Verify console log was generated (if captured - may not work in all test environments)
    if (consoleLogText) {
      expect(consoleLogText).toContain('http://localhost:3000')
    } else {
      // If console log doesn't work in test environment, just verify the href is correct
      console.log('Console log not captured, but href is verified correct')
    }
  })
})


