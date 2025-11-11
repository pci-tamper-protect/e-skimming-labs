/**
 * Handle Dangerous Warning Page
 * 
 * This utility function detects and handles Chrome's dangerous site warning page.
 * It clicks "Details" and then clicks "this unsafe site" link if the warning is present.
 * 
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @returns {Promise<boolean>} - Returns true if warning was handled, false if not present
 */
async function handleDangerousWarning(page) {
  try {
    // Check if the dangerous warning page is present
    // Look for the details button or the proceed link
    const detailsButton = page.locator('#details-button')
    const proceedLink = page.locator('#proceed-link')
    
    // Check if either element is visible (with short timeout)
    const isDetailsVisible = await detailsButton.isVisible({ timeout: 2000 }).catch(() => false)
    const isProceedVisible = await proceedLink.isVisible({ timeout: 2000 }).catch(() => false)
    
    if (isDetailsVisible || isProceedVisible) {
      console.log('[Playwright] Dangerous warning page detected, handling...')
      
      // If details button is visible, click it first to expand the details
      if (isDetailsVisible) {
        await detailsButton.click({ timeout: 5000 })
        // Wait a bit for the details to expand
        await page.waitForTimeout(500)
      }
      
      // Click the "this unsafe site" link to proceed
      if (await proceedLink.isVisible({ timeout: 2000 }).catch(() => false)) {
        await proceedLink.click({ timeout: 5000 })
        // Wait for navigation to complete
        await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {})
        console.log('[Playwright] Successfully bypassed dangerous warning')
        return true
      }
    }
    
    return false
  } catch (error) {
    // If any error occurs, just continue - the warning might not be present
    console.log('[Playwright] No dangerous warning detected or error handling it:', error.message)
    return false
  }
}

module.exports = { handleDangerousWarning }

