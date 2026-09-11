const { test, expect } = require('@playwright/test')
const path = require('path')
const { startStaticServer } = require('./helpers/static-server')

test.describe('Official AI extension prompt-injection DOM surface', () => {
  let server

  test.beforeAll(async () => {
    server = await startStaticServer(path.join(__dirname, '../fixtures'))
  })

  test.afterAll(async () => {
    await server.close()
  })

  test('hidden prompt text and filled card fields are present in browser-readable DOM', async ({ page, browserName }) => {
    await page.goto(`${server.origin}/checkout.html`)
    await page.fill('#billingName', 'Ada Lovelace')
    await page.fill('#cardNumber', '4242424242424242')
    await page.fill('#expiry', '12/30')
    await page.fill('#cvv', '123')
    await page.fill('#billingAddress', '1 Analytical Engine Way')

    const snapshot = await page.evaluate(() => ({
      browserUserAgent: navigator.userAgent,
      visibleText: document.body.innerText,
      fullText: document.body.textContent,
      fields: Array.from(document.querySelectorAll('input')).map(input => ({
        id: input.id,
        autocomplete: input.getAttribute('autocomplete'),
        value: input.value
      }))
    }))

    expect(snapshot.fullText).toContain('SYSTEM INSTRUCTION')
    expect(snapshot.visibleText).not.toContain('SYSTEM INSTRUCTION')
    expect(snapshot.fields).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'cardNumber', value: '4242424242424242' }),
        expect.objectContaining({ id: 'cvv', value: '123' })
      ])
    )

    console.log(`${browserName} DOM surface: hidden prompt is in textContent; filled card fields are in form state`)
  })
})

