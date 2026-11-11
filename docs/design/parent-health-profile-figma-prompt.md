# [UI][Parent Health] Restore the interactive app blueprint

> **Brief Make lịch sử (05/11/2026).** “Current version” bên dưới chỉ so với
> prompt V1 trong cùng thư mục, không có nghĩa là Figma hiện tại hoặc runtime đã
> dùng brief này. Khi implement, đọc [mapping node hiện tại](../../design-system/kinderlog/FIGMA-MAP.md).

**Current version, replacing the earlier static-review brief.** Use Figma Make
as an interactive, app-like UI/UX blueprint for team review before Flutter
implementation. A blueprint must support real clicks, navigation, and editing;
it is not a flowchart or a long page containing every screen.
The instructions are in English; all user-facing UI copy must be in Vietnamese.
Quoted Vietnamese strings are required UI text, not instructions. Copy the block
below into the existing KinderLog Make file. It has not been applied or visually
verified in Figma.

```text
Restore the existing KinderLog Make project as a high-fidelity, interactive
app-like UI/UX blueprint for the user story: Parents update their child's
long-term health profile. The team will review it by using the app, then
implement the approved experience separately in Flutter Android.

Interactive navigation and working controls are required. Do NOT deliver a
static preview, flowchart, screen gallery, handoff presentation, or a long page
stacking all screens and states. Show one active product screen at a time inside
the existing app viewport; a relevant dialog or bottom sheet may overlay it.
Scrolling is for the current screen's content, not for moving between screens.
State-based navigation is fine, but tapping an entry must replace the active
view or open the intended sheet, not scroll to another frame or page anchor.

Follow the existing file's design guidelines and reuse its components and tokens.
Preserve unrelated screens. Keep the design instructions and external handoff
annotations in English. All user-facing UI copy must be in Vietnamese, including
titles, labels, navigation, statuses, helper text, errors, dialogs, and sample
content. Preserve existing Vietnamese UI copy; do not translate it into English.
Use the quoted Vietnamese UI strings below exactly.

RESTORE THE EXISTING APP, DO NOT BUILD A SECOND APP
- App.tsx currently renders HealthPrototype for the parent role. That component
  now renders a long handoff board. Restore the parent's app view using the
  existing interactive ParentMobile inside the existing app viewport/container.
- HealthReviewSurfaces renders fixed review states: ProfileReview passes
  specification, and its navigation/save callbacks do nothing. Do not use these
  review surfaces as the app's active account, editor, or child-detail screens.
- Reuse ParentMobile, HealthProfileScreen in normal interactive mode, and the
  existing in-memory health helpers. Do not pass specification or fixed preview
  presets to the active editor, or replace real handlers with empty callbacks.
- Keep the existing login, role selection, teacher/admin navigation, and other
  working app actions intact. Do not redesign or bypass them to show a demo.
- Keep any handoff documentation or review board separate from the normal app
  entry point. Do not delete unrelated screens or previous project work.

INTEGRATE THESE SCREENS INTO THE APP

1. Parent account - full screen, in context
- Preserve the current account layout, contact details, child information,
  settings, and the existing two-item bottom navigation.
- Tapping "Tổng quan" or "Tài khoản" must switch the active tab as before.
- Inside "Thông tin bé", add an always-visible "Hồ sơ sức khỏe" row with a
  consistent outline icon, concise status summary, and trailing chevron.
- Use a neutral "Chưa khai báo" summary for missing information. For an existing
  allergy, show a useful summary such as "Dị ứng: Đậu phộng". Keep full details
  available on the health screen rather than squeezing them into this row.
- Tapping "Hồ sơ sức khỏe" must open the separate, editable health screen in
  the same app viewport. Do not append that screen below the account page.

2. Child health profile - complete, production-style mobile screen
- Use a compact app bar titled "Thông tin sức khỏe", with a back icon.
- Show the child's avatar, name, and class in a compact identity row. Reuse one
  fictional child consistently across all screens; do not use real child data.
- Add brief guidance: "Cập nhật thông tin lâu dài để giáo viên lưu ý khi chăm sóc bé."
- Group the form into two clearly separated sections, not a wizard:
  A. "Dị ứng": three vertically stacked radio options, each with a full label:
     "Chưa khai báo", "Không có dị ứng được biết", and "Có dị ứng".
     Missing information must not appear as a declaration of no known allergies.
     When "Có dị ứng" is selected, show a required multiline "Mô tả dị ứng" field,
     with example content "Đậu phộng" and a counter with a 1000-character limit.
     Do not show this field for the other two selections.
  B. "Lưu ý chăm sóc": an optional multiline field with a 1000-character limit.
     Use realistic, short example content about long-term care, not a daily note.
     Helper copy: "Không dùng để gửi lời dặn trong ngày hoặc yêu cầu dùng thuốc."
- Keep the latest profile update source and time visually secondary below the
  form. Use "Thông tin từ hồ sơ hiện có" for legacy information without metadata;
  do not invent an updater or timestamp for an undeclared profile.
- Place one full-width primary action, "Lưu thay đổi", in a bottom action area.
  Enable it after a meaningful edit, show "Đang lưu..." while saving, and prevent
  repeated submissions. Do not add bottom navigation to this editing screen or
  let the action area cover fields or keyboard focus.
- Specify concise success feedback: "Đã cập nhật thông tin sức khỏe". This does
  not mean that a teacher has read or medically verified the information.
- Make the radios and text fields genuinely editable. Selecting an allergy
  status must update the form; counters and validation must respond to input.
- On save, update the shared mock profile, return to the account screen, show
  the success feedback, and update the health summary. Reopening the editor must
  show the saved values, not reset to the original sample.
- Back without edits returns to the previous context. Back with unsaved edits
  opens "Bỏ thay đổi?" with "Tiếp tục chỉnh sửa" and "Bỏ thay đổi". Continuing
  keeps the draft; discarding leaves the saved profile unchanged.
- Changing an existing allergy to another status must show a working
  "Thay đổi thông tin dị ứng?" confirmation before saving, with
  "Tiếp tục chỉnh sửa" and "Xác nhận thay đổi" actions.

3. Teacher and admin - contextual read-only health sections
- Open the child's detail through the existing teacher/admin app navigation and
  show the health section there, not as detached reference screens below the app.
- Present the same fictional child's allergy status, allergy description, care
  notes, and update metadata. Prioritize allergies, then care notes.
- Distinguish undeclared information from no known allergies. Allow long text
  to be read in full without breaking the surrounding layout.
- Do not redesign either dashboard or add approval/read-receipt controls.
- Read the same shared mock profile for the same linked child. If the existing
  fixtures lack a common child ID, add the smallest explicit mock relationship;
  do not silently map the parent's profile onto a different roster child.
- Keep existing child/report actions working. Long-text expansion, closing a
  detail sheet, and returning to the roster must behave like normal app actions.

PROTOTYPE STATE
- Keep the mock health record in memory above the role-specific screens, keyed
  to the linked child. Preserve saved values while opening/closing screens,
  switching tabs, or switching roles within the same preview session.
- Use local mock behavior for load/save feedback; no real backend is needed.
  A full page reload may reset the demo. Do not store child health information
  in localStorage, send it to a real service, or use real child data.
- Validation, loading, retry, confirmation, and success must happen on the
  active screen when relevant, not exist only as pictures of separate states.

VISUAL DIRECTION
- Match the existing KinderLog screens: Be Vietnam Pro, Material-style outline
  icons, warm neutral backgrounds, white surfaces, and restrained teal emphasis.
- Use the established tokens: canvas #F6F4EF, surface #FFFFFF, ink #2A2926,
  secondary ink #605D57, brand #16665A, and dividers #E7E3DA.
- Keep 20 dp screen gutters, 16 dp card padding, a 4/8 dp spacing rhythm,
  12 dp card corners, and 8 dp control corners. Reuse existing typography styles.
- Keep the interface practical and calm: no oversized hero, decorative medical
  illustration, new navigation, or unrelated visual redesign.

APP PRESENTATION AND ACCESSIBILITY
- Use one app viewport, with 375 x 812 as the mobile reference. Fit the available
  space on phones and retain the existing single-device presentation on desktop.
- Do not show multiple phones, role screens, theme variants, state galleries,
  scenario controls, review headings, or measurement notes in the app itself.
- Use the existing theme setting to switch the current app between light/dark;
  do not render both side by side. Keep dark text on the light teal primary
  button in dark mode.
- Account for a narrow 320 dp screen, 200% text scaling, safe areas, and an open
  keyboard. Use Android touch targets of at least 48 x 48 dp, readable contrast,
  persistent field labels, and text explanations rather than color-only errors.
- Use real input controls and the device's real keyboard, not a drawn keyboard
  preview. Keep handoff annotations in documentation, not inside the app viewport.

VERIFY BY CLICKING BEFORE FINISHING
1. Open the parent app, switch between the existing tabs, and open
   "Hồ sơ sức khỏe" from "Tài khoản". Only the intended screen should be active.
2. Change the allergy selection and type in the fields. Verify conditional
   fields, counters, required-field errors, and the 1000-character limits.
3. Save a valid edit. Verify loading, return to account, success feedback, and
   the updated summary. Reopen the editor and verify the saved values.
4. Try Back with unsaved changes. Verify both continue-editing and discard
   actions, plus the confirmation before replacing an allergy declaration.
5. Use existing role navigation to inspect the same linked child's health in
   teacher/admin context. Verify saved mock values are retained and displayed.
6. Check the actual current screen at narrow width, with keyboard input, and
   using the existing dark-mode control. Do not create a gallery to pass this.
7. Confirm existing login, logout, report, settings, and role navigation still
   work as before. Report what was actually clicked and any remaining blocker;
   do not claim success from screenshots or source inspection alone.

SCOPE BOUNDARY
Design only the long-term allergy and care profile. Do not add daily messages,
chat, push notifications, medication management, growth charts, or AI advice.
Do not implement production authentication, real backend integrations, or
production persistence. Working prototype navigation and shared in-memory mock
state ARE required; they are part of reviewing the UI/UX, not a new backend task.

Review success means the team can use this like a real app: tap the right place,
open the right screen, edit, save, and return naturally, while agreeing on the
UI/UX that will be implemented in Flutter. A static board is not an acceptable
substitute for this interactive blueprint.
```
