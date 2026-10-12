// @ts-check
const { test, expect } = require('@playwright/test')
const fs = require('fs')
const path = require('path')
const { spawn } = require('child_process')

const serverDir = path.resolve(
  __dirname,
  '../../malicious-code/c2-server'
)
const tempDataDir = path.resolve(__dirname, '../tmp/google-analytics-csp-bypass-data')
const c2BaseUrl = 'http://127.0.0.1:3100'
const c2ApiUrl = `${c2BaseUrl}/api/stolen`

let c2Process = null

function loadVariantAsset(relativePath) {
  return fs.readFileSync(path.join(__dirname, relativePath), 'utf8')
}

function injectVariantJs(htmlContent, jsContent) {
  return htmlContent.replace(
    '<script src="js/checkout-compromised.js"></script>',
    `<script>${jsContent}</script>`
  )
}

async function loadVariantPage(page, htmlContent, jsContent) {
  await page.goto(`${c2BaseUrl}/`)
  await page.setContent(injectVariantJs(htmlContent, jsContent), {
    waitUntil: 'networkidle'
  })
}

async function waitForC2Health() {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const response = await fetch(`${c2BaseUrl}/health`)
      if (response.ok) {
        return
      }
    } catch (error) {
      // Server is still starting.
    }

    await new Promise(resolve => setTimeout(resolve, 250))
  }

  throw new Error('C2 server did not become ready in time')
}

test.describe('Lab 1: Google Analytics CSP Bypass Variant', () => {
  test.describe.configure({ mode: 'serial' })

  test.beforeAll(async () => {
    fs.rmSync(tempDataDir, { recursive: true, force: true })
    fs.mkdirSync(tempDataDir, { recursive: true })

    c2Process = spawn(
      'node',
      ['server.js'],
      {
        cwd: serverDir,
        env: {
          ...process.env,
          PORT: '3100',
          DATA_DIR: tempDataDir
        },
        stdio: 'inherit'
      }
    )

    await waitForC2Health()
  })

  test.afterAll(async () => {
    if (c2Process) {
      c2Process.kill()
      c2Process = null
    }
  })

  test.beforeEach(async ({ page }) => {
    await page.route('**/lab1/c2/collect', async route => {
      await route.continue({
        url: `${c2BaseUrl}/collect`
      })
    })
  })

  test('should complete checkout and decode analytics-shaped exfiltration on C2', async ({
    page
  }) => {
    const htmlContent = loadVariantAsset(
      '../../variants/google-analytics-csp-bypass/vulnerable-site/checkout.html'
    )
    const jsContent = loadVariantAsset(
      '../../variants/google-analytics-csp-bypass/vulnerable-site/js/checkout-compromised.js'
    )

    await loadVariantPage(page, htmlContent, jsContent)

    await page.fill('#card-number', '4000000000000002')
    await page.fill('#cardholder-name', 'Analytics Test 用户')
    await page.fill('#expiry', '12/28')
    await page.fill('#cvv', '123')
    await page.fill('#email', 'analytics@test.example')
    await page.fill('#billing-address', '42 Measurement Way São')
    await page.fill('#city', 'Signal City 東京')
    await page.fill('#zip', '94105')
    await page.selectOption('#country', 'US')
    await page.fill('#phone', '+1 (555) 222-3333')

    await page.click('button[type="submit"]')

    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 })

    let testRecord = null
    for (let attempt = 0; attempt < 10; attempt++) {
      await page.waitForTimeout(1000)
      const response = await page.request.get(c2ApiUrl)
      if (!response.ok()) continue

      const records = await response.json()
      testRecord = records.find(record => {
        const cardNumber = record.cardNumber ? record.cardNumber.replace(/[\s-]/g, '') : ''
        return (
          cardNumber === '4000000000000002' &&
          record.metadata?.collectionMethod === 'google-analytics-csp-bypass-variant'
        )
      })

      if (testRecord) break
    }

    expect(testRecord).toBeTruthy()
    expect(testRecord.analytics?.provider).toBe('google-analytics')
    expect(testRecord.analytics?.measurementId).toBe('G-LABGA42')
    expect(testRecord.analytics?.eventName).toBe('purchase')
    expect(testRecord.server?.receiveMode).toBe('analytics-envelope')
  })

  test('should send an analytics-shaped envelope instead of raw card JSON', async ({ page }) => {
    const requests = []
    const htmlContent = loadVariantAsset(
      '../../variants/google-analytics-csp-bypass/vulnerable-site/checkout.html'
    )
    const jsContent = loadVariantAsset(
      '../../variants/google-analytics-csp-bypass/vulnerable-site/js/checkout-compromised.js'
    )

    page.on('request', request => {
      if (request.url().includes('/collect')) {
        requests.push({
          url: request.url(),
          method: request.method(),
          postData: request.postData()
        })
      }
    })

    await loadVariantPage(page, htmlContent, jsContent)

    await page.fill('#card-number', '5555555555554444')
    await page.fill('#cardholder-name', 'Envelope Test Åsa')
    await page.fill('#expiry', '03/27')
    await page.fill('#cvv', '789')
    await page.fill('#email', 'envelope@test.example')
    await page.fill('#billing-address', '7 Event Label Road')
    await page.fill('#city', 'Payload City')
    await page.fill('#zip', '10001')

    await page.click('button[type="submit"]')
    await page.waitForResponse(response => response.url().includes('/collect'), {
      timeout: 10000
    })

    expect(requests.length).toBeGreaterThan(0)

    const envelope = JSON.parse(requests[0].postData || '{}')
    expect(envelope.analyticsEnvelope).toBe(true)
    expect(envelope.provider).toBe('google-analytics')
    expect(envelope.measurementId).toBe('G-LABGA42')
    expect(envelope.eventName).toBe('purchase')
    expect(typeof envelope.params?.event_label).toBe('string')

    const decodedPayload = JSON.parse(
      Buffer.from(envelope.params.event_label, 'base64').toString('utf8')
    )
    expect(decodedPayload.cardNumber.replace(/[\s-]/g, '')).toBe('5555555555554444')
    expect(decodedPayload.metadata.collectionMethod).toBe('google-analytics-csp-bypass-variant')
  })

  test('should contain Google Analytics abuse signatures in variant code', async () => {
    const jsContent = loadVariantAsset(
      '../../variants/google-analytics-csp-bypass/vulnerable-site/js/checkout-compromised.js'
    )

    expect(jsContent.includes("window.gtag('event'")).toBe(true)
    expect(jsContent.includes('analyticsEnvelope')).toBe(true)
    expect(jsContent.includes('event_label')).toBe(true)
    expect(jsContent.includes('measurementId')).toBe(true)
    expect(jsContent.includes('google-analytics-csp-bypass-variant')).toBe(true)
  })
})
