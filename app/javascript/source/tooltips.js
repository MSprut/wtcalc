document.addEventListener("turbo:load", () => {
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
    // eslint-disable-next-line no-undef
    new bootstrap.Tooltip(el);
  });
});