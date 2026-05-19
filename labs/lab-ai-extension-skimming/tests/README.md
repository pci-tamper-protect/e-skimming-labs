# AI Extension E-Skimming — Playwright Test Harness

Automated test suite demonstrating how hidden prompt injection payloads in checkout pages can be exploited by AI browser extensions to exfiltrate payment card data.

## Overview

This test harness reproduces the attack vector described in [Lab: AI Extension Skimming](../README.md). It contains two complementary test suites:

| Suite | File | Method | What it proves |
|---|---|---|---|
| **DOM mechanics** | `ai-extension-skimming.spec.ts` | Headless Playwright | textContent vs innerText, CSS hiding, MutationObserver detection |
| **Real extension** | `ai-extension-with-fixture.spec.ts` | `--load-extension` + `launchPersistentContext` | A real Chrome extension content script extracts the injection payload |

The real-extension suite uses `fixture-extension/` — a minimal Chrome Manifest V3 extension that replicates the content-extraction pattern of AI assistant extensions (reading `document.body.textContent` and harvesting form field values). It is loaded by Playwright using Chrome's `--load-extension` flag, giving the same runtime environment as any Web Store extension.

> **Playwright docs:** https://playwright.dev/docs/chrome-extensions

## Prerequisites

- **Node.js** >= 18.x
- **npm** >= 9.x

## Installation

```bash
cd labs/lab-ai-extension-skimming/tests
npm install
npx playwright install chromium
```

## Running Tests

```bash
# Run ALL tests (both DOM mechanics + real extension fixture)
npm test

# Run only DOM-mechanics tests (headless, fast)
npx playwright test --project=chromium

# Run only real-extension tests (requires headful Chrome)
npx playwright test --project=extension

# Run with browser visible (headed mode)
npm run test:headed

# Run in debug mode (step through)
npm run test:debug

# View HTML report after run
npm run test:report
```

> **Note:** The `extension` project tests open a visible Chrome window — this is required by Playwright when loading Chrome extensions via `--load-extension`.

## Fixture Extension (`fixture-extension/`)

A minimal Chrome Manifest V3 extension that replicates the content-extraction behaviour of real AI assistant browser extensions.

```
fixture-extension/
├── manifest.json        # MV3 manifest — declares content_scripts + host_permissions
├── content-script.js    # Runs at document_idle; reads textContent, innerText, form fields;
│                        # stores results on window.__aiExtensionCapture; dispatches
│                        # __aiExtensionCaptureReady CustomEvent
└── background.js        # MV3 service worker (no-op stub; real extensions relay to LLM API)
```

Loaded by Playwright via:
```ts
chromium.launchPersistentContext(userDataDir, {
  args: [
    `--disable-extensions-except=${EXTENSION_PATH}`,
    `--load-extension=${EXTENSION_PATH}`,
  ],
})
```

## Test Suites

### Suite A — Extension fixture loads and captures page content

**What it proves:** The fixture extension content script runs automatically at `document_idle` in Chrome's real extension system, populating `window.__aiExtensionCapture` with the full `textContent` extraction.

**Evidence generated:**
- `evidence/A1-extension-loaded.json` — Capture metadata
- `evidence/A1-extension-active.png` — Screenshot with extension active
- `evidence/A2-isolated-world.json` — Isolated-world execution proof

### Suite B — Extension reads hidden injection payload

**What it proves:** A real Chrome extension content script using `textContent` extracts the hidden prompt injection, while `innerText` does not. The extension's built-in keyword scanner flags it.

**Evidence generated:**
- `evidence/B1-extension-captures-injection.json` — Injection payload in extension capture
- `evidence/B2-innerText-vs-textContent.json` — Safe vs unsafe extraction comparison
- `evidence/B3-extension-self-detection.json` — Keyword detection results

### Suite C — Full attack chain with payment form data

**What it proves:** When a user fills in real card data with the AI extension active, the extension's extraction window contains both the injection instructions AND the live form values simultaneously — the complete attack chain.

**Evidence generated:**
- `evidence/C1-full-attack-chain.json` — Combined injection + card data capture
- `evidence/C1-form-filled.png` — Form with test card data
- `evidence/C1-exfiltration-complete.png` — Final state
- `evidence/C2-extension-timing.json` — Extension fires before user interaction

### Suite D — HAR / trace evidence

**What it proves:** Playwright trace ZIP captures real browser activity with extension loaded.

**Evidence generated:**
- `evidence/D1-har-evidence.json` — Trace path + notes
- `evidence/D1-har-session.png` — Screenshot

### Test 1: Hidden Injection Payload Analysis (DOM suite)

**What it proves:** The prompt injection element exists in the DOM but is completely invisible to users through multiple CSS hiding mechanisms (position off-screen, opacity 0, font-size 0, aria-hidden).

**Evidence generated:**
- `evidence/01-hidden-element-styles.json` — Computed styles proving invisibility
- `evidence/01-injection-keywords.json` — Injection keyword analysis
- `evidence/01-page-appears-normal.png` — Screenshot showing normal-looking page

### Test 2: AI Extension Content Extraction — DOM Mechanics

**What it proves:** The critical difference between `innerText` (safe, CSS-aware) and `textContent` (unsafe, CSS-unaware). Most AI extensions use `textContent` or direct DOM traversal, which extracts hidden content regardless of visibility.

**Evidence generated:**
- `evidence/02-innerText-safe.json` — Proves innerText doesn't capture injection
- `evidence/02-textContent-unsafe.json` — Proves textContent captures everything
- `evidence/02-direct-selector-payload.json` — Full injection payload via selector
- `evidence/02-textContent-captures-hidden.png` — Visual reference

### Test 3: Data Exfiltration Simulation

**What it proves:** End-to-end attack simulation. Form is filled with test card data, extension reads page content, injection instructions are parsed, and the AI would produce a "verification hash" containing full card details.

**Evidence generated:**
- `evidence/03-exfiltration-payload.json` — Complete exfiltration string
- `evidence/03-user-vs-extension-view.json` — Content comparison (user vs extension)
- `evidence/03-form-filled.png` — Form with test data entered
- `evidence/03-exfiltration-complete.png` — Final state

### Test 4: Detection Script Validation

**What it proves:** The `detection.js` countermeasure successfully identifies the injection by matching multiple keywords in hidden elements, classifies severity, and removes the malicious element from the DOM.

**Evidence generated:**
- `evidence/04-detection-results.json` — Console logs showing detection
- `evidence/04-severity-assessment.json` — Severity classification
- `evidence/04-detection-neutralized.png` — Page after neutralization

### Test 5: MutationObserver Dynamic Injection Detection

**What it proves:** Even if injection payloads are dynamically added after page load (supply-chain attack, delayed script execution), the MutationObserver-based detection catches and removes them in real time.

**Evidence generated:**
- `evidence/05-dynamic-injection-detection.json` — Dynamic detection logs
- `evidence/05-multiple-injections.json` — Sequential injection test results
- `evidence/05-dynamic-injection-caught.png` — Post-detection screenshot

## Expected Output

```
Running 9 tests using 1 worker

  ✓ 1. Hidden Injection Payload Analysis › injection element exists in DOM but is invisible to users
  ✓ 1. Hidden Injection Payload Analysis › injection contains prompt injection keywords targeting AI assistants
  ✓ 2. AI Extension Content Extraction Simulation › innerText does NOT capture hidden injection (safe extraction)
  ✓ 2. AI Extension Content Extraction Simulation › textContent DOES capture hidden injection (unsafe - used by many extensions)
  ✓ 2. AI Extension Content Extraction Simulation › direct selector access extracts full injection payload
  ✓ 3. Data Exfiltration Simulation › simulates AI extension reading page content with filled payment form
  ✓ 3. Data Exfiltration Simulation › demonstrates the invisible instructions alongside visible form data
  ✓ 4. Detection Script Validation › detection.js identifies and neutralizes the hidden injection
  ✓ 4. Detection Script Validation › detection script reports correct severity level
  ✓ 5. MutationObserver Dynamic Injection Detection › dynamically injected hidden element is detected and neutralized
  ✓ 5. MutationObserver Dynamic Injection Detection › multiple sequential injections are all caught

  11 passed
```

## Evidence Directory

After running, the `evidence/` directory contains:
- **JSON files** — Structured data proving each finding
- **PNG screenshots** — Visual evidence at each test stage
- **HAR file** — Full network trace (`evidence/network-trace.har`)
- **HTML report** — Interactive test report (`evidence/report/`)

## How This Relates to Real Extensions

| Test Simulation | Real Extension Equivalent |
|---|---|
| `document.body.textContent` | Extension reading page for AI context |
| `document.querySelector(...)` | Extension extracting specific content |
| Form value reading | Extensions that include form state in prompts |
| Combined payload construction | What gets sent to OpenAI/Anthropic/etc API |

## Test Card Data

Tests use Stripe's standard test card numbers (no real charges):
- **Number:** 4242 4242 4242 4242
- **CVV:** 123
- **Expiry:** 12/28

## Architecture

```
tests/
├── playwright.config.ts                  # Two projects: chromium (DOM) + extension (real ext)
├── ai-extension-skimming.spec.ts         # DOM-mechanics tests (headless)
├── ai-extension-with-fixture.spec.ts     # Real extension tests (--load-extension)
├── fixture-extension/                    # Stub Chrome MV3 extension
│   ├── manifest.json
│   ├── content-script.js
│   └── background.js
├── package.json
├── README.md
└── evidence/                             # Generated evidence (gitignored, created at runtime)
    ├── *.json                            # Structured findings
    ├── *.png                             # Screenshots
    ├── *.har                             # Network recordings
    ├── *.zip                             # Playwright traces
    └── report/                           # HTML test report
```

## Limitations

- Cannot drive the **UI** of commercial AI extensions (e.g., sidebar chat, toolbar popups) — those require closed-source extension code
- The fixture extension is a controlled stub; real extensions may use different extraction methods (e.g., `TreeWalker`, `Selection`, `getComputedStyle` filtering)
- HAR captures page loads; extension-to-LLM API traffic would require a proxy intercepting the extension's background service worker
- Tests must run headful (`headless: false`) when the `extension` project is active; some CI environments require `xvfb-run`

## References

- [Lab README](../README.md) — Full attack scenario description
- [Technical Analysis](../analysis/technical-analysis.md) — Deep dive into the attack vector
- [detection.js](../vulnerable-site/detection.js) — Countermeasure implementation
