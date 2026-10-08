# KinderLog — Figma Make Sync Backlog

**Purpose:** tracks UI that exists in the Flutter app but not (yet) in the Figma Make prototype. Make is the team's visual blueprint — drift erodes its reliability, so gaps are recorded here instead of rotting in chat.

**Status:** deferred — run as ONE batched Make session **after** the Timetable feature ships (Make fix + Flutter port + push). Doing it earlier buys nothing: none of these items block or overlap the Timetable.

**Trigger to run:** before any capstone report/demo that uses Make as the app's visual record.

---

## Items

| # | Item | Flutter source | Sync note |
|---|---|---|---|
| 1 | Forgot password — 3 steps (Email → OTP → Mật khẩu mới), resend countdown, success dialog | `frontend/lib/features/kindergarten_dashboard/screens/forgot_password_screen.dart` | Mirror first; known debt to decide on: hardcoded `Colors.red/blue/amber/green.shade*`, custom mini-stepper (not the shared StepIndicator), success `AlertDialog` (not the sheet pattern) — see MASTER §13.2 D3, §15.5 |
| 2 | Change password — full screen + `showKSheet` form variant | `frontend/lib/features/kindergarten_dashboard/screens/change_password_screen.dart` | On-system (KCard/KButton/tokens). Mirror both variants; the form is duplicated between screen and sheet — keep one source when syncing |
| 3 | Login: "Quên mật khẩu?" link | `auth_screens.dart` (~line 286) | Add to Make Login below the password field |
| 4 | Account: "Đổi mật khẩu" row | `teacher_tabs.dart` (~line 520) | Add to Make Account → "Tùy chỉnh" card |
| 5 | Parent header: change-password lock button | `parent_screens.dart` (~line 234) | Add to Make ParentHome header |
| 6 | Login error banner debt (`Colors.red.shade*`) | `auth_screens.dart` (~lines 167–180) | Make Login already uses `badTint`; when syncing, decide whether the Flutter cleanup (MASTER D3) happens before or after |
| — | Any other drift found during the pass | — | Record inline here |

## Procedure when the pass runs

1. Open the Make project; add/update the screens above using existing Make components and tokens only.
2. Verify each against the Flutter source side-by-side.
3. Per item, decide: **mirror as-is** or **mirror + cleanup**; record any decision in MASTER (new version note).
4. Update this file's status (mark items done, date the pass).

---

*Created 2026-10-07 alongside MASTER v1.1. Keep this file with the design system.*
