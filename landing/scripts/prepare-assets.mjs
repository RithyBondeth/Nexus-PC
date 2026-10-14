import { mkdir, copyFile } from 'node:fs/promises';
import sharp from 'sharp';
const base = new URL('../', import.meta.url);
const dest = new URL('dist/assets/', base);
await mkdir(dest, { recursive: true });
const licenseDest = new URL('licenses/', dest);
await mkdir(licenseDest, { recursive: true });
for (const [pkg, filename] of [['@fontsource/dm-sans', 'dm-sans.txt'], ['@fontsource/space-grotesk', 'space-grotesk.txt'], ['@phosphor-icons/core', 'phosphor-icons.txt']]) {
  await copyFile(new URL(`node_modules/${pkg}/LICENSE`, base), new URL(filename, licenseDest));
}
for (const weight of [400, 500, 600, 700]) {
  for (const family of ['dm-sans', 'space-grotesk']) {
    await copyFile(new URL(`node_modules/@fontsource/${family}/files/${family}-latin-${weight}-normal.woff2`, base), new URL(`${family}-${weight}.woff2`, dest));
  }
}
const icons = ['arrow-up-right', 'arrow-right', 'play', 'game-controller', 'hand-tap', 'cube', 'plus', 'minus', 'check', 'sun', 'moon', 'list', 'x', 'github-logo', 'folder-simple', 'cpu', 'lightning', 'shield-check', 'arrows-out-simple', 'caret-right', 'download-simple', 'link-simple'];
for (const name of icons) {
  await copyFile(new URL(`node_modules/@phosphor-icons/core/assets/regular/${name}.svg`, base), new URL(`${name}.svg`, dest));
}
await sharp(new URL('artwork/world.jpg', base).pathname).resize(1600).webp({ quality: 80, effort: 6 }).toFile(new URL('world.webp', dest).pathname);
console.log('Local fonts, icons, and optimized artwork ready.');
