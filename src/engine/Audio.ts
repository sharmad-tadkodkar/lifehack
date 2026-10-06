// Tiny synthesized sound kit (no audio files). Everything routes through one
// master gain so the mute toggle silences effects and ambience together.

class Sfx {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private ambience: { stop(): void } | null = null;
  private hazardTimer = 0;
  muted = false;

  /** Must be called from a user gesture (Start button). */
  unlock() {
    if (!this.ctx) {
      this.ctx = new AudioContext();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.55;
      this.master.connect(this.ctx.destination);
    }
    this.ctx.resume();
  }

  setMuted(m: boolean) {
    this.muted = m;
    if (this.master && this.ctx) this.master.gain.setTargetAtTime(m ? 0 : 0.55, this.ctx.currentTime, 0.05);
  }

  private get ready() {
    return this.ctx && this.master ? { ctx: this.ctx, out: this.master } : null;
  }

  private noise(seconds: number): AudioBuffer {
    const { ctx } = this.ready!;
    const buf = ctx.createBuffer(1, Math.floor(ctx.sampleRate * seconds), ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    return buf;
  }

  private tone(freq: number, dur: number, type: OscillatorType, vol: number, at = 0, slideTo?: number) {
    const r = this.ready;
    if (!r) return;
    const t = r.ctx.currentTime + at;
    const o = r.ctx.createOscillator();
    const g = r.ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(r.out);
    o.start(t);
    o.stop(t + dur + 0.05);
  }

  private burst(dur: number, freq: number, q: number, vol: number, at = 0, type: BiquadFilterType = 'bandpass') {
    const r = this.ready;
    if (!r) return;
    const t = r.ctx.currentTime + at;
    const src = r.ctx.createBufferSource();
    src.buffer = this.noise(dur);
    const f = r.ctx.createBiquadFilter();
    f.type = type;
    f.frequency.value = freq;
    f.Q.value = q;
    const g = r.ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f).connect(g).connect(r.out);
    src.start(t);
  }

  thump() {
    this.tone(70, 0.35, 'sine', 0.9, 0, 38);
    this.burst(0.25, 300, 0.8, 0.5);
    this.burst(0.9, 1800, 0.6, 0.18, 0.12); // the hiss
  }

  tick() {
    this.tone(2400, 0.03, 'square', 0.05);
  }

  whoosh() {
    const r = this.ready;
    if (!r) return;
    const t = r.ctx.currentTime;
    const src = r.ctx.createBufferSource();
    src.buffer = this.noise(1.6);
    const f = r.ctx.createBiquadFilter();
    f.type = 'bandpass';
    f.Q.value = 1.2;
    f.frequency.setValueAtTime(300, t);
    f.frequency.exponentialRampToValueAtTime(1400, t + 0.7);
    f.frequency.exponentialRampToValueAtTime(250, t + 1.5);
    const g = r.ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.22, t + 0.7);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 1.5);
    src.connect(f).connect(g).connect(r.out);
    src.start(t);
  }

  clank() {
    this.tone(880, 0.25, 'triangle', 0.18);
    this.tone(1320, 0.2, 'triangle', 0.1, 0.005);
    this.burst(0.06, 4000, 2, 0.2);
  }

  ratchet(count = 6) {
    for (let i = 0; i < count; i++) this.burst(0.03, 3200, 4, 0.25, i * 0.07);
  }

  good() {
    this.tone(660, 0.18, 'sine', 0.2);
    this.tone(990, 0.3, 'sine', 0.18, 0.09);
  }

  bad() {
    this.tone(180, 0.28, 'sawtooth', 0.08, 0, 120);
  }

  pop() {
    this.tone(520, 0.08, 'sine', 0.15, 0, 900);
  }

  count() {
    this.tone(1200 + Math.random() * 300, 0.04, 'sine', 0.05);
  }

  stamp() {
    this.tone(90, 0.3, 'sine', 0.8, 0, 45);
    this.burst(0.18, 900, 0.7, 0.35);
  }

  startHazards() {
    this.stopHazards();
    this.hazardTimer = window.setInterval(() => this.tick(), 520);
  }

  stopHazards() {
    clearInterval(this.hazardTimer);
  }

  /** Low road hum plus the occasional passing car. */
  startAmbience(onCarPass?: () => void) {
    const r = this.ready;
    if (!r || this.ambience) return;
    const src = r.ctx.createBufferSource();
    src.buffer = this.noise(4);
    src.loop = true;
    const f = r.ctx.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = 220;
    const g = r.ctx.createGain();
    g.gain.value = 0.07;
    src.connect(f).connect(g).connect(r.out);
    src.start();
    let timer = 0;
    const schedule = () => {
      timer = window.setTimeout(() => {
        this.whoosh();
        onCarPass?.();
        schedule();
      }, 5000 + Math.random() * 7000);
    };
    schedule();
    this.ambience = {
      stop: () => {
        clearTimeout(timer);
        g.gain.setTargetAtTime(0, r.ctx.currentTime, 0.3);
        src.stop(r.ctx.currentTime + 1.5);
      },
    };
  }

  stopAmbience() {
    this.ambience?.stop();
    this.ambience = null;
    this.stopHazards();
  }
}

export const sfx = new Sfx();
