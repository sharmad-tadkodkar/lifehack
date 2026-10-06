import { gsap } from 'gsap';
import type { SceneController } from '../../engine/types';
import { sfx } from '../../engine/Audio';

// Hand-built SVG roadside scene. Layers are separate groups so each repair
// step can animate the actual props: hazards blink, the jack extends, the car
// rises, nuts spin off, the flat rolls away, the spare slides on.

const HUB = { x: 360, y: 360 }; // rear wheel centre, car-local coordinates
const PIVOT = '640 400'; // front tyre contact patch: the car tilts around this
const JACK_X = 432;

function rotateAroundPivot(p: { x: number; y: number }, deg: number) {
  const [px, py] = PIVOT.split(' ').map(Number);
  const a = (deg * Math.PI) / 180;
  const dx = p.x - px;
  const dy = p.y - py;
  return { x: px + dx * Math.cos(a) - dy * Math.sin(a), y: py + dx * Math.sin(a) + dy * Math.cos(a) };
}

const nutPositions =(r = 14) =>
  [0, 1, 2, 3, 4].map(i => {
    const a = (-90 + i * 72) * (Math.PI / 180);
    return { x: HUB.x + r * Math.cos(a), y: HUB.y + r * Math.sin(a) };
  });

function wheel(id: string, cx: number, cy: number, opts: { nuts?: string; rim?: string; spare?: boolean } = {}) {
  const spokes = [0, 1, 2, 3, 4]
    .map(i => {
      const a = (-54 + i * 72) * (Math.PI / 180);
      return `<line x1="${cx + 9 * Math.cos(a)}" y1="${cy + 9 * Math.sin(a)}" x2="${cx + 23 * Math.cos(a)}" y2="${cy + 23 * Math.sin(a)}" />`;
    })
    .join('');
  const nuts = opts.nuts
    ? `<g class="${opts.nuts}">${nutPositions()
        .map(p => `<circle cx="${p.x - HUB.x + cx}" cy="${p.y - HUB.y + cy}" r="3.4" />`)
        .join('')}</g>`
    : '';
  return `
  <g id="${id}">
    <g class="tire"><circle cx="${cx}" cy="${cy}" r="42" fill="#121214" stroke="#070708" stroke-width="2"/>
      <circle cx="${cx}" cy="${cy}" r="35" fill="none" stroke="#26262b" stroke-width="2"/>
      ${opts.spare ? `<circle cx="${cx}" cy="${cy}" r="38.5" fill="none" stroke="#3a3a40" stroke-width="1" stroke-dasharray="3 4"/>` : ''}
    </g>
    <g class="rim">
      <circle cx="${cx}" cy="${cy}" r="${opts.spare ? 24 : 27}" fill="url(#${opts.rim ?? 'gRim'})" />
      <g stroke="${opts.spare ? '#1b1b1e' : '#6d727a'}" stroke-width="${opts.spare ? 3 : 4.5}" stroke-linecap="round">${opts.spare ? '' : spokes}</g>
      ${opts.spare ? `<circle cx="${cx}" cy="${cy}" r="18" fill="none" stroke="#ff5a36" stroke-width="1.2" opacity=".75"/>` : ''}
      <circle cx="${cx}" cy="${cy}" r="8.5" fill="#2b2d31" stroke="#8b9098" stroke-width="1.2"/>
      ${nuts}
    </g>
  </g>`;
}

const SVG = /* svg */ `
<svg viewBox="90 40 830 470" preserveAspectRatio="xMidYMid meet" overflow="visible" xmlns="http://www.w3.org/2000/svg" class="scene-svg" aria-label="A car with a flat tire on the side of a road at night">
  <defs>
    <linearGradient id="gSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0f0f12"/><stop offset=".62" stop-color="#1c1717"/><stop offset="1" stop-color="#3a1f17"/>
    </linearGradient>
    <radialGradient id="gHorizon" cx=".72" cy="1" r=".7">
      <stop offset="0" stop-color="#ff5a36" stop-opacity=".35"/><stop offset="1" stop-color="#ff5a36" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="gRoad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1d1d20"/><stop offset="1" stop-color="#26262a"/>
    </linearGradient>
    <linearGradient id="gShoulder" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1b1a19"/><stop offset="1" stop-color="#121212"/>
    </linearGradient>
    <linearGradient id="gBody" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#e2694a"/><stop offset=".45" stop-color="#c4472c"/><stop offset="1" stop-color="#6e2416"/>
    </linearGradient>
    <linearGradient id="gGlass" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#3b4350"/><stop offset=".55" stop-color="#1a1d23"/><stop offset="1" stop-color="#252a33"/>
    </linearGradient>
    <radialGradient id="gRim" cx=".4" cy=".35" r=".8">
      <stop offset="0" stop-color="#d9dde3"/><stop offset=".6" stop-color="#8d939b"/><stop offset="1" stop-color="#4b4f56"/>
    </radialGradient>
    <radialGradient id="gSteel" cx=".4" cy=".35" r=".8">
      <stop offset="0" stop-color="#4a4c52"/><stop offset="1" stop-color="#1f2024"/>
    </radialGradient>
    <radialGradient id="gAmber" r=".5">
      <stop offset="0" stop-color="#ffb347" stop-opacity=".95"/><stop offset="1" stop-color="#ff8a00" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="gRed" r=".5">
      <stop offset="0" stop-color="#ff4a3a" stop-opacity=".8"/><stop offset="1" stop-color="#ff2a1a" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="gBeam" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#fff3d6" stop-opacity=".35"/><stop offset="1" stop-color="#fff3d6" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="gLamp" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffcf8a" stop-opacity=".22"/><stop offset="1" stop-color="#ffcf8a" stop-opacity="0"/>
    </linearGradient>
    <filter id="fBlur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
  </defs>

  <g id="cam">
    <rect x="-1200" y="-900" width="3400" height="1220" fill="url(#gSky)"/>
    <rect x="-1200" y="80" width="3400" height="240" fill="url(#gHorizon)"/>
    <g id="stars" fill="#f2efe9">
      ${Array.from({ length: 90 }, () => `<circle cx="${(Math.random() * 2400 - 700).toFixed(0)}" cy="${(Math.random() * 400 - 210).toFixed(0)}" r="${(Math.random() * 1.1 + 0.3).toFixed(1)}" opacity="${(Math.random() * 0.5 + 0.15).toFixed(2)}"/>`).join('')}
    </g>
    <circle cx="820" cy="78" r="16" fill="#f2efe9" opacity=".85"/>
    <circle cx="827" cy="73" r="15" fill="#151416"/>
    <g id="hills">
      <path d="M-1200 300 L-1200 240 Q -800 215 -500 236 T -200 250 Q 0 205 160 238 T 470 228 T 760 236 T 1060 222 T 1500 236 T 2200 230 L 2200 300 Z" fill="#141315"/>
      <g fill="#ffb15c" opacity=".55">
        ${Array.from({ length: 26 }, (_, i) => `<rect x="${60 + i * 34 + (i % 3) * 7}" y="${252 + (i % 4) * 6}" width="2" height="2"/>`).join('')}
      </g>
    </g>

    <!-- street lamp -->
    <g id="lamp">
      <polygon points="888,148 790,452 1000,452 924,148" fill="url(#gLamp)"/>
      <rect x="902" y="140" width="5" height="170" fill="#0c0c0e"/>
      <path d="M904 142 Q 904 128 890 128 L 870 128" stroke="#0c0c0e" stroke-width="5" fill="none"/>
      <rect x="860" y="126" width="22" height="7" rx="2" fill="#ffd9a0"/>
      <ellipse cx="871" cy="134" rx="22" ry="8" fill="#ffcf8a" opacity=".35" filter="url(#fBlur)"/>
    </g>

    <!-- road -->
    <rect x="-1200" y="300" width="3400" height="128" fill="url(#gRoad)"/>
    <g id="traffic" opacity="0">
      <ellipse cx="0" cy="0" rx="60" ry="12" fill="#ffefc9" opacity=".25" filter="url(#fBlur)"/>
      <path d="M-46 4 L-40 -10 Q -30 -20 -8 -20 L 18 -20 Q 30 -18 38 -8 L 48 -5 Q 54 -3 54 4 Z" fill="#0d0d0f"/>
      <circle cx="52" cy="-2" r="3" fill="#fff6e0"/>
      <circle cx="-44" cy="-2" r="2.4" fill="#ff3a2a"/>
    </g>
    <g id="dashes" fill="#d9d4cb" opacity=".55">
      ${Array.from({ length: 36 }, (_, i) => `<rect x="${-1200 + i * 100}" y="338" width="48" height="4" rx="1"/>`).join('')}
    </g>
    <rect x="-1200" y="426" width="3400" height="3" fill="#d9d4cb" opacity=".6"/>
    <rect x="-1200" y="429" width="3400" height="900" fill="url(#gShoulder)"/>
    <g fill="#2b2927">
      ${Array.from({ length: 160 }, () => `<circle cx="${(Math.random() * 2400 - 700).toFixed(0)}" cy="${(434 + Math.random() * 260).toFixed(0)}" r="${(Math.random() * 1.6 + 0.5).toFixed(1)}"/>`).join('')}
    </g>

    <g id="rig">
      <!-- warning triangle (placed well behind the car) -->
      <g id="triangle" opacity="0">
        <ellipse cx="128" cy="402" rx="34" ry="5" fill="#000" opacity=".5"/>
        <circle class="tri-glow" cx="128" cy="374" r="34" fill="url(#gRed)"/>
        <path d="M128 344 L156 396 L100 396 Z" fill="none" stroke="#ff3d2a" stroke-width="7" stroke-linejoin="round"/>
        <path d="M128 360 L144 390 L112 390 Z" fill="#2a1512"/>
        <rect x="104" y="398" width="48" height="4" fill="#3b3b40"/>
      </g>

      <ellipse cx="500" cy="403" rx="300" ry="11" fill="#000" opacity=".55"/>

      <!-- scissor jack -->
      <g id="jack" opacity="0">
        <rect x="${JACK_X - 34}" y="396" width="68" height="6" rx="2" fill="#2d2f33"/>
        <polyline id="jackArms" fill="none" stroke="#9aa0a8" stroke-width="5" stroke-linejoin="round"/>
        <line id="jackScrew" stroke="#c9ced5" stroke-width="2.5"/>
        <path id="jackCrank" fill="none" stroke="#ff5a36" stroke-width="3" stroke-linecap="round"/>
        <rect id="jackSaddle" width="26" height="6" rx="1.5" fill="#6c7178"/>
      </g>

      <!-- wheel chock -->
      <g id="chock" opacity="0">
        <path d="M683 400 L722 400 L686 366 Z" fill="#e8b931"/>
        <path d="M694 400 L700 400 L689 389 L689 383 Z M706 400 L712 400 L688 377 L688 371 Z" fill="#1a1a1a" opacity=".55"/>
      </g>

      <g id="carTilt">
        <!-- headlight beam -->
        <polygon points="770,296 1100,250 1100,372" fill="url(#gBeam)"/>
        <g id="body">
          <path d="M232 352 L228 312 Q228 286 252 280 L318 270 L392 218 Q402 210 418 209 L556 209 Q576 209 590 220 L648 264 L738 276 Q768 282 770 306 L772 338 Q772 352 758 352 L690 352 A50 50 0 0 0 590 352 L410 352 A50 50 0 0 0 310 352 Z" fill="url(#gBody)"/>
          <path d="M336 270 L398 225 Q404 220 414 220 L482 220 L482 268 Z" fill="url(#gGlass)"/>
          <path d="M492 220 L552 220 Q568 220 580 229 L628 266 L492 268 Z" fill="url(#gGlass)"/>
          <path d="M404 224 L430 224 L380 262 L356 262 Z" fill="#fff" opacity=".06"/>
          <path d="M250 290 L762 293" stroke="#f08a6c" stroke-width="1.5" opacity=".55"/>
          <path d="M487 270 L487 346 M612 272 L616 346" stroke="#5a1c10" stroke-width="1.6" opacity=".8"/>
          <rect x="440" y="282" width="20" height="4" rx="2" fill="#5a1c10"/>
          <rect x="566" y="283" width="20" height="4" rx="2" fill="#5a1c10"/>
          <path d="M626 258 L642 252 L646 266 L630 268 Z" fill="#8e301d"/>
          <path d="M752 288 L770 291 L771 304 L748 301 Z" fill="#fff4d8"/>
          <rect x="228" y="288" width="9" height="14" rx="2" fill="#ff3a2a"/>
          <path d="M236 334 L310 334 M410 334 L590 334 M690 334 L768 334" stroke="#3d130b" stroke-width="10" opacity=".55"/>
          <!-- hazard lenses -->
          <rect class="haz-lens" x="228" y="304" width="9" height="7" rx="2" fill="#7a4a10"/>
          <rect class="haz-lens" x="760" y="306" width="10" height="7" rx="2" fill="#7a4a10"/>
          <g id="hazards" opacity="0">
            <rect x="228" y="304" width="9" height="7" rx="2" fill="#ffb347"/>
            <rect x="760" y="306" width="10" height="7" rx="2" fill="#ffb347"/>
            <circle cx="232" cy="307" r="34" fill="url(#gAmber)"/>
            <circle cx="765" cy="309" r="34" fill="url(#gAmber)"/>
          </g>
        </g>
        ${wheel('wheelFront', 640, 360)}
        ${wheel('wheelRear', HUB.x, HUB.y, { nuts: 'nuts-rear' })}
        <g id="spare" opacity="0">${wheel('spareWheel', HUB.x, HUB.y, { nuts: 'nuts-spare', rim: 'gSteel', spare: true })}</g>
        <g id="wrench" opacity="0">
          <g stroke="#c4c9d0" stroke-width="5.5" stroke-linecap="round">
            <line x1="${HUB.x - 40}" y1="${HUB.y}" x2="${HUB.x + 40}" y2="${HUB.y}"/>
            <line x1="${HUB.x}" y1="${HUB.y - 40}" x2="${HUB.x}" y2="${HUB.y + 40}"/>
          </g>
          <circle cx="${HUB.x}" cy="${HUB.y - 14}" r="6" fill="#8d939b" stroke="#2b2d31" stroke-width="1.5"/>
        </g>
      </g>

      <!-- removed flat, lying by the car -->
      <g id="flatOut" opacity="0">${wheel('flatOutWheel', HUB.x, HUB.y)}</g>
    </g>
  </g>

  <g id="calloutPos"><g id="callout" opacity="0">
    <rect id="calloutBg" x="0" y="34" height="32" rx="16" fill="#141414" fill-opacity=".85" stroke="#ff5a36" stroke-width="1.5"/>
    <text id="calloutText" x="500" y="55" text-anchor="middle" fill="#f2efe9" font-family="Space Grotesk, Inter, sans-serif" font-size="14" font-weight="600" letter-spacing="2.5"></text>
  </g></g>
</svg>`;

export function createFlatTireScene(): SceneController {
  let root: HTMLElement;
  let svg: SVGSVGElement;
  const tl: gsap.core.Animation[] = [];
  const jack = { top: 372 };
  let hazardTween: gsap.core.Tween | null = null;
  let resizeObs: ResizeObserver | null = null;
  const lastHighlight = new Map<string, number>();
  const done = new Set<string>();

  const $ = <T extends Element = SVGGElement>(sel: string) => svg.querySelector(sel) as T;
  const $$ = (sel: string) => Array.from(svg.querySelectorAll(sel));
  const wait = (s: number) => new Promise(r => setTimeout(r, s * 1000));
  const play = (anim: gsap.core.Timeline | gsap.core.Tween) =>
    new Promise<void>(resolve => {
      tl.push(anim);
      anim.eventCallback('onComplete', () => resolve());
    });

  function drawJack() {
    const baseY = 394;
    const top = jack.top;
    const h = baseY - top;
    const arm = 31;
    const w = Math.sqrt(Math.max(0, arm * arm - (h / 2) ** 2));
    const mid = (baseY + top) / 2;
    $('#jackArms').setAttribute('points', `${JACK_X},${baseY} ${JACK_X - w},${mid} ${JACK_X},${top} ${JACK_X + w},${mid} ${JACK_X},${baseY}`);
    const screw = $('#jackScrew');
    screw.setAttribute('x1', String(JACK_X - w - 6));
    screw.setAttribute('x2', String(JACK_X + w + 26));
    screw.setAttribute('y1', String(mid));
    screw.setAttribute('y2', String(mid));
    $('#jackCrank').setAttribute('d', `M${JACK_X + w + 26} ${mid} l 0 -12 l 14 0`);
    const saddle = $('#jackSaddle');
    saddle.setAttribute('x', String(JACK_X - 13));
    saddle.setAttribute('y', String(top - 5));
  }

  // Always frame the whole car + triangle; spill extra space into sky and road.
  function fit() {
    const { clientWidth: cw, clientHeight: ch } = root;
    if (!cw || !ch) return;
    const F = { x: 90, y: 60, w: 830, h: 430 };
    const a = cw / ch;
    let { x, y, w, h } = F;
    if (a > w / h) {
      w = h * a;
      x = F.x + F.w / 2 - w / 2;
    } else {
      h = w / a;
      y = F.y - (h - F.h) * 0.62;
    }
    svg.setAttribute('viewBox', `${x} ${y} ${w} ${h}`);
    // keep the callout pill centred in view
    gsap.set('#calloutPos', { x: x + w / 2 - 500, y: y + 6 });
  }

  function callout(text: string) {
    const t = $<SVGTextElement>('#calloutText');
    t.textContent = text;
    const w = text.length * 10.5 + 40;
    const bg = $('#calloutBg');
    bg.setAttribute('x', String(500 - w / 2));
    bg.setAttribute('width', String(w));
    gsap.timeline()
      .fromTo('#callout', { opacity: 0, y: -10 }, { opacity: 1, y: 0, duration: 0.35, ease: 'back.out(2)' })
      .to('#callout', { opacity: 0, y: -6, duration: 0.4, delay: 1.9 });
  }

  function startHazards() {
    if (hazardTween) return;
    hazardTween = gsap.to('#hazards', { opacity: 1, duration: 0.08, repeat: -1, yoyo: true, repeatDelay: 0.44, ease: 'none' });
    sfx.startHazards();
  }

  function zoom(scale: number, dur = 1.2) {
    gsap.to('#cam', { scale, svgOrigin: '400 430', duration: dur, ease: 'power2.inOut' });
  }

  function wrenchTurn(dir: 1 | -1, turns = 2) {
    const w = $('#wrench');
    return gsap.timeline()
      .set(w, { rotation: 0, svgOrigin: `${HUB.x} ${HUB.y}` })
      .to(w, { opacity: 1, duration: 0.25 })
      .to(w, { rotation: dir * 75, duration: 0.45, ease: 'power2.inOut', repeat: turns - 1, repeatDelay: 0.15, onRepeat: () => sfx.ratchet(4), onStart: () => sfx.ratchet(4) })
      .to(w, { opacity: 0, duration: 0.3 });
  }

  const steps: Record<string, () => Promise<void>> = {
    async safe() {
      startHazards();
      callout('HAZARDS ON');
      const spin = gsap.to('#wheelFront .rim, #wheelRear .rim', { rotation: '+=200', duration: 1.8, ease: 'power1.inOut' });
      tl.push(spin);
      await play(gsap.timeline()
        .to('#rig', { y: 48, x: 30, duration: 1.8, ease: 'power2.inOut' })
        .to('#carTilt', { rotation: -2.6, duration: 0.25, yoyo: true, repeat: 1, ease: 'sine.inOut' }, 0.6));
      gsap.set('#carTilt', { rotation: -1.2 });
    },
    async secure() {
      callout('BRAKE ON · WHEELS CHOCKED');
      sfx.clank();
      await play(gsap.timeline()
        .fromTo('#chock', { opacity: 0, x: 40, y: 10 }, { opacity: 1, x: 0, y: 0, duration: 0.6, ease: 'back.out(1.6)' })
        .to('#carTilt', { rotation: -1.6, duration: 0.12, yoyo: true, repeat: 1 }, 0.4));
    },
    async triangle() {
      callout('TRIANGLE · 50 M BACK');
      sfx.pop();
      tl.push(gsap.to('#triangle .tri-glow', { opacity: 0.35, duration: 0.9, repeat: -1, yoyo: true, ease: 'sine.inOut' }));
      await play(gsap.fromTo('#triangle', { opacity: 0, y: -30, scale: 0.6, svgOrigin: '128 400' }, { opacity: 1, y: 0, scale: 1, duration: 0.7, ease: 'bounce.out' }));
    },
    async loosen() {
      zoom(1.28);
      callout('LOOSEN · HALF TURN');
      await wait(0.6);
      await play(gsap.timeline()
        .add(wrenchTurn(-1, 2))
        .to('#wheelRear .nuts-rear', { rotation: -40, svgOrigin: `${HUB.x} ${HUB.y}`, duration: 0.6 }, 0.4));
    },
    async jack() {
      callout('JACKING POINT');
      sfx.clank();
      jack.top = 372;
      drawJack();
      await play(gsap.timeline()
        .fromTo('#jack', { opacity: 0, x: -120 }, { opacity: 1, x: 0, duration: 0.8, ease: 'power3.out' })
        .to(jack, { top: 356, duration: 0.6, onUpdate: drawJack, ease: 'power1.out' }));
    },
    async lift() {
      callout('CLEAR OF THE GROUND');
      sfx.ratchet(14);
      await play(gsap.timeline()
        .to(jack, { top: 335.5, duration: 1.8, onUpdate: drawJack, ease: 'power1.inOut' })
        .to('#carTilt', { rotation: 4.5, svgOrigin: PIVOT, duration: 1.8, ease: 'power1.inOut' }, 0)
        .to('#wheelRear .tire', { scaleY: 1, scaleX: 1, duration: 1.2 }, 0.4));
    },
    async remove() {
      callout('FLAT OFF');
      await play(wrenchTurn(-1, 2));
      sfx.clank();
      const nuts = $$('#wheelRear .nuts-rear circle');
      await play(gsap.timeline()
        .to(nuts, { y: 70, x: () => gsap.utils.random(-30, 30), opacity: 0, duration: 0.6, stagger: 0.08, ease: 'power2.in' }));
      // swap the attached wheel for the free-rolling copy at the same spot
      const hub = rotateAroundPivot(HUB, gsap.getProperty('#carTilt', 'rotation') as number);
      gsap.set('#wheelRear', { opacity: 0 });
      const out = $('#flatOut');
      gsap.set(out, { opacity: 1, x: hub.x - HUB.x, y: hub.y - HUB.y });
      gsap.set('#flatOutWheel .tire', { scaleY: 0.84, scaleX: 1.06, svgOrigin: `${HUB.x} ${HUB.y + 42}` });
      await play(gsap.timeline()
        .to(out, { x: -150, duration: 1.1, ease: 'power2.out' })
        .to(out, { y: 0, duration: 1.1, ease: 'bounce.out' }, 0)
        .to('#flatOutWheel', { rotation: -260, svgOrigin: `${HUB.x} ${HUB.y}`, duration: 1.1, ease: 'power2.out' }, 0));
    },
    async spare() {
      callout('SPARE ON');
      gsap.set('#spare .nuts-spare circle', { opacity: 0 });
      await play(gsap.timeline()
        .fromTo('#spare', { opacity: 0, x: -150 }, { opacity: 1, x: 0, duration: 1, ease: 'power3.out' })
        .add(() => sfx.clank(), 0.9));
    },
    async tighten() {
      callout('STAR PATTERN');
      const nuts = $$('#spare .nuts-spare circle');
      const order = [0, 2, 4, 1, 3].map(i => nuts[i]);
      await play(gsap.timeline()
        .to(order, { opacity: 1, duration: 0.15, stagger: { each: 0.28, onStart: () => sfx.pop() } })
        .add(wrenchTurn(1, 2), 0.4));
    },
    async lower() {
      callout('DOWN · TIGHTENED');
      zoom(1);
      sfx.ratchet(12);
      await play(gsap.timeline()
        .to(jack, { top: 352, duration: 1.5, onUpdate: drawJack, ease: 'power1.inOut' })
        .to('#carTilt', { rotation: 0, svgOrigin: PIVOT, duration: 1.5, ease: 'power1.inOut' }, 0)
        .to(jack, { top: 372, duration: 0.4, onUpdate: drawJack })
        .to('#jack', { x: -140, opacity: 0, duration: 0.6, ease: 'power2.in' })
        .add(wrenchTurn(1, 1)));
    },
  };

  return {
    mount(container) {
      root = container;
      root.innerHTML = SVG;
      svg = root.querySelector('svg')!;
      drawJack();
      fit();
      resizeObs = new ResizeObserver(fit);
      resizeObs.observe(root);
      gsap.set('#carTilt', { svgOrigin: PIVOT, rotation: 0 });
      gsap.set('#wheelFront .rim', { svgOrigin: '640 360' });
      gsap.set('#wheelRear .rim', { svgOrigin: `${HUB.x} ${HUB.y}` });
      // slow ambient drift
      tl.push(gsap.to('#stars', { x: -12, duration: 30, repeat: -1, yoyo: true, ease: 'sine.inOut' }));
    },

    async intro() {
      // driving...
      const dashes = gsap.to('#dashes', { x: -100, duration: 0.35, repeat: -1, ease: 'none' });
      const hills = gsap.to('#hills', { x: -60, duration: 6, ease: 'none' });
      const spin = gsap.to('#wheelFront .rim, #wheelRear .rim', { rotation: '+=360', duration: 0.35, repeat: -1, ease: 'none' });
      const bob = gsap.to('#body', { y: -1.2, duration: 0.18, repeat: -1, yoyo: true, ease: 'sine.inOut' });
      tl.push(dashes, hills, spin, bob);
      gsap.from('#rig', { x: -520, duration: 1.4, ease: 'power2.out' });
      await wait(1.6);
      // ...THUMP
      sfx.thump();
      gsap.timeline()
        .to('#carTilt', { rotation: -3, duration: 0.08 })
        .to('#carTilt', { rotation: 1.2, duration: 0.14 })
        .to('#carTilt', { rotation: -1.2, duration: 0.5, ease: 'elastic.out(1, 0.4)' });
      gsap.to('#wheelRear .tire', { scaleY: 0.84, scaleX: 1.06, svgOrigin: `${HUB.x} ${HUB.y + 42}`, duration: 0.5, ease: 'power3.out' });
      gsap.to(dashes, { timeScale: 0, duration: 1.6, ease: 'power2.out', onComplete: () => dashes.kill() });
      gsap.to(spin, { timeScale: 0, duration: 1.6, ease: 'power2.out', onComplete: () => spin.kill() });
      bob.kill();
      gsap.set('#body', { y: 0 });
      await wait(1.4);
      gsap.to('#cam', { keyframes: [{ x: -3 }, { x: 3 }, { x: 0 }], duration: 0.3 });
    },

    async playStep(id) {
      if (done.has(id)) return;
      done.add(id);
      await steps[id]?.();
    },

    playReaction(key) {
      if (key === 'wobble') {
        sfx.bad();
        gsap.timeline()
          .to('#carTilt', { x: 4, duration: 0.06 })
          .to('#carTilt', { x: -4, duration: 0.06, repeat: 3, yoyo: true })
          .to('#carTilt', { x: 0, duration: 0.1 });
      } else if (key === 'carPass') {
        gsap.fromTo('#traffic', { x: -150, y: 322, opacity: 1, scale: 0.75 }, { x: 1150, duration: 1.3, ease: 'none', onComplete: () => gsap.set('#traffic', { opacity: 0 }) });
      }
    },

    highlight(key) {
      const now = performance.now();
      if (now - (lastHighlight.get(key) ?? 0) < 1500) return;
      lastHighlight.set(key, now);
      const target: Record<string, string> = {
        hazards: '#hazards',
        chock: '#chock',
        triangle: '#triangle',
        nuts: done.has('spare') ? '#spare .nuts-spare' : '#wheelRear .nuts-rear',
        jack: '#jack',
        spare: '#spare',
        wheel: done.has('spare') ? '#spare' : '#wheelRear',
      };
      const el = target[key] && svg.querySelector(target[key]);
      if (!el) return;
      el.classList.add('hl');
      const hidden = Number(getComputedStyle(el).opacity) < 0.05;
      if (hidden) el.classList.add('ghost');
      setTimeout(() => el.classList.remove('hl', 'ghost'), 1300);
    },

    destroy() {
      resizeObs?.disconnect();
      tl.forEach(t => t.kill());
      hazardTween?.kill();
      sfx.stopHazards();
      root.innerHTML = '';
    },
  };
}
