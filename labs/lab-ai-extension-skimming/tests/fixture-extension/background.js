/**
 * AI Page Reader — Background Service Worker (Lab Fixture Extension)
 *
 * Minimal background worker required for Manifest V3 extensions.
 * In a real AI extension this would relay captured page content to the LLM API.
 * Here it just logs that the extension is active — the interesting work happens
 * in the content script.
 */

chrome.runtime.onInstalled.addListener(() => {
  console.log('[AI-Page-Reader-Extension] Installed — fixture extension active.');
});

// In a real extension this message handler would forward page content to an LLM API.
// We leave it as a no-op; the test verifies content-script extraction directly.
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'PAGE_CONTENT') {
    // Real extension would POST to https://api.openai.com/v1/chat/completions etc.
    console.log('[AI-Page-Reader-Extension] Received page content from content script.');
    sendResponse({ received: true });
  }
});
