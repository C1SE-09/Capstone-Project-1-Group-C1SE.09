# [Fix][Attendance] Patch overlays, save race, and badge contrast

Paste this into the existing KinderLog Figma Make project. This is a targeted
patch prompt, not a redesign or a Flutter implementation. It has not been applied.

```text
Patch the existing KinderLog Attendance feature in place. Fix only the three
issues below. Inspect the current source first and apply only fixes still needed.
Keep the existing interactive app, layout, large student cards, navigation,
attendance logic, and completed health feature unchanged.

These instructions are in English. All user-facing UI text stays in Vietnamese.
Do not create a new app, static showcase, screen gallery, or extra dependencies.

Inspect:
- src/screens/attendance/AttendanceScreen.tsx
- src/screens/attendance/attendanceState.tsx
- src/index.css
- src/components/ui.tsx, as the reference for BottomBar, BottomSheet, and Toast

1. FIX FOOTER CSS WITHOUT BREAKING OVERLAYS
The current rule is too broad:
.attendance-screen > .absolute { position: relative; inset: auto; flex-shrink: 0; }

BottomBar, BottomSheet, and Toast all have direct-child absolute wrappers, so
this footer workaround also changes the positioning of dialogs and feedback.

- Replace this broad rule with an attendance-footer-specific wrapper or class.
  Apply footer layout overrides only to that wrapper or its bottom bar.
- Keep BottomSheet and Toast as correctly positioned overlays inside the app
  viewport, with their intended stacking order and backdrop behavior.
- Do not make overlays consume space in the attendance screen's flex layout,
  push the grid, appear underneath the footer, or get clipped off-screen.
- Place attendance toasts above the action area with a small gap, without
  obscuring either button; account for the footer's actual rendered height.
- Keep the footer accessible and the last student card fully reachable by
  scrolling. Preserve safe-area spacing and existing dialog focus behavior.
- Prefer an attendance-local fix; do not change shared components globally.

2. PREVENT EDITS FROM BEING LOST WHILE SAVING
saveDraft currently captures a draft, waits, and saves that snapshot. Student
cards still accept taps during the wait, then synchronization with the saved
record can overwrite those newer edits.

- Disable every student card button while saving, including keyboard activation.
- Guard changeStatus against updates while saving. Keep the existing guards
  against repeated saves and leaving the screen during the pending save.
- Preserve "Đang lưu..." feedback and restore normal interaction after saving.
- Keep the existing state model; ensure the saved record and displayed draft
  agree after completion. Do not remove synchronization just to hide the issue.

3. IMPROVE ATTENDANCE TEXT CONTRAST ONLY
Review .attendance-saved, .attendance-arrived .attendance-badge, and
.attendance-absent .attendance-badge. In light mode, the current green text/tint
pair is about 3.59:1 and the red pair about 4.18:1, below 4.5:1 for small text.

- Use darker attendance-scoped text colors or suitable existing darker tokens
  to achieve at least 4.5:1 for normal-sized active badge/status text.
- Preserve the green/red/amber meanings, background tints, icons, typography,
  and spacing. Do not enlarge text just to avoid fixing its contrast.
- Verify light and dark mode independently. Do not alter global semantic colors
  or recolor unrelated screens, especially the completed health feature.

PRESERVE THESE RULES
- One tap cycles "Đến" -> "Vắng" -> "Đến Trễ" -> "Đến"; roster order stays stable.
- Header labels remain "Tổng", "Đến", and "Vắng". Late counts as arrived.
- "Lưu điểm danh" saves only; "Gửi thông báo bé vắng" never saves attendance.
- The notification button is disabled with zero absences; late children are
  excluded from its confirmation list. Notifications remain simulated only.
- Retain the existing unsaved-changes confirmation and session-only mock records.

VERIFY BY ACTUALLY USING THE APP
- Open the absence-notification sheet and unsaved-changes sheet. Confirm their
  backdrops cover the app viewport, the actions remain reachable, closing works,
  and the grid does not move or shrink to make room for either overlay.
- Save and verify the toast is readable and not hidden by the footer.
- Tap Save, then immediately try tapping a student card or activating it with
  the keyboard. Status must not change during saving; no edit may disappear.
- Reopen after saving and verify the saved values. Edit again and test both
  continue-editing and discard actions: continuing keeps the draft; discarding
  leaves the saved record unchanged. Cards must work again after saving ends.
- Cycle a card three times and confirm live counters and stable ordering.
- Check the final card, footer, and sheets at 375 px and 320 px widths and with
  enlarged text. Switch the current app's theme to check contrast in both modes.
- Keep all checks in the interactive app; do not generate a review gallery.

Report only the files changed, measured contrast ratios, and interactions
actually tested. Explicitly list anything unverified; source changes or a static
screenshot alone are not proof that the interactive issues are fixed.
```
