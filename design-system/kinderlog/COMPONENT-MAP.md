# KinderLog — Component, typography và asset

**Kiểm kê:** 05/11/2026. ID/variant của component lấy từ metadata Design System
`142:2`; chỉ KButton đã đọc thêm design context, variables và screenshot.
Mapping là điểm tìm code, không phải Code Connect đã đăng ký hoặc xác nhận khớp ảnh.
Đường dẫn code dưới đây tính từ `frontend/lib/features/kindergarten_dashboard/`.
Chi tiết chữ ký widget và bảng tra hex → `context.k.*` xem thêm tại
[.agents/rules/flutter-design-system.md](../../.agents/rules/flutter-design-system.md).

## Component dùng lại

| Component Figma / node | Variant hoặc state đã thấy | Flutter cần đọc / khác biệt |
|---|---|---|
| [KButton · 142:42](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-42) | Primary / Secondary / Ghost / Destructive × Default / Pressed / Disabled / Loading | `widgets.dart` → `KButton`. `secondary`, `ghost`, `danger`; disabled qua `onPressed: null`. Chưa có API loading. Cao tối thiểu 44; Figma 48. |
| [KInput · 142:65](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-65) | Default / Focused / Filled / Error / Disabled | `TextField` / `TextFormField`, `_buildTheme()` trong `theme.dart`. Chưa có class `KInput`; form đặc thù trong `screens/parent_requests_form_fields.dart`. |
| [KStatusBadge · 142:82](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-82) | Success / Warning / Error / Info / Neutral | `widgets.dart` → `StatusBadge`, `SeverityChip`; map theo domain enum/adapter, không theo màu đơn thuần. |
| [KChip · 142:88](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-88) | Selected / Unselected | `widgets.dart` → `FilterChipButton`; chip đơn/thuốc còn có widget riêng. |
| [KCard · 142:103](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-103) | Default / Highlighted / Interactive | `widgets.dart` → `KCard(child, padding, onTap, color)`. Mặc định `padding` của wrapper là zero; caller phải truyền đúng padding theo node. |
| [KSheetHeader · 142:113](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-113) | Header sheet | `widgets.dart` → `showKSheet`, header trong các sheet. Chưa có class `KSheetHeader`; tránh thêm hai drag handle khi ghép wrapper. |
| [KAvatar · 142:125](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-125) | S 32 / M 40 / L 56 | `widgets.dart` → `Avatar`; kiểm tra size và nguồn ảnh tại caller. |
| [KStatCard · 142:127](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-127) | Stat card | `widgets.dart` → `StatCard`; card riêng của Tổng quan ở `screens/teacher_tabs.dart`. |
| [KListSkeleton · 142:148](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-148), [KEmptyState · 142:164](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=142-164) | Loading / empty | Loading/empty đang được dựng tại màn. Không giả định có class Flutter cùng tên. |
| [KPageHeader · 237:446](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=237-446) | Main / Back / Form | `widgets.dart` → `KAppBar`; header inline của màn. `KAppBar` cao 62/68 tùy subtitle, chưa tương đương tự động các variant Figma 48/44/85. |
| [KSettingsRow · 237:469](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=237-469) | Navigation / Info / Toggle / Danger | `screens/parent_account.dart`, `screens/teacher_account_screen.dart`, `widgets.dart` → `KInfoRow`, `ThemeSelector`. |
| [KSearchField · 240:1560](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=240-1560) | Mobile / Desktop × Default / Focus | `widgets.dart` → `SearchField`. Task Flutter mobile dùng variant Mobile; không lấy thông số Admin Web. |
| [KListRow · 240:1588](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=240-1588) | Student / Notification / History / Request | `screens/teacher_tabs.dart`, `screens/parent_notifications.dart`, `widgets/leave_request_card.dart`, `screens/parent_requests_widgets.dart`. |
| [KNavTeacher · 232:461](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=232-461) | Điều hướng giáo viên | `_TeacherNavigation` trong `screens/teacher_shell.dart`; mic là hành động, các mục khác là tab. |
| [KNavParent · 232:549](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=232-549) | Điều hướng phụ huynh | `widgets/parent_navigation_bar.dart`; kiểm tra cả ParentFlow và standalone flow. |

Một widget có tên gần giống không đồng nghĩa khớp thiết kế. Đọc node cụ thể,
kiểm tra khả năng cấu hình rồi mới mở rộng component hoặc ghi lý do cần widget mới.
Không thêm dependency Code Connect hay framework design system chỉ để dùng bảng này.

## Garden Voice — component đã port cục bộ

Garden Voice dùng font Nunito và palette riêng. `GardenVoiceScope` trong
`theme.dart` áp dụng token cục bộ cho màn đã port, nên không đổi đột ngột UI còn
lại đang theo baseline A2.

| Component Figma / node | Flutter | Ghi chú |
|---|---|---|
| [GV / KButton · 452:686](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-686) | `GardenVoiceScope` button themes + `KButton` palette metrics | GV: Nunito bold 14, minimum height 48, radius 24; A2 outside scope stays 44/8. Primary default captured/tested as `gv-kbutton-primary.png`; Figma Loading variant has no matching `KButton` state API yet and remains a separate task. |
| [GV / KInput · 452:734](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-734) | Forgot-password step 1 `TextField` in `screens/forgot_password_screen.dart` | GV: 48px field, 14px radius, 14px Nunito Regular text, 14px horizontal padding, `#C7DEDA` border; label Nunito Bold 14. Email stays user-entered; Figma's sample is not hardcoded. |
| [GV / KStatusBadge · 452:745](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-745) | `StatusBadge` uses Garden Voice palette within `GardenVoiceScope` | GV variants use 8×4 padding, 6px dot, 6px gap, pill radius, Nunito Medium 12/1.4 and separate semantic dot/text/tint colors; A2 spacing/11px label is preserved outside GV scope. |
| [GV / KChip · 452:761](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-761) | `FilterChipButton` (`widgets.dart`) trong `GardenVoiceScope` | GV: pill radius, padding `14×8` (cao 36px), Selected dùng `brand` (`warn` khi `warn: true`) + chữ `surface` Nunito Bold `14/1.4`; Unselected mặc định dùng `surface` + viền `1px line` + chữ `inkSoft` Nunito Regular `14/1.4`. Parent inbox truyền `unselectedTextColor: context.k.ink` để đạt contrast trên chip; wrapper 48px giữ touch target, semantics ngoài widget cung cấp label/selected. Ngoài GV giữ 13px Medium A2. |
| [GV / KCard · 452:766](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-766) | `KCard` (`widgets.dart`) + `GardenVoiceScope.cardTheme` (`theme.dart`) | GV: radius `24px`, Default/Interactive dùng `surface` + viền `1px line` (`#E5E8EB`), Highlighted (`color != surface`) bỏ viền. Wrapper giữ `padding ?? EdgeInsets.zero`; ngoài GV giữ radius 12px A2. |
| [GV / KAvatar · 452:781](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-781) | `Avatar` (`widgets.dart`) trong `GardenVoiceScope` | GV: tròn (`BoxShape.circle`), S (`<=32`: Nunito Medium `12/1.4`), M (`<=40`: Nunito Bold `14/1.4`), L (`>40`: Nunito Bold `16/1.4`), cặp màu semantic lấy từ `context.k.*` (`okTint/ok`, `badTint/badText`, `sleepRowTint/sleepRowText`, `activityRowTint/activityRowText`, `accentTint/accentDeep`). |
| [GV / Chọn giao diện · 562:1668](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=562-1668) | `ThemeSelector` (`widgets.dart`) trong `GardenVoiceScope` | GV: màn chọn giao diện đầy đủ (`hub_back.svg` 44×44 + tiêu đề Nunito Bold `16/1.4`, mô tả Regular `15/1.4`, dòng `Đang dùng` Regular `14/1.4` + giá trị Bold `14/1.4 brandStrong`, 3 thẻ `Sáng`/`Tối`/`Theo máy` nền `surfaceSunken` bo `16px`, padding `15px`). Ngoài GV giữ bộ chọn inline 3 cột A2. |
| [GV / KPageHeader · 452:813](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-813) | `KAppBar` (`widgets.dart`) trong `GardenVoiceScope` | GV: nền `canvas`, bỏ đường kẻ đáy; Main (`onBack == null`) dùng title Nunito Bold `20/1.4` + subtitle Regular `14/1.4` (gap 2px); Back/Form (`onBack != null`) dùng nút back `44×44` (`assets/garden_voice/hub_back.svg`, giữ tooltip `'Quay lại'`) + title Nunito Bold `16/1.4` + subtitle Medium `12/1.4` (gap 1px). |
| [GV / KSettingsRow · 452:836](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-836) | `KInfoRow` (`widgets.dart`) trong `GardenVoiceScope` | GV: `minHeight: 48`, padding `16×13`, gap `12px`, label/value Nunito Regular `14/1.4` (`inkSoft` / `ink`, hoặc `bad` khi `danger: true`). Ngoài GV giữ label 13px, padding `14×10` A2. |
| [GV / KSearchField · 452:854](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-854) | `SearchField` (`widgets.dart`) trong `GardenVoiceScope` | GV (variant Mobile `452:855` / `452:858`): cao `48px`, radius `12px`, nền `surface`, viền `1px lineStrong` (`#B5D4CE`) / focus `1px brand` (`#087F70`), icon `assets/garden_voice/record_search.svg` (`16.25×16.25`, gap 10px, padding ngang 14px), chữ/placeholder Nunito Regular `14/1.4` (`ink` / `inkSoft`). |
| [GV / Navigation teacher · 456:1725](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=456-1725) | `widgets/garden_voice_teacher_navigation.dart` | SVG active/inactive local, 5 action, shell 60 + bottom 16/SafeArea. Review 2026-11-11: live frame `453:801` dùng shell/edge/selected `#F1F7F6` / `#B5D4CE` / `#CBE9DE`; widget hiện resolve qua `surface` / `line` / `brandTint`, chưa khớp các màu này. |
| [GV / Navigation parent · 456:1834](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=456-1834) | `widgets/garden_voice_parent_navigation.dart` | SVG active/inactive local, 4 action. |
| [GV / Class header · 564:1706](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=564-1706) | `widgets/garden_voice_class_header.dart` → `GardenVoiceClassHeader` | Dùng chung cho ClassList, Attendance và teacher Timetable: `school_v2.png`, tên lớp/cô, chuông và 4 class tabs. Callback do caller sở hữu; không vẽ badge đơn nghỉ khi không có count thật. |
| [GV / Medication & emergency · 454:1384, 454:1487, 563:1649](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1384) | `ParentRequestLayout`, `MedicationCard`, `MedicationBadge`, `MedicationAction`, `GardenVoiceTeacherNavigation` | `ParentRequestLayout` hỗ trợ subtitle và caller-owned `onBack` mà không đổi các caller cũ. `MedicationCard` có radius/color/border overrides; `MedicationBadge.showDot` chỉ bật cho trạng thái thuốc GV. API/response quyết định status. |

## Typography và token

Trang sửa bé (`screens/parent_child_edit_screen.dart`, 10/11/2026) mở từ bút chì
trong sheet `454:2379`. Đã bổ sung frame [`632:1535`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=632-1535)
vào section gia đình `568:1944`, phát triển từ pattern của `562:1636`:
lề 20, Nunito 14/1.4, label 700, input bo 14,
`KAppBar`, `FilterChipButton`, `KButton` 48/24 trong `GardenVoiceScope`.
Không thêm token hoặc asset mới. Nút Lưu/Hủy ghim dưới vùng cuộn để dùng được
khi mở bàn phím/chữ lớn. Alias `showParentChildEditSheet` giữ tương thích caller
cũ và chuyển sang `showParentChildEditScreen`; không còn mở sheet sửa lồng nhau.

Frame Figma dùng instance header/input/chip/button hiện có; ô dị ứng nhiều dòng
override chiều cao 114 (label 20 + gap 6 + field 88), padding field 14. Icon lịch
và bút chì là vector Material Icons chính thức, tương ứng icon Flutter; nút bút
chì `632:1584` có vùng bấm 44×44. Không dùng raster toàn màn. Prototype Lưu/Hủy
và Quay lại nối về hồ sơ bé, không phải thao tác ghi API trong prototype.

- Runtime: `theme.dart` chứa `KColors`, `KPalette`, `context.k`, `KSpace`, `KRadii`.
  Size chữ của các role hiện kế thừa Material; xem §3 MASTER để hiểu hạn chế.
- Font local: `frontend/assets/fonts/BeVietnamPro-{Regular,Medium,SemiBold,Bold}.ttf`
  được đăng ký là `BeVietnamPro` với weight 400/500/600/700 trong `pubspec.yaml`.
- Login frame `496:3859` dùng Be Vietnam Pro và KL/Warm Sage, không dùng `GardenVoiceScope`;
  `KPalette.loginWarmSage` chỉ đổi token tại màn Login, không sửa palette A2/GV.
- KButton live: **Be Vietnam Pro / 14 / 600**, line height `normal` trong context.
  Không chuyển `normal` thành một hệ số tùy ý. Header DS nhắc Quicksand nhưng repo
  chưa bundle font này; phải đọc role/node sử dụng trước khi thêm hoặc thay font.
- Ghi đủ `family, weight, fontSize, lineHeight, letterSpacing` khi map một style;
  nếu line height Figma là px, hệ số Flutter `height = lineHeight / fontSize`.
  Ghi rõ đơn vị letter spacing nếu Figma dùng phần trăm. Không suy ra type scale
  toàn app từ một component. Size cơ sở vẫn hỗ trợ system text scaling.
- Figma KButton hiện có radius 20, Flutter `KRadii.control` hiện là 8. Tham khảo
  §0 MASTER cho các chênh lệch brand/radius/loading trước khi dùng token cũ.

## Asset đang có và nguồn gốc

Đường dẫn asset tính từ `frontend/`. Không có URL asset Figma tạm nào được coi
là đường dẫn runtime hợp lệ. Ảnh đầu ra UI capture không được dùng làm asset màn.

| Asset local | Callsite / vai trò | Nguồn và mức xác minh |
|---|---|---|
| `assets/fonts/BeVietnamPro-*.ttf` | Family chung trong theme | Đã có local + khai báo weight; đối chiếu role Figma trước khi đổi. |
| `assets/request_timeline/complete.png`, `waiting.png`, `future.png` | `screens/parent_requests_detail_screen.dart`; timeline đơn | Có bản SVG cùng tên với root/viewBox 11×11. Callsite hiện chọn complete/waiting; future là asset dự trữ. Chưa xác minh node xuất gốc của ba asset. |
| `assets/audio/siren.wav` | `lib/core/notifications/emergency_siren_service.dart` | Âm cảnh báo runtime; không thuộc bộ ảnh đối chiếu Figma. |
| Illustration ở login `110:2` / Tổng quan giáo viên `293:543` | Frame màn `1:2` / `1:22` | Có trong metadata live; chưa được nhập vào bộ asset local. Không tự vẽ lại hoặc thay bằng icon khi implement hai màn này. |
| `assets/fonts/Nunito-VariableFont_wght.ttf` | `GardenVoiceScope` | Nunito variable 200–900 từ Google Fonts; khai báo local trong `pubspec.yaml`, dùng weight Flutter thay vì giả bold. |
| `assets/garden_voice/teacher_garden.png`, `report_clipboard.png`, `nav_*.svg` | Tổng quan/Nav giáo viên Garden Voice | Nguồn Figma node `453:584` và `456:1725`; render SVG bằng `flutter_svg`. |
| `assets/garden_voice/login_classroom.png` | `LoginScreen` · frame `496:3859` / illustration `496:3864` | PNG local từ export node, 342×220; hiển thị đúng tỷ lệ với Be Vietnam Pro/KL Warm Sage. |
| `assets/garden_voice/no_assignment.svg` | `NoAssignmentScreen` GV · `454:1190` / illustration `454:1193` | SVG local 76×76; Parent dùng variant A2 hiện có. |
| `assets/garden_voice/bug_report_add.svg` | `BugReportBottomSheet` · `454:1154` / tile thêm ảnh `454:1173` | SVG local 64×64 gồm nền tile và dấu cộng; tile chỉ hiện khi còn chỗ trong giới hạn 5 ảnh. |
| `assets/garden_voice/hub_back.svg`, `class_group.svg`, `caret_filled.svg`, `record_search.svg`, `record_back.svg`, `record_status_dot.svg`, `record_progress_outer.svg` | RecordHub / RecordingScreen | Nguồn Figma nodes `453:918` và `453:1005`; progress foreground được vẽ theo thời lượng thực, không dùng cung tĩnh trong fixture. |
| `assets/garden_voice/record_permission.svg`, `record_error.svg` | `RecordingScreen` recovery dialogs · `454:1712` / `454:1778`, `454:1810` / `454:1876` | SVG Figma local 56×56; nút cài đặt dùng URL scheme hiện có, chưa xác minh trên thiết bị Android thật. |
| `assets/garden_voice/process_error.svg`, `review_play.svg`, `review_spoon.svg`, `review_bowl.svg`, `review_moon.svg`, `review_artist_palette.svg`, `report_mascot.svg` | Processing error, audio/review cards, Done screen | Assets local từ Garden Voice `454:1204`, `453:1154`, `453:1350`; giữ viewBox/kích thước gốc. |
| `assets/garden_voice/done_replay.svg` | Done audio row play control | Asset node `453:1381`, viewBox 20×20; chỉ render cùng bản ghi audio thực. |
| `assets/notifications/back_44.svg`, `unread_dot.svg` | TeacherNotificationsScreen header and unread status | Inbox target frame `454:1557` inside Garden Voice canvas `452:556`; local SVGs retain 44×44 and 8×8 viewBoxes. |
| `assets/notifications/pending_dot.svg` | Focused leave-request detail status badge | Node `53:19` (`160:841`); 6×6 accent status marker. |
| `assets/garden_voice/edit_back.svg`, `edit_health.svg` | Full-screen edit-report header and health field | Garden Voice node `453:1270`; SVGs kept local at source viewBox sizes; report-editor field art reuses `review_spoon/bowl/moon/artist_palette.svg` and `parent_notification_health.svg`. |
| `assets/garden_voice/process_error.svg` | ProcessingScreen lỗi phân tích | Nguồn Figma node `454:1204`, viewBox 76×76, dùng nguyên kích thước cho biểu tượng lỗi Garden Voice. |
| `assets/garden_voice/parent_child_reading.png`, `parent_teacher.png`, `parent_*.svg`, report icon SVG | Tổng quan/Nav phụ huynh Garden Voice; `parent_report_close.svg` reused by BugReportSheet | Nguồn Figma node `454:1907` và `456:1834`; close control uses shared 44×44 asset at `454:1154`, không dùng URL Figma runtime. |
| `assets/garden_voice/school_v2.png`, `chevron_down.svg`, `class_search.svg` | `ClassListScreen` (`screens/teacher_tabs.dart`) | Nguồn Figma node `564:1706` (`I564:1706;565:4405`, `565:3496`, `565:3511`); minh họa trường học 250×86, chevron 20×20 và kính lúp 24×24. |
| `assets/garden_voice/books_v2.png`, `teacher_portrait.png`, `account_user_round.svg`, `account_chevron_right.svg`, `account_bell.svg`, `account_palette.svg`, `account_settings.svg`, `account_help.svg`, `account_bug.svg`, `account_info.svg`, `account_logout.svg` | `TeacherAccountScreen` (`screens/teacher_account_screen.dart`) | Nguồn Figma node `454:827` (`I454:827;565:4527`, `467:1778`, `565:4170`, `565:4173`, `565:4181`, `565:4190`, `565:4199`, `565:4210`, `565:4217`, `565:4224`, `565:4231`); giữ nguyên viewBox và tỉ lệ gốc. |
| `assets/garden_voice/attendance_check.svg`, `attendance_chevron_left.svg`, `attendance_chevron_right.svg`, `attendance_users.svg`, `attendance_calendar.svg`, `plant_detail.png` | `screens/attendance_screen.dart` · frame `453:801` | SVG tải local từ asset references của `453:801` (viewBox tương ứng 17×17, 23×23, 23×23, 32×32, 25×25); plant PNG 2172×724 nguồn cùng frame, được crop vào ô minh họa nhỏ. `class_search.svg` dùng lại từ `564:1706`. |
| `assets/garden_voice/approval_success.svg` | `screens/attendance_approval_result_screen.dart` · frames `454:1345`, `454:1673` | Hai asset result trong Figma có cùng SHA-256; dùng một SVG local 40×40. Nội dung trạng thái/ETA lấy từ response `LeaveRequestEntity`, không dùng copy demo để khẳng định push hoặc check-in sync. |
| `assets/garden_voice/timetable_users.svg`, `timetable_utensils.svg`, `timetable_sparkles.svg`, `timetable_leaf.svg`, `timetable_moon.svg`, `timetable_heart.svg` | `screens/timetable_screens.dart` · frame `454:931` | SVG local từ activity icon set của frame GV; render 19×19 trong icon circle. |
| `assets/garden_voice/parent_spoon.svg`, `parent_bowl.svg`, `parent_artist_palette.svg`, `parent_crescent_moon.svg` | `screens/timetable_screens.dart` · frame `454:2287` | SVG local từ icon set lịch PH; palette dùng nguyên hình 28×28, spoon/bowl giữ tỉ lệ gốc trong icon bữa ăn. Không dùng fixture schedule trong production. |
| `assets/garden_voice/medication_created.svg`, `medication_confirmed.svg`, `medication_lock.svg` | `parent_medication_submitted_screen.dart` · `454:3026`; `teacher_medication_screen.dart` · `454:1445` | SVG local xuất từ các node frame tương ứng; 64×64 success, 40×40 confirmed, 16×16 lock. Dùng thay ký tự/icon gần giống; status vẫn lấy từ response canonical. |
| `assets/garden_voice/emergency_back.svg`, `emergency_user.svg`, `emergency_triangle_alert.svg`, `emergency_sent.svg` | `teacher_emergency_sheet.dart` · `454:1487`, `454:1532` | SVG local xuất từ M8/M9: back 24×24, user 20×20, alert 28×28, success/error illustration 76×76. Recipient rows chỉ dùng API contacts; không render shield/school recipient chưa có trong response. |
| `assets/garden_voice/chevron_right.svg` | `teacher_emergency_sheet.dart` · `454:1487` | Dùng lại chevron GV local 16×16, scale lên 18×18 trong child selector; không dùng URL tạm. |

Khi thêm asset, cập nhật dòng tương ứng với **fileKey + nodeId xuất gốc**, file
local, kích thước tự nhiên/viewBox, slot trong màn, kích thước render và cách fit.
Đọc hướng dẫn tải asset của Figma connector, tải về local rồi khai báo `pubspec.yaml`.
Giữ bản gốc và tỉ lệ; nếu chuyển định dạng vì Flutter chưa có renderer tương ứng,
ghi quyết định và kiểm tra ảnh sau chuyển đổi, không cài thêm package mặc định.
Không suy ra nguồn gốc “đã xác minh” chỉ từ tên file hoặc màu trông giống nhau.
