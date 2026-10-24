import { mkdir, copyFile, writeFile, rm } from 'node:fs/promises';
import sharp from 'sharp';
const base = new URL('../', import.meta.url);
const dest = new URL('dist/assets/', base);
await mkdir(dest, { recursive: true });
const licenseDest = new URL('licenses/', dest);
await mkdir(licenseDest, { recursive: true });
for (const [pkg, filename] of [['@fontsource/ubuntu', 'ubuntu.txt'], ['@fontsource/ubuntu-mono', 'ubuntu-mono.txt'], ['@phosphor-icons/core', 'phosphor-icons.txt'], ['simple-icons', 'simple-icons.txt'], ['devicon', 'devicon.txt']]) {
  await copyFile(new URL(`node_modules/${pkg}/${pkg === 'simple-icons' ? 'LICENSE.md' : 'LICENSE'}`, base), new URL(filename, licenseDest));
}
for (const weight of [300, 400, 500, 700]) {
  await copyFile(new URL(`node_modules/@fontsource/ubuntu/files/ubuntu-latin-${weight}-normal.woff2`, base), new URL(`ubuntu-${weight}.woff2`, dest));
}
await copyFile(new URL('node_modules/@fontsource/ubuntu-mono/files/ubuntu-mono-latin-400-normal.woff2', base), new URL('ubuntu-mono-400.woff2', dest));
const icons = ['arrow-up-right', 'arrow-right', 'game-controller', 'hand-tap', 'plus', 'check', 'sun', 'moon', 'list', 'x', 'github-logo', 'folder-simple', 'shield-check', 'arrows-out-simple', 'cloud', 'magnifying-glass', 'wifi-high', 'battery-high', 'cell-signal-full', 'file-zip', 'hash'];
for (const name of icons) {
  await copyFile(new URL(`node_modules/@phosphor-icons/core/assets/regular/${name}.svg`, base), new URL(`${name}.svg`, dest));
}
const brands = new URL('brands/', dest);
await rm(brands, { recursive: true, force: true });
await mkdir(brands, { recursive: true });
// Multi-colour originals come from devicon; single-colour marks come from Simple Icons with the brand colour baked in.
const devicons = { flutter: 'flutter/flutter-original', dart: 'dart/dart-original', kotlin: 'kotlin/kotlin-original', android: 'android/android-original', cplusplus: 'cplusplus/cplusplus-original', vulkan: 'vulkan/vulkan-original', sqlite: 'sqlite/sqlite-original', google: 'google/google-original' };
for (const [name, file] of Object.entries(devicons)) {
  await copyFile(new URL(`node_modules/devicon/icons/${file}.svg`, base), new URL(`${name}.svg`, brands));
}
const simpleIcons = await import('simple-icons');
for (const name of ['snapdragon', 'arm', 'wine', 'mediatek', 'samsung']) {
  const icon = simpleIcons[`si${name[0].toUpperCase()}${name.slice(1)}`];
  await writeFile(new URL(`${name}.svg`, brands), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><title>${icon.title}</title><path fill="#${icon.hex}" d="${icon.path}"/></svg>\n`);
}
await sharp(new URL('artwork/world.jpg', base).pathname).resize(1600).webp({ quality: 80, effort: 6 }).toFile(new URL('world.webp', dest).pathname);
console.log('Local fonts, icons, and optimized artwork ready.');
