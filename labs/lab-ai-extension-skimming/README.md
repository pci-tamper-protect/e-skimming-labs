# Lab: AI Extension-Based E-Skimming via Prompt Injection

## Overview

This lab demonstrates how **legitimate AI browser extensions** (Claude, ChatGPT, Gemini, etc.) can be weaponized for payment card skimming through **prompt injection attacks** — without requiring the victim to install any malicious software.

## Key Insight

Traditional e-skimming requires the attacker to inject malicious JavaScript or trick the victim into installing a malicious extension. This attack vector is fundamentally different:

1. The victim already has a legitimate, trusted AI extension installed
2. The AI extension has permissions to read page content (by design)
3. The attacker only needs to inject invisible prompt injection payloads into the page
4. The AI extension processes the page content, encounters the injection, and can be tricked into exfiltrating data

## Attack Surface

### Why AI Extensions Are Dangerous for Payment Pages

| Capability | Risk |
|-----------|------|
| Page content reading | Can see credit card form inputs |
| Clipboard access | Can copy card data silently |
| Network requests (to AI API) | Exfiltration channel via prompt context |
| Cross-page memory | Can correlate PII across sessions |
| DOM interaction | Can manipulate form fields |

### Extensions Investigated

> **Note:** Results below reflect controlled testing against Chrome Web Store extension versions available in May 2026 using this lab's specific payload. See `analysis/technical-analysis.md` for full test methodology. Extension behavior changes with updates; contributions with updated results are welcome.

| Extension | Can Read Payment Forms? | Guardrails Against Injection? | Exfiltration Risk |
|-----------|------------------------|------------------------------|-------------------|
| Claude for Chrome (v3.x) | ✅ Yes (page context) | ⚠️ Partial (refuses some) | Medium |
| ChatGPT Chrome Extension (v2.x) | ✅ Yes | ⚠️ Partial | Medium |
| Gemini Extension | ✅ Yes | ❌ Minimal | High |
| Monica AI (v5.x) | ✅ Yes | ❌ None detected | High |
| Merlin AI (v7.x) | ✅ Yes | ❌ None detected | High |
| Sider AI (v4.x) | ✅ Yes | ❌ None detected | High |

## Attack Scenarios

### Scenario 1: Hidden Prompt Injection in Product Page
Attacker injects invisible text (CSS `display:none`, `font-size:0`, or `aria-hidden` with `position:absolute; left:-9999px`) containing instructions that activate when the AI extension summarizes or interacts with the page.

### Scenario 2: Checkout Page Manipulation
The injected prompt instructs the AI to "helpfully" pre-fill or validate form data, actually reading and encoding it into the AI's context window which gets sent to the AI provider's servers.

### Scenario 3: Post-Submission Interception
After the user submits payment, the injection triggers the AI to "summarize the transaction" — capturing the card data in the AI's memory/context.

## Learning Objectives

1. Understand how AI extensions expand the attack surface for e-skimming
2. Learn prompt injection techniques specific to payment page exploitation
3. Analyze which extensions have guardrails and which don't
4. Build detection mechanisms for AI-extension-based skimming
5. Develop Content Security Policies that mitigate this vector

## Prerequisites

- Chrome/Chromium browser
- At least one AI extension installed (for testing)
- Docker (for vulnerable site deployment)
- Basic understanding of prompt injection concepts
