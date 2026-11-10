// Nimbstia motion helpers, shared by every panel (panel.lua inlines this file like i18n.js; file://
// pages load it with <script src>). The CSS half and what each motion means: theme.css, MOTION SYSTEM.
// Every helper is safe to call again while it is still running (it starts from where things are on
// screen), and with prefers-reduced-motion each one jumps straight to its end state.
(function () {
  'use strict';
  var W = window, D = document, NB = W.NB = W.NB || {};
  var mq = W.matchMedia ? W.matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };
  var reduced = NB.reduced = function () { return !!mq.matches; };
  var hasLinear = !!(W.CSS && CSS.supports && CSS.supports('transition-timing-function', 'linear(0,1)'));
  var SPRING = hasLinear
    ? 'linear(0,.075,.24,.429,.605,.751,.861,.937,.985,1.013,1.025,1.028,1.026,1.021,1.016,1.011,1.007,1.004,1.002,1,1)'
    : 'cubic-bezier(.34,1.36,.64,1)';
  var now = function () { return W.performance ? performance.now() : Date.now(); };

  // One highlight that glides to `target` inside `host` (a positioned, possibly scrolling container).
  // The host's content may be re-rendered at any time: a missing highlight is created again in place.
  // opts: { cls: extra class ('ring'), animate: false to place it without motion, pad: px outset }
  NB.glide = function (host, target, opts) {
    opts = opts || {};
    var g = host._nbGlide;
    if (!target) { if (g) g.remove(); host._nbGlide = null; host.classList.remove('has-glide'); return; }
    var fresh = !g || g.parentNode !== host;
    if (fresh) {
      g = D.createElement('i'); g.className = 'nb-glide' + (opts.cls ? ' ' + opts.cls : ''); g.setAttribute('aria-hidden', 'true');
      host.insertBefore(g, host.firstChild); host._nbGlide = g; host.classList.add('has-glide');
    }
    // offsets, not client rects: rows may still be rising and the panel scaling while this runs
    var x = 0, y = 0, n = target, pad = opts.pad || 0;
    while (n && n !== host) { x += n.offsetLeft; y += n.offsetTop; n = n.offsetParent; }
    if (n !== host) { // host is not positioned: fall back to rects
      var hr = host.getBoundingClientRect(), tr = target.getBoundingClientRect();
      x = tr.left - hr.left - host.clientLeft + host.scrollLeft; y = tr.top - hr.top - host.clientTop + host.scrollTop;
    }
    x -= pad; y -= pad;
    var w = target.offsetWidth + 2 * pad, h = target.offsetHeight + 2 * pad;
    var jump = fresh || opts.animate === false || reduced();
    // a held arrow key repeats every 30-80 ms: shorten the glide so the highlight keeps up with the key
    var t = now(), fast = t - (host._nbGlideT || 0) < 110; host._nbGlideT = t;
    g.style.setProperty('--glide-dur', jump ? '0s' : fast ? '.07s' : '.18s');
    g.style.width = w + 'px'; g.style.height = h + 'px';
    g.style.borderRadius = opts.radius || getComputedStyle(target).borderRadius;
    g.style.transform = 'translate3d(' + x + 'px,' + y + 'px,0)';
    if (jump) { void g.offsetWidth; g.style.removeProperty('--glide-dur'); }
  };

  // Sliding thumb of a segmented control: the item with class "on" inside `seg`. The items must stay in
  // the DOM between calls (patch classes, do not rebuild) so the thumb can travel from where it is.
  // from: a client rect to start from when the control itself was rebuilt (optional).
  NB.thumb = function (seg, animate, from) {
    var on = seg.querySelector('.on'), t = seg._nbThumb;
    if (!on) { if (t) t.style.opacity = 0; return; }
    var fresh = !t || t.parentNode !== seg;
    if (fresh) {
      t = D.createElement('i'); t.className = 'seg-thumb'; t.setAttribute('aria-hidden', 'true');
      seg.insertBefore(t, seg.firstChild); seg._nbThumb = t; seg.classList.add('has-thumb');
    }
    var sr = seg.getBoundingClientRect(), prev = fresh && from ? from : t.getBoundingClientRect();
    (t.getAnimations ? t.getAnimations() : []).forEach(function (a) { a.cancel(); });
    var x = on.offsetLeft, y = on.offsetTop, w = on.offsetWidth, h = on.offsetHeight;
    t.style.opacity = 1; t.style.left = x + 'px'; t.style.top = y + 'px'; t.style.width = w + 'px'; t.style.height = h + 'px';
    if ((fresh && !from) || animate === false || reduced() || !prev.width || !t.animate || !w) return;
    var dx = prev.left - sr.left - seg.clientLeft + seg.scrollLeft - x, dy = prev.top - sr.top - seg.clientTop + seg.scrollTop - y;
    if (Math.abs(dx) < .5 && Math.abs(dy) < .5 && Math.abs(prev.width - w) < .5) return;
    t.animate([{ transform: 'translate(' + dx + 'px,' + dy + 'px) scaleX(' + (prev.width / w) + ')' }, { transform: 'none' }],
      { duration: 220, easing: SPRING });
  };

  // Count a number to its new value. `key` remembers the last value across re-renders, so only a real
  // change animates; from: start value for the first time this key is seen (default: no animation).
  // fmt(n) -> string. The element keeps tabular figures so its width does not jitter.
  var last = {}, raf = {};
  NB.count = function (el, key, to, fmt, opts) {
    opts = opts || {}; fmt = fmt || function (n) { return String(Math.round(n)); };
    var from = key in last ? last[key] : opts.from;
    last[key] = to;
    if (raf[key]) { cancelAnimationFrame(raf[key].id); from = raf[key].cur; raf[key] = null; }
    if (from == null || from === to || reduced() || typeof to !== 'number' || !isFinite(to)) { el.textContent = fmt(to); return; }
    var t0 = now(), dur = opts.dur || 420, st = raf[key] = { cur: from, id: 0 };
    (function step() {
      var p = Math.min(1, (now() - t0) / dur), e = 1 - Math.pow(1 - p, 4);
      st.cur = from + (to - from) * e;
      if (!el.isConnected) { raf[key] = null; return; }
      el.textContent = fmt(p < 1 ? st.cur : to);
      if (p < 1) st.id = requestAnimationFrame(step); else raf[key] = null;
    })();
  };
  NB.forget = function (prefix) { for (var k in last) if (!prefix || k.indexOf(prefix) === 0) delete last[k]; };

  // Keycap feedback: every <kbd> (or .k chip) under `root` whose text is `label` dips for a moment.
  NB.press = function (label, root) {
    var list = (root || D).querySelectorAll('kbd,.k'), hit = false;
    for (var i = 0; i < list.length; i++) {
      var k = list[i];
      if (k.textContent.trim() !== label) continue;
      hit = true;
      k.classList.remove('hit'); void k.offsetWidth; k.classList.add('hit');
      (function (k) { setTimeout(function () { k.classList.remove('hit'); }, 260); })(k);
    }
    return hit;
  };

  // Confirmation at the place of the action: swap an icon button's glyph for a check that pops, then back.
  var CHECK = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3.5 8.5 3 3 6-7"/></svg>';
  NB.confirm = function (el, ms) {
    if (!el) return;
    if (el._nbOld == null) el._nbOld = el.innerHTML;
    clearTimeout(el._nbT);
    el.innerHTML = CHECK; el.classList.add('ok');
    if (el.firstChild && !reduced()) el.firstChild.classList.add('nb-pop');
    el._nbT = setTimeout(function () { if (el.isConnected) el.innerHTML = el._nbOld; el.classList.remove('ok'); el._nbOld = null; }, ms || 900);
  };
})();
