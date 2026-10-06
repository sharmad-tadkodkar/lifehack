import { gsap } from 'gsap';
import { h, ICONS } from './dom';

/** onPress runs synchronously inside the click (audio/speech unlock); onStart after the exit animation. */
export function renderTitle(app: HTMLElement, onPress: () => void, onStart: () => void) {
  const el = h('section', { class: 'screen title-screen' }, `
    <div class="title-glow"></div>
    <div class="title-road"><i></i><i></i><i></i><i></i><i></i><i></i></div>
    <div class="title-inner">
      <div class="kicker">A voice-first survival game</div>
      <h1 class="logo" aria-label="Oh S#IT">
        <span class="logo-word">Oh</span>
        <span class="logo-word">S<span class="hash">#</span>IT</span>
      </h1>
      <div class="logo-sub">The Life Skills Game</div>
      <p class="tagline">When life breaks down, do you know how to fix it?</p>
      <button class="cta" type="button">Start Surviving ${ICONS.arrow}</button>
      <div class="title-meta">
        <span>Scenario 01 · Flat Tire</span><span class="dot"></span><span>~3 min</span><span class="dot"></span><span>${ICONS.mic} Mic + sound on</span>
      </div>
    </div>
  `);
  app.replaceChildren(el);

  const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });
  tl.from(el.querySelector('.title-glow'), { opacity: 0, scale: 0.8, duration: 1.6 }, 0)
    .from(el.querySelector('.kicker'), { opacity: 0, y: 12, duration: 0.7 }, 0.2)
    .from(el.querySelectorAll('.logo-word'), { opacity: 0, y: 40, skewY: 4, stagger: 0.12, duration: 0.9 }, 0.3)
    .from(el.querySelector('.hash'), { rotate: -25, scale: 1.6, duration: 0.7, ease: 'back.out(3)' }, 0.75)
    .from(el.querySelector('.logo-sub'), { opacity: 0, letterSpacing: '0.6em', duration: 1 }, 0.7)
    .from(el.querySelector('.tagline'), { opacity: 0, y: 10, duration: 0.8 }, 1)
    .from(el.querySelector('.cta'), { opacity: 0, y: 14, scale: 0.96, duration: 0.7 }, 1.25)
    .from(el.querySelector('.title-meta'), { opacity: 0, duration: 0.8 }, 1.5);

  const btn = el.querySelector<HTMLButtonElement>('.cta')!;
  btn.addEventListener('click', () => {
    btn.disabled = true;
    onPress();
    gsap.to(el.querySelector('.title-inner'), { opacity: 0, y: -20, duration: 0.5, ease: 'power2.in' });
    gsap.to(el.querySelector('.title-road'), { opacity: 0, duration: 0.5 });
    gsap.to(el, { opacity: 0, duration: 0.4, delay: 0.35, onComplete: onStart });
  }, { once: true });
}
