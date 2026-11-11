# [UI][Attendance] Add touch-first attendance to the interactive prototype

Copy the prompt below into the existing KinderLog Figma Make project.
Instructions are in English; quoted Vietnamese strings are user-facing UI copy.
This is a proposed interactive design, not a Flutter implementation or a real
notification service. The completed health feature is outside this task's scope.

```text
Extend the existing KinderLog app with an interactive, touch-first teacher
attendance screen. Keep the app usable like a real mobile app: tap an entry,
open its screen, edit, save, and go back. Show one active screen at a time,
not a static preview, screen gallery, or long page stacking multiple screens.

Use English for these design instructions only. All user-facing UI text must
be in Vietnamese. Preserve the existing design system and completed features,
especially the child health profile. Do not redesign the app or add dependencies.

ENTRY AND CONTEXT
- Add a clear "Điểm danh" entry on the existing teacher class screen, near
  "Thời khóa biểu". Open attendance as a dedicated screen with a working Back
  action. Do not add a new bottom-navigation tab or replace child-detail actions.
- Use the currently selected class, its existing fictional roster and child IDs,
  and the app's current demo date. Show the class and date under "Điểm danh".
- Keep attendance state separate from report status and health data. Key mock
  records by class, date, and child. Use a seeded fictional attendance snapshot
  for this demo; do not silently establish an all-present policy for a new day.

HEADER: VISUAL ATTENDANCE TRACKING
- Below the compact app bar, show exactly three prominent, equal-width counters:
  "Tổng", "Đến", and "Vắng". Use large, readable numbers and short labels.
- Derive counts from the full class roster and current attendance draft:
  Total = roster size; Arrived = on-time + late; Absent = absent only.
  The invariant must always be Total = Arrived + Absent.
- Count "Đến Trễ" under "Đến", not "Vắng". Add small supporting text such as
  "Trong đó 2 bé đến trễ" beneath the arrived count when needed, not a fourth KPI.
- Update counters immediately after each card tap. Keep this summary compact
  and visible while the student grid scrolls. Do not add charts or a large hero.

STUDENT CARDS: OVERSIZED AND FINGER-FRIENDLY
- Prefer a two-column grid at normal phone widths, with 12 dp gaps and 20 dp
  screen gutters. Cards should be at least about 160 dp tall, not compact rows.
  At narrow widths or large text sizes, switch to a roomy one-column layout.
- Each card contains a large circular avatar, about 64 dp, the child's readable
  name, and a prominent status badge. Use fictional avatars or initials; no real
  child photos are needed. Let names wrap and cards grow rather than clipping.
- Make the entire card one large button. Tapping the avatar, name, or card
  background must perform the same attendance action, not open child details.
- One tap advances exactly one step through this repeating cycle:
  "Đến" -> "Vắng" -> "Đến Trễ" -> "Đến".
- Show a short helper above the grid:
  "Chạm vào thẻ để đổi: Đến → Vắng → Đến Trễ".
- Distinguish states with both text and an existing outline icon:
  green/check for arrived, restrained red/absence icon for absent, and
  amber/clock for late. Use subtle tinted surfaces or borders, not loud blocks.
- Provide immediate pressed feedback without shifting layout. Keep student
  order stable when statuses change; do not reorder or jump the scroll position.
- Do not interrupt every tap with a modal or toast. Show a discreet
  "Có thay đổi chưa lưu" indicator when the draft differs from the saved record.

TWO INDEPENDENT BOTTOM ACTIONS
Place two clearly separated, full-width buttons in a bottom action area, stacked
with about 12 dp between them and at least 52 dp height each. Respect safe areas
and leave enough scroll padding so the last student card remains fully reachable.

1. "Lưu điểm danh" — primary green action
- Use the existing brand green, with a clear save/check icon and readable text.
- Enable after a meaningful change. Clicking saves the draft to the shared
  in-memory attendance record, briefly shows "Đang lưu...", prevents double
  submission, then displays "Đã lưu điểm danh" and a saved-state indicator.
- Reopening the same class/date in this preview must retain the saved values.
- Saving must NEVER send absence notifications automatically.

2. "Gửi thông báo bé vắng" — separate orange/amber action
- Give it a distinct notification icon and orange/amber treatment, with adequate
  contrast. It must not look like the primary save button or a delete action.
- Keep it visible but disabled when the current draft has no absent students;
  show a short "Không có bé vắng" explanation. Enable it whenever absent > 0.
- Late students are NOT absent and must never be included as recipients.
- Clicking opens a real confirmation sheet titled "Gửi thông báo bé vắng?",
  listing the absent children and their count, with "Hủy" and
  "Gửi thông báo" actions. Do not navigate to a detached preview screen.
- Base this preview on the currently displayed draft. If there are unsaved
  edits, clearly show "Điểm danh chưa lưu" and explain that sending does not
  save attendance. Do not silently save or require a save just to open the sheet.
- This notification action is visual and interactive only: confirming shows
  simulated feedback, "Đã mô phỏng gửi thông báo", without sending a real push,
  SMS, email, or backend request. Cancelling changes nothing.

NAVIGATION AND POLISH
- Back returns to the teacher class screen. With unsaved changes, ask
  "Bỏ thay đổi điểm danh?" with "Tiếp tục điểm danh" and "Bỏ thay đổi".
  Continuing preserves the draft; discarding restores the saved snapshot.
- Reuse Be Vietnam Pro, the existing warm canvas, white surfaces, brand green,
  outline icons, 12 dp card corners, and 8 dp button corners. Keep the existing
  theme behavior, including dark-mode contrast; do not show both themes at once.
- All controls must work by touch and keyboard, with at least 48 dp touch
  targets. Announce each child's name and current status; do not rely on color.
- Keep mock records in memory for the preview session; a full page reload may
  reset them. Do not add localStorage persistence, backend work, attendance
  history, bulk marking, search/filter controls, or real notification integrations.
- Preserve existing login, class selection, reports, health, and role navigation.

VERIFY THROUGH ACTUAL INTERACTION
1. Open attendance from the class screen and verify the selected class/roster.
2. Tap one card three times: it must return to its starting status, with correct
   live counters at every step and no student-order changes.
3. Save, leave, and reopen; verify the saved values remain in this session.
4. Verify the notification button is disabled with zero absences and enabled
   with absences. Check that its sheet excludes every late student.
5. Verify Save does not notify, and the notification action does not save.
6. Check the unsaved-changes dialog, bottom-card visibility, small-screen layout,
   and large text. Report any interaction that was not actually tested.

Deliver this inside the existing interactive app, not as a new showcase page.
```
