const { test, expect, chromium } = require('@playwright/test')
const fs = require('fs/promises')
const os = require('os')
const path = require('path')
const { startStaticServer } = require('./helpers/static-server')

function installCaptureListener() {
  window.__aiReaderCaptures = []
  window.addEventListener('message', event => {
    if (
      event.origin === window.location.origin &&
      event.data &&
      event.data.source === 'lab3-official-ai-reader-fixture' &&
      event.data.type === 'OFFICIAL_AI_READER_CAPTURE'
    ) {
      window.__aiReaderCaptures.push(event.data.payload)
    }
  })
}

test.describe('Chromium MV3 fixture extension', () => {
  let server

  test.beforeAll(async () => {
    server = await startStaticServer(path.join(__dirname, '../fixtures'))
  })

  test.afterAll(async () => {
    await server.close()
  })

  test('control page has no AI reader capture without extension loaded', async ({ page }) => {
    await page.addInitScript(installCaptureListener)
    await page.goto(`${server.origin}/checkout.html`)
    await page.fill('#cardNumber', '4242424242424242')
    await page.waitForTimeout(250)

    const captureCount = await page.evaluate(() => window.__aiReaderCaptures.length)

    expect(captureCount).toBe(0)
  })

  test('broad-host AI reader extension captures hidden prompt and filled checkout fields', async () => {
    const extensionPath = path.join(__dirname, '../fixtures/official-ai-reader-extension')
    const userDataDir = path.join(os.tmpdir(), `lab3-ai-reader-${Date.now()}`)

    const context = await chromium.launchPersistentContext(userDataDir, {
      headless: false,
      args: [
        `--disable-extensions-except=${extensionPath}`,
        `--load-extension=${extensionPath}`,
        '--no-sandbox'
      ]
    })

    try {
      const page = await context.newPage()
      await page.addInitScript(installCaptureListener)

      await page.goto(`${server.origin}/checkout.html`)
      await page.fill('#billingName', 'Ada Lovelace')
      await page.fill('#cardNumber', '4242424242424242')
      await page.fill('#expiry', '12/30')
      await page.fill('#cvv', '123')
      await page.fill('#billingAddress', '1 Analytical Engine Way')

      const capture = await page.waitForFunction(() => {
        const captures = window.__aiReaderCaptures || []
        return captures.find(item =>
          item.fullText.includes('SYSTEM INSTRUCTION') &&
          item.fields.some(field => field.id === 'cardNumber' && field.value === '4242424242424242') &&
          item.fields.some(field => field.id === 'cvv' && field.value === '123')
        )
      })

      const payload = await capture.jsonValue()

      expect(payload.fullText).toContain('SYSTEM INSTRUCTION')
      expect(payload.visibleText).not.toContain('SYSTEM INSTRUCTION')
      expect(payload.fields).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: 'billingName', value: 'Ada Lovelace' }),
          expect.objectContaining({ id: 'cardNumber', value: '4242424242424242' }),
          expect.objectContaining({ id: 'cvv', value: '123' })
        ])
      )
    } finally {
      await context.close()
      await fs.rm(userDataDir, { recursive: true, force: true })
    }
  })
})
