function initFileCaption(scope = document) {
  const input = scope.querySelector('#csv_file');
  if (!input) return;
  const label = scope.querySelector('[data-file-label]');
  const cap = scope.querySelector('#csv_caption');

  const update = () => {
    if (input.files && input.files.length) {
      const names = Array.from(input.files).map(f => f.name).join(', ');
      cap.textContent = names;
      cap.classList.remove('text-muted'); cap.classList.add('text-success');
      if (label) { label.classList.replace('btn-outline-secondary', 'btn-success'); label.textContent = 'Файл выбран'; }
    } else {
      cap.textContent = 'Файл не выбран';
      cap.classList.remove('text-success'); cap.classList.add('text-muted');
      if (label) { label.classList.replace('btn-success', 'btn-outline-secondary'); label.textContent = 'Выбрать файл'; }
    }
  };

  input.addEventListener('change', update);
  update(); // начальное состояние
}

// Работает и с Turbo, и без него
document.addEventListener('turbo:load', () => initFileCaption());
document.addEventListener('DOMContentLoaded', () => initFileCaption());