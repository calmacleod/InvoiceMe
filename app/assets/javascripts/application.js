document.addEventListener('DOMContentLoaded', () => {
  const items = document.getElementById('line-items');
  let itemIndex = Date.now();
  const scaled = (value, places) => {
    if (!new RegExp(`^\\d+(?:\\.\\d{0,${places}})?$`).test(value)) return 0n;
    const [whole, fraction = ''] = value.split('.');
    return BigInt(whole) * (10n ** BigInt(places)) + BigInt(fraction.padEnd(places, '0'));
  };
  const updateTotal = () => {
    if (!items) return;
    let total = 0n;
    items.querySelectorAll('.line-row:not([hidden])').forEach(row => {
      const quantity = scaled(row.querySelector('.item-quantity').value, 3);
      const cents = scaled(row.querySelector('.item-rate').value, 2);
      total += (quantity * cents + 500n) / 1000n;
    });
    document.getElementById('live-total').textContent = new Intl.NumberFormat('en-CA', {style:'currency',currency:'CAD'}).format(Number(total) / 100);
  };
  document.getElementById('add-item')?.addEventListener('click', () => {
    const template = document.getElementById('line-item-template');
    items.insertAdjacentHTML('beforeend', template.innerHTML.replaceAll('NEW_ITEM', String(++itemIndex)));
    items.lastElementChild.querySelector('input[type=text]').focus();
  });
  items?.addEventListener('input', updateTotal);
  items?.addEventListener('click', event => {
    const remove = event.target.closest('.remove-item');
    if (!remove) return;
    const row = remove.closest('.line-row');
    row.querySelector('.destroy-item').value = '1';
    row.hidden = true;
    row.querySelectorAll('input:not([type=hidden])').forEach(input => input.required = false);
    updateTotal();
  });
  document.getElementById('game-filter')?.addEventListener('input', event => {
    const term = event.target.value.toLowerCase();
    document.querySelectorAll('.game-option').forEach(option => { option.hidden = !option.dataset.search.includes(term); });
  });
  document.querySelector('.publish-form')?.addEventListener('submit', event => {
    if (!window.confirm('Finalize this invoice and save it to Google Drive and the master spreadsheet? Finalized invoice details cannot be edited.')) { event.preventDefault(); return; }
    event.target.querySelector('button').disabled = true;
    event.target.querySelector('button').textContent = 'Saving to Google…';
  });
  document.querySelector('.delete-form')?.addEventListener('submit', event => {
    if (!window.confirm('Delete this draft?')) event.preventDefault();
  });
});
