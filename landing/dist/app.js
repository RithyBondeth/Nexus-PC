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

// Console-style launcher demo: controller focus walks the cover shelf, the hero follows, then Play launches a game.
// The story phone's sideways screen gets a copy of the same launcher, driven by touch.
const LX_GAMES = [
  ['Aurora Run', 'Ready', '4.2 GB'], ['Pale Summit', 'Ready', '11.8 GB'], ['Ember Ridge', 'Needs setup', '2.6 GB'],
  ['Deep Signal', 'Ready', '7.1 GB'], ['Glass Harbor', 'Ready', '3.4 GB'], ['Night Market', 'Ready', '9.9 GB']
];
const LX_STEPS = ['Matching Snapdragon profile…', 'Preparing Wine + Box64…', 'Starting game'];
const launcherSource = document.querySelector('[data-launcher]');
const launcherCopy = document.querySelector('[data-launcher-copy]');
if (launcherSource && launcherCopy) {
  const copy = launcherSource.cloneNode(true);
  copy.classList.add('touch');
  launcherCopy.append(copy);
}
function runLauncher(root, startDelay) {
  const $ = selector => root.querySelector(selector);
  const art = [...root.querySelectorAll('.lx-art span')];
  const covers = [...root.querySelectorAll('.lx-cover')];
  const play = $('.lx-play'), tap = $('.lx-tap'), title = $('[data-lx-title]');
  let visible = true;
  if ('IntersectionObserver' in window) new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }).observe(root);
  const sleep = ms => new Promise(done => setTimeout(done, ms));
  const whenVisible = async () => { while (!visible) await sleep(400); };
  // Layout offsets, not screen rects: the phones are rotated and tilted in 3D.
  const centre = el => {
    let x = el.offsetWidth / 2, y = el.offsetHeight / 2;
    for (let node = el; node && node !== root; node = node.offsetParent) { x += node.offsetLeft; y += node.offsetTop; }
    return [x, y];
  };
  const focus = el => {
    root.querySelectorAll('.focus').forEach(node => node.classList.remove('focus'));
    el.classList.add('focus');
    const [x, y] = centre(el);
    tap.style.left = `${x}px`; tap.style.top = `${y}px`;
    tap.classList.remove('hit'); void tap.offsetWidth; tap.classList.add('hit');
  };
  const show = index => {
    const [name, state, size] = LX_GAMES[index];
    art.forEach((layer, i) => layer.classList.toggle('on', i === index));
    covers.forEach((cover, i) => cover.classList.toggle('selected', i === index));
    title.classList.add('swap');
    // Text changes while the title is faded out, so the pills never disagree with it.
    setTimeout(() => {
      title.textContent = name;
      title.classList.remove('swap');
      $('[data-lx-state]').textContent = state;
      $('.lx-pill.state').classList.toggle('setup', state !== 'Ready');
      $('.lx-pill.state .icon').style.setProperty('--icon', `url("assets/${state === 'Ready' ? 'check-circle-fill' : 'wrench-fill'}.svg")`);
      $('[data-lx-size]').textContent = size;
      $('[data-lx-play]').textContent = state === 'Ready' ? 'PLAY' : 'SET UP';
    }, 220);
  };
  const loop = async () => {
    await sleep(startDelay);
    for (;;) {
      for (let i = 0; i <= 3; i++) {
        await whenVisible();
        focus(covers[i]); show(i);
        await sleep(1500);
      }
      focus(play); await sleep(700);
      play.classList.add('pressed'); await sleep(220); play.classList.remove('pressed');
      $('[data-lx-launch]').textContent = `Launching ${LX_GAMES[3][0]}`;
      root.classList.add('launching');
      $('[data-lx-status]').textContent = 'Preparing';
      for (const step of LX_STEPS) { $('[data-lx-step]').textContent = step; await sleep(950); }
      $('[data-lx-status]').textContent = 'Game running';
      await sleep(700);
      root.classList.remove('launching');
      root.querySelectorAll('.focus').forEach(node => node.classList.remove('focus'));
      await sleep(1600);
      $('[data-lx-status]').textContent = 'Runtime ready';
    }
  };
  if (motion) loop();
}
document.querySelectorAll('[data-launcher]').forEach((root, i) => runLauncher(root, i === 0 ? 3400 : 600));

// Boot log on the hero phone
const bootLog = document.querySelector('[data-boot-log]');
if (motion && bootLog) {
  ['Detecting chipset…', 'Snapdragon · Adreno', 'Preparing Wine + Box64…', 'Launching game'].forEach((line, i) => setTimeout(() => { bootLog.textContent = line; }, i * 600));
}

