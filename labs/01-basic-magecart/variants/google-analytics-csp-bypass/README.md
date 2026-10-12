# Google Analytics CSP Bypass Variant

This Lab 1 variant demonstrates the same basic card skimming flow as the base
Magecart lab, but changes the exfiltration method to look like legitimate
analytics traffic.

## Key Differences from Base Lab

### Exfiltration Changes

1. Uses a `gtag('event', 'purchase', ...)`-style call instead of a direct raw
   card-data POST
2. Encodes stolen card data into a compact Base64 payload carried in
   `event_label`
3. Blends exfiltration into traffic that defenders may already allow in CSP
4. Preserves normal checkout completion to reduce user suspicion

### What Stays the Same

- Same checkout pages and payment field selectors
- Same overall data collection timing
- Same goal: steal cardholder, PAN, expiry, CVV, and page metadata
- Same local lab workflow and dashboard expectations

## Why This Variant Matters

This variant models a subtle but important detection challenge: a browser
request can target an expected service category like analytics and still carry
stolen payment data.

It is useful for training detection systems to look for:

- High-entropy or Base64-like analytics fields
- Payment-field reads followed by analytics API usage
- Mismatch between expected analytics identifiers and observed requests
- Encoded card data hidden in benign-looking event metadata

## Proposed Implementation Pattern

- Reuse the base `checkout-compromised.js` structure
- Replace the exfiltration helper with a GA-like sender
- Tag metadata as `google-analytics-csp-bypass-variant`
- Keep a local `gtag` shim and collector so the lab remains self-contained

## Detection Signatures

Expected signals include:

- `gtag(...)` or analytics wrapper calls near checkout submission
- `btoa(JSON.stringify(...))` on card data
- Long `event_label` or custom event parameter values
- Analytics traffic immediately after payment form interaction
- Decoding logic on the C2 side that reconstructs the hidden card payload

## Testing

Run the variant tests with:

```bash
cd labs/01-basic-magecart
./run-variant-tests.sh ga
```

Or directly through Playwright:

```bash
cd labs/01-basic-magecart/test
$env:SKIMMER_VARIANT='google-analytics-csp-bypass'
npx playwright test
```

## Contributing Notes

- The implementation keeps the normal checkout UX intact
- The C2 server remains backward-compatible with the base Lab 1 payload format
- Tests verify both the analytics-shaped envelope and the decoded stolen-card
  record
