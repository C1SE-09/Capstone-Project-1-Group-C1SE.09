# Figma Make prompt — Parent Screen v4 FINAL (KinderLog)

> **Lịch sử, không phải token hiện tại (05/11/2026).** “FINAL” là tên phiên bản
> prompt ở thời điểm viết. Palette teal/cream và typography trong file này không
> được dùng để ghi đè node Figma live. Xem [nguồn thiết kế](../../design-system/kinderlog/FIGMA-MAP.md)
> và [baseline/chênh lệch](../../design-system/kinderlog/MASTER.md).

Changes vs v3: hero compacted (oversized stat fixed) — name 24→20, "128" 28→20,
avatar 56→48, tighter padding. Otherwise identical to approved v3.

---

Design a warm, trustworthy mobile app for parents of kindergarten children, called **KinderLog**.
The app lets parents read daily voice-transcribed reports about their child's day at school.
Design **3 mobile screens (390×844, light theme)** in a friendly, calm, editorial style.
Avoid generic AI-app aesthetics: no gradient hero cards, no pill-labeled icon buttons,
no quote-circle icons, no card-inside-card nesting. Keep the hero block COMPACT — it must
not exceed ~150dp height; no text larger than 20px anywhere on the screen.
All visible text is **Vietnamese**.

## Brand tokens (use exactly)

- Background canvas: `#F6F4EF` (warm cream) · Cards: `#FFFFFF` · Sunken surface: `#EFECE5`
- Primary brand (deep teal): `#16665A` · Strong: `#114F46` · Tint: `#E6EFEC`
- Text: primary `#2A2926` · secondary `#605D57` · faint `#757169`
- Dividers: `#E7E3DA`
- Semantic: success `#3F8B5C` on tint `#E7F1EA` · warning `#B0791B` on tint `#F6EED9`
  · danger `#BB4A34` on tint `#F6E6E1` · info `#4B6F8C` on tint `#E7EEF3`
- Corner radii: small controls 8, cards 12, hero/large cards 16, pills 99
- Spacing: 4/8 rhythm (8, 12, 16, 24). Section titles sit directly on canvas.
- Typography: clean geometric sans (Inter-like). Scale: 12 caption, 13 label, 14 body,
  16 section title, 20 screen title / hero name (MAX). Strong level contrast.
- Interactive elements ≥48dp touch targets. Material Symbols outlined icons (1.5–2px
  stroke), never emoji. Pressed feedback: 6–8% black overlay, no layout shift.
- Dark-mode twin values: canvas `#1C1B1A`, cards `#252422`, text `#E8E6E1`/`#C4C2BC`,
  brand `#52BBA8`, danger `#E87B63` on `#3A2621`.

## Screen 1 — "Tổng quan" (Overview tab)

1. Status bar (safe area). **One header row, no cards**: left column "Xin chào,"
   (12 faint) above "Trần Văn Tuấn" (24 semibold). Right: exactly **2 icon-only
   buttons** — bell (with small red dot) and bug. Icons on canvas, no labels,
   no chips, no borders. Thin divider below.
2. Child card (white, radius 16): 48dp avatar photo (fallback "GB" teal tint),
   "Trần Gia Bảo" (16 semibold), "Lớp Mầm A · Cô Nguyễn Thị Mai" (13 secondary),
   chevron. Divider, then row: calendar icon + "Thời khóa biểu của lớp"
   (teal 14 medium) + chevron. Name tappable.
3. Safety banner: danger tint `#F6E6E1`, shield icon `#BB4A34`, "Lưu ý sức khỏe"
   (14 semibold danger), "Bé bị dị ứng đậu phộng — nhà trường đã nắm thông tin" (13).
4. "Báo cáo hôm nay" (16 semibold): card, document icon in teal tint circle,
   "Chưa có báo cáo hôm nay" (14 medium), "14/10/2026" (12 faint).
5. "Báo cáo gần đây" (16 semibold): 2 rows (white radius 12, 56dp): document icon,
   date, status pill — "Đã đọc" (success tint/text), "Chưa đọc" (danger tint/text
   + red dot), chevron.
6. Bottom nav: 2 tabs — "Tổng quan" (home, selected teal + dot, red badge "1"),
   "Tài khoản" (person, gray `#757169`).

## Screen 2 — "Tài khoản" (Account tab)

1. **Hero block — COMPACT** (~140dp tall), flat `#16665A` (NO gradient), radius 16,
   white text, padding 16, asymmetric: top row 48dp avatar photo (fallback "TT" on
   white 15% circle) + pencil icon top-right; name "Trần Văn Tuấn" (**20 semibold**)
   + chip "Bố của Bảo" (12, white 85% on white 18% pill) on the SAME row as avatar;
   stat line under it, modest: **"128"** (**18 bold**) + " ngày cùng con ở
   KinderLog" (13 white 85%) on the same baseline; one leaf line-icon at 8% white
   opacity bottom-right corner (watermark, not over text). Nothing taller than 20px.
2. **Teacher note** — editorial: 3px vertical teal bar left, italic text (14 ink,
   lh 1.5): "Bảo hôm nay rất hăng hái vẽ tranh, con ăn hết suất và ngủ đủ giấc."
   Footer (12 faint): "Cô Nguyễn Thị Mai · 13/10/2026" + teal link "Đọc báo cáo ›"
   (14 medium) right. No border, sits on canvas.
3. "Thông tin liên hệ" card (radius 12), rows 48dp: "Email" → "tuan.tran@gmail.com";
   "Quan hệ với bé" → "Bố"; "Số điện thoại" → "0901 234 567" (pencil affordance).
4. "Thông tin bé" card (radius 16): 48dp avatar (fallback "GB"), "Trần Gia Bảo"
   (16 semibold, tappable + chevron). Rows: "Biệt danh" → "Bảo"; "Lớp" → "Mầm A";
   "Giáo viên chủ nhiệm" → "Cô Nguyễn Thị Mai"; "Dị ứng" → warning icon +
   "Đậu phộng" (danger).
5. Settings card (radius 12, 4 rows 56dp): lock "Đổi mật khẩu" + chevron;
   bell "Thông báo đẩy" + subtitle "Nhận thông báo khi có báo cáo mới" + switch ON
   (teal track); contrast icon "Giao diện" + **segmented "Sáng" (selected teal fill)
   | "Tối" | "Tự động"** (unselected: `#EFECE5`, ink secondary); info
   "Về KinderLog" + "v1.0.0" (12 faint).
6. Logout: outlined 52dp radius 12, danger border/text "Đăng xuất" + icon.

## Screen 3 — Child detail bottom sheet

Over dimmed Overview (30% scrim). White sheet, top radius 16, 32×4 handle:
64dp avatar (fallback "GB"); "Trần Gia Bảo" (18 semibold); "Biệt danh: Bảo" (13);
close X. Info rows (label 13 secondary left, value 14 primary right): "Ngày sinh" →
"12/03/2023"; "Lớp" → "Mầm A"; "Phòng" → "Phòng 1"; "Giáo viên chủ nhiệm" →
"Cô Nguyễn Thị Mai". Safety block: danger tint card, warning icon,
"Dị ứng đậu phộng" (14 semibold danger). Primary teal button 52dp: phone icon +
"Gọi cô Nguyễn Thị Mai". (No timetable button here.)

## Interaction notes

- Tap child name → sheet; scrim/X → dismiss.
- Pencil (hero or phone row) → edit sheet: phone field + "Lưu".
- "Đọc báo cáo ›" → opens 13/10 report. Theme segmented switches instantly;
  "Tự động" = follow system. Logout → confirm dialog ("Ở lại" / "Đăng xuất").
- Unread pill danger → success after opening. Press = 6–8% overlay, no shift.

## Quality bar

Contrast ≥4.5:1; icon-only controls labeled for a11y; 8dp grid; nothing clipped at
375px; safe areas respected. Also render Account once in **dark mode**
(canvas `#1C1B1A`, cards `#252422`, brand `#52BBA8`) to prove the twin works.
