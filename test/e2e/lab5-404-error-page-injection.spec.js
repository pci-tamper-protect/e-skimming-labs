// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

const { currentEnv } = require(path.resolve(__dirname, '../config/test-env.js'))

test.describe('Lab 5: 404 Error Page Injection', () => {
  test('missing script is served as fallback JavaScript and records a masked capture', async ({
    page
  }) => {
    await page.goto(`${currentEnv.lab5.vulnerable}/`)
    await page.waitForLoadState('domcontentloaded')

    if (page.url().includes('/sign-in')) {
      console.log('Lab 5 redirected to sign-in; skipping unauthenticated run')
      test.skip()
      return
    }

    const missingScriptUrl = `${currentEnv.lab5.vulnerable}/js/vendor/analytics-cart.js`
    const scriptResponse = await page.request.get(missingScriptUrl)
    expect(scriptResponse.status()).toBe(200)
    expect(scriptResponse.headers()['content-type']).toContain('application/javascript')
    expect(scriptResponse.headers()['x-content-type-options']).toBe('nosniff')
    expect(scriptResponse.headers()['cache-control']).toContain('no-store')

    const scriptBody = await scriptResponse.text()
    expect(scriptBody).toContain('404-error-page-injection')
    expect(scriptBody).toContain('/lab5/c2/collect')

    const suffix = String(Math.floor(Math.random() * 9000) + 1000)
    const cardNumber = `411111111111${suffix}`
    const maskedCard = `4111 **** **** ${suffix}`

    const collectResponsePromise = page.waitForResponse(
      response =>
        response.url().includes('/lab5/c2/collect') && response.request().method() === 'POST'
    )

    await page.fill('input[name="cardholder"]', 'Lab Five Tester')
    await page.fill('input[name="cardNumber"]', cardNumber)
    await page.fill('input[name="expiry"]', '12/30')
    await page.fill('input[name="cvv"]', '123')
    await page.getByRole('button', { name: 'Place demo order' }).click()

    const collectResponse = await collectResponsePromise
    expect(collectResponse.ok()).toBeTruthy()

    await expect(page.locator('#checkout-result')).toContainText('Demo order accepted')

    const recordsResponse = await page.evaluate(async url => {
      const resp = await fetch(url, { credentials: 'include' })
      if (!resp.ok) throw new Error(`Lab 5 C2 API returned HTTP ${resp.status}`)
      return resp.json()
    }, `${currentEnv.lab5.c2}/api/stolen`)

    const records = Array.isArray(recordsResponse.records) ? recordsResponse.records : []
    const match = records.find(
      record => record.source === '404-error-page-injection' && record.masked_card === maskedCard
    )

    expect(
      match,
      `Expected a masked Lab 5 capture, got: ${JSON.stringify(recordsResponse)}`
    ).toBeTruthy()
    expect(match.cvv_present).toBe(true)
    expect(match.expiry_present).toBe(true)
    expect(match.cardholder_present).toBe(true)
  })
})
