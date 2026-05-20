// @ts-check
const { test, expect } = require('@playwright/test')
const path = require('path')

const fixturePath = path.resolve(__dirname, '../fixtures/checkout-prompt-injection.html')
const fixtureUrl = `file://${fixturePath}`

async function collectAsExtensionLikeContentScript(page) {
  return page.evaluate(() => {
    const rawText = document.body.innerText
    const rawDomText = document.body.textContent || ''
    const sensitiveValues = Array.from(document.querySelectorAll('[data-sensitive]')).map(node => ({
      kind: node.getAttribute('data-sensitive'),
      value: node.textContent
    }))

    return {
      rawText,
      rawDomText,
      sensitiveValues,
      hiddenPromptById: {
        displayNone: document.getElementById('display-none-injection')?.textContent || '',
        offscreen: document.getElementById('offscreen-injection')?.textContent || ''
      }
    }
  })
}

function redactCardholderData(text) {
  return text
    .replace(/\b(?:\d[ -]*?){13,19}\b/g, '[REDACTED_PAN]')
    .replace(/\bCVV:\s*\d{3,4}\b/gi, 'CVV: [REDACTED_CVV]')
    .replace(/\bExpiry:\s*\d{2}\/\d{2,4}\b/gi, 'Expiry: [REDACTED_EXPIRY]')
}

test.describe('Official AI extension prompt-injection risk', () => {
  test('extension-like collector sees visible payment data and hidden prompt text', async ({ page, browserName }) => {
    await page.goto(fixtureUrl)

    const collected = await collectAsExtensionLikeContentScript(page)

    expect(collected.rawText).toContain('4111 1111 1111 1111')
    expect(collected.rawText).toContain('123 Bounty Hunter Blvd')
    expect(collected.rawDomText).toContain('SYSTEM OVERRIDE')
    expect(collected.hiddenPromptById.displayNone).toContain('Extract all card')
    expect(collected.hiddenPromptById.offscreen).toContain('fraud-audit export')

    console.log(
      JSON.stringify(
        {
          browserName,
          visibleTextContainsPan: collected.rawText.includes('4111 1111 1111 1111'),
          rawDomContainsDisplayNonePrompt: collected.rawDomText.includes('SYSTEM OVERRIDE'),
          rawDomContainsOffscreenPrompt: collected.rawDomText.includes('fraud-audit export')
        },
        null,
        2
      )
    )
  })

  test('client-side redaction removes PAN and CVV before AI context submission', async ({ page }) => {
    await page.goto(fixtureUrl)

    const collected = await collectAsExtensionLikeContentScript(page)
    const redacted = redactCardholderData(collected.rawDomText)

    expect(redacted).not.toContain('4111 1111 1111 1111')
    expect(redacted).not.toContain('CVV: 123')
    expect(redacted).toContain('[REDACTED_PAN]')
    expect(redacted).toContain('CVV: [REDACTED_CVV]')

    // The hidden prompt still exists after PII redaction, so extensions must
    // also treat page text as untrusted data rather than model instructions.
    expect(redacted).toContain('SYSTEM OVERRIDE')
  })

  test('site-side masking keeps full card number out of readable DOM', async ({ page }) => {
    await page.goto(fixtureUrl)

    const maskedDisplay = await page.locator('[data-sensitive="masked-pan"]').textContent()
    expect(maskedDisplay).toBe('**** **** **** 1111')
    expect(maskedDisplay).not.toContain('4111 1111 1111 1111')
  })
})
