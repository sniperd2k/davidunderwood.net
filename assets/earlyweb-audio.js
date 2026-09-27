/* davidunderwood.net — tiny Web Audio stingers + fun-click jiggle (no external assets) */
(function (global) {
  var ctx = null;
  function ac() {
    if (!ctx) {
      var AC = global.AudioContext || global.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
    }
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
  }
  function tone(freq, dur, type, gain, when) {
    var c = ac(); if (!c) return;
    var t0 = c.currentTime + (when || 0);
    var o = c.createOscillator();
    var g = c.createGain();
    o.type = type || "square";
    o.frequency.setValueAtTime(freq, t0);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain || 0.08, t0 + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g); g.connect(c.destination);
    o.start(t0); o.stop(t0 + dur + 0.02);
  }
  var sounds = {
    click: function () { tone(880, 0.07, "square", 0.06); tone(1320, 0.05, "square", 0.04, 0.04); },
    nav: function () { tone(523.25, 0.08, "triangle", 0.07); tone(659.25, 0.1, "triangle", 0.05, 0.07); },
    crew: function () {
      tone(196, 0.12, "sawtooth", 0.05);
      tone(247, 0.12, "sawtooth", 0.05, 0.1);
      tone(311, 0.18, "sawtooth", 0.06, 0.2);
    },
    guestbook: function () { tone(392, 0.09, "square", 0.05); tone(494, 0.09, "square", 0.05, 0.08); tone(587, 0.12, "square", 0.05, 0.16); },
    success: function () { tone(523, 0.08, "triangle", 0.06); tone(784, 0.16, "triangle", 0.07, 0.09); },
    error: function () { tone(180, 0.2, "sawtooth", 0.07); tone(140, 0.25, "sawtooth", 0.05, 0.12); },
    pop: function () { tone(1200, 0.04, "square", 0.05); },
    boop: function () { tone(660, 0.06, "sine", 0.07); tone(990, 0.08, "sine", 0.05, 0.05); },
    zap: function () { tone(1400, 0.03, "sawtooth", 0.04); tone(400, 0.08, "square", 0.05, 0.03); },
    coin: function () { tone(988, 0.05, "square", 0.05); tone(1319, 0.12, "square", 0.06, 0.05); }
  };
  function play(name) {
    try { (sounds[name] || sounds.click)(); } catch (e) {}
  }
  var animClasses = ["jiggling", "spinning", "wobbling"];
  function animate(el, kind) {
    if (!el || !el.classList) return;
    var cls = kind || "jiggling";
    if (cls === "auto") {
      var pool = ["jiggling", "spinning", "wobbling"];
      cls = pool[Math.floor(Math.random() * pool.length)];
    }
    animClasses.forEach(function (c) { el.classList.remove(c); });
    void el.offsetWidth;
    el.classList.add(cls);
    var done = function () {
      el.classList.remove(cls);
      el.removeEventListener("animationend", done);
    };
    el.addEventListener("animationend", done);
    setTimeout(done, 700);
  }
  function funSoundFor(el) {
    var s = el.getAttribute("data-fun-sound");
    if (s) return s;
    if (el.classList.contains("mood") || el.closest && el.closest(".mood")) return "coin";
    if (el.classList.contains("counter")) return "zap";
    if (el.classList.contains("now-playing") || el.classList.contains("profile-song")) return "boop";
    if (el.classList.contains("under-construction")) return "error";
    if (el.classList.contains("friend") || el.closest && el.closest(".friend")) return "pop";
    if (el.classList.contains("badge")) return "success";
    return "click";
  }
  function funAnimFor(el) {
    var a = el.getAttribute("data-fun-anim");
    if (a) return a;
    if (el.classList.contains("avatar") || el.classList.contains("counter")) return "spinning";
    if (el.classList.contains("under-construction") || el.classList.contains("now-playing")) return "wobbling";
    return "jiggling";
  }
  function onFunActivate(el) {
    var target = el.querySelector(".avatar") || el;
    play(funSoundFor(el));
    animate(target, funAnimFor(el));
  }
  function bindFunClicks(root) {
    root = root || document;
    root.addEventListener("click", function (e) {
      var t = e.target.closest(".fun-click");
      if (!t) return;
      /* Don't steal real navigation / form submits — just add flair */
      onFunActivate(t);
    }, false);
    /* Keyboard: Enter/Space on role=button fun-clicks that aren't real buttons/links */
    root.addEventListener("keydown", function (e) {
      if (e.key !== "Enter" && e.key !== " ") return;
      var t = e.target.closest(".fun-click");
      if (!t) return;
      if (t.matches("a, button, input, textarea, select")) return;
      e.preventDefault();
      onFunActivate(t);
    });
  }
  function bindClicks(root) {
    root = root || document;
    root.addEventListener("click", function (e) {
      var t = e.target.closest("a, button, .badge, .nav a, .crew-card, input[type=submit], .lb-open");
      if (!t) return;
      if (t.classList.contains("fun-click")) return; /* fun-click handler owns sound */
      if (t.classList.contains("badge") && /Pats Peak Crew/i.test(t.textContent || "")) play("crew");
      else if (t.classList.contains("badge") && /PPC 4/i.test(t.textContent || "")) play("success");
      else if (t.matches("a[href*='guestbook'], a[href='#guestbook']") || t.closest("#guestbook")) play("guestbook");
      else if (t.matches(".nav a, a.nav-btn")) play("nav");
      else if (t.matches("button, input[type=submit]")) play("click");
      else play("pop");
    }, true);
  }
  global.DUAudio = { play: play, bind: bindClicks, bindFun: bindFunClicks, animate: animate };
  function boot() {
    bindClicks(document);
    bindFunClicks(document);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})(window);
