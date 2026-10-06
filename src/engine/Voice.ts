// Voice layer: speech recognition (player), speech synthesis (narrator) and a
// live mic level for the waveform. All browser-native, no server.

type RecognitionCtor = new () => SpeechRecognitionLike;
interface SpeechRecognitionLike {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  maxAlternatives: number;
  onresult: ((e: any) => void) | null;
  onerror: ((e: any) => void) | null;
  onend: (() => void) | null;
  onspeechstart: (() => void) | null;
  start(): void;
  stop(): void;
  abort(): void;
}

export type ListenError = 'not-allowed' | 'no-speech' | 'network' | 'other';

export interface ListenHandlers {
  onInterim(text: string): void;
  onLevel(level: number): void;
}

const Ctor: RecognitionCtor | undefined =
  (window as any).SpeechRecognition ?? (window as any).webkitSpeechRecognition;

const isTouch = matchMedia('(pointer: coarse)').matches;

export class Voice {
  readonly canListen = !!Ctor;
  readonly canSpeak = 'speechSynthesis' in window;
  muted = false;
  listening = false;

  private rec: SpeechRecognitionLike | null = null;
  private voice: SpeechSynthesisVoice | null = null;
  private stream: MediaStream | null = null;
  private levelRaf = 0;
  private audioCtx: AudioContext | null = null;

  constructor() {
    if (this.canSpeak) {
      const choose = () => (this.voice = pickVoice(speechSynthesis.getVoices()));
      choose();
      speechSynthesis.addEventListener?.('voiceschanged', choose);
    }
  }

  /** iOS only allows speech after a gesture: prime it with an empty utterance. */
  unlock() {
    if (this.canSpeak) speechSynthesis.speak(new SpeechSynthesisUtterance(''));
  }

  /** Narrator line. Resolves when finished (or immediately when muted). */
  speak(text: string): Promise<void> {
    if (!this.canSpeak || this.muted) return Promise.resolve();
    speechSynthesis.cancel();
    return new Promise(resolve => {
      const u = new SpeechSynthesisUtterance(text);
      if (this.voice) u.voice = this.voice;
      u.rate = 1.04;
      u.pitch = 0.92;
      // Some engines never fire onend; fall back to an estimate.
      const fallback = setTimeout(done, 1500 + text.length * 62);
      function done() {
        clearTimeout(fallback);
        resolve();
      }
      u.onend = done;
      u.onerror = done;
      speechSynthesis.speak(u);
    });
  }

  stopSpeaking() {
    if (this.canSpeak) speechSynthesis.cancel();
  }

  /** Listen for one utterance. Resolves with the final transcript ('' if nothing). */
  listen(h: ListenHandlers): Promise<string> {
    if (!Ctor) return Promise.reject<string>('other');
    this.stopSpeaking();
    this.cancel();

    const rec = new Ctor();
    rec.lang = 'en-US';
    rec.interimResults = true;
    rec.continuous = false;
    rec.maxAlternatives = 1;
    this.rec = rec;
    this.listening = true;

    let finalText = '';
    let interim = '';
    let error: ListenError | null = null;

    this.startLevel(h.onLevel);

    return new Promise<string>((resolve, reject) => {
      rec.onresult = (e: any) => {
        interim = '';
        for (let i = e.resultIndex; i < e.results.length; i++) {
          const r = e.results[i];
          if (r.isFinal) finalText += r[0].transcript;
          else interim += r[0].transcript;
        }
        h.onInterim((finalText + ' ' + interim).trim());
      };
      rec.onerror = (e: any) => {
        error = e.error === 'not-allowed' || e.error === 'service-not-allowed'
          ? 'not-allowed'
          : e.error === 'no-speech' ? 'no-speech'
          : e.error === 'network' ? 'network'
          : e.error === 'aborted' ? null : 'other';
      };
      rec.onend = () => {
        this.listening = false;
        this.stopLevel();
        if (this.rec === rec) this.rec = null;
        const text = (finalText || interim).trim();
        if (text) resolve(text);
        else if (error) reject(error);
        else resolve('');
      };
      try {
        rec.start();
      } catch {
        this.listening = false;
        this.stopLevel();
        reject('other');
      }
    });
  }

  /** Stop listening and keep what was heard. */
  finish() {
    this.rec?.stop();
  }

  cancel() {
    if (this.rec) {
      this.rec.onresult = null;
      this.rec.abort();
      this.rec = null;
    }
    this.listening = false;
    this.stopLevel();
  }

  // Real mic level on desktop. On touch devices a second mic stream fights with
  // speech recognition, so the UI animates a synthetic level instead.
  private async startLevel(onLevel: (l: number) => void) {
    if (isTouch || !navigator.mediaDevices?.getUserMedia) {
      const tick = () => {
        onLevel(0.25 + Math.random() * 0.35);
        this.levelRaf = requestAnimationFrame(tick);
      };
      tick();
      return;
    }
    try {
      this.stream ??= await navigator.mediaDevices.getUserMedia({ audio: true });
      if (!this.listening) return;
      this.audioCtx ??= new AudioContext();
      const src = this.audioCtx.createMediaStreamSource(this.stream);
      const analyser = this.audioCtx.createAnalyser();
      analyser.fftSize = 512;
      src.connect(analyser);
      const data = new Uint8Array(analyser.fftSize);
      const tick = () => {
        analyser.getByteTimeDomainData(data);
        let sum = 0;
        for (const v of data) sum += ((v - 128) / 128) ** 2;
        onLevel(Math.min(1, Math.sqrt(sum / data.length) * 4));
        this.levelRaf = requestAnimationFrame(tick);
      };
      tick();
    } catch {
      /* level is cosmetic */
    }
  }

  private stopLevel() {
    cancelAnimationFrame(this.levelRaf);
  }
}

function pickVoice(voices: SpeechSynthesisVoice[]): SpeechSynthesisVoice | null {
  const en = voices.filter(v => v.lang?.toLowerCase().startsWith('en'));
  const prefs = ['Daniel', 'Google UK English Male', 'Arthur', 'Oliver', 'Alex', 'Aaron', 'Google US English', 'Samantha'];
  for (const name of prefs) {
    const v = en.find(v => v.name.includes(name));
    if (v) return v;
  }
  return en.find(v => v.localService) ?? en[0] ?? null;
}
