(function () {
  'use strict';
  document.documentElement.classList.remove('no-js');

  // --- Nav: burger below 1060px ----------------------------------------------
  var header = document.querySelector('.site-header');
  var burger = document.getElementById('nav-toggle');
  if (header && burger) {
    burger.addEventListener('click', function () {
      var open = header.classList.toggle('menu-open');
      burger.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.querySelectorAll('nav.links a').forEach(function (a) {
      a.addEventListener('click', function () {
        header.classList.remove('menu-open');
        burger.setAttribute('aria-expanded', 'false');
      });
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        header.classList.remove('menu-open');
        burger.setAttribute('aria-expanded', 'false');
      }
    });
  }

  // --- Copy chips: data-copy="#id", hidden without the clipboard API ---------
  if (navigator.clipboard) {
    document.querySelectorAll('.copy-chip[data-copy]').forEach(function (b) {
      b.hidden = false;
      b.addEventListener('click', function () {
        var el = document.querySelector(b.getAttribute('data-copy'));
        if (!el) return;
        navigator.clipboard.writeText(el.textContent.replace(/^\$ /, '')).then(function () {
          b.textContent = 'copied \u26A1';
          setTimeout(function () { b.textContent = 'copy'; }, 1500);
        });
      });
    });
  }

  // --- Blur-fade reveals ----------------------------------------------------
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
    // watchdog: if no callback lands (some embedded webviews), show everything
    setTimeout(function () {
      if (!document.querySelector('.reveal.in-view')) {
        revealed.forEach(function (el) { el.classList.add('in-view'); });
      }
    }, 700);
  } else {
    revealed.forEach(function (el) { el.classList.add('in-view'); });
  }

  // --- Orb web (hero + closing band) ---------------------------------------
  function orbWeb(svg, nodeColor, accStroke) {
    if (!svg) return;
    var c = 360, spokes = 14, rings = [58, 96, 136, 178, 222, 268, 316];
    var NS = 'http://www.w3.org/2000/svg';
    function ang(i) { return i * 2 * Math.PI / spokes - Math.PI / 2 + (i % 3) * 0.02; }
    function pt(i, r) { return [c + r * Math.cos(ang(i)), c + r * Math.sin(ang(i))]; }
    var radii = '', spiral = '';
    for (var i = 0; i < spokes; i++) {
      var e = pt(i, 340 + (i % 4) * 6);
      radii += 'M' + c + ' ' + c + ' L' + e[0].toFixed(1) + ' ' + e[1].toFixed(1) + ' ';
    }
    rings.forEach(function (r) {
      for (var i = 0; i < spokes; i++) {
        var a = pt(i, r), b = pt((i + 1) % spokes, r);
        var ma = (ang(i) + ang(i + 1)) / 2;
        var m = [c + r * 0.93 * Math.cos(ma), c + r * 0.93 * Math.sin(ma)];
        spiral += 'M' + a[0].toFixed(1) + ' ' + a[1].toFixed(1) + ' Q' + m[0].toFixed(1) + ' ' + m[1].toFixed(1) + ' ' + b[0].toFixed(1) + ' ' + b[1].toFixed(1) + ' ';
      }
    });
    function path(d, w) {
      var el = document.createElementNS(NS, 'path');
      el.setAttribute('d', d);
      el.setAttribute('stroke', 'var(--web-stroke)');
      el.setAttribute('stroke-width', w);
      el.setAttribute('fill', 'none');
      svg.appendChild(el);
    }
    path(radii, '1.4');
    path(spiral, '1.1');
    // dew drops
    [[2, 136], [5, 222], [9, 178], [12, 268], [7, 96]].forEach(function (n) {
      var q = pt(n[0], n[1]), el = document.createElementNS(NS, 'circle');
      el.setAttribute('cx', q[0].toFixed(1));
      el.setAttribute('cy', q[1].toFixed(1));
      el.setAttribute('r', '3.5');
      el.setAttribute('fill', nodeColor);
      svg.appendChild(el);
    });
    // one accent node
    var q = pt(10, 222), acc = document.createElementNS(NS, 'circle');
    acc.setAttribute('cx', q[0].toFixed(1));
    acc.setAttribute('cy', q[1].toFixed(1));
    acc.setAttribute('r', '6.5');
    acc.setAttribute('fill', 'var(--accent)');
    if (accStroke) {
      acc.setAttribute('stroke', accStroke);
      acc.setAttribute('stroke-width', '1.5');
    }
    svg.appendChild(acc);
    // impulse running a thread
    var dot = document.createElementNS(NS, 'circle');
    dot.setAttribute('r', '4');
    dot.setAttribute('fill', 'var(--accent)');
    var mo = document.createElementNS(NS, 'animateMotion');
    mo.setAttribute('dur', '7s');
    mo.setAttribute('repeatCount', 'indefinite');
    var sp = pt(4, 346);
    mo.setAttribute('path', 'M' + c + ' ' + c + ' L' + sp[0].toFixed(1) + ' ' + sp[1].toFixed(1) + ' L' + c + ' ' + c);
    dot.appendChild(mo);
    svg.appendChild(dot);
  }
  orbWeb(document.getElementById('webHero'), 'var(--text)', 'var(--text)');
  orbWeb(document.getElementById('webCta'), '#8B8E7D', '');

  // --- Smooth scroll to #quick-start ---------------------------------------
  document.querySelectorAll('a[href="#quick-start"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var t = document.getElementById('quick-start');
      if (!t) return;
      e.preventDefault();
      window.scrollTo({ top: t.getBoundingClientRect().top + window.pageYOffset - 90, behavior: 'smooth' });
    });
  });
})();
