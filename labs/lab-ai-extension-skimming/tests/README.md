# AI Extension E-Skimming — Playwright Test Harness

Automated test suite demonstrating how hidden prompt injection payloads in checkout pages can be exploited by AI browser extensions to exfiltrate payment card data.

## Overview

This test harness reproduces the attack vector described in [Lab: AI Extension Skimming](../README.md). It uses Playwright to simulate the behavior of AI browser extensions that read page content, demonstrating how invisible prompt injection payloads hidden via CSS can be extracted and used to steal card data.

> **Note:** These tests simulate extension behavior programmatically. Playwright cannot control real browser extensions, but the DOM access patterns used here are identical to what extensions like AI assistants, summarizers, and copilots perform.

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
# Run all tests
npm test

# Run with browser visible (headed mode)
npm run test:headed

# Run in debug mode (step through)
npm run test:debug

# View HTML report after run
npm run test:report
```

## Test Structure

### Test 1: Hidden Injection Payload Analysis

**What it proves:** The prompt injection element exists in the DOM but is completely invisible to users through multiple CSS hiding mechanisms (position off-screen, opacity 0, font-size 0, aria-hidden).

**Evidence generated:**
- `evidence/01-hidden-element-styles.json` — Computed styles proving invisibility
- `evidence/01-injection-keywords.json` — Injection keyword analysis
- `evidence/01-page-appears-normal.png` — Screenshot showing normal-looking page

### Test 2: AI Extension Content Extraction Simulation

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
├── playwright.config.ts      # Test configuration (HAR, screenshots, local server)
├── ai-extension-skimming.spec.ts  # Main test suite (11 tests)
├── package.json              # Dependencies
├── README.md                 # This file
└── evidence/                 # Generated evidence (gitignored, created at runtime)
    ├── *.json                # Structured findings
    ├── *.png                 # Screenshots
    ├── network-trace.har     # Network recording
    └── report/               # HTML test report
```

## Limitations

- Cannot test actual browser extension behavior (Chrome extension APIs not available in Playwright)
- Simulates DOM access patterns that extensions use rather than running real extension code
- HAR captures page loads but not extension-to-API traffic (would require extension proxy)
- Detection timing may vary slightly between runs

## References

- [Lab README](../README.md) — Full attack scenario description
- [Technical Analysis](../analysis/technical-analysis.md) — Deep dive into the attack vector
- [detection.js](../vulnerable-site/detection.js) — Countermeasure implementation
