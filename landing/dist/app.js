const icons = document.querySelectorAll('[data-icon]');
icons.forEach(icon => icon.style.setProperty('--icon', `url("assets/${icon.dataset.icon}.svg")`));

const themeButton = document.querySelector('.theme-toggle');
const themeMedia = window.matchMedia('(prefers-color-scheme: light)');
let hasSavedTheme = false;
try { hasSavedTheme = Boolean(localStorage.getItem('nexus-theme')); } catch {}
function updateThemeButton() {
  const isDark = document.documentElement.dataset.theme === 'dark';
  themeButton.setAttribute('aria-label', `Switch to ${isDark ? 'light' : 'dark'} theme`);
  themeButton.querySelector('.icon').style.setProperty('--icon', `url("assets/${isDark ? 'sun' : 'moon'}.svg")`);
  document.querySelector('meta[name="theme-color"]').content = isDark ? '#101210' : '#f0f2ec';
}
themeButton.addEventListener('click', () => {
  const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = theme;
  hasSavedTheme = true;
  try { localStorage.setItem('nexus-theme', theme); } catch {}
  updateThemeButton();
});
themeMedia.addEventListener('change', event => {
  if (!hasSavedTheme) { document.documentElement.dataset.theme = event.matches ? 'light' : 'dark'; updateThemeButton(); }
});
updateThemeButton();

const menuButton = document.querySelector('.menu-toggle');
const mobileMenu = document.querySelector('#mobile-nav');
function setMenu(open) {
  mobileMenu.hidden = !open;
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
window.matchMedia('(min-width: 768px)').addEventListener('change', event => { if(event.matches) setMenu(false); });

const controlButtons = document.querySelectorAll('[data-control]');
controlButtons.forEach(button => button.addEventListener('click', () => {
  controlButtons.forEach(control => { const active = control === button; control.classList.toggle('active', active); control.setAttribute('aria-pressed', String(active)); });
  document.querySelector('#hero-phone').dataset.mode = button.dataset.control;
  document.querySelector('#control-status').textContent = `${button.dataset.control === 'immersive' ? 'Immersive preview' : button.dataset.control === 'touch' ? 'Touch controls' : 'Controller mode'} selected.`;
}));

const tabs = [...document.querySelectorAll('.journey-step')];
function activateTab(tab, focus = false) {
  tabs.forEach(item => {
    const active = item === tab;
    item.classList.toggle('active', active);
    item.setAttribute('aria-selected', String(active));
    item.tabIndex = active ? 0 : -1;
    document.getElementById(item.getAttribute('aria-controls')).hidden = !active;
  });
  if (focus) tab.focus();
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => activateTab(tab));
  tab.addEventListener('keydown', event => {
    let next;
    if (event.key === 'ArrowDown' || event.key === 'ArrowRight') next = (index + 1) % tabs.length;
    if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;
    if (next !== undefined) { event.preventDefault(); activateTab(tabs[next], true); }
  });
});
document.getElementById('demo-import').addEventListener('click', () => activateTab(tabs[1], true));

if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
  document.documentElement.classList.add('js-reveal');
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); } });
  }, { threshold: .12 });
  document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
}
