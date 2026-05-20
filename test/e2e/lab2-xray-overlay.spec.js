// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

const { currentEnv } = require(path.resolve(__dirname, '../config/test-env.js'))

test.describe('Lab 2: Form Overlay X-Ray variant', () => {
  // Shared auth-skip helper
  async function gotoXray(page) {
    await page.goto(`${currentEnv.lab2.vulnerable}/?variant=form-overlay-xray`)
    await page.waitForLoadState('networkidle')
    if (page.url().includes('/sign-in')) {
      console.log('⏭️  Lab 2 redirected to sign-in — skipping (set TEST_USER_EMAIL_* to run with auth)')
      test.skip()
      return false
    }
    // 600ms script timeout + rendering headroom
    await page.waitForTimeout(1200)
    return true
  }

  test('xray sheen appears over the cards form', async ({ page }) => {
    if (!await gotoXray(page)) return

    // Sheen and badge are visible
    await expect(page.locator('#xray-sheen')).toBeVisible()
    await expect(page.locator('.xray-badge')).toContainText('SKIMMER LAYER')

    // At least one field tag present
    const tags = page.locator('.xray-field-tag')
    await expect(tags.first()).toBeVisible()
    const tagCount = await tags.count()
    console.log(`🔍 Field tags visible: ${tagCount}`)
    expect(tagCount).toBeGreaterThanOrEqual(1)

    // Sheen overlaps the add-card-form (top within ±50px)
    const [sheenBox, formBox] = await Promise.all([
      page.locator('#xray-sheen').boundingBox(),
      page.locator('#add-card-form').boundingBox(),
    ])
    expect(sheenBox).not.toBeNull()
    expect(formBox).not.toBeNull()
    expect(sheenBox.width).toBeGreaterThan(0)
    expect(sheenBox.height).toBeGreaterThan(0)
    expect(Math.abs(sheenBox.top - formBox.top)).toBeLessThan(50)
    console.log(`✅ Sheen at (${sheenBox.left.toFixed(0)}, ${sheenBox.top.toFixed(0)}) — form at (${formBox.left.toFixed(0)}, ${formBox.top.toFixed(0)})`)
  })

  test('opacity slider persists across tab switch', async ({ page }) => {
    if (!await gotoXray(page)) return

    await expect(page.locator('#xray-sheen')).toBeVisible()

    // Set opacity to 0.4 via the JS API (same as the slider wiring does)
    await page.evaluate(() => window.xrayOverlay.setOpacity(0.4))
    const opacityBefore = await page.evaluate(() =>
      document.getElementById('xray-sheen')?.style.opacity
    )
    expect(opacityBefore).toBe('0.4')
    console.log('✅ Opacity set to 0.4')

    // Switch to Transfer tab — triggers MutationObserver → placeSheen()
    await page.click('.tab-link[data-section="transfer"]')
    await page.waitForTimeout(500)

    // Switch back to Cards tab
    await page.click('.tab-link[data-section="cards"]')
    await page.waitForTimeout(800)

    await expect(page.locator('#xray-sheen')).toBeVisible()

    const opacityAfter = await page.evaluate(() =>
      document.getElementById('xray-sheen')?.style.opacity
    )
    expect(opacityAfter).toBe('0.4')
    console.log(`✅ Opacity preserved after tab switch: ${opacityAfter}`)
  })

  test('form submit sends form_overlay_capture to C2', async ({ page }) => {
    if (!await gotoXray(page)) return

    const cvv = String(Math.floor(Math.random() * 900) + 100)
    console.log(`\n🃏 Test CVV: ${cvv}`)

    await expect(page.locator('#add-card-form')).toBeVisible()

    await page.fill('#card-number', '4242424242424242')
    await page.fill('#card-expiry', '1228')
    await page.fill('#card-holder-name', 'Jane XRay')
    await page.fill('#card-cvv-input', cvv)
    await page.fill('#card-billing-zip', '94102')

    await expect(page.locator('#card-number')).toHaveValue('4242 4242 4242 4242')
    console.log('✅ Form filled')

    const submitBtn = page.locator('#add-card-form button[type="submit"]')
    await submitBtn.scrollIntoViewIfNeeded()
    const submitTime = Date.now()
    await submitBtn.click({ force: true })
    console.log(`📤 Submitted at ${new Date(submitTime).toISOString()}`)

    // Wait for sendBeacon to reach the C2
    await page.waitForTimeout(2000)

    const records = await page.evaluate(async (url) => {
      const resp = await fetch(url, { credentials: 'include' })
      if (!resp.ok) throw new Error(`C2 API returned HTTP ${resp.status}`)
      return resp.json()
    }, `${currentEnv.lab2.c2}/api/stolen`)
    console.log(`📋 C2 records: ${records.length}`)

    const match = records.find(r => {
      if (r.type !== 'form_overlay_capture' || r.variant !== 'xray') return false
      const serverMs = new Date(r.serverTime).getTime()
      if (serverMs < submitTime || serverMs > submitTime + 10_000) return false
      // CVV must appear somewhere in the captured data
      return JSON.stringify(r.data || {}).includes(cvv)
    })

    if (match) {
      console.log(`✅ Matched xray capture — CVV: ${cvv}, serverTime: ${match.serverTime}`)
    }

    expect(
      match,
      `Expected a form_overlay_capture/xray record with CVV=${cvv} after ${new Date(submitTime).toISOString()}.\nAll records: ${JSON.stringify(records.map(r => ({ type: r.type, variant: r.variant, serverTime: r.serverTime })), null, 2)}`
    ).toBeTruthy()
  })
})
