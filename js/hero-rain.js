(function () {
  'use strict';
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var canvas = document.querySelector('.hero-rain');
  if (!canvas || !canvas.getContext) return;
  var ctx = canvas.getContext('2d');
  var hero = canvas.parentElement;

  var COUNT = 48;
  var particles = [];
  var flicker = null;      // {x, y, start}
  var nextFlickerAt = 0;
  var running = false;
  var rafId = 0;

  function rand(min, max) { return min + Math.random() * (max - min); }

  function resize() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = hero.offsetWidth * dpr;
    canvas.height = hero.offsetHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function spawn() {
    particles.length = 0;
    for (var i = 0; i < COUNT; i++) {
      particles.push({
        x: rand(0, hero.offsetWidth),
        y: rand(0, hero.offsetHeight),
        len: rand(6, 16),
        alpha: rand(0.06, 0.28),
        vy: rand(0.25, 0.7)
      });
    }
  }

  function scheduleFlicker(now) {
    nextFlickerAt = now + rand(9000, 14000);
  }

  function frame(now) {
    if (!running) return;
    var w = hero.offsetWidth, h = hero.offsetHeight;
    ctx.clearRect(0, 0, w, h);

    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      p.y += p.vy;
      if (p.y - p.len > h) { p.y = -p.len; p.x = rand(0, w); }
      var dx = 0.12 * p.vy * p.len;
      ctx.strokeStyle = 'rgba(199,206,232,' + p.alpha.toFixed(3) + ')';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(p.x, p.y - p.len);
      ctx.lineTo(p.x + dx, p.y);
      ctx.stroke();
    }

    // Occasional cyan flicker on a random particle
    if (!flicker && now >= nextFlickerAt) {
      var t = particles[Math.floor(rand(0, particles.length))];
      flicker = { x: t.x, y: t.y, start: now };
    }
    if (flicker) {
      var e = (now - flicker.start) / 600;
      if (e >= 1) {
        flicker = null;
        scheduleFlicker(now);
      } else {
        var a = 0.35 * Math.sin(Math.PI * e);
        var g = ctx.createRadialGradient(flicker.x, flicker.y, 0, flicker.x, flicker.y, 120);
        g.addColorStop(0, 'rgba(53,224,255,' + a.toFixed(3) + ')');
        g.addColorStop(1, 'rgba(53,224,255,0)');
        ctx.fillStyle = g;
        ctx.fillRect(flicker.x - 120, flicker.y - 120, 240, 240);
      }
    }

    rafId = requestAnimationFrame(frame);
  }

  function start() {
    if (running) return;
    running = true;
    scheduleFlicker(performance.now());
    rafId = requestAnimationFrame(frame);
  }

  function stop() {
    running = false;
    cancelAnimationFrame(rafId);
  }

  var resizeTimer;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () { resize(); spawn(); }, 150);
  });

  // Pause when the hero is off-screen
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (entries) {
      entries[0].isIntersecting ? start() : stop();
    }).observe(hero);
  } else {
    start();
  }

  resize();
  spawn();
})();
