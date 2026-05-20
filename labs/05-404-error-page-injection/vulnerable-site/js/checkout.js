;(() => {
  const form = document.querySelector('[data-lab5-checkout]')
  const result = document.getElementById('checkout-result')

  if (!form || !result) return

  form.addEventListener('submit', event => {
    event.preventDefault()
    result.textContent =
      'Demo order accepted. Check the Lab 5 C2 dashboard for the masked training capture.'
  })
})()
