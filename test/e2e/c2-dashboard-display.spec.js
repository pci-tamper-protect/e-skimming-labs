// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

const { currentEnv, TEST_ENV } = require(path.resolve(__dirname, '../config/test-env.js'))
const { handleDangerousWarning } = require('../utils/handle-dangerous-warning')
const { skipIfAuthRedirect } = require('../utils/skip-if-auth-redirect')

// stg: skip when proxy is not configured (labs are private, not reachable)
const dashboardTests = (TEST_ENV === 'stg' && process.env.USE_PROXY !== 'true')
  ? test.describe.skip
  : test.describe

dashboardTests('C2 Dashboard Display', () => {
  test.describe.configure({ mode: 'parallel' })

  test('Lab 1: C2 dashboard shows masked card from checkout capture', async ({ page }) => {
    const cvv = String(Math.floor(Math.random() * 900) + 100)
    console.log(`\n🃏 Lab 1 test CVV: ${cvv}`)

    // ── 1. Navigate to Lab 1 checkout ──────────────────────────────────────────
    await page.goto(`${currentEnv.lab1.vulnerable}/checkout.html`)
    await page.waitForLoadState('networkidle')
    await handleDangerousWarning(page)
    await skipIfAuthRedirect(page, 'Lab 1')

    // ── 2. Fill and submit the checkout form ───────────────────────────────────
    // The skimmer script is injected dynamically with a 500ms setTimeout + 100ms poll interval.
    // networkidle fires when the script finishes downloading (~500ms after the setTimeout fires).
    // Wait an extra 800ms so the setInterval fires and attaches the submit listener.
    await page.waitForTimeout(800)
    await expect(page.locator('#payment-form')).toBeVisible()
    await page.fill('#card-number', '4242424242424242')
    await page.fill('#expiry', '1228')
    await page.fill('#cvv', cvv)

    const submitTime = Date.now()
    await page.click('.submit-btn')
    console.log(`📤 Submitted at ${new Date(submitTime).toISOString()}`)

    // ── 3. Wait for the skimmer POST to reach C2 ───────────────────────────────
    await page.waitForTimeout(2000)

    // ── 4. Navigate to C2 dashboard ────────────────────────────────────────────
    await page.goto(`${currentEnv.lab1.c2}`)
    await page.waitForLoadState('networkidle')
    await skipIfAuthRedirect(page, 'Lab 1 C2')

    // ── 5. Wait for at least one captured record to appear ─────────────────────
    await expect(page.locator('#stolenData .stolen-record').first()).toBeVisible({ timeout: 10000 })

    // ── 6. Assert counter is non-zero ──────────────────────────────────────────
    const totalText = await page.locator('#totalRecords').textContent()
    expect(parseInt(totalText || '0', 10)).toBeGreaterThan(0)
    console.log(`📊 Total records: ${totalText}`)

    // ── 7. Find the record matching this run's CVV ─────────────────────────────
    const records = page.locator('#stolenData .stolen-record')
    const count = await records.count()
    console.log(`📋 Dashboard record count: ${count}`)

    let matchFound = false
    for (let i = 0; i < count; i++) {
      const recordText = await records.nth(i).textContent() || ''
      if (recordText.includes(cvv)) {
        matchFound = true

        // Masked card: 4242****4242 (first4 + asterisks + last4)
        expect(recordText).toContain('4242')
        expect(recordText).toMatch(/4242[\s\*•]*4242/)
        expect(recordText).not.toContain('424242424242')  // raw PAN must not appear

        console.log(`✅ Matched record with CVV ${cvv}: masked card visible, raw PAN absent`)
        break
      }
    }

    expect(matchFound, `Expected a dashboard record containing CVV=${cvv} but none found in ${count} records`).toBe(true)
  })

  test('Lab 2: C2 dashboard shows masked card from DOM skimmer capture', async ({ page }) => {
    const cvv = String(Math.floor(Math.random() * 900) + 100)
    const cardHolder = 'Jane Test'
    const billingZip = '94102'
    console.log(`\n🃏 Lab 2 test CVV: ${cvv}`)

    // ── 1. Navigate to Lab 2 banking app and wait for skimmer init ─────────────
    await page.goto(`${currentEnv.lab2.vulnerable}/`)
    await page.waitForLoadState('networkidle')
    await handleDangerousWarning(page)
    await skipIfAuthRedirect(page, 'Lab 2')

    await page.waitForTimeout(1500)  // skimmer setTimeout fires after 1s

    // ── 2. Fill and submit the add-card form ───────────────────────────────────
    await expect(page.locator('#add-card-form')).toBeVisible()
    await page.fill('#card-number', '4242424242424242')
    await page.fill('#card-expiry', '1228')
    await page.fill('#card-holder-name', cardHolder)
    await page.fill('#card-cvv-input', cvv)
    await page.fill('#card-billing-zip', billingZip)

    const submitBtn = page.locator('#add-card-form button[type="submit"]')
    await submitBtn.scrollIntoViewIfNeeded()
    const submitTime = Date.now()
    await submitBtn.click({ force: true })
    console.log(`📤 Submitted at ${new Date(submitTime).toISOString()}`)

    // ── 3. Wait for the skimmer POST to reach C2 ───────────────────────────────
    await page.waitForTimeout(2000)

    // ── 4. Navigate to C2 dashboard ────────────────────────────────────────────
    await page.goto(`${currentEnv.lab2.c2}`)
    await page.waitForLoadState('networkidle')
    await skipIfAuthRedirect(page, 'Lab 2 C2')

    // ── 5. Wait for at least one attack record to appear ──────────────────────
    await expect(page.locator('#recentData .attack-record').first()).toBeVisible({ timeout: 10000 })

    // ── 6. Assert attack counter is non-zero ───────────────────────────────────
    const totalText = await page.locator('#totalAttacks').textContent()
    expect(parseInt(totalText || '0', 10)).toBeGreaterThan(0)
    console.log(`📊 Total attacks: ${totalText}`)

    // ── 7. Find the record matching this run's CVV ─────────────────────────────
    const records = page.locator('#recentData .attack-record')
    const count = await records.count()
    console.log(`📋 Dashboard record count: ${count}`)

    let matchFound = false
    for (let i = 0; i < count; i++) {
      const recordText = await records.nth(i).textContent() || ''
      if (recordText.includes(cvv)) {
        matchFound = true

        // Masked card: 4242****4242
        expect(recordText).toContain('4242')
        expect(recordText).toMatch(/4242[\s\*•]*4242/)
        expect(recordText).not.toContain('424242424242')  // raw PAN must not appear

        console.log(`✅ Matched record with CVV ${cvv}: masked card visible, raw PAN absent`)
        break
      }
    }

    expect(matchFound, `Expected a dashboard record containing CVV=${cvv} but none found in ${count} records`).toBe(true)
  })
})
