# Nexus-PC landing page

A responsive, buildless landing page with original cinematic artwork, self-hosted fonts, accessible workflow tabs, control-mode previews, FAQs, and a persistent theme switch. Development claims are intentionally framed as project goals; the handheld scene is labeled as a concept.

## Run locally

```sh
npm install
npm run assets
npm run dev
```

Open http://127.0.0.1:4173. Static files are in `dist/`, ready for any static host. No runtime dependencies, accounts, tracking, or email collection.

## Design

Native CSS cinematic hardware direction. Space Grotesk display type, DM Sans body type, one lime accent, Phosphor icons. The system theme is respected; a manual selection is stored locally. Motion uses CSS and IntersectionObserver with a reduced-motion fallback.

## Artwork

`artwork/world.jpg` was generated with the built-in Imagegen tool. It is original concept artwork, not footage or a claim of a compatible game. The optimized WebP is served from `dist/assets/world.webp`. Prompt:

> Wide cinematic AAA game environment: an immense dark alpine valley, weathered brutalist ruins, a luminous pale lime eclipse on the horizon, mist over a lake, fern-covered rocky foreground, and a tiny lone cloaked explorer on the right. Charcoal and muted olive palette, sharp texture, volumetric light, dark negative space to the left. No text, UI, logos, devices, or watermark.
