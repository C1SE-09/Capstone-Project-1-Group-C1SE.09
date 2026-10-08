# KinderLog — Figma Make Sync Backlog

**Purpose:** tracks UI that exists in the Flutter app but not (yet) in the Figma Make prototype. Make is the team's visual blueprint — drift erodes its reliability, so gaps are recorded here instead of rotting in chat.

**Status:** ✅ pass completed 2026-10-08 (Make verified against Flutter source). Items 1–5 added to Make; item 6 requires no Make change.

**Trigger to run:** before any capstone report/demo that uses Make as the app's visual record — done for this pass.

---

## Completed — 2026-10-08

Verified in Make source (`advURIMI3Zgnv462eZJMpU`):

| # | Result |
|---|---|
| 1 | ✅ `src/screens/ForgotPassword.tsx` — 3 steps via the shared StepIndicator, OTP input, 60s resend countdown, success sheet, back link; wired as `stage: 'forgot'` in `App.tsx` |
| 2 | ✅ `src/components/ChangePasswordSheet.tsx` — sheet with lock header, 3 password fields (eye toggles), exact validation copy; also exports `ErrorBanner` + `PasswordField` reused by ForgotPassword (no duplicated form) |
| 3 | ✅ `Login.tsx` — right-aligned "Quên mật khẩu?" link under the password field (44px), opens the forgot stage |
| 4 | ✅ `Account.tsx` — "Đổi mật khẩu" row (KeyRound) between "Quay lại chọn lớp khác" and the theme block; saves close the sheet + Toast |
| 5 | ✅ `ParentFlow.tsx` — KeyRound lock button in the home header (between bell and logout); same sheet + toast |
| 6 | ➖ No Make change — Make's login banner already uses `bad`/`badTint`; the Flutter cleanup (hard-coded `Colors.red.shade*`) remains tracked as MASTER §13.2 D3 |

Decisions made: Make mirrors the **cleaned** version (design-system components, no hard-coded colors); Flutter keeps its debt as a separate cleanup task. No MASTER version bump needed — §7.10 and §15 remain accurate.

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
