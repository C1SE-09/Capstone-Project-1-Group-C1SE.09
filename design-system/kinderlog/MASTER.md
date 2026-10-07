# KinderLog — Design System (MASTER)

**Status:** Living document · Baseline v1.0 · 2026-10-07
**Source of truth:** the current KinderLog Figma reconstruction, mirrored by `frontend/lib/features/kindergarten_dashboard/` (Flutter).
**Documentation method:** values captured from the existing implementation and palette definitions (`theme.dart`, `widgets.dart`, `screens/*`). UI/UX Pro Max Quick Reference used for structure, UX-state coverage, accessibility rules, and anti-patterns. Its generative `--design-system` recommendations were intentionally **not** adopted — this document records the current design, it does not propose a new one.
**Change policy:** This baseline is descriptive. No color, type, spacing, component, or layout value changes without an explicit, recorded decision. New work must reuse these tokens; deviations are recorded in §15.

---

## 1. Visual Style

| Aspect | Current definition |
|---|---|
| Character | Calm, warm, service-oriented. Soft cream canvas, deep teal brand, low-contrast borders, generous whitespace. |
| Depth model | Flat. Surfaces are separated by **1px borders**, not shadows. Shadows appear only on the raised center mic button and the login logo mark. |
| Shape language | Rounded rectangles. Cards 12, controls 9, chips/full pills. |
| Color strategy | One brand hue (teal) + three semantic hue families (ok/warn/bad) + one info hue. All status color pairs are tint + ink (soft background + strong foreground). |
| Imagery | None. No photography, no illustration. Identity carried by the logo mark, palette, and typography. |
| Gradients | Exactly one: the 56px login logo mark (brand → brand @ 80%). Nothing else. |
| Platform | Mobile only, portrait. Material 3. |

---

## 2. Color Palette

Both themes ship as first-class. Widgets resolve colors through a semantic palette (`context.k` in Flutter), never through per-screen hex values.

### 2.1 Light

| Token | Hex | Role |
|---|---|---|
| canvas | `#F6F4EF` | App background, app-bar background (96% alpha) |
| surface | `#FFFFFF` | Cards, sheets, nav bar, inputs |
| surfaceSunken | `#EFECE5` | Inset fields on login, badges "none", step circles idle |
| ink | `#2A2926` | Primary text, snackbar background |
| inkSoft | `#605D57` | Secondary text, inactive nav labels |
| inkFaint | `#757169` | Tertiary/meta text (darkened to meet WCAG AA on canvas) |
| line | `#E7E3DA` | Dividers, card borders, input borders |
| lineStrong | `#D9D4C9` | Input border emphasis, sheet drag handle |
| brand | `#16665A` | Primary actions, active states, selection |
| brandStrong | `#114F46` | Reserved darker brand |
| brandTint | `#E6EFEC` | Tinted surfaces: class chip, icon squares, banners |
| ok | `#3F8B5C` | Success text/dot; `read` badge surface |
| okTint | `#E7F1EA` | Success soft background |
| warn | `#B0791B` | Warning text/dot, health filters |
| warnDeep | `#8A5E12` | Warning on tinted background |
| warnTint | `#F6EED9` | Warning soft background |
| bad | `#BB4A34` | Error text/dot, attention badge |
| badTint | `#F6E6E1` | Error soft background |
| info | `#4B6F8C` | Informational text/dot (draft state) |
| infoTint | `#E7EEF3` | Informational soft background |

### 2.2 Dark

| Token | Hex | Notes |
|---|---|---|
| canvas | `#1C1B1A` | |
| surface | `#252422` | Cards/sheets/nav |
| surfaceSunken | `#2D2C29` | |
| ink | `#E8E6E1` | |
| inkSoft | `#C4C2BC` | |
| inkFaint | `#9A9891` | |
| line | `#3E3D3A` | |
| lineStrong | `#4E4D49` | |
| brand | `#52BBA8` | Lightened for dark-surface contrast |
| brandStrong | `#6DD4C0` | |
| brandTint | `#1E3833` | |
| ok | `#6FCF8E` · okTint `#1E3328` | |
| warn | `#E5B05C` · warnDeep `#F5C878` · warnTint `#3A2F1A` | |
| bad | `#E87B63` · badTint `#3A2621` | |
| info | `#7BA3C7` · infoTint `#1F2D3A` | |

### 2.3 Semantic pairing rules

- Status pairs are always **(tint background, ink foreground)**: `badTint/bad`, `okTint/ok`, `warnTint/warn`, `infoTint/info`.
- Selected chips invert: solid tone background + white text.
- The `read` badge is the only solid-status surface: `ok` background + white text.
- Brand tint surfaces always pair with brand foreground.

---

## 3. Typography

**Family:** Be Vietnam Pro (bundled, weights 400 / 500 / 600 / 700). No system-font fallback is designed for; the family is part of the identity.

### 3.1 Theme roles (scale with system text size)

| Role | Weight | Line height | Color | Typical use |
|---|---|---|---|---|
| headlineLarge | 700 | 1.25 | ink | Reserved large display |
| headlineMedium | 700 | 1.3 | ink | Screen titles ("Chọn lớp", "Tài khoản", "Chào …") |
| titleLarge | 600 | 1.35 | ink | Card titles, sheet titles |
| titleMedium | 600 | 1.4 | ink | Row/child names, app-bar title |
| bodyLarge | 400 | 1.5 | ink | Body |
| bodyMedium | 400 | 1.5 | inkSoft | Secondary body |
| bodySmall | 400 | 1.45 | inkFaint | Meta, hints, counts |
| labelLarge | 600 | — | inherited | Button labels |

**Base sizes in use (reference, not fixed tokens):** 28 / 22 / 18 / 16 / 15 / 14 / 13 / 12 / 11. Theme roles intentionally carry **no fixed `fontSize`** so system text scaling applies.

### 3.2 Hierarchy rules

- One headline per screen; section headings are 15/600 in `ink`; meta lines are 12 in `inkFaint`.
- Numeric emphasis (progress "3/12", stat values) is weight 600, never a different family.
- All-caps is used in exactly one place: the login submit button ("ĐĂNG NHẬP", weight 700, letter-spacing 0.5). Not a general pattern.

---

## 4. Spacing System

Scale (`KSpace`): **4 · 8 · 12 · 16 · 20 · 24 · 32** (x1–x8).

| Context | Value |
|---|---|
| Screen horizontal padding | 20 (24 on login/centered flows) |
| Screen top padding | 24 (42 on class select) |
| Card internal padding | 14–16 (24 on login card) |
| Between list cards | 12–20 |
| Between fields | 12–18 |
| Icon-to-label gap | 8–14 |

Rhythm rule: related items 4–8, groups 12–16, sections 20–24, screen blocks 32.

---

## 5. Border Radius

| Token | Value | Applied to |
|---|---|---|
| card | 12 | Cards, class-select icon squares, tooltip/notice surfaces |
| control | 9 | Buttons, inputs (theme-level) |
| (login fields/button) | 10 | Login screen inputs and submit button |
| sheet | 20 (top only) | Bottom sheets |
| chip | stadium (99) | Filter chips, badges, class-select chip |
| circle | 50% | Avatars, icon circles, mic button, step dots |

Radius discipline: 9 for standard controls, 10 only within the login card, 12 for containers, pill only for chips/badges/small controls.

---

## 6. Shadows / Elevation

The system is border-first; elevation is the exception.

| Element | Treatment |
|---|---|
| Cards | `elevation: 0`, 1px `line` border, radius 12 |
| App bar | Flat `canvas` @ 96%, 1px bottom `line` border, no tint/scroll elevation |
| Bottom nav | Flat `surface`, 1px top `line` border |
| Bottom sheets | `surface`, radius 20 top, default scrim |
| Snackbar | Floating, `ink` background, radius 8 |
| Center mic button | **Only raised element:** elevation 7, `brand` @ 45% shadow, 4px `surface` ring |
| Login logo mark | `brand` @ 30% shadow, blur 12, offset (0, 4) |
| Stat icon squares | Tonal only: `tone` @ 12%, radius 8 |

---

## 7. Components

### 7.1 Buttons (`KButton`)

| Variant | Surface | Text | Use |
|---|---|---|---|
| Filled (default) | brand | white | Primary action |
| Outlined (`secondary`) | transparent | brand | Secondary/cancel |
| Text (`ghost`) | transparent | brand | Tertiary/inline |

- Shape: radius 9, full available width by default, **minimum height 44**.
- Optional 18px leading icon with 8px gap.
- States: enabled / disabled (`onPressed: null`, reduced emphasis, no action) / loading (label replaced by 22×22 white spinner, non-interactive).
- Local override: login submit is 48 high, radius 10, all-caps label.
- Pill buttons appear only as inline affordances ("Đổi lớp": outlined, radius 20, 12.5/600, padding 10×6).

### 7.2 Cards (`KCard`)

- `surface` background, 1px `line` border, radius 12, zero elevation, `clipBehavior: antiAlias`.
- Optional tap (InkWell ripple), optional tint color (e.g. `brandTint` for banners).
- Padding: 14 (stat) / 16 (standard) / 24 (login).
- Cards may contain single rows, avatar+text+trailing rows, or a column of rows separated by `Divider`.
- **No nested cards.**

### 7.3 Forms & Inputs

- Filled fields on `surface` (theme) or `surfaceSunken` (login), `isDense`, padding 14×12 (14×14 on login), radius 9 (10 on login).
- Borders: `line`/`lineStrong` at rest, **`brand` at 1.5px on focus**.
- Hint style: `inkFaint`; labels for login fields sit above as 13/600 text.
- Search field: leading 20px search icon (`inkFaint`), hint "Tìm…".
- Numeric fields accept digits only (`FilteringTextInputFormatter.digitsOnly`); text areas weigh 3–4 lines with optional character counter.
- Errors: banner above the form (login) or inline text in `bad`; forms retain entered values.

### 7.4 Navigation

**App bar (`KAppBar`)** — detail screens only: title (+ optional subtitle), optional back chevron with tooltip "Quay lại", no elevation, bottom border.

**Bottom navigation** — main teacher shell only:
- Four destinations: Tổng quan · Lớp · Lịch sử · Tài khoản.
- 22px icon over an 11px label; active = `brand`, idle = `inkFaint`; 76px tall + bottom safe area.
- Center 60px circular mic button raised 18px above the bar (the single primary "record" action), labeled for screen readers.
- Destinations are sections, never actions; the mic is the only action in the bar.

**Bottom sheets (`showKSheet`)** — 40×4 drag handle (`lineStrong`), top radius 20, `surface`, 20px padding, raises above the keyboard.

**Dialogs** — confirmations only (e.g. logout, delete/discard): short title, one-line body, two actions (`Hủy` outlined + confirming action filled).

**No drawer, no sidebar, no rail** — phone-only product.

### 7.5 Icons

- Library: Material Icons, predominantly rounded variants (`school_rounded`, `mic_none_rounded`, `swap_horiz_rounded`, `logout_rounded`…).
- Sizes in use: 15–18 inline, 20–22 controls, 28 primary, 30 logo. One family, filled style, no mixed stroke systems.
- Icon-only controls must carry a tooltip/label (back, notifications, logout, password toggle, sheet close, mic). Decorative icons beside text carry no label.
- Emoji are used **only** as section markers inside report field labels (🍽️ 😴 🎨 🎭 🏥 📝, 💬). They are content markers, not navigation or control icons. See §15.1.

### 7.6 Lists & Tables

- **No tables exist in the product.** Data is presented as card-contained rows.
- List patterns: child roster (single card, divider-separated rows, Avatar + name + StatusBadge + chevron), history (date-grouped cards; group label 11/600 `inkFaint`, letter-spacing 0.4), parent reports (ListTile rows with status text).
- Row height is content-driven; 12px padding per side; avatars 40 in rows.
- Long lists are scrollable `ListView`s inside the page; screens with a fixed header + list use Column + Expanded.

### 7.7 Status Indicators

| Indicator | Form | Mapping |
|---|---|---|
| ReportStatusBadge | Pill: 6px dot + 11/500 label, tint background | none = sunken/inkSoft · draft & processing = infoTint/info · submitted = okTint/ok · read = solid ok/white · attention = badTint/bad |
| SeverityChip | 8px dot + 12/500 label | none = ok · mild = warn · moderate = bad |
| ProgressRing | 76px ring, 7px stroke, round caps, brand on sunken, centered % | Daily report completion |
| Count text | e.g. "3 chưa xong" in `inkFaint` | Secondary counters |

Color is never the only signal: every status pairs a colored dot with a text label.

### 7.8 Charts / Data Visualization

- **No charts are rendered.** `fl_chart` is present in the dependency list but unused.
- The only data visualization is `ProgressRing` (§7.7) plus numeric stat cards.
- Any future chart work must reuse the tint/ink semantic pairs and the type scale; introduce no new hues.

### 7.9 Component Hierarchy

```
Scaffold
├── KAppBar (detail screens)            — title, subtitle, back, trailing action
├── Body
│   ├── loading | error | empty | content
│   └── content
│       ├── KCard ── row(s) / column(s) / tinted banner
│       │     ├── Avatar
│       │     ├── StatusBadge / SeverityChip
│       │     └── ProgressRing / StatCard
│       ├── SearchField
│       ├── FilterChipButton (Wrap / horizontal scroll)
│       └── (rows separated by Divider)
├── BottomActionBar (flow screens)      — primary + secondary KButton
├── bottomNavigationBar (teacher shell) — 4 destinations + raised mic
└── showKSheet (modal tasks)            — handle, content, KButtons
```

State ladder for every async screen: **loading → error (retry) → empty → content**.

---

## 8. Interaction States

| Element | Default | Pressed | Focused | Disabled | Selected/Active |
|---|---|---|---|---|---|
| Buttons | filled/outlined/text | Material ripple via InkWell/press elevation | focus ring (platform) | `onPressed: null`, dimmed, inert | — |
| Cards (tappable) | surface + border | ripple | — | — | — |
| Inputs | line border | — | brand 1.5px border | — | — |
| Chips | surface + line border | ripple | — | — | solid tone + white text |
| Nav destinations | inkFaint | ripple | — | — | brand icon + label |
| Step circles | sunken + number | — | — | — | brand + check |
| Status badge | static | — | — | — | — |

Mobile-only surface: hover states are not part of the system. All interactive elements give pressed feedback within the standard Material ripple.

---

## 9. Loading / Empty / Error States

| State | Current pattern |
|---|---|
| Screen loading | Centered `CircularProgressIndicator` (brand), full-screen or content-area |
| Button loading | Label replaced by 22×22 white spinner; button disabled |
| Step progress | `StepIndicator` with animated indeterminate bar under the active step |
| Error | Centered text "Không tải được {X} · Thử lại" as a `TextButton` that refetches |
| Inline error | Login error banner (tinted, error icon, message); report editor inline `bad` text |
| Empty | Centered one-liner: "Chưa có lớp được phân công.", "Không tìm thấy trẻ phù hợp.", "Chưa có báo cáo gần đây." |
| Partial data | Cards render with "Chưa có thông tin trường" style fallbacks |

All messages are Vietnamese, sentence case, user-facing (no codes).

---

## 10. Responsive Behavior

- **Target: phone portrait only.** No tablet, foldable, or landscape-specific layouts exist; no breakpoints are defined.
- `SafeArea` wraps headers, lists, and bottom bars (top in content areas, bottom on nav/bottom bars).
- The only width constraint is the login card (`maxWidth: 420`, centered).
- Keyboard: `adjustResize` (AndroidManifest) + scroll views; sheets add bottom view-inset padding.
- Content is full-width with 20px gutters; long text wraps to available width.

---

## 11. Accessibility Rules (current commitments)

**Implemented in the current build:**

- Icon-only controls carry accessible names: back ("Quay lại"), password visibility toggle, notifications, logout, sheet close, mic ("Ghi nhận hoạt động").
- Text scales with the system size for theme-level type roles (no fixed sizes in the type scale).
- Status is never color-only: dot + text label pairs everywhere.
- `inkFaint` was set to meet WCAG AA (4.5:1) on canvas in light mode.
- Dark theme is a designed scheme (not an inversion) with lightened brand/status hues.
- Reduce Motion is honored in the animated `StepIndicator` (falls back to a static bar).
- Touch targets: primary buttons 44+ high; nav rows padded; mic button 60.
- Contrast: body ≥ 4.5:1, large/non-text ≥ 3:1 as the bar for any new color pair.

**Bar for new work (per UI/UX Pro Max checklist):**

- Every new icon-only control gets a label and announces selected/disabled/expanded state.
- Decorative icons beside visible text are hidden from the accessibility tree.
- Focus order must match visual order.
- Reduced-motion and largest-text checks before shipping any new surface.
- Minimum targets: 44pt iOS / 48dp Android — expand hit areas when visuals are smaller.

---

## 12. UX Patterns

- **One dominant action per screen.** The teacher shell centralizes "record" in one raised mic; detail screens use a single filled primary.
- **Progressive disclosure.** Class-level recording first, "hoặc chọn từng trẻ" second; class list opens a per-child action sheet rather than inline controls.
- **Recognition over recall.** Status badges, counts, and labels are always visible; nothing requires remembering a previous screen.
- **Confirmation only for destructive/irreversible actions** (logout, discard); everything else acts immediately with undo-by-refetch.
- **Date grouping** in history and parent lists with short, localized labels.
- **Filters are chips**: Tất cả / Cảnh báo sức khỏe (roster), Tất cả / Bản nháp / Đã gửi / Đã đọc (history).
- **Loading → error → empty → content ladder** on every data screen.
- **Read markers:** opening a parent report marks it read automatically and updates the badge.
- **Vietnamese-first copy**, sentence case, no technical jargon in UI text.

---

## 13. Anti-Patterns

### 13.1 Rules this system already follows — keep it that way

1. No card shadows or ghost-card borders + shadow combined.
2. No nested cards.
3. No status conveyed by color alone.
4. No emoji as navigation/control icons.
5. No sidebar/drawer on a phone product.
6. No decorative gradients beyond the logo mark.
7. No ad-hoc hue outside the semantic set (ok/warn/bad/info/brand).
8. No hard-coded per-screen color values; all colors resolve through the palette.
9. No icon mixed-families or mixed stroke weights.
10. No modal for tasks that need neither interruption nor protected focus (sheets are the default).

### 13.2 Current deviations (documented; do not propagate into new work without a decision)

| # | Deviation | Where |
|---|---|---|
| D1 | Emoji used as section markers in report field labels (🍽️ 😴 🎨 🎭 🏥 📝, 💬) | Report editor, review cards |
| D2 | Explicit `fontSize` overrides bypass system text scaling across many widgets | Throughout screens (10.5–17 range) |
| D3 | Hard-coded `Colors.red.shade*` in the login error banner instead of `bad`/`badTint` | `auth_screens.dart` |
| D4 | `Colors.white` literals for on-brand text instead of an on-brand token | Buttons, chips, nav mic |
| D5 | Button minimum height 44 (< Android 48dp) | `KButton` |
| D6 | Raised mic button uses a colored shadow/halo | Teacher shell |
| D7 | Off-scale font sizes: 10.5 / 11.5 / 12.5 / 13.5 | Record flow, history |
| D8 | Raw exception text can reach the login error banner | `auth_screens.dart` login |
| D9 | No tablet/landscape layout (accepted scope for this product) | Global |
| D10 | No focus-order management defined | Global |

D1–D4, D6–D8 are candidates for a future, explicitly-scoped cleanup task. They are recorded here so they are not silently "fixed" or silently copied.

---

## 14. Flutter Implementation Notes

- Tokens live in `frontend/lib/features/kindergarten_dashboard/theme.dart`:
  - `KColors` — raw palette constants (light + dark).
  - `KPalette` — `ThemeExtension` with both instances; register on each `ThemeData`.
  - `context.k` — the only sanctioned way for widgets to read palette colors.
  - `KSpace` (4–32) and `KRadii` (card 12, control 9).
- `kinderTheme()` / `kinderThemeDark()` build both themes; `MaterialApp.router` uses `themeMode: ThemeMode.system`.
- Global component defaults (card, divider, input, snackbar) are defined once in `_buildTheme`.
- Shared widgets live in `widgets.dart`: `KCard`, `KButton`, `KAppBar`, `Avatar`, `StatusBadge`, `SeverityChip`, `SearchField`, `FilterChipButton`, `ProgressRing`, `StatCard`, `StepIndicator`, `BottomActionBar`, `showKSheet`.
- Screens must compose these widgets; new one-off components require a recorded reason.

---

## 15. Open Observations (no fixes implied)

1. `fl_chart` is a dependency but no chart is rendered; ProgressRing is the only visualization.
2. Dark theme is complete in code but has no captured verification pass on device.
3. History/roster use `ListView` with prebuilt children in places; large rosters may warrant `ListView.builder` later.
4. Login has no password-recovery path; report editor send has no confirmation.
5. Empty/error copy is consistent by convention, not enforced by a shared widget.

---

*End of baseline v1.0 — any revision must be recorded as a new version with a decision note.*
