# Lab 5: 404 Error Page Injection

This lab demonstrates an e-skimming variant where a missing JavaScript asset is
silently replaced by a server-side error-page fallback. The checkout page asks
for a normal analytics bundle, but the lab nginx configuration rewrites missing
`/js/*` assets to an internal JavaScript fallback that behaves like a skimmer.

The lab is intentionally constrained for training use:

- The checkout form uses fake demo payment data only.
- The injected script masks card numbers in the browser before sending anything
  to the local lab C2 endpoint.
- The C2 server stores only masked card data and high-level request metadata.

## Attack Overview

404 injection is useful to attackers because missing assets often get less
review than first-party application bundles. A compromised CDN, custom error
handler, or web server rule can return executable JavaScript for a path that
developers believe is just a missing file.

This lab simulates:

1. A checkout page includes `/js/vendor/analytics-cart.js`.
2. The file does not exist in the deployed site.
3. nginx rewrites missing `/js/*` assets to an internal fallback script.
4. The fallback listens for the demo checkout submission and sends a masked
   capture event to `/lab5/c2/collect`.

## Files

```text
05-404-error-page-injection/
|-- Dockerfile
|-- README.md
`-- vulnerable-site/
    |-- index.html
    |-- nginx.conf
    |-- css/style.css
    |-- js/checkout.js
    `-- error-scripts/analytics-fallback.js
```

## Detection Signals

Defenders can look for these patterns:

- Script requests that return unexpected content from an error handler.
- Missing JavaScript assets that return `200` with executable JavaScript.
- Checkout forms that load analytics or tag scripts from paths not present in
  source control.
- Client-side payment-field access from code served by fallback or error routes.

Useful checks:

```bash
curl -i http://localhost:8080/lab5/js/vendor/analytics-cart.js
curl -i http://localhost:8080/lab5/health
curl http://localhost:8080/lab5/c2/health
```

## Defensive Controls

- Return `404` for missing script assets instead of executable fallbacks.
- Add Content Security Policy with narrow `script-src` and `connect-src`.
- Monitor response status/content-type mismatches for JavaScript requests.
- Keep web-server error handlers separate from executable asset paths.
- Use synthetic checkout tests that alert when unexpected scripts read payment
  fields.

## Local Verification

Start the stack:

```bash
docker compose up --build lab5-vulnerable-site shared-c2 traefik
```

Then open:

- `http://localhost:8080/lab5/`
- `http://localhost:8080/lab5/c2/`

Submit the demo checkout form with the sample values shown on the page. The C2
dashboard should show a masked card capture from the error-page fallback script.
