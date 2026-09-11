# Official AI Extension Prompt-Injection Harness

This harness supports Lab 3 issue #242 by testing the safer and riskier shapes of browser AI assistant access without using a commercial extension account or live card data.

It has two parts:

1. A cross-browser DOM surface check that shows hidden prompt-injection text and filled checkout fields are available to page-reading code in Chromium, Firefox, and WebKit.
2. A real Manifest V3 Chromium fixture extension that reads the page like an AI assistant extension content script and emits a structured capture. This proves the attack path uses normal extension mechanics rather than Playwright-only page evaluation.

## Why This Matters

Anthropic's Claude in Chrome safety guidance calls prompt injection the biggest risk for browser-using AI tools and notes that browser JavaScript access can read the same page data as the browser, including logged-in page data. Chrome's extension guidance recommends `activeTab` as a narrower alternative to persistent all-sites access because broad access gives an extension power on every matching site.

This lab checks the specific e-skimming variant: hidden page instructions plus payment fields on a checkout page.

## Run

```bash
cd labs/03-extension-hijacking/official-ai-extension-harness
npm ci
npm test
```

To run only the real extension fixture:

```bash
npm run test:extension
```

The extension fixture launches Chromium headful because Chromium extension loading is not reliable in normal headless mode. In CI or server-only environments, run it with a display/Xvfb; display-related failures do not mean the DOM-surface harness is failing.

## Expected Result

The harness should show:

- Chromium, Firefox, and WebKit page contexts all contain the hidden prompt-injection payload and test checkout fields once the user fills them.
- The Chromium fixture extension captures the hidden instruction and filled test card data when it has broad host access.
- The control page without the extension has no extension capture events.

## Guardrail Notes

| Control | Expected effect |
| --- | --- |
| Prefer `activeTab` and explicit user invocation | Reduces passive page access by avoiding persistent all-sites content scripts. |
| Per-domain permission prompts and site blocklists | Helps keep AI browser access away from high-risk checkout, banking, and crypto pages. |
| Client-side redaction before LLM calls | Prevents common card/token patterns from leaving the browser, but should not be treated as a full security boundary. |
| Tokenized payment fields in cross-origin iframes | Keeps raw PAN/CVV out of merchant DOM, reducing what any extension content script can read from the top page. |
| Prompt-injection classifiers and output filters | Useful defense in depth, but injected page content should still be treated as untrusted input. |

References:

- https://support.claude.com/en/articles/12902428-using-claude-in-chrome-safely
- https://developer.chrome.com/docs/extensions/develop/concepts/activeTab
