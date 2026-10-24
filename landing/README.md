# Nexus-PC landing page

A responsive, buildless landing page with an animated ASCII background, an interactive landscape phone running a procedural concept game, a scroll-pinned portrait phone that walks through the app's Library and Device screens, a filterable chipset list with honest status labels, a stack pipeline with full-colour technology logos, a manual-vs-Nexus comparison, a roadmap, FAQs, and a persistent theme switch. Development claims are framed as project goals.

## Run locally

```sh
npm install
npm run assets
npm run dev
```

Open http://127.0.0.1:4173. Static files are in `dist/`, ready for any static host. No runtime dependencies, accounts, tracking, or email collection.

## Design

Device-first direction: Ubuntu and Ubuntu Mono type, one lime accent, Phosphor UI icons and full-colour technology logos (devicon originals for Flutter, Dart, Kotlin, Android, C++, Vulkan, SQLite and Google; Simple Icons with the brand colour for Snapdragon, Arm, Wine, MediaTek and Samsung). The hero and closing card draw a flowing ASCII field on canvas that lights up around the pointer. Both phones run a procedural retro game scene drawn on canvas, not footage of a real game. Chipset statuses: Verified means the Phase 0 proof passed on a real device; Target means the Snapdragon + Adreno family being built for, untested; Untested means other ARM64 chips. Canvas loops pause off-screen, and all motion is disabled under `prefers-reduced-motion`. Brand names and logos belong to their owners; the footer says the project is not affiliated with them.

## Artwork

`artwork/world.jpg` is now used only as the social preview image. It was generated with the built-in Imagegen tool. It is original concept artwork, not footage or a claim of a compatible game. The optimized WebP is served from `dist/assets/world.webp`. Prompt:

> Wide cinematic AAA game environment: an immense dark alpine valley, weathered brutalist ruins, a luminous pale lime eclipse on the horizon, mist over a lake, fern-covered rocky foreground, and a tiny lone cloaked explorer on the right. Charcoal and muted olive palette, sharp texture, volumetric light, dark negative space to the left. No text, UI, logos, devices, or watermark.
