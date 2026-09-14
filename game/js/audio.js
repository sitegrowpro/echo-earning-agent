// Procedural WebAudio: zero audio files, everything synthesized. Horror needs
// silence + punctuation: room tone, rain, footsteps, creaks, knocks, stings.
export class AudioSys {
  constructor() {
    this.ctx = null; this.master = null; this.vol = 0.8;
    this.amb = null; this.rain = null; this.heart = null; this.tv = null;
    this.stepAlt = false;
  }
  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = this.vol;
    this.master.connect(this.ctx.destination);
  }
  setVol(v) { this.vol = v; if (this.master) this.master.gain.value = v; }

  noiseBuf(sec = 1) {
    const b = this.ctx.createBuffer(1, this.ctx.sampleRate * sec, this.ctx.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    return b;
  }
  // ---- looping beds ----
  startAmbience() {
    if (!this.ctx || this.amb) return;
    const src = this.ctx.createBufferSource(); src.buffer = this.noiseBuf(2); src.loop = true;
    const f = this.ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 220;
    const g = this.ctx.createGain(); g.gain.value = 0.05;
    src.connect(f).connect(g).connect(this.master); src.start();
    const hum = this.ctx.createOscillator(); hum.type = 'sine'; hum.frequency.value = 59;
    const hg = this.ctx.createGain(); hg.gain.value = 0.012;
    hum.connect(hg).connect(this.master); hum.start();
    this.amb = { src, hum };
  }
  startRain() {
    if (!this.ctx || this.rain) return;
    const src = this.ctx.createBufferSource(); src.buffer = this.noiseBuf(2); src.loop = true;
    const f = this.ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 2500;
    const g = this.ctx.createGain(); g.gain.value = 0.035;
    src.connect(f).connect(g).connect(this.master); src.start();
    this.rain = { src };
  }
  stopRain() { if (this.rain) { try { this.rain.src.stop(); } catch {} this.rain = null; } }
  setTV(on) {
    if (!this.ctx) return;
    if (on && !this.tv) {
      const src = this.ctx.createBufferSource(); src.buffer = this.noiseBuf(1); src.loop = true;
      const f = this.ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 900; f.Q.value = 0.6;
      const g = this.ctx.createGain(); g.gain.value = 0.028;
      src.connect(f).connect(g).connect(this.master); src.start();
      this.tv = { src };
    } else if (!on && this.tv) { try { this.tv.src.stop(); } catch {} this.tv = null; }
  }
  setHeart(on, fast = false) {
    if (!this.ctx) return;
    if (on && !this.heart) {
      const o = this.ctx.createOscillator(); o.type = 'sine'; o.frequency.value = 55;
      const g = this.ctx.createGain(); g.gain.value = 0;
      o.connect(g).connect(this.master); o.start();
      const beat = () => {
        if (!this.heart) return;
        const t = this.ctx.currentTime;
        g.gain.cancelScheduledValues(t);
        g.gain.setValueAtTime(0.0, t);
        g.gain.linearRampToValueAtTime(0.35, t + 0.08);
        g.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
        g.gain.linearRampToValueAtTime(0.28, t + 0.42);
        g.gain.exponentialRampToValueAtTime(0.001, t + 0.7);
        this.heart.timer = setTimeout(beat, fast ? 620 : 950);
      };
      this.heart = { o, timer: 0 }; beat();
    } else if (!on && this.heart) {
      clearTimeout(this.heart.timer);
      try { this.heart.o.stop(); } catch {}
      this.heart = null;
    }
  }
  // ---- one-shots ----
  blip(freq, dur, type = 'square', vol = 0.12, slide = 0) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(20, freq + slide), t + dur);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g).connect(this.master); o.start(t); o.stop(t + dur + 0.02);
  }
  thump(freq = 70, dur = 0.18, vol = 0.5) { this.blip(freq, dur, 'sine', vol, -30); }
  footstep(run, crouch, indoor = true) {
    if (!this.ctx) return;
    this.stepAlt = !this.stepAlt;
    const f = (this.stepAlt ? 95 : 82) + (indoor ? 0 : -12);
    this.blip(f, 0.09, 'sine', crouch ? 0.05 : run ? 0.3 : 0.14, -25);
  }
  doorCreak(open) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator(); o.type = 'sawtooth';
    o.frequency.setValueAtTime(open ? 180 : 320, t);
    o.frequency.linearRampToValueAtTime(open ? 340 : 140, t + 0.5);
    const f = this.ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 700; f.Q.value = 4;
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.06, t + 0.12);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.6);
    o.connect(f).connect(g).connect(this.master); o.start(t); o.stop(t + 0.65);
  }
  doorShut() { this.thump(65, 0.22, 0.55); }
  locked() { this.blip(140, 0.07, 'square', 0.14); setTimeout(() => this.blip(110, 0.09, 'square', 0.14), 110); }
  knock(n = 3, heavy = false) {
    for (let i = 0; i < n; i++)
      setTimeout(() => this.thump(heavy ? 55 : 85, 0.16, heavy ? 0.7 : 0.5), i * (heavy ? 420 : 300));
  }
  glassBreak() {
    if (!this.ctx) return;
    const src = this.ctx.createBufferSource(); src.buffer = this.noiseBuf(0.5);
    const f = this.ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 3800;
    const g = this.ctx.createGain();
    const t = this.ctx.currentTime;
    g.gain.setValueAtTime(0.5, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.5);
    src.connect(f).connect(g).connect(this.master); src.start(t);
    this.blip(1200, 0.2, 'triangle', 0.2, -800);
  }
  textDing() { this.blip(880, 0.12, 'sine', 0.16); setTimeout(() => this.blip(1174, 0.18, 'sine', 0.16), 130); }
  phoneBuzz() { this.blip(160, 0.35, 'sawtooth', 0.2); setTimeout(() => this.blip(160, 0.35, 'sawtooth', 0.2), 450); }
  microwaveBeep(final = false) {
    this.blip(1046, 0.15, 'square', 0.2);
    if (final) { setTimeout(() => this.blip(1046, 0.15, 'square', 0.2), 250); setTimeout(() => this.blip(1046, 0.3, 'square', 0.2), 500); }
  }
  sting() {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    [110, 116, 233, 466, 932].forEach((fr) => {
      const o = this.ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = fr;
      const g = this.ctx.createGain();
      g.gain.setValueAtTime(0.22, t); g.gain.exponentialRampToValueAtTime(0.001, t + 1.1);
      o.connect(g).connect(this.master); o.start(t); o.stop(t + 1.2);
    });
    this.thump(45, 0.8, 0.7);
  }
  siren() {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator(); o.type = 'triangle';
    o.frequency.setValueAtTime(660, t);
    for (let i = 0; i < 6; i++) {
      o.frequency.linearRampToValueAtTime(i % 2 ? 660 : 880, t + i * 0.9 + 0.9);
    }
    const g = this.ctx.createGain(); g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.12, t + 2);
    o.connect(g).connect(this.master); o.start(t); o.stop(t + 6);
  }
  powerDown() { this.blip(300, 0.7, 'sawtooth', 0.12, -260); }
  powerUp() { this.blip(80, 0.5, 'sawtooth', 0.1, 240); }
  uiClick() { this.blip(520, 0.05, 'square', 0.08); }
  pickup() { this.blip(660, 0.08, 'triangle', 0.15, 220); }
  staticBurst() {
    if (!this.ctx) return;
    const src = this.ctx.createBufferSource(); src.buffer = this.noiseBuf(0.4);
    const g = this.ctx.createGain();
    const t = this.ctx.currentTime;
    g.gain.setValueAtTime(0.3, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
    src.connect(g).connect(this.master); src.start(t);
  }
}
