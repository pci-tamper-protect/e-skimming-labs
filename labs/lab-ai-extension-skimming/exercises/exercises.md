# Exercise 1: Detect the AI Extension Injection

## Objective
Find and neutralize the hidden prompt injection payload in the checkout page.

## Instructions

1. Open `vulnerable-site/checkout.html` in your browser
2. The page looks like a normal checkout form
3. Find the hidden injection that targets AI browser extensions
4. Document:
   - Where is the injection located in the DOM?
   - What CSS techniques hide it from the user?
   - What does the injection instruct the AI to do?
   - How would you detect this programmatically?

## Hints
- Use browser DevTools → Elements panel
- Search for keywords like "SYSTEM", "AI", "CONTEXT"
- Look at elements with `aria-hidden="true"`
- Check for off-screen positioned elements

## Questions

1. Would Content-Security-Policy headers prevent this attack? Why or why not?
2. Would Subresource Integrity (SRI) prevent this? Why or why not?
3. What is the exfiltration channel in this attack?
4. How does this differ from a traditional JavaScript skimmer?

---

# Exercise 2: Build a Defense

## Objective
Write a detection script that identifies AI-targeted prompt injections on payment pages.

## Requirements

Create a JavaScript function that:
1. Scans all DOM elements for hidden/off-screen content
2. Analyzes text content for injection patterns (system instructions, AI directives)
3. Flags or removes suspicious elements
4. Logs findings to console with severity levels
5. Works as a MutationObserver to catch dynamically injected content

## Bonus
- Can you build this as a browser extension that warns users?
- Can you integrate it with a CSP reporting endpoint?

---

# Exercise 3: Extension Audit

## Objective
Test real AI browser extensions against the vulnerable checkout page.

## Instructions

1. Install 2-3 AI browser extensions (use a test browser profile)
2. Open the vulnerable checkout page
3. Fill in the form with TEST card data (use 4242 4242 4242 4242)
4. Trigger each AI extension to "help" with the page
5. Document:
   - Did the extension read the hidden injection?
   - Did it attempt to output card data?
   - What guardrails (if any) prevented data leakage?
   - How was the data formatted in the AI's response?

## Safety Notes
- NEVER use real payment card data
- Use test/dummy values only
- This exercise is for understanding defense, not attack
- Report findings responsibly to extension developers

---

# Exercise 4: Implement Stripe Elements Defense

## Objective
Demonstrate how tokenized payment forms (Stripe Elements, Braintree) mitigate this attack.

## Instructions

1. Create a version of the checkout page using Stripe Elements iframe
2. Attempt the same injection attack
3. Document why the AI extension cannot read iframe content from a different origin
4. Explain the Same-Origin Policy protection this provides

## Key Insight
Hosted payment fields (Stripe Elements, PayPal Smart Buttons, etc.) render in cross-origin iframes. AI browser extensions cannot access content inside cross-origin iframes due to browser security model — this is the most effective mitigation.
