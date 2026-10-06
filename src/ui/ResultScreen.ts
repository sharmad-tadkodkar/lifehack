import { gsap } from 'gsap';
import { h, ICONS, escapeHtml } from './dom';
import { CATEGORIES, CATEGORY_LABEL, type Category, type Diagnosis } from '../engine/types';
import { sfx } from '../engine/Audio';

export interface ResultData {
  scenarioLabel: string;
  score: number;
  breakdown: Record<Category, number>;
  diagnosis: Diagnosis;
  seconds: number;
  mistakes: number;
  hints: number;
  spoken: number;
  answers: number;
}

export function renderResult(app: HTMLElement, d: ResultData, onRetry: () => void) {
  const R = 92;
  const C = 2 * Math.PI * R;
  const mins = Math.floor(d.seconds / 60);
  const secs = String(Math.round(d.seconds % 60)).padStart(2, '0');

  const el = h('section', { class: 'screen result' }, `
    <div class="result-glow"></div>
    <div class="result-inner">
      <div class="kicker">${escapeHtml(d.scenarioLabel)} · Survived</div>
      <div class="iq-block">
        <svg class="iq-ring" viewBox="0 0 220 220" aria-hidden="true">
          <circle cx="110" cy="110" r="${R}" class="track"/>
          <circle cx="110" cy="110" r="${R}" class="fill" stroke-dasharray="${C}" stroke-dashoffset="${C}"/>
        </svg>
        <div class="iq-text">
          <div class="iq-label">Your Life IQ</div>
          <div class="iq-num"><span class="num">0</span><span class="of">/ 100</span></div>
        </div>
      </div>
      <div class="bars">
        ${CATEGORIES.map(c => `
          <div class="bar-row">
            <span class="bar-label">${CATEGORY_LABEL[c]}</span>
            <span class="bar"><i data-v="${d.breakdown[c]}"></i></span>
            <span class="bar-val">${d.breakdown[c]}<small>/25</small></span>
          </div>`).join('')}
      </div>
      <div class="diag">
        <div class="diag-title">Diagnosis: <strong>${escapeHtml(d.diagnosis.title)}</strong></div>
        <div class="diag-line">${escapeHtml(d.diagnosis.line)}</div>
      </div>
      <div class="stats">
        <span><b>${mins}:${secs}</b> time</span>
        <span><b>${d.mistakes}</b> ${d.mistakes === 1 ? 'mistake' : 'mistakes'}</span>
        <span><b>${d.hints}</b> ${d.hints === 1 ? 'hint' : 'hints'}</span>
        <span><b>${d.spoken}/${d.answers}</b> spoken</span>
      </div>
      <div class="actions">
        <button class="cta retry" type="button">Survive again ${ICONS.arrow}</button>
        <button class="ghost-btn" type="button" disabled>Next: Dead Battery · soon</button>
      </div>
    </div>
  `);
  app.replaceChildren(el);

  const num = el.querySelector('.num')!;
  const counter = { v: 0 };
  let lastTick = 0;
  const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });
  tl.from(el.querySelector('.kicker'), { opacity: 0, y: 10, duration: 0.6 })
    .from(el.querySelector('.iq-block'), { opacity: 0, scale: 0.85, duration: 0.8 }, 0.1)
    .to(el.querySelector('.iq-ring .fill'), { strokeDashoffset: C * (1 - d.score / 100), duration: 2.2, ease: 'power2.out' }, 0.5)
    .to(counter, {
      v: d.score, duration: 2.2, ease: 'power2.out',
      onUpdate: () => {
        const v = Math.round(counter.v);
        num.textContent = String(v);
        if (v !== lastTick) { lastTick = v; if (v % 2 === 0) sfx.count(); }
      },
    }, 0.5)
    .from(el.querySelectorAll('.bar-row'), { opacity: 0, x: -16, stagger: 0.1, duration: 0.5 }, 1)
    .add(() => {
      el.querySelectorAll<HTMLElement>('.bar i').forEach((b, i) =>
        gsap.to(b, { width: `${(Number(b.dataset.v) / 25) * 100}%`, duration: 1, delay: i * 0.1, ease: 'power2.out' }));
    }, 1.1)
    .from(el.querySelector('.diag-title'), { opacity: 0, y: 10, duration: 0.6 }, 2.8)
    .fromTo(el.querySelector('.diag-line'),
      { opacity: 0, scale: 1.5, rotate: -3 },
      { opacity: 1, scale: 1, rotate: -1.5, duration: 0.35, ease: 'power4.in', onComplete: () => {
        sfx.stamp();
        gsap.fromTo(el.querySelector('.result-inner'), { x: -6 }, { x: 0, duration: 0.4, ease: 'elastic.out(1, 0.3)' });
      } }, 3.3)
    .from(el.querySelector('.stats'), { opacity: 0, duration: 0.6 }, 3.9)
    .from(el.querySelectorAll('.actions button'), { opacity: 0, y: 10, stagger: 0.1, duration: 0.5 }, 4.1);

  el.querySelector('.retry')!.addEventListener('click', onRetry, { once: true });
}
