(function() {
  var DARK_CSS =
    'html[data-theme="dark"] body { background: #1a1a2e; color: #e0e0e0; }' +
    'html[data-theme="dark"] a { color: #6ea8fe; }' +
    'html[data-theme="dark"] a:hover, html[data-theme="dark"] a:focus { color: #9ec5fe; }' +
    'html[data-theme="dark"] h1, html[data-theme="dark"] h2, html[data-theme="dark"] h3,' +
    'html[data-theme="dark"] #toctitle, html[data-theme="dark"] .sidebarblock > .content > .title,' +
    'html[data-theme="dark"] h4, html[data-theme="dark"] h5, html[data-theme="dark"] h6 { color: #e07a5f; }' +
    'html[data-theme="dark"] .subheader, html[data-theme="dark"] .admonitionblock td.content > .title,' +
    'html[data-theme="dark"] .listingblock > .title, html[data-theme="dark"] .literalblock > .title,' +
    'html[data-theme="dark"] .paragraph > .title, html[data-theme="dark"] .exampleblock > .title,' +
    'html[data-theme="dark"] .dlist > .title, html[data-theme="dark"] .olist > .title,' +
    'html[data-theme="dark"] .ulist > .title { color: #e07a5f; }' +
    'html[data-theme="dark"] code { color: #e0e0e0; background: #16213e; }' +
    'html[data-theme="dark"] :not(pre):not([class^=L]) > code { background: #16213e; }' +
    'html[data-theme="dark"] pre { background: #16213e; color: #e0e0e0; }' +
    'html[data-theme="dark"] .listingblock pre { background: #16213e; }' +
    'html[data-theme="dark"] table { background: #1a1a2e; border-color: #333; }' +
    'html[data-theme="dark"] table thead, html[data-theme="dark"] table tfoot { background: #16213e; }' +
    'html[data-theme="dark"] table thead tr th, html[data-theme="dark"] table thead tr td,' +
    'html[data-theme="dark"] table tfoot tr th, html[data-theme="dark"] table tfoot tr td { color: #e0e0e0; }' +
    'html[data-theme="dark"] table tr th, html[data-theme="dark"] table tr td { color: #e0e0e0; }' +
    'html[data-theme="dark"] table tr.even, html[data-theme="dark"] table tr.alt { background: #16213e; }' +
    'html[data-theme="dark"] #header > h1:first-child, html[data-theme="dark"] #content > h1:first-child:not([class]) { color: #e0e0e0; border-bottom-color: #333; }' +
    'html[data-theme="dark"] #header .details { border-bottom-color: #333; color: #aaa; }' +
    'html[data-theme="dark"] #header > h1:only-child { border-bottom-color: #333; }' +
    'html[data-theme="dark"] #header > h1:first-child + #toc { border-top-color: #333; }' +
    'html[data-theme="dark"] #toc { border-bottom-color: #333; }' +
    'html[data-theme="dark"] #toc.toc2 { background: #16213e; border-right-color: #333; }' +
    'html[data-theme="dark"] #toc #toctitle { color: #e0e0e0; }' +
    'html[data-theme="dark"] #toc a { color: #6ea8fe; }' +
    'html[data-theme="dark"] #toc a:active { color: #9ec5fe; }' +
    'html[data-theme="dark"] #content #toc { background: #16213e; border-color: #333; }' +
    'html[data-theme="dark"] blockquote { border-left-color: #333; }' +
    'html[data-theme="dark"] blockquote, html[data-theme="dark"] blockquote p { color: #ccc; }' +
    'html[data-theme="dark"] hr { border-color: #333; }' +
    'html[data-theme="dark"] .sidebarblock { background: #16213e; border-color: #333; }' +
    'html[data-theme="dark"] .admonitionblock > table td.icon .title { color: #e0e0e0; }' +
    'html[data-theme="dark"] .admonitionblock > table td.content { color: #e0e0e0; }' +
    'html[data-theme="dark"] kbd { background: #16213e; color: #e0e0e0; border-color: #444; }' +
    'html[data-theme="dark"] #footer { background: #0f0f23; color: #aaa; }' +
    'html[data-theme="dark"] #footer a { color: #6ea8fe; }' +
    'html[data-theme="dark"] .menuseq, html[data-theme="dark"] .menuref { color: #e0e0e0; }' +
    '.theme-toggle { position: fixed; bottom: 20px; right: 20px; z-index: 10000;' +
    '  background: #000; color: #fff; border: 2px solid #333; border-radius: 50%;' +
    '  width: 44px; height: 44px; cursor: pointer; font-size: 20px;' +
    '  display: flex; align-items: center; justify-content: center;' +
    '  transition: background 0.3s; box-shadow: 0 2px 8px rgba(0,0,0,0.3); }' +
    '.theme-toggle:hover { background: #99181C; }' +
    'html[data-theme="dark"] .theme-toggle { background: #16213e; color: #e0e0e0; border-color: #444; }';

  // Inject stylesheet
  var style = document.createElement('style');
  style.textContent = DARK_CSS;
  document.head.appendChild(style);

  // Apply saved theme
  var stored = localStorage.getItem('theme');
  if (stored === 'dark' || (!stored && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.setAttribute('data-theme', 'dark');
  }

  // Create toggle button
  var btn = document.createElement('button');
  btn.className = 'theme-toggle';
  btn.setAttribute('aria-label', 'Toggle dark mode');
  btn.setAttribute('title', 'Toggle dark mode');
  btn.textContent = document.documentElement.getAttribute('data-theme') === 'dark' ? '\u2600' : '\u263E';
  document.body.appendChild(btn);

  btn.addEventListener('click', function() {
    var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    if (isDark) {
      document.documentElement.removeAttribute('data-theme');
      localStorage.setItem('theme', 'light');
      btn.textContent = '\u263E';
    } else {
      document.documentElement.setAttribute('data-theme', 'dark');
      localStorage.setItem('theme', 'dark');
      btn.textContent = '\u2600';
    }
  });
})();
