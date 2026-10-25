# Nexus-PC landing page

A responsive, buildless landing page with an animated ASCII background, an interactive landscape phone running a console-style launcher, a scroll-pinned portrait phone that walks through the app's Library and Device screens, a filterable chipset list with honest status labels, a stack pipeline with full-colour technology logos, a manual-vs-Nexus comparison, a roadmap, FAQs, and a persistent theme switch. Development claims are framed as project goals.

## Run locally

```sh
npm install
npm run assets
npm run dev
```

Open http://127.0.0.1:4173. Static files are in `dist/`, ready for any static host. No runtime dependencies, accounts, tracking, or email collection.

## Design

Device-first direction that matches the app's SteamOS-style theme (`app/production/lib/theme/nexus_theme.dart`): the same blue-slate surfaces in dark and light, a Steam blue for links, focus and selection, the brand lime for primary actions, bold Ubuntu headings with Ubuntu Mono details, the lime bar-mark logo (also the app's top bar and launcher icon), Phosphor UI icons and full-colour technology logos (devicon originals for Flutter, Dart, Kotlin, Android, C++, Vulkan, SQLite and Google; Simple Icons with the brand colour for Snapdragon, Arm, Wine, MediaTek and Samsung). The hero and closing card draw a flowing ASCII field on canvas that lights up around the pointer. The app draws the same flowing ASCII field behind its pages (`app/production/lib/theme/ascii_field.dart`). The scroll-pinned portrait phone rebuilds the app's Library and Device screens, floating bottom bar and ASCII background at the app's own sizes (1 `--dp` is one density-independent pixel on a 390 dp phone). Its covers (`dist/assets/cover-*.webp`) are the app's own generated `GameArtwork` posters for those titles, rendered from Flutter. The hero phone shows the app's Home screen in landscape as a console-style launcher: controller focus walks a shelf of six sample titles, the full-screen art and title follow the focus, then Play launches a game through a "Preparing Wine + Box64" screen. The story phone's sideways screen runs a copy of the same launcher, driven by touch. The covers and backgrounds (`dist/assets/launcher/`) are the app's own generated `GameArtwork` posters, rendered from Flutter. The titles are made up, and the top bar labels them "Concept · sample titles". Real commercial game footage is deliberately not used: it is not ours to show and would imply compatibility that has not been tested. The real Phase 0 captures stay in `docs/evidence`, linked from the chipset section. Chip badges are drawn in CSS from the real Snapdragon, MediaTek and Samsung marks rather than copied from vendor artwork. Chipset statuses: Verified means the Phase 0 proof passed on a real device; Target means the Snapdragon + Adreno family being built for, untested; Untested means other ARM64 chips. Canvas loops pause off-screen, and all motion is disabled under `prefers-reduced-motion`. Brand names and logos belong to their owners; the footer says the project is not affiliated with them.

## Artwork

`artwork/world.jpg` is used only as the social preview image. It was generated with the built-in Imagegen tool. It is original concept artwork, not footage or a claim of a compatible game. The optimized WebP is served from `dist/assets/world.webp`. Prompt:

> Wide cinematic AAA game environment: an immense dark alpine valley, weathered brutalist ruins, a luminous pale lime eclipse on the horizon, mist over a lake, fern-covered rocky foreground, and a tiny lone cloaked explorer on the right. Charcoal and muted olive palette, sharp texture, volumetric light, dark negative space to the left. No text, UI, logos, devices, or watermark.
