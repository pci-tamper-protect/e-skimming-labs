// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

const { currentEnv } = require(path.resolve(__dirname, '../config/test-env.js'))

test.describe('Lab 2: Card Capture via DOM Skimmer', () => {
  test('captured card appears in C2 within 2s — verified by time and CVV', async ({ page, request }) => {
    // Unique CVV per run — used to identify this specific capture
    const cvv = String(Math.floor(Math.random() * 900) + 100)
    const cardHolder = 'Jane Test'
    const billingZip = '94102'

    console.log(`\n🃏 Test CVV: ${cvv}`)

    // ── 1. Navigate to lab2 and wait for the skimmer to initialise (1s delay) ──
    await page.goto(`${currentEnv.lab2.vulnerable}/`)
    await page.waitForLoadState('networkidle')
    await page.waitForTimeout(1500)  // skimmer setTimeout fires after 1s

    // Confirm the card form is visible
    await expect(page.locator('#add-card-form')).toBeVisible()

    // ── 2. Fill the card form ─────────────────────────────────────────────────
    // banking.js formats on 'input': digits → '4242 4242 4242 4242'
    await page.fill('#card-number', '4242424242424242')
    // banking.js formats: '1228' → '12/28'
    await page.fill('#card-expiry', '1228')
    await page.fill('#card-holder-name', cardHolder)
    await page.fill('#card-cvv-input', cvv)
    await page.fill('#card-billing-zip', billingZip)

    // Verify fields before submit
    await expect(page.locator('#card-number')).toHaveValue('4242 4242 4242 4242')
    await expect(page.locator('#card-expiry')).toHaveValue('12/28')
    await expect(page.locator('#card-cvv-input')).toHaveValue(cvv)

    console.log('✅ Form filled')

    // ── 3. Submit and record the time ─────────────────────────────────────────
    const submitTime = Date.now()
    await page.click('#add-card-form button[type="submit"]')
    console.log(`📤 Submitted at ${new Date(submitTime).toISOString()}`)

    // ── 4. Wait 2 s for the skimmer POST to reach the C2 server ──────────────
    await page.waitForTimeout(2000)

    // ── 5. Query the C2 JSON API ──────────────────────────────────────────────
    const response = await request.get(`${currentEnv.lab2.c2}/api/stolen`)
    expect(response.ok()).toBeTruthy()

    const records = await response.json()
    console.log(`📋 C2 records: ${records.length}`)

    // ── 6. Find the matching capture ──────────────────────────────────────────
    const match = records.find(r => {
      if (r.type !== 'form_submission') return false

      // Time window: must have arrived after submit and within 10s
      const serverMs = new Date(r.serverTime).getTime()
      if (serverMs < submitTime || serverMs > submitTime + 10_000) return false

      // CVV must match
      const fields = Object.values(r.formData || {})
      return fields.some(f => f.value === cvv)
    })

    if (match) {
      const card = Object.values(match.formData).find(f => /cardNumber|card-number/i.test(f.fieldName))
      console.log(`✅ Matched capture — card: ${card?.value}, CVV: ${cvv}, serverTime: ${match.serverTime}`)
    }

    expect(
      match,
      `Expected a form_submission record with CVV=${cvv} arriving after ${new Date(submitTime).toISOString()} but found none.\nAll records: ${JSON.stringify(records.map(r => ({ type: r.type, serverTime: r.serverTime })), null, 2)}`
    ).toBeTruthy()

    // ── 7. Sanity-check the card number in the matched record ─────────────────
    const capturedCard = Object.values(match.formData).find(f =>
      /cardNumber|card-number/i.test(f.fieldName || '')
    )
    expect(capturedCard?.value?.replace(/\s/g, '')).toBe('4242424242424242')
    console.log('✅ Card number verified')
  })
})
