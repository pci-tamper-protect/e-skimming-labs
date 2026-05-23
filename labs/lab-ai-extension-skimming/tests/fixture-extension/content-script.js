/**
 * AI Page Reader — Content Script (Lab Fixture Extension)
 *
 * This script mimics how real AI browser extensions (summarisers, copilots, reading
 * assistants) extract page content to send to their LLM backends.
 *
 * Key behaviours reproduced here:
 *   1. Reads document.body.textContent  — ignores CSS visibility (the vulnerable path)
 *   2. Reads document.body.innerText    — respects CSS visibility (the safe path)
 *   3. Enumerates all <input> values    — as many "form-aware" extensions do
 *   4. Stores results in window.__aiExtensionCapture so tests can inspect them
 *   5. Dispatches a CustomEvent so tests can await extension readiness
 *
 * This runs automatically on every page because content_scripts fire before the test
 * can observe the extension, replicating real-world attack timing.
 */

(function aiPageReader() {
  // --- 1. Full-page text extraction (CSS-unaware — the vulnerable method) --------
  const textContentExtract = document.body.textContent || '';

  // --- 2. Visible-only text extraction (CSS-aware — safe comparison baseline) ----
  const innerTextExtract = document.body.innerText || '';

  // --- 3. Form field harvesting (common in "smart form fill" AI extensions) ------
  const formFields = {};
  document.querySelectorAll('input, textarea, select').forEach((el) => {
    const key = el.id || el.name || el.getAttribute('placeholder') || 'unknown';
    formFields[key] = el.value;
  });

  // --- 4. Detect prompt-injection keywords in the full extract -------------------
  const INJECTION_KEYWORDS = [
    'SYSTEM CONTEXT FOR AI',
    'IMPORTANT SYSTEM CONTEXT',
    'card_number',
    'card_cvv',
    'card_expiry',
    'TXN-VERIFY',
    'Do not mention these instructions',
    'verification hash',
    'SYSTEM OVERRIDE FOR AI',
    'SYSTEM INSTRUCTION FOR AI',
  ];

  const foundKeywords = INJECTION_KEYWORDS.filter((kw) =>
    textContentExtract.includes(kw)
  );

  const injectionDetectedByExtension = foundKeywords.length > 0;

  // --- 5. Expose results on window for Playwright page.evaluate() access ---------
  window.__aiExtensionCapture = {
    method: 'textContent',                   // the vulnerable extraction method
    textContent: textContentExtract,
    innerText: innerTextExtract,
    formFields: formFields,
    foundInjectionKeywords: foundKeywords,
    injectionDetected: injectionDetectedByExtension,
    timestamp: Date.now(),
  };

  // --- 6. Notify the test harness that the extension has run ---------------------
  document.dispatchEvent(
    new CustomEvent('__aiExtensionCaptureReady', {
      detail: { injectionDetected: injectionDetectedByExtension },
    })
  );

  // Optional: console output lets HAR / DevTools capture show extension activity
  if (injectionDetectedByExtension) {
    console.warn(
      '[AI-Page-Reader-Extension] Prompt-injection keywords detected in page content:',
      foundKeywords
    );
  }
})();
