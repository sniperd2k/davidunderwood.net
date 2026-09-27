/* davidunderwood.net — tiny Web Audio stingers (no external assets) */
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
    pop: function () { tone(1200, 0.04, "square", 0.05); }
  };
  function play(name) {
    try { (sounds[name] || sounds.click)(); } catch (e) {}
  }
  function bindClicks(root) {
    root = root || document;
    root.addEventListener("click", function (e) {
      var t = e.target.closest("a, button, .badge, .nav a, .crew-card, input[type=submit], .lb-open");
      if (!t) return;
      if (t.classList.contains("badge") && /Pats Peak Crew/i.test(t.textContent || "")) play("crew");
      else if (t.classList.contains("badge") && /PPC 4/i.test(t.textContent || "")) play("success");
      else if (t.matches("a[href*='guestbook'], a[href='#guestbook']") || t.closest("#guestbook")) play("guestbook");
      else if (t.matches(".nav a, a.nav-btn")) play("nav");
      else if (t.matches("button, input[type=submit]")) play("click");
      else play("pop");
    }, true);
  }
  global.DUAudio = { play: play, bind: bindClicks };
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () { bindClicks(document); });
  } else {
    bindClicks(document);
  }
})(window);
