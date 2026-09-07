# Design brief — TrailGuard interaction layer & button system

> Status: **BUILT (reduced scope)** — approved 2026-09-07, then narrowed mid-build at the
> user's request ("quick … no hard just clear").
>
> **Descoped from the approved brief, deliberately:**
> - The `TrailPressable` primitive with press-scale, busy state and a states-controller became
>   `lib/widgets/pressable.dart` — a ~120-line wrapper over `Material` + `InkWell`. Flutter's
>   `InkWell` already provides ripple, hover and keyboard activation; re-implementing them was
>   the "hard" part and bought nothing.
> - **The SOS arming ring (§7, the signature) was not built.** SOS now simply has a working
>   `onTap`, a screen-reader name and keyboard access. The dead tap is fixed; the memorable
>   moment is not there. This is the one place the delivered work is weaker than the brief.
> - Press-scale 0.97 (§2 row 4) dropped — `InkWell`'s ripple is the press feedback instead.
> - Reduced-motion handling (§5) not implemented.
> - The 4 motion tokens were trimmed to 5 state tokens actually consumed.
> Date: 2026-09-07 · Stack: Flutter 3.47 / Material 3 · Pattern: component system + app-shell navigation
> Scope: interaction layer + button system, web-aware phone-first, one signature (SOS)

---

## 1. Thesis

**Every control in TrailGuard should tell you it heard you — before, during, and after the press —
whether you are tapping it with cold hands on a phone or tabbing through it in a browser.**

Success looks like: **zero dead taps.** Every interactive element has hover, focus, pressed,
disabled and busy states. The emergency control is reachable in one gesture *and* one keystroke.
Nothing in the interactive layer fails WCAG AA.

---

## 2. Decisions

| # | Decision | Why | Runner-up | Confidence |
|---|---|---|---|---|
| 1 | **Keep the entire token system.** Green forest palette, Plus Jakarta Sans + Manrope, radii 18/24/999. | `theme.dart` is a real, coherent M3 system; I measured 8 pairs and 7 pass AA, 6 pass AAA. | The database proposed a blue/amber flat palette (`#3B82F6`) — **discarded outright.** | high (read `theme.dart`, ran `contrast`) |
| 2 | **Add exactly 4 missing tokens**, not a new system: `focusRing`, `pressedOverlay`, `disabledOpacity`, `motionFast/motionBase`. | You cannot build states without naming them; adding them to `theme.dart` keeps the "tokens only" rule intact. | Hard-coding state values at each site — rejected, that is how the current drift started. | high |
| 3 | **One new primitive: `TrailPressable`.** Ripple + press-scale + hover + focus ring + disabled + busy + semantics + haptics, in one widget. | 10 controls currently hand-roll their feedback or omit it entirely. Fixing sites one by one does not stop the 11th. | Fixing each `GestureDetector` individually — rejected, no leverage. | high |
| 4 | **Press feedback = scale 0.97 over 120ms, no delay, zero elevation change.** | The database's "Flat Design Mobile (Touch-First)" spec, and it matches a theme that is `elevation: 0` throughout. | Elevation lift on press — rejected; the reasoning rule lists complex shadows as an anti-pattern for this product type. | high |
| 5 | **Focus ring: 2px `primary`, 2px offset, keyboard-only** (`WidgetState.focused`, never on tap). | UX rule *Focus States* scored 9.17, severity High — and this is now a browser app with **zero** focus handling in 8,781 lines. | The browser default outline — rejected, it is nearly invisible on `#E8FFF0`. | high |
| 6 | **Bottom nav inactive: `primary` @ 0.55 → 0.75 opacity.** | Current `#7BA092` on white = **2.88:1, FAIL**. At 0.75 it computes to `#4B7D6A` = **4.73:1, AA pass**, and stays a token expression rather than a new hex. | A neutral grey (`onSurfaceVariant`, 9.32:1) — rejected, it breaks the green identity for no accessibility gain. | high (computed) |
| 7 | **Nav label 9px → 10px, icon 22 → 24px.** | `navigation.md` mobile spec is "icon 24px + label 10–11px, always show label". 9px is below any legible floor. | Dropping labels for icons only — rejected, checklist item 23 forbids unnamed icon-only nav. | high |
| 8 | **All touch targets ≥ 48×48.** Send (44), voice (44) and avatar (42) come up. | UX rule *Touch Target Size*, severity High; the flat-design spec sets `--touch-target: 48px`. | Keeping 44 (the bare iOS minimum) — rejected, this app is used with gloves and one hand. | high |
| 9 | **Send button gets three states: disabled / ready / streaming-stop.** | `_isThinking` already exists (`chat_screen.dart:37`, set `:169`) and is **never** used to guard send, so taps queue overlapping responses. UX rule *Loading Buttons*, High. | A toast saying "please wait" — rejected, a disabled control beats an error message. | high |
| 10 | **Signature: the SOS arming control** (spec in §7). | It is the highest-stakes control in the app and currently the least discoverable one. | Spending the boldness on chat streaming — the user chose SOS. | high |

**Binding constraints — anti-patterns we will not ship:**

- **No color-only state indicators.** Every state changes at least two channels (color + scale, or
  color + shape, or color + weight). Listed as an anti-pattern for this product type.
- **No shadows or 3D effects on controls.** The theme is `elevation: 0`; press feedback is scale, not lift.
- **No new accent color.** Accent means action; decoration uses neutrals.
- **No animation scattered across elements.** One orchestrated moment (SOS), everything else at 120–150ms.
- **No emoji as icons.** Material Icons only, consistent weight.
- **No `outline: none` without a replacement** — every focusable control gets a visible ring.

---

## 3. Wireframe

### 3a. `TrailPressable` — the state machine every control inherits

```
IDLE                 HOVER (web)           FOCUSED (keyboard)      PRESSED
+--------------+     +--------------+      +==============+        +------------+
|              |     |░░░░░░░░░░░░░░|      ‖              ‖        |            |   scale 0.97
|   [icon]     |     |░░ [icon] ░░░░|      ‖   [icon]     ‖        |  [icon]    |   120ms easeOut
|              |     |░░░░░░░░░░░░░░|      +==============+        +------------+
+--------------+     +--------------+       ^ 2px primary ring,     + ripple from
                      ^ pressedOverlay        2px offset              touch point
                        @ 4% primary          keyboard only         + haptic

DISABLED             BUSY
+--------------+     +--------------+
|   [icon]     |     |   ( ) 18px   |   spinner replaces label,
+--------------+     +--------------+   width held so nothing jumps
 opacity 0.38         onPressed ignored
 no ripple, no hover  no ripple
 cursor: not-allowed
```

### 3b. The SOS signature — press-and-hold to arm

```
   RESTING                      ARMING (held 0-800ms)          FIRED
+---------------------+     +---------------------+     +---------------------+
| (!)  EMERGENCY SOS  |     | (!)  KEEP HOLDING…  |     | (!)  DISPATCH OPEN  |
|      Hold to open   |     |      ▓▓▓▓▓▓▓░░░░░░  |     |      Connecting…    |
|      Rescue Dispatch|     |      release=cancel |     |                     |
+---------------------+     +---------------------+     +---------------------+
   errorContainer bg          ring sweeps 0→360°          error bg, white text
   error circle + arrow       around the SOS circle       heavyImpact haptic
                              mediumImpact at start        → RescueChatScreen
                              scale 0.98

   TAP (no hold)  →  ring flashes 25% + label swaps to "Hold to open" for 1.4s
                     — never a dead tap, never an accidental fire
   Space/Enter    →  hold-to-arm works identically from the keyboard
```

### 3c. Bottom nav — before / after

```
BEFORE                                  AFTER
+----------------------------+          +----------------------------+
| [▣HOME] chat  map  cam  pr |          | [▣HOME] Chat  Map  Cam  Pr |
+----------------------------+          +----------------------------+
  inactive #7BA092  2.88:1 FAIL           inactive #4B7D6A  4.73:1 PASS
  icon 22 / label 9px                     icon 24 / label 10px
  no focus ring                           2px focus ring, Tab order L→R
  no hover                                hover tint on web
  no haptic                               selectionClick on change
```

### 3d. Send button — three states

```
DISABLED (empty)      READY                  STREAMING
   ( ➤ )                ( ➤ )                  ( ■ )
   opacity .38          primary fill           error fill
   onPressed: null      haptic lightImpact     tap = stop generating
   48×48                48×48                  48×48
```

---

## 4. Element spec — every conversion site

### 4a. New files

| File | Contains |
|---|---|
| `lib/widgets/trail_pressable.dart` | `TrailPressable` + `TrailIconButton` + `HapticLevel` enum |
| `lib/widgets/sos_button.dart` (rewrite) | The arming control from §3b |

### 4b. `TrailPressable` API

```dart
TrailPressable({
  required Widget child,
  required VoidCallback? onPressed,   // null ⇒ disabled state, no ripple, no hover
  String? semanticLabel,              // required in practice; asserts in debug
  String? tooltip,                    // shown on hover/long-press
  BorderRadius? borderRadius,         // null + shape:circle ⇒ CircleBorder
  PressableShape shape = .rounded,
  bool busy = false,                  // shows spinner, ignores taps
  HapticLevel haptic = .light,
  double pressScale = 0.97,
  Color? overlayColor,
  EdgeInsets? padding,
  Size minimumSize = const Size(48, 48),
})
```

### 4c. Conversion table — all 10 `GestureDetector` sites

| # | Site | Today | Action | Why |
|---|---|---|---|---|
| 1 | `sos_button.dart:19` | long-press + double-tap only, no `onTap` | **Rewrite as arming control** | No tap handler on the emergency control; unreachable by keyboard |
| 2 | `chat_screen.dart:474` | send button, always "enabled" | → `TrailPressable`, 3 states | Silent no-op when empty; queues overlapping streams |
| 3 | `rescue_chat_screen.dart:237` | send button, always "enabled" | → `TrailPressable`, 3 states | Same, in the emergency flow — worse |
| 4 | `voice_button.dart:81` | mic toggle, 44×44 | → `TrailPressable` circle, 48×48 | No press feedback on a stateful toggle |
| 5 | `camera_screen.dart:309` | shutter, 76×76 | → `TrailPressable` circle | The single most-tapped control on that screen has no feedback |
| 6 | `home_screen.dart:170` | avatar → `/profile`, 42×42 | → `TrailPressable` circle, 48×48 | Undersized nav target, no affordance |
| 7 | `profile_screen.dart:150` | avatar picker | → `TrailPressable` circle | Looks decorative; nothing says it is tappable |
| 8 | `map_screen.dart:385` | search bar → `_openSearch` | → `TrailPressable` rounded | Looks like an input, behaves like a button, gives no feedback |
| 9 | `map_screen.dart:247` | map surface tap-to-collapse | **keep `GestureDetector`** | A full-bleed surface gesture, not a control |
| 10 | `map_screen.dart:585` | bottom-sheet drag handle | **keep**, add `Semantics` | Legitimate gesture affordance; needs a name, not a ripple |

### 4d. Other edits

| Site | Change |
|---|---|
| `theme.dart` | Add the 4 state tokens (§2 row 2) + `focusColor`/`hoverColor` on the button themes |
| `app.dart:250,259` | Nav inactive `0.55` → `0.75` |
| `app.dart:260` | Nav label `fontSize: 9` → `10` |
| `app.dart` `_NavPill` | Icon `22` → `24`; wrap in `TrailPressable`; add `Semantics(selected:)`; `selectionClick` haptic |
| `chat_screen.dart` | Send guarded by `_isThinking`; streaming state becomes a stop control |
| Every `IconButton` (9 sites) | Add `tooltip:` where missing — 6 of 9 have none |

---

## 5. States

| State | Trigger | Visual | Note |
|---|---|---|---|
| **Idle** | default | token colors, scale 1.0 | — |
| **Hover** | pointer over (web) | `pressedOverlay` @ 4% primary | Never fires on touch devices |
| **Focused** | keyboard Tab | 2px `primary` ring, 2px offset | Keyboard-only; suppressed on tap |
| **Pressed** | pointer down | scale 0.97, ripple, overlay @ 8% | 120ms easeOut, haptic on down |
| **Disabled** | `onPressed == null` | opacity 0.38, no ripple/hover, `SystemMouseCursors.basic` | M3 disabled opacity |
| **Busy** | `busy: true` | 18px spinner, width held | Taps ignored; prevents double-submit |
| **Selected** | nav active | filled pill + white icon + 24px icon | Two channels, never color alone |
| **SOS arming** | hold 0–800ms | ring sweeps 0→360°, scale 0.98 | Release before 800ms cancels |
| **SOS hint** | tap without hold | ring flashes 25%, label → "Hold to open" 1.4s | Replaces today's dead tap |

**Reduced motion:** `MediaQuery.disableAnimations` (set by OS/browser) drops press-scale and the
pulse to zero and shortens the SOS arm to a 250ms fade — the ring still fills, because it carries
information, not decoration.

---

## 6. Interaction & motion

| Element | Duration | Curve |
|---|---|---|
| Press scale | 120ms | `easeOut` |
| Hover / focus fade | 150ms | `easeOut` |
| Nav pill fill | 250ms (unchanged) | `easeOut` |
| SOS arm sweep | 800ms | `linear` (a progress bar must not lie about progress) |
| SOS cancel | 200ms | `easeIn` |

**Haptics** (`HapticFeedback`, silently no-ops on web):
`selectionClick` on nav change · `lightImpact` on primary actions · `mediumImpact` on SOS arm start ·
`heavyImpact` on SOS fire.

**Keyboard:** Tab reaches every control in visual order. Enter/Space activates. SOS responds to
held Space/Enter with the same 800ms arm.

---

## 7. The signature — one element, and only one

**The SOS arming ring.**

It is the only place in the app that gets a bespoke animation. It earns it because it solves four
real problems at once, all of which I verified in the code:

1. `sos_button.dart:19-21` has **no `onTap`** — tapping the emergency button today does nothing.
2. It is **unreachable by keyboard**, which now matters because the app runs in a browser.
3. Long-press exists to stop accidental firing — a real constraint the redesign must preserve.
4. The current subtitle ("Long-press — opens Rescue Dispatch simulation") is instructions
   compensating for a missing affordance.

The ring makes the control tappable, discoverable, keyboard-operable and still guarded. Everything
else in this brief stays deliberately quiet.

---

## 8. Tokens used

All existing, from `lib/core/theme.dart`:

```
primary            #0F5238    focus ring, active nav, primary fill
primaryFixed       #B1F0CE    icon container backgrounds
error              #BA1A1A    SOS circle, streaming-stop, listening mic
errorContainer     #FFDAD6    SOS card background
onErrorContainer   #93000A    SOS text                     (7.24:1 ✓)
surfaceContainerLowest #FFFFFF  nav + card surfaces
onSurfaceVariant   #404943    secondary text               (8.88:1 ✓)
outlineVariant     #BFC9C1    drag handle, dividers
radius             18 controls · 24 cards · 28 nav · 999 pills
type               Plus Jakarta Sans (headline) · Manrope (body)
```

Four new, added to `theme.dart`:

```
focusRing          primary, 2px, 2px offset
pressedOverlay     primary @ 8%  (hover 4%)
disabledOpacity    0.38
motionFast 120ms · motionBase 150ms · motionArm 800ms
```

Changed: nav inactive `primary @ 0.55` → `primary @ 0.75` (2.88:1 FAIL → 4.73:1 PASS).
**No new colors.**
