(function () {
  'use strict';

  // JS is running: enable reveal animations
  document.documentElement.classList.remove('no-js');

  // --- Mobile navigation -----------------------------------------------------
  var navToggle = document.getElementById('nav-toggle');
  var mobileNav = document.getElementById('mobile-nav');
  if (navToggle && mobileNav) {
    var closeNav = function () {
      mobileNav.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
    };
    navToggle.addEventListener('click', function () {
      var open = mobileNav.classList.toggle('open');
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    mobileNav.addEventListener('click', function (e) {
      if (e.target.closest('a')) closeNav();
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') closeNav();
    });
  }

  // --- Copy-to-clipboard chips -----------------------------------------------
  if (navigator.clipboard) {
    document.querySelectorAll('.copy-chip[data-copy]').forEach(function (btn) {
      btn.hidden = false;
      btn.addEventListener('click', function () {
        var el = document.querySelector(btn.getAttribute('data-copy'));
        if (!el) return;
        navigator.clipboard.writeText(el.textContent).then(function () {
          var label = btn.textContent;
          btn.textContent = 'Copied ⚡';
          setTimeout(function () { btn.textContent = label; }, 1500);
        });
      });
    });
  }

  // --- BlurFade reveals --------------------------------------------------------
  var revealed = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && revealed.length) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in-view');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15 });
    revealed.forEach(function (el) { io.observe(el); });
  } else {
    revealed.forEach(function (el) { el.classList.add('in-view'); });
  }
})();
