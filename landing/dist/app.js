const root = document.documentElement;
const motion = root.classList.contains('motion');
const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));

document.querySelectorAll('[data-icon]').forEach(icon => icon.style.setProperty('--icon', `url("assets/${icon.dataset.icon}.svg")`));
document.querySelectorAll('[data-brand-mask]').forEach(logo => logo.style.setProperty('--icon', `url("assets/brands/${logo.dataset.brandMask}.svg")`));

// Theme
const themeButton = document.querySelector('.theme-toggle');
const themeMedia = matchMedia('(prefers-color-scheme: light)');
let hasSavedTheme = false;
try { hasSavedTheme = Boolean(localStorage.getItem('nexus-theme')); } catch {}
function updateThemeButton() {
  const isDark = root.dataset.theme === 'dark';
  themeButton.setAttribute('aria-label', `Switch to ${isDark ? 'light' : 'dark'} theme`);
  themeButton.querySelector('.icon').style.setProperty('--icon', `url("assets/${isDark ? 'sun' : 'moon'}.svg")`);
  document.querySelector('meta[name="theme-color"]').content = isDark ? '#0a0e14' : '#e6ebf1';
}
themeButton.addEventListener('click', () => {
  const theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
  root.dataset.theme = theme;
  hasSavedTheme = true;
  try { localStorage.setItem('nexus-theme', theme); } catch {}
  updateThemeButton();
});
themeMedia.addEventListener('change', event => {
  if (!hasSavedTheme) { root.dataset.theme = event.matches ? 'light' : 'dark'; updateThemeButton(); }
});
updateThemeButton();

// Header and mobile menu
const header = document.querySelector('.site-header');
const menuButton = document.querySelector('.menu-toggle');
const mobileMenu = document.querySelector('#mobile-nav');
function setMenu(open) {
  mobileMenu.hidden = !open;
  header.classList.toggle('menu-open', open);
  menuButton.setAttribute('aria-expanded', String(open));
  menuButton.setAttribute('aria-label', `${open ? 'Close' : 'Open'} navigation`);
  menuButton.querySelector('.icon').style.setProperty('--icon', `url("assets/${open ? 'x' : 'list'}.svg")`);
}
menuButton.addEventListener('click', () => setMenu(mobileMenu.hidden));
mobileMenu.querySelectorAll('a').forEach(link => link.addEventListener('click', () => setMenu(false)));
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && !mobileMenu.hidden) { setMenu(false); menuButton.focus(); }
});
document.addEventListener('click', event => { if (!mobileMenu.hidden && !event.target.closest('.site-header')) setMenu(false); });
matchMedia('(min-width: 861px)').addEventListener('change', event => { if (event.matches) setMenu(false); });

// Split headings into masked words
document.querySelectorAll('[data-split]').forEach(heading => {
  let index = 0;
  const walk = node => {
    [...node.childNodes].forEach(child => {
      if (child.nodeType === Node.TEXT_NODE) {
        const fragment = document.createDocumentFragment();
        child.textContent.split(/(\s+)/).forEach(part => {
          if (!part) return;
          if (/^\s+$/.test(part)) { fragment.append(' '); return; }
          const word = document.createElement('span');
          word.className = 'w';
          word.innerHTML = '<span></span>';
          word.firstChild.textContent = part;
          word.style.setProperty('--i', index++);
          fragment.append(word);
        });
        child.replaceWith(fragment);
      } else if (child.nodeType === Node.ELEMENT_NODE) walk(child);
    });
  };
  walk(heading);
});

// Reveal on scroll: fades, split words, line drawings, count-ups
function countUp(element) {
  const target = Number(element.dataset.count);
  if (!motion) return;
  const start = performance.now();
  const step = now => {
    const t = clamp((now - start) / 1600);
    element.textContent = Math.round(target * (1 - Math.pow(1 - t, 4)));
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
const revealTargets = document.querySelectorAll('.reveal, [data-split], .chip-rail');
if ('IntersectionObserver' in window && motion) {
  document.querySelectorAll('.feature-grid, .stats, .timeline, .faq-list').forEach(group => {
    group.querySelectorAll('.reveal').forEach((item, i) => item.style.setProperty('--stagger', `${i * 90}ms`));
  });
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('in-view');
      entry.target.querySelectorAll('[data-count]').forEach(countUp);
      observer.unobserve(entry.target);
    });
  }, { threshold: .15, rootMargin: '0px 0px -5% 0px' });
  revealTargets.forEach(element => observer.observe(element));
} else {
  revealTargets.forEach(element => element.classList.add('in-view'));
}
document.querySelector('.hero h1').classList.add('in-view');

// Hero control modes
const phone = document.querySelector('#hero-phone');
const controlSwitch = document.querySelector('.control-switch');
const controlButtons = [...controlSwitch.querySelectorAll('[data-control]')];
const controlNames = { immersive: 'Immersive preview', touch: 'Touch controls', controller: 'Controller mode' };
controlButtons.forEach((button, index) => button.addEventListener('click', () => {
  controlButtons.forEach(control => { const active = control === button; control.classList.toggle('active', active); control.setAttribute('aria-pressed', String(active)); });
  controlSwitch.style.setProperty('--idx', index);
  phone.dataset.mode = button.dataset.control;
  document.querySelector('#control-status').textContent = `${controlNames[button.dataset.control]} selected.`;
}));

// Chipset rail: arrow buttons, staggered entry, tilting spotlight badge
const rail = document.querySelector('.chip-rail');
rail.querySelectorAll('.chip-tile').forEach((tile, k) => tile.style.setProperty('--k', k));
document.querySelectorAll('[data-rail]').forEach(button => button.addEventListener('click', () => {
  rail.scrollBy({ left: Number(button.dataset.rail) * rail.clientWidth * .8, behavior: motion ? 'smooth' : 'auto' });
}));
const spotlight = document.querySelector('[data-tilt]');
if (motion && matchMedia('(hover: hover)').matches) {
  spotlight.addEventListener('pointermove', event => {
    const rect = spotlight.getBoundingClientRect();
    spotlight.style.setProperty('--try', `${((event.clientX - rect.left) / rect.width - .5) * 22}deg`);
    spotlight.style.setProperty('--trx', `${-((event.clientY - rect.top) / rect.height - .5) * 22}deg`);
  });
  spotlight.addEventListener('pointerleave', () => { spotlight.style.setProperty('--try', '0deg'); spotlight.style.setProperty('--trx', '0deg'); });
}

document.querySelectorAll('.term-list li').forEach((item, k) => item.style.setProperty('--k', k));

// App screens stagger their rows in
document.querySelectorAll('.app-view').forEach(view => {
  view.querySelectorAll('.stagger').forEach((item, k) => {
    item.style.setProperty('--k', k);
  });
});

// Scroll-linked: progress bar, header hide, pinned story, timeline fill, hero drift
const story = document.querySelector('.story');
const steps = [...document.querySelectorAll('.story-step')];
const appPhone = document.querySelector('.app-phone');
const appViews = [...document.querySelectorAll('.app-view')];
const storyBar = document.querySelector('.story-progress');
const timelineWrap = document.querySelector('.timeline-wrap');
const timelineLine = document.querySelector('.timeline-line');
const heroVisual = document.querySelector('#hero-visual');
let activeStep = 0;
let lastY = scrollY;
let ticking = false;
function onScroll() {
  const y = scrollY;
  const max = root.scrollHeight - innerHeight;
  root.style.setProperty('--p', max > 0 ? (y / max).toFixed(4) : 0);
  header.classList.toggle('scrolled', y > 12);
  header.classList.toggle('hidden', motion && y > 500 && y > lastY && mobileMenu.hidden);
  lastY = y;

  const storyTop = story.offsetTop;
  const storyProgress = clamp((y - storyTop) / (story.offsetHeight - innerHeight));
  storyBar.style.setProperty('--sp', storyProgress.toFixed(4));
  const next = Math.min(steps.length - 1, Math.floor(storyProgress * steps.length));
  if (next !== activeStep) {
    activeStep = next;
    steps.forEach((step, i) => step.classList.toggle('active', i === next));
    appViews.forEach((view, i) => view.classList.toggle('active', i === next));
    appPhone.dataset.screen = next;
  }

  const rect = timelineWrap.getBoundingClientRect();
  timelineLine.style.setProperty('--tp', clamp((innerHeight * .8 - rect.top) / (rect.height + innerHeight * .3)).toFixed(4));

  if (motion && y < innerHeight * 1.2) {
    heroVisual.style.transform = `translate3d(0, ${y * .12}px, 0)`;
  }
  ticking = false;
}
addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(onScroll); } }, { passive: true });
addEventListener('resize', onScroll);
onScroll();

if (motion && matchMedia('(hover: hover)').matches) {
  // Hero device tilts toward the pointer; glare and cards follow with eased lag
  const hero = document.querySelector('.hero');
  const cards = [...document.querySelectorAll('.float-card')];
  const target = { x: 0, y: 0 };
  const current = { x: 0, y: 0 };
  hero.addEventListener('pointermove', event => {
    target.x = event.clientX / innerWidth - .5;
    target.y = event.clientY / innerHeight - .5;
  });
  hero.addEventListener('pointerleave', () => { target.x = 0; target.y = 0; });
  const tick = () => {
    current.x += (target.x - current.x) * .07;
    current.y += (target.y - current.y) * .07;
    phone.style.setProperty('--ry', `${(current.x * 18).toFixed(2)}deg`);
    phone.style.setProperty('--rx', `${(-current.y * 12).toFixed(2)}deg`);
    phone.style.setProperty('--gx', `${(current.x * 40).toFixed(1)}%`);
    cards.forEach(card => {
      const depth = Number(card.dataset.depth);
      card.style.transform = `translate3d(${(current.x * depth).toFixed(1)}px, ${(current.y * depth).toFixed(1)}px, 0)`;
    });
    requestAnimationFrame(tick);
  };
  tick();

  // Magnetic buttons
  document.querySelectorAll('.magnetic').forEach(element => {
    element.addEventListener('pointermove', event => {
      const rect = element.getBoundingClientRect();
      const x = event.clientX - rect.left - rect.width / 2;
      const y = event.clientY - rect.top - rect.height / 2;
      element.style.translate = `${x * .22}px ${y * .35}px`;
    });
    element.addEventListener('pointerleave', () => { element.style.translate = ''; });
  });

  // Feature glow follows the pointer
  document.querySelectorAll('.feature').forEach(card => card.addEventListener('pointermove', event => {
    const rect = card.getBoundingClientRect();
    card.style.setProperty('--mx', `${event.clientX - rect.left}px`);
    card.style.setProperty('--my', `${event.clientY - rect.top}px`);
  }));
}

// FAQ: animate height open and closed
document.querySelectorAll('.faq-list details').forEach(details => {
  const summary = details.querySelector('summary');
  const body = details.querySelector('.faq-body');
  summary.addEventListener('click', event => {
    if (!motion || !body.animate) return;
    event.preventDefault();
    if (details.open) {
      const animation = body.animate({ height: [`${body.offsetHeight}px`, '0px'], opacity: [1, 0] }, { duration: 450, easing: 'cubic-bezier(.65,0,.35,1)' });
      details.classList.add('closing');
      animation.onfinish = () => { details.open = false; details.classList.remove('closing'); };
    } else {
      details.open = true;
      body.animate({ height: ['0px', `${body.offsetHeight}px`], opacity: [0, 1] }, { duration: 550, easing: 'cubic-bezier(.22,1,.36,1)' });
    }
  });
});

// ASCII fields: flowing noise rendered as monospace characters, lit up around the pointer
const ASCII_RAMP = ' .\'`:-~=+*cox%#@';
function asciiField(canvas) {
  const ctx = canvas.getContext('2d');
  const host = canvas.parentElement;
  const kind = canvas.dataset.ascii;
  const pointer = { x: -9999, y: -9999, energy: 0 };
  let cols = 0, rows = 0, cellW = 8, cellH = 14, width = 0, height = 0, colors = {}, visible = true, last = 0;
  const readColors = () => {
    const style = getComputedStyle(canvas);
    colors = { base: style.getPropertyValue('--ascii').trim(), hi: style.getPropertyValue('--ascii-hi').trim() };
  };
  const resize = () => {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    width = canvas.clientWidth; height = canvas.clientHeight;
    canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // The app draws 11 dp characters; the phone mockup scales them to its 390 dp screen.
    const size = kind === 'app' ? 11 * width / 390 : width < 640 ? 11 : 13;
    ctx.font = `${size}px "Ubuntu Mono", ui-monospace, monospace`;
    ctx.textBaseline = 'top';
    cellW = ctx.measureText('M').width; cellH = size * 1.18;
    cols = Math.ceil(width / cellW) + 1; rows = Math.ceil(height / cellH) + 1;
    readColors();
  };
  const mask = (x, y) => {
    if (kind === 'hero') {
      const right = width < 1020 ? 1 : Math.min(1, Math.max(0, (x - .28) / .4));
      return (.25 + .75 * right) * Math.min(1, (1 - y) * 2.2);
    }
    if (kind === 'app') return (Math.min(1, (1 - y) * 1.6) * .85 + .15) * (.55 + .45 * x);
    const dx = x - .5, dy = (y - .5) * 1.4;
    return Math.max(0, 1 - Math.sqrt(dx * dx + dy * dy) * 1.25);
  };
  const draw = time => {
    const t = time / 1000;
    ctx.clearRect(0, 0, width, height);
    pointer.energy *= .96;
    for (let r = 0; r < rows; r++) {
      let base = '', hi = '';
      const y = r / rows;
      for (let c = 0; c < cols; c++) {
        const x = c / cols;
        const warp = Math.sin(y * 5.2 + t * .5) * .9 + Math.sin(x * 3.1 - t * .3) * .6;
        let v = .5 + .25 * Math.sin(x * 7.5 + warp + t * .45) + .25 * Math.cos(y * 9 - warp * 1.3 + t * .35);
        v = v * v * mask(x, y);
        const px = c * cellW, py = r * cellH;
        const dist = Math.hypot(px - pointer.x, (py - pointer.y) * 1.2);
        const ripple = pointer.energy * Math.exp(-dist * dist / 26000) * (.6 + .4 * Math.sin(dist * .06 - t * 6));
        const level = Math.min(.999, v + Math.max(0, ripple));
        const ch = ASCII_RAMP[Math.floor(level * ASCII_RAMP.length)];
        if (ripple > .22 && ch !== ' ') { hi += ch; base += ' '; } else { base += ch; hi += ' '; }
      }
      ctx.fillStyle = colors.base; ctx.fillText(base, 0, r * cellH);
      if (hi.trim()) { ctx.fillStyle = colors.hi; ctx.fillText(hi, 0, r * cellH); }
    }
  };
  const loop = time => {
    if (visible && time - last > 33) { last = time; draw(time); }
    if (motion) requestAnimationFrame(loop);
  };
  host.addEventListener('pointermove', event => {
    const rect = canvas.getBoundingClientRect();
    pointer.x = event.clientX - rect.left; pointer.y = event.clientY - rect.top; pointer.energy = 1;
  });
  new ResizeObserver(() => { resize(); draw(performance.now()); }).observe(canvas);
  new MutationObserver(() => { readColors(); draw(performance.now()); }).observe(root, { attributes: true, attributeFilter: ['data-theme'] });
  if ('IntersectionObserver' in window) new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }).observe(canvas);
  document.fonts.ready.then(() => { resize(); draw(performance.now()); });
  requestAnimationFrame(loop);
}
document.querySelectorAll('[data-ascii]').forEach(asciiField);

// Retro concept game: parallax ridges, a striped sun and a perspective grid, drawn procedurally
function ridge(seed, count) {
  const points = [];
  for (let i = 0; i <= count; i++) points.push(.5 + .5 * Math.sin(i * 1.7 + seed) * Math.cos(i * .63 + seed * 2.1));
  return points;
}
const RIDGES = [ridge(1.3, 24), ridge(4.1, 18), ridge(7.7, 14)];
const STARS = Array.from({ length: 70 }, (_, i) => [((i * 97) % 101) / 101, ((i * 53) % 61) / 61 * .55, (i % 5) / 5]);
function gameScene(canvas) {
  const ctx = canvas.getContext('2d');
  let width = 0, height = 0, visible = true, last = 0;
  const resize = () => {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    width = canvas.clientWidth; height = canvas.clientHeight;
    if (!width || !height) return;
    canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  const draw = time => {
    if (!width || !height) return;
    const t = time / 1000, horizon = height * .6;
    const sky = ctx.createLinearGradient(0, 0, 0, horizon);
    sky.addColorStop(0, '#05070d'); sky.addColorStop(.7, '#0c1726'); sky.addColorStop(1, '#163452');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, width, horizon);
    STARS.forEach(([x, y, p]) => {
      ctx.globalAlpha = .35 + .35 * Math.sin(t * 2 + p * 9);
      ctx.fillStyle = '#dbe9f8'; ctx.fillRect(x * width, y * height, 1.5, 1.5);
    });
    ctx.globalAlpha = 1;
    const sunX = width * .62, sunY = horizon * .78, sunR = height * .26;
    const sun = ctx.createLinearGradient(0, sunY - sunR, 0, sunY + sunR);
    sun.addColorStop(0, '#e9ffb0'); sun.addColorStop(.55, '#c3ed72'); sun.addColorStop(1, '#5c8a1c');
    ctx.save();
    ctx.beginPath(); ctx.arc(sunX, sunY, sunR, 0, Math.PI * 2); ctx.clip();
    ctx.fillStyle = sun; ctx.fillRect(sunX - sunR, sunY - sunR, sunR * 2, sunR * 2);
    ctx.fillStyle = '#0c1726';
    for (let i = 0; i < 7; i++) {
      const band = (i + (t * .25) % 1) / 7;
      ctx.fillRect(sunX - sunR, sunY + band * sunR, sunR * 2, Math.max(1, band * sunR * .22));
    }
    ctx.restore();
    const ridgeColors = ['#16283c', '#0f1c2b', '#08111b'];
    RIDGES.forEach((points, layer) => {
      const speed = (layer + 1) * 14, amp = height * (.2 - layer * .045), baseY = horizon + layer * 2;
      const step = width / (points.length - 3), offset = (t * speed) % step;
      const shift = Math.floor(t * speed / step);
      ctx.beginPath(); ctx.moveTo(0, baseY);
      for (let i = 0; i < points.length; i++) {
        const value = points[(i + shift) % points.length];
        ctx.lineTo(i * step - offset, baseY - value * amp - (2 - layer) * height * .03);
      }
      ctx.lineTo(width, baseY); ctx.closePath();
      ctx.fillStyle = ridgeColors[layer]; ctx.fill();
      if (layer === 2) { ctx.strokeStyle = 'rgba(195,237,114,.55)'; ctx.lineWidth = 1.2; ctx.stroke(); }
    });
    ctx.fillStyle = '#060a10'; ctx.fillRect(0, horizon, width, height - horizon);
    ctx.strokeStyle = 'rgba(195,237,114,.45)'; ctx.lineWidth = 1;
    const vx = width / 2;
    for (let i = -12; i <= 12; i++) { ctx.beginPath(); ctx.moveTo(vx + i * width * .02, horizon); ctx.lineTo(vx + i * width * .16, height); ctx.stroke(); }
    for (let i = 0; i < 9; i++) {
      const p = ((i + (t * .9) % 1) / 9), y = horizon + Math.pow(p, 2.2) * (height - horizon);
      ctx.globalAlpha = .2 + p * .7; ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
    }
    ctx.globalAlpha = 1;
    const shipX = vx + Math.sin(t * 1.1) * width * .12, shipY = height * .84 + Math.sin(t * 3) * 2;
    ctx.fillStyle = '#c3ed72'; ctx.beginPath();
    ctx.moveTo(shipX, shipY - height * .06); ctx.lineTo(shipX + width * .035, shipY + height * .03); ctx.lineTo(shipX, shipY + height * .012); ctx.lineTo(shipX - width * .035, shipY + height * .03); ctx.closePath(); ctx.fill();
    ctx.fillStyle = 'rgba(195,237,114,.35)'; ctx.fillRect(shipX - 2, shipY + height * .03, 4, height * .03 + Math.random() * 4);
  };
  const loop = time => {
    if (visible && time - last > 33) { last = time; draw(time); }
    if (motion) requestAnimationFrame(loop);
  };
  new ResizeObserver(() => { resize(); draw(performance.now()); }).observe(canvas);
  if ('IntersectionObserver' in window) new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }).observe(canvas);
  requestAnimationFrame(loop);
}
document.querySelectorAll('[data-game]').forEach(gameScene);

// Boot log and score ticker on the hero phone
const bootLog = document.querySelector('[data-boot-log]');
if (motion && bootLog) {
  ['Detecting chipset…', 'Snapdragon · Adreno', 'Preparing Wine + Box64…', 'Launching game'].forEach((line, i) => setTimeout(() => { bootLog.textContent = line; }, i * 600));
}
const score = document.querySelector('[data-score]');
if (motion && score) {
  let points = 0;
  setInterval(() => { points += 10 + Math.floor(Math.random() * 40); score.textContent = String(points).padStart(6, '0'); }, 400);
}

// Hero screen alternates between the concept scene and real runtime captures
const heroScreen = document.querySelector('.device-screen[data-slide]');
const screenLabel = document.querySelector('[data-screen-label]');
const slides = [
  ['Concept scene', 9000],
  ['Real capture · Xiaomi 17 Pro · Phase 0', 5000],
  ['Real capture · Fifteen · 16 KB ARM64', 5000]
];
if (motion && heroScreen) {
  let slide = 0;
  const advance = () => {
    slide = (slide + 1) % slides.length;
    heroScreen.dataset.slide = slide;
    screenLabel.textContent = slides[slide][0];
    setTimeout(advance, slides[slide][1]);
  };
  setTimeout(advance, 3000 + slides[0][1]);
}
