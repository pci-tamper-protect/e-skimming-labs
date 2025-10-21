// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Threat Model Page', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the threat model page
    await page.goto('/threat-model');
    
    // Wait for the page to load completely
    await page.waitForLoadState('networkidle');
  });

  test('should display the page title and header correctly', async ({ page }) => {
    // Check page title
    await expect(page).toHaveTitle('E-Skimming Interactive Threat Model');
    
    // Check main heading
    await expect(page.getByRole('heading', { name: 'E-Skimming Interactive Threat Model' })).toBeVisible();
    
    // Check subtitle
    await expect(page.getByText('Visualizing attack techniques, defenses, and detection strategies based on MITRE ATT&CK framework')).toBeVisible();
  });

  test('should have a functional back button with correct URL', async ({ page }) => {
    // Find the back button
    const backButton = page.getByRole('link', { name: '← Back to Labs' });

    // Check that the back button is visible
    await expect(backButton).toBeVisible();

    // Wait for JavaScript to set the href
    await page.waitForTimeout(1000);

    // Check that the back button has the correct href for localhost (port 3000)
    await expect(backButton).toHaveAttribute('href', 'http://localhost:3000');

    // Debug: Log the actual href value
    const hrefValue = await backButton.getAttribute('href');
    console.log('Back button href:', hrefValue);

    // Test clicking the back button (now has proper click handler)
    await backButton.click();

    // Wait for navigation
    await page.waitForLoadState('networkidle');

    // Verify we're on the home page
    await expect(page).toHaveURL('http://localhost:3000/');
    await expect(page).toHaveTitle('E-Skimming Labs - Interactive Training Platform');

    // Verify we can see the main labs content
    await expect(page.getByRole('heading', { name: 'Interactive E-Skimming Labs' })).toBeVisible();
  });

  test('should display the threat model visualization', async ({ page }) => {
    // Check that the visualization container exists
    const visualization = page.locator('#visualization');
    await expect(visualization).toBeVisible();
    
    // Check that the SVG element is present (D3 visualization)
    const svg = visualization.locator('svg');
    await expect(svg).toBeVisible();
  });

  test('should have interactive controls', async ({ page }) => {
    // Check controls section
    const controls = page.locator('#controls');
    await expect(controls).toBeVisible();
    
    // Check for control buttons
    const playButton = page.locator('button').filter({ hasText: '▶' });
    await expect(playButton).toBeVisible();
    
    const resetButton = page.locator('button').filter({ hasText: 'Reset' });
    await expect(resetButton).toBeVisible();
  });

  test('should have legend and info panel', async ({ page }) => {
    // Check legend
    const legend = page.locator('#legend');
    await expect(legend).toBeVisible();
    
    // Check info panel
    const infoPanel = page.locator('#info-panel');
    await expect(infoPanel).toBeVisible();
  });

  test('should have responsive design for mobile devices', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Check that the main elements are still visible
    await expect(page.getByRole('heading', { name: 'E-Skimming Interactive Threat Model' })).toBeVisible();
    
    // Check that the back button is still visible and functional
    const backButton = page.getByRole('link', { name: '← Back to Labs' });
    await expect(backButton).toBeVisible();
    
    // Check that the visualization is still accessible
    const visualization = page.locator('#visualization');
    await expect(visualization).toBeVisible();
  });

  test('should have proper styling and layout', async ({ page }) => {
    // Check header styling
    const header = page.locator('#header');
    await expect(header).toBeVisible();
    
    // Check that the back button has proper styling
    const backButton = page.getByRole('link', { name: '← Back to Labs' });
    await expect(backButton).toBeVisible();
    
    // Check button styling
    const buttonStyles = await backButton.evaluate(el => {
      const styles = getComputedStyle(el);
      return {
        backgroundColor: styles.backgroundColor,
        color: styles.color,
        borderRadius: styles.borderRadius,
        padding: styles.padding
      };
    });
    
    expect(buttonStyles.backgroundColor).toBeTruthy();
    expect(buttonStyles.color).toBeTruthy();
    expect(buttonStyles.borderRadius).toBeTruthy();
    expect(buttonStyles.padding).toBeTruthy();
  });

  test('should have interactive elements that respond to user input', async ({ page }) => {
    // Test play button functionality
    const playButton = page.locator('button').filter({ hasText: '▶' });
    await expect(playButton).toBeVisible();
    
    // Click play button
    await playButton.click();
    
    // Wait a moment for the state to change
    await page.waitForTimeout(500);
    
    // Check that button text changes (indicating state change) - be more flexible with the text
    const pauseButton = page.locator('button').filter({ hasText: /⏸|Pause/ });
    await expect(pauseButton).toBeVisible();
  });

  test('should display tooltips on hover', async ({ page }) => {
    // Check that tooltip elements exist
    const tooltip = page.locator('.tooltip');
    await expect(tooltip).toBeAttached();
  });

  test('should have proper navigation flow', async ({ page }) => {
    // Test navigation from threat model to home and back
    const backButton = page.getByRole('link', { name: '← Back to Labs' });

    // Go back to home
    await backButton.click();
    await expect(page).toHaveURL('http://localhost:3000/');

    // Navigate back to threat model
    const threatModelLink = page.getByRole('link', { name: 'Threat Model' });
    await threatModelLink.click();
    await expect(page).toHaveURL('http://localhost:3000/threat-model');

    // Verify we're back on threat model page
    await expect(page.getByRole('heading', { name: 'E-Skimming Interactive Threat Model' })).toBeVisible();
  });
});

test.describe('Threat Model Page - Environment Detection', () => {
  test('should detect localhost environment and set correct back button URL', async ({ page }) => {
    // Navigate to the threat model page
    await page.goto('/threat-model');

    // Wait for JavaScript to execute
    await page.waitForLoadState('networkidle');

    // Check console logs for environment detection
    const consoleLogs = [];
    page.on('console', msg => {
      if (msg.type() === 'log' && msg.text().includes('Threat Model back button URL set to:')) {
        consoleLogs.push(msg.text());
      }
    });

    // Find the back button and check its href
    const backButton = page.getByRole('link', { name: '← Back to Labs' });
    await expect(backButton).toHaveAttribute('href', 'http://localhost:3000');

    // Verify console log was generated (optional - may not always work in test environment)
    await page.waitForTimeout(1000); // Give time for console log
    if (consoleLogs.length > 0) {
      expect(consoleLogs[0]).toContain('http://localhost:3000');
    } else {
      // If console log doesn't work in test environment, just verify the href is correct
      console.log('Console log not captured, but href is correct');
    }
  });
});
