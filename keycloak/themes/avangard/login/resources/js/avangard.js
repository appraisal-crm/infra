// Theme sync: the SPA passes ?theme=light|dark on the auth request; remember it
// so follow-up pages (failed login, required actions) keep the same theme.
(function () {
  var KEY = 'avangard-theme';
  var param = new URLSearchParams(window.location.search).get('theme');
  if (param === 'light' || param === 'dark') localStorage.setItem(KEY, param);
  var theme = localStorage.getItem(KEY);
  if (theme !== 'light' && theme !== 'dark') {
    theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  document.documentElement.setAttribute('data-theme', theme);

  // Small theme toggle in the corner of the card, added once the DOM is ready.
  window.addEventListener('DOMContentLoaded', function () {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.id = 'avangard-theme-toggle';
    btn.setAttribute('aria-label', 'Toggle theme');
    var render = function () {
      var dark = document.documentElement.getAttribute('data-theme') === 'dark';
      btn.textContent = dark ? '☀' : '☾'; // ☀ / ☾
    };
    btn.addEventListener('click', function () {
      var next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem(KEY, next);
      render();
    });
    render();
    document.body.appendChild(btn);
  });
})();
