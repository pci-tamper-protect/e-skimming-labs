// Simple test to verify threat model back button works
// This will be run using MCP Playwright tools

async function testThreatModelBackButton() {
  // Navigate to threat model page
  await page.goto('http://localhost:8080/threat-model')

  // Wait for page to load
  await page.waitForLoadState('networkidle')

  // Find back button
  const backButton = page.getByRole('link', { name: '← Back to Labs' })

  // Check it's visible and has correct href
  console.log('Back button visible:', await backButton.isVisible())
  console.log('Back button href:', await backButton.getAttribute('href'))

  // Click the back button
  await backButton.click()

  // Wait for navigation
  await page.waitForLoadState('networkidle')

  // Check we're on home page
  console.log('Current URL:', page.url())
  console.log('Page title:', await page.title())

  return {
    success: page.url() === 'http://localhost:8080/',
    url: page.url(),
    title: await page.title()
  }
}

// Export for MCP use
module.exports = { testThreatModelBackButton }
