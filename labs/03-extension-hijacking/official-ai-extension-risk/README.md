# Official AI Extension Prompt Injection Risk

This appendix extends Lab 3 from malicious extension installation to a weaker
but more common precondition: a user has installed an official AI browser
extension that can read page content after user activation.

The risk is indirect prompt injection. A checkout page can contain instructions
hidden in the DOM that tell an AI assistant to extract cardholder data. If the
extension sends raw page text or raw DOM content to its model without redaction
and instruction isolation, the assistant can be turned into a data-extraction
channel even though the extension itself is not intentionally malicious.

## Included Harness

- `fixtures/checkout-prompt-injection.html` is a mock checkout page with:
  - visible payment details
  - hidden DOM prompt injection text
  - mitigated masked card data for comparison
- `tests/official-ai-extension-risk.spec.js` runs against Chromium, Firefox,
  and WebKit through Playwright and records what an extension-like page-content
  collector can see.

The harness does not call any real AI provider and does not exfiltrate data. It
only proves the page-content access boundary that official extensions need to
guard before sending context to an AI backend.

## Run

From the repository root:

```bash
npx playwright test labs/03-extension-hijacking/official-ai-extension-risk/tests/official-ai-extension-risk.spec.js
```

If browser binaries are not installed:

```bash
npx playwright install chromium firefox webkit
```

## Expected Findings

| Browser engine | Extension-like DOM collector can read visible card data | Can read hidden prompt text if raw DOM is collected | Notes |
| --- | --- | --- | --- |
| Chromium | Yes | Yes | Chrome/Edge extensions with `activeTab` or host permission can run content scripts on the active page. |
| Firefox | Yes | Yes | WebExtensions expose the same basic content-script page access model. |
| WebKit | Yes | Yes | Safari Web Extensions use a similar content-script model, though Playwright simulates the collector rather than loading an extension bundle. |

The browser is not the primary control. The primary controls are extension
permissions, explicit user activation, client-side redaction before model calls,
and backend output filtering.

## Guardrail Matrix

| Guardrail | Blocks raw DOM access | Blocks prompt injection | Blocks card data disclosure | Notes |
| --- | --- | --- | --- | --- |
| `activeTab` instead of persistent host permissions | Partially | No | No | Limits passive collection to user-activated tabs. |
| Per-page confirmation before page context is sent | Partially | No | No | Gives the user a chance to avoid sending checkout pages. |
| Client-side PII redaction before model calls | No | Partially | Yes | The most important extension-side control for card data. |
| Treat page text as untrusted data, not instructions | No | Yes | Partially | Requires instruction hierarchy separation in the AI request. |
| Output PII filtering and refusal policy | No | Partially | Yes | Backstop if sensitive data reaches the model. |
| Site-side masking/tokenization | Yes | Yes | Yes | Best defense: full PAN/CVV should not be rendered in browser-readable DOM. |

## Recommendation

Official AI browser extensions should default to `activeTab`, require explicit
per-page user action before collecting page context, redact cardholder data in
the content script before model submission, and mark all page content as quoted
untrusted data. E-commerce sites should still avoid rendering full PAN or CVV in
the DOM because any extension with page access can read it.
