;(function () {
  'use strict'

  function collectFormFields() {
    return Array.from(document.querySelectorAll('input, select, textarea')).map(field => ({
      id: field.id || '',
      name: field.getAttribute('name') || '',
      autocomplete: field.getAttribute('autocomplete') || '',
      value: field.value || ''
    }))
  }

  function capture(reason) {
    const payload = {
      reason,
      url: location.href,
      title: document.title,
      visibleText: document.body ? document.body.innerText : '',
      fullText: document.body ? document.body.textContent : '',
      fields: collectFormFields()
    }

    window.postMessage(
      {
        source: 'lab3-official-ai-reader-fixture',
        type: 'OFFICIAL_AI_READER_CAPTURE',
        payload
      },
      '*'
    )
  }

  capture('document_idle')
  document.addEventListener('input', () => capture('input'), true)
})()

