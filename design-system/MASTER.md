# TrailGuard AI — standing design decisions

Read this before changing any UI. Update it when a decision changes; do not silently discard
a decision a human made.

## Tokens

`lib/core/theme.dart` is the single source of truth. Never hard-code a `Color(0xFF…)` in a widget.

- **Palette:** forest green. `primary #0F5238`, `background #E8FFF0`, `error #BA1A1A`.
  Measured: primary-on-white **9.19:1**, body-on-background **8.88:1**, error pair **7.24:1**.
- **Type:** Plus Jakarta Sans (headline) + Manrope (body). One headline family, one body family.
- **Radii (from `DESIGN.md`, adopted 2026-09-07):** `radiusField` 8 · secondary chrome 12 ·
  `radiusCard` 16 · `radiusPill` 999. The pill is the signature interactive shape. Before this
  the app used 12 different radius values (2,4,8,10,12,14,16,18,20,22,24,999) — a soup, not a
  scale. 41 call sites were remapped.
- **Buttons are pills, sentence case, 16px/w700, no letter-spacing.** Uppercase survives only on
  eyebrow tags (`AppTheme.label()` at 1.5 tracking): section headers, stat labels, status chips.
- **Elevation: 0.** Press feedback is ripple, never a shadow lift. Shadows are an anti-pattern
  for a safety app; the only exception is the map search bar floating over the map.

### Interaction state tokens (added 2026-09-07)

`hoverOverlay` 4% · `pressedOverlay` 10% · `focusOverlay` 16% · `disabledOpacity` 0.38 ·
`minTapTarget` 48. Nothing may invent its own state values.

## `DESIGN.md` — how much of it applies

`DESIGN.md` is an Uber-inspired system (black/white, pill-999, 16px cards, sentence case).
**Adopted: the shape and button language only** — pill interactive shape, the radius scale,
sentence-case button labels, button type.

**Deliberately NOT adopted, and why:**
- Its `#000000`/`#FFFFFF` palette and its "don't introduce a second brand accent colour
  (orange, blue, green)" rule. TrailGuard's identity is forest green, and more importantly
  `DESIGN.md` defines **no error colour at all** — a survival app with an `Emergency SOS`
  button and a rescue-dispatch flow cannot give up its red.
- UberMove / UberMoveText. Plus Jakarta Sans + Manrope stay.
- Its editorial 4:3 illustration system — TrailGuard has no illustration library.

## Rules

1. **No bare `GestureDetector` for anything that behaves like a button.** Use
   `lib/widgets/pressable.dart`. Two exceptions exist and are intentional: the map surface
   (`map_screen.dart:248`) and the sheet drag handle (`:580`) — surface gestures, not controls.
2. **Every control has a screen-reader name.** `Pressable.label` is required; `IconButton`
   needs a `tooltip`.
3. **48×48 minimum tap target.** Not the 44 iOS floor — this app is used one-handed, outdoors,
   sometimes with gloves.
4. **Keyboard focus gets a 2px ring, not just a tint** — white on dark fills, primary otherwise.
   The app runs in a browser; Tab has to work.
5. **A disabled control must say why.** `Pressable` shows its tooltip while disabled on purpose.
6. **No state is signalled by colour alone.** Pair colour with an icon, a shape, or weight.
7. **Bottom-nav inactive is `primary @ 0.75`, never lower.** At 0.55 it computed to `#7BA092` on
   white = 2.88:1 and failed WCAG at every threshold. 0.75 gives `#4B7D6A` = 4.73:1.

## Known open items

- **`google_fonts` fetches Plus Jakarta Sans and Manrope from Google's CDN at runtime.** For an
  app whose entire pitch is "works offline", the fonts should be bundled as assets. Until they
  are, the first launch without a network renders in a fallback face with different metrics.
- The SOS signature interaction (see `DESIGN-BRIEF.md` §7) is designed but not built.
- 49 `withOpacity` deprecation warnings remain in older screens; new code uses `withValues`.
