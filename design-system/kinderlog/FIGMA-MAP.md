# KinderLog — Figma → Flutter

**Task:** [UI][Garden Voice] port Batch 5 auth, settings, child actions, and recording states

**Kiểm kê:** 10/11/2026, metadata live của `452:556`, code trong worktree và capture mới; Batch 5 đối chiếu live context, variables, screenshot ngày 11/11/2026 cho 11 frame được giao. Không phải sign-off pixel toàn ứng dụng. Các bảng trang cũ bên dưới được giữ để tra nghiệp vụ.

**Bổ sung sau lượt kiểm kê:** [UI][Figma] bổ sung màn chỉnh sửa thông tin bé —
đã tạo frame editable [`632:1535`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=632-1535)
trong section gia đình `568:1944`, kích thước 390×844. Các tổng số frame của
lượt audit bên dưới là ảnh chụp trước bổ sung này, không tính frame mới.

> **Target refactor hiện tại:** [08 · Garden Voice · Duyệt toàn bộ UI](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=452-556), node `452:556`. Phạm vi hiện tại là Flutter Giáo viên/Phụ huynh; Admin Web chưa thuộc đợt này. Các bảng `0:1` / `2:2` bên dưới vẫn là mapping code và nghiệp vụ, không phải visual target cho task Garden Voice.

## Nguồn và mức xác minh — lịch sử kiểm kê 05/11/2026

Các xác minh trong mục này được giữ từ lượt kiểm kê trước; nguồn live và mức
xác minh của task hiện tại nằm trong mục audit Garden Voice bên dưới.

- File Design đã đọc: [KinderLog](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog), key `9RurF0HiJlYLVDV7ljp2bH`.
- Đã xác nhận **ID, tên và kích thước** các frame trên trang Giáo viên `0:1`,
  Phụ huynh `2:2`, Design System `142:2` bằng metadata hiện tại.
- Đã đọc variables, design context và screenshot của KButton `142:42`.
  Những dòng màn hình dưới đây mới là mapping để tìm code; chưa xác nhận app
  render khớp từng frame hoặc mọi trạng thái của component.
- Make `advURIMI3Zgnv462eZJMpU` được nhắc trong `SYNC-BACKLOG.md` là nguồn lịch sử.
  Không dùng trạng thái “đã sync” ngày 08/10 để suy ra Design hiện tại đã khớp app.
- File còn có các trang `99 — Lưu trữ trước tinh gọn`, `04 · Dark mode · Concept đa màu`,
  `05 · Thử nghiệm · Nhật ký mầm non`, `07 · Sổ tay lớp học · Hướng thiết kế mới`.
  Không tự chọn chúng làm mục tiêu khi task chưa chỉ định. **Ngoại lệ hiện tại là
  Garden Voice `452:556` theo yêu cầu refactor này.** Trang `Admin Web — Desktop`
  thuộc ứng dụng khác và chưa nằm trong phạm vi Flutter.

Quy tắc ưu tiên nguồn nằm trong [frontend/AGENTS.md](../../frontend/AGENTS.md);
quy trình gọi Figma MCP (Auto-Dissection, thu thập kép, bảng đối chiếu) nằm trong
[.agents/rules/figma-mcp-workflow.md](../../.agents/rules/figma-mcp-workflow.md) và
token/widget tái sử dụng trong [.agents/rules/flutter-design-system.md](../../.agents/rules/flutter-design-system.md).
Các thông số trong [MASTER.md](MASTER.md) mô tả baseline Flutter. Figma live đã
thay đổi; đọc bảng chênh lệch §0 của MASTER trước khi dùng palette/font/radius.

## Audit Garden Voice `452:556` — 10/11/2026

### Nguồn, cách đếm và tiêu chí

- File key: `9RurF0HiJlYLVDV7ljp2bH`; canvas: `452:556` — **08 · Garden Voice · Duyệt toàn bộ UI**. Đã gọi `get_metadata` trên canvas; **không gọi `get_design_context` trên canvas**.
- Cây metadata hoàn chỉnh có **81 FRAME kích thước 390×844**: **78 frame màn/state** trực thuộc 16 section mobile và **3 frame lồng**. Hai `Overlay` và một `Viewport` không phải ba màn/route mới. Admin Web 1200×800 và thư viện component không nằm trong kiểm kê mobile này.
- Đã đối chiếu code, caller/router, scope, asset local và từng điểm capture trong `frontend/test/figma_request_layout_test.dart` (**T** trong các bảng). `L797` nghĩa là dòng 797 trong T, không phải tên một test khác. `—` nghĩa là không có capture riêng cho frame/state đó trong T; có functional test ở file khác không thay thế điều kiện này.
- Đã lấy song song context + screenshot cho từng frame: `496:3859`, `454:1074`, `453:584`, `453:918`, `453:1005`, `453:1092`, `453:1154`, `453:1270`, `453:1350`, `453:1389`, `563:1688`, `563:1708`, `564:1706`, `454:827`, `562:1668`, `454:1204`, `454:1557`, `454:1907`, `454:2526`. Các frame còn lại được kiểm kê từ metadata và code, **chưa được nghiệm thu ảnh riêng**.
- Đường dẫn Flutter dưới đây tính từ `frontend/lib/features/kindergarten_dashboard/`; số dòng là vị trí của worktree tại lượt audit, không phải permalink commit. Ảnh audit gốc nằm ở `frontend/build/ui-captures-gv-audit-2026-11-10/`; capture theo batch tiếp tục nằm trong `frontend/build/ui-captures/` và `frontend/build/ui-captures-batch3/` (đều là build output bị ignore).

| Trạng thái | Điều kiện dùng trong lượt audit |
|---|---|
| **[ĐÃ PORT]** | Có scope GV ở đường vào thực tế, các khối/layout và asset của state đã được đối chiếu, có capture đúng state trong T. Đây là mức port cấu trúc/asset, không phải chứng nhận pixel-perfect hoặc toàn bộ flow/backend. Ngoại lệ nghiệp vụ được ghi riêng. |
| **[PORT DỞ DANG]** | Đã có scope/GV layout/asset hoặc đang tái dùng một flow GV, nhưng còn lệch khối/layout/theme, rơi scope khi chuyển route, thiếu state hoặc thiếu capture đúng state. Không nâng trạng thái chỉ vì test xanh. |
| **[CHƯA PORT]** | Màn vẫn là A2/visual cũ ở đường vào thực tế, hoặc chưa có UI tương ứng. Navigation GV là sibling không làm body A2 trở thành GV. Frame mô phỏng hệ điều hành/cuộc gọi vẫn được kê riêng, không mặc định phải xây thành màn Flutter. |

**Tổng hợp theo 78 màn/state:** **17 [ĐÃ PORT] · 51 [PORT DỞ DANG] · 10 [CHƯA PORT]**.
Nếu đếm đủ 81 FRAME raw, ba frame lồng thêm **2 dở dang + 1 chưa port**: tổng **17 / 53 / 11**. T hiện tạo **43 capture màn/state và 2 capture component**; một số capture màn khác state/nội dung Figma nên chưa đủ điều kiện hoàn tất.

### 1. Đăng nhập và khôi phục tài khoản — section `568:1929`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `496:3859` | 01 — Đăng nhập | 390×844 | `screens/auth_screens.dart:167` | `teacher-login-gv.png` | [PORT DỞ DANG] Layout và illustration node `496:3864` đã port; dùng Be Vietnam Pro + KL/Warm Sage local palette theo context, không ép Nunito/GV. Giữ remember và hiện/ẩn mật khẩu (không có trong frame); “Khám phá” chỉ là nhãn tĩnh, không demo-login/credential. |
| `454:1074` | GV · Giáo viên · 16 — Quên mật khẩu | 390×844 | `screens/forgot_password_screen.dart:285`, `:459` | L400, chỉ bước email | [PORT DỞ DANG] Bước 1 có scope/layout GV; bước OTP/reset dùng nhánh Scaffold A2. Canvas chỉ có frame bước 1, không bịa node riêng cho bước 2–3. |
| `454:1190` | GV · Giáo viên · 19 — Chưa được phân lớp | 390×844 | `screens/no_assignment_screen.dart:21`, caller `screens/teacher_shell.dart:451` | `teacher-no-assignment-gv.png` | [ĐÃ PORT] Dùng illustration `no_assignment.svg` 76×76, Nunito/GV tokens và CTA `Đăng xuất`; chỉ bật GV variant để giữ Parent empty-state cũ. |

### 2. Tổng quan và thông báo giáo viên — section `568:1930`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `453:584` | GV · Giáo viên · 02 — Tổng quan giáo viên | 390×844 | `screens/teacher_tabs.dart:94`, `widgets/garden_voice_teacher_overview.dart:108` | L497 | [PORT DỞ DANG] Có minh họa/scope; capture cắt nhãn “Thuốc hôm nay”, tint chuông và nav khác frame live. Không thêm unread giả để giống mẫu. |
| `454:1557` | GV · Giáo viên · 25 — Thông báo (giáo viên) | 390×844 | `screens/teacher_notifications_screen.dart:215` | L1237, L1257 | [PORT DỞ DANG] Scope, card và asset đã có; khoảng header/filter và nav còn khác ảnh live. Giờ event thiếu trong API không được tự tạo. |

### 3. Ghi nhận và duyệt báo cáo — section `568:1931`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `453:918` | GV · Giáo viên · 05 — Ghi nhận hoạt động | 390×844 | `screens/record_screens.dart:107` | L544 | [PORT DỞ DANG] Có header/search/class asset; avatar/tint và fixture roster chưa tương ứng state bốn hàng của frame. Capture hiện có hai trẻ và khoảng trống lớn trong card. |
| `453:1005` | GV · Giáo viên · 06 — Ghi âm | 390×844 | `screens/record_screens.dart:911` | L582 | [PORT DỞ DANG] Có recorder/scope/asset; cùng Nguyễn Minh An nhưng avatar đỏ thay vì amber, metric card/header còn lệch. Giữ khóa gửi khi đang thu vì file chưa hoàn tất. |
| `453:1092` | GV · Giáo viên · 07 — Phân tích | 390×844 | `screens/record_screens.dart:1690` | L610 | [PORT DỞ DANG] Có đủ nhóm xử lý; status trong capture một dòng thay vì hai dòng, làm lệch geometry các khối sau. |
| `563:1688` | GV · Giáo viên · Đoạn ghi chưa xác định bé | 390×844 | `screens/record_screens.dart:2992`, `:3232` | L873 | [PORT DỞ DANG] Subtitle bị ghép vào header; hai CTA đang nằm trong card đỏ, Figma đặt ngoài card; fixture transcript khác. |
| `563:1708` | GV · Giáo viên · Gán đoạn ghi | 390×844 | `screens/record_screens.dart:2964`, `:4126` | L878 | [PORT DỞ DANG] Route `_AssignScreen` không bọc lại scope; dùng màu/font cục bộ, thiếu assertion theme sau push và fixture cùng roster. Không xóa trẻ thật để ép số nút giống mẫu. |
| `453:1154` | GV · Giáo viên · 08 — Xem lại báo cáo | 390×844 | `screens/record_screens.dart:548`, `:2992`, `widgets/review/` | L797; geometry L673–785 | [ĐÃ PORT] Review nhận scope từ RecordFlow; khối transcript/audio/quan sát, asset và geometry có đối chiếu/capture. Giữ “Bỏ duyệt” theo nghiệp vụ; line-wrap vẫn khác nhẹ, chưa sign-off pixel/phát audio thiết bị. |
| `453:1270` | GV · Giáo viên · 09 — Chỉnh sửa báo cáo | 390×844 | `screens/record_screens.dart:3417`, `widgets/review/edit_observation_screen.dart:214` | L926 | [PORT DỞ DANG] Đã full-screen và có SVG; field đang radius 12/viền line, cỡ chữ/chiều cao khác node, sức khỏe bị ép hai dòng. Giữ “Lưu thay đổi” rồi quay lại review, không bypass approve. |
| `453:1350` | GV · Giáo viên · 10 — Hoàn thành | 390×844 | `widgets/review/done_screen_view.dart:100`, `:156` | L986, không audio | [PORT DỞ DANG] Mascot/count đã có; capture thiếu input audio nên không kiểm tra được khối nghe lại và vị trí CTA của state Figma. Không coi thiếu fixture là bằng chứng runtime không có audio row. |
| `453:1389` | GV · Giáo viên · 11 — Lịch sử báo cáo | 390×844 | `screens/teacher_tabs.dart:702`, caller `screens/teacher_shell.dart:519` | `teacher-report-history-gv.png` | [ĐÃ PORT] Bọc `GardenVoiceScope`, header “Báo cáo” + `SearchField` + 4 `FilterChipButton` (`Tất cả`, `Bản nháp`, `Đã gửi`, `Đã đọc`), nhóm ngày (`Hôm nay`, `Hôm qua`, `dd/MM/yyyy`), card bo `18px` viền `lineStrong` với `Avatar` + dòng giờ + `_HistoryStatusPill` (`Đã gửi`, `Bản nháp`, `Đã đọc`, `Cần chú ý`) và `GardenVoiceTeacherNavigation`. |

### 4. Gán cả lớp hoặc bỏ qua — section `568:1932`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `563:1722` | GV · Giáo viên · Duyệt ghi nhận cả lớp | 390×844 | `screens/record_screens.dart`, `ReviewScreen._sendBatch` | `teacher-review-classwide-gv.png` | [PORT DỞ DANG] Có hai thẻ data-driven “Riêng…” / “Áp dụng cho cả lớp”; giữ bước `Duyệt tất cả` trước khi xác nhận gửi, không approve ngầm. API partial giữ màn Review, ghi nhận ID đã gửi và lần retry chỉ gửi ID còn lại. |
| `563:1738` | GV · Giáo viên · Đã gửi báo cáo cả lớp | 390×844 | `screens/record_screens.dart`, `_ClasswideDoneScreen` | `teacher-done-classwide-gv.png` | [ĐÃ PORT] Trang xác nhận cả lớp chỉ hiện khi item classwide vẫn approved và mọi draft ID của item được API/fallback xác nhận sent/skipped; nội dung lấy từ class label. |
| `563:1757` | GV · Giáo viên · Duyệt sau khi bỏ qua | 390×844 | `screens/record_screens.dart:3030`, `:3350` | `teacher-review-after-skip-gv.png` | [PORT DỞ DANG] Có banner từ đoạn đã bỏ qua, summary bé, gửi có điều kiện theo trạng thái duyệt và `Xử lý lại đoạn ghi` restore; copy trích transcript thật thay cho text demo. |

### 5. Lỗi ghi âm và phân tích — section `568:1933`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:1712` | GV · Giáo viên · 06 — Ghi âm · Thiếu quyền micro | 390×844 | `screens/record_screens.dart:713`, `_showRecordingRecoveryDialog` | `teacher-recording-permission-gv.png` | [PORT DỞ DANG] Dialog/scrim và recovery buttons đã port; `app-settings:` dùng `url_launcher` có sẵn nhưng chưa xác minh mở Settings trên thiết bị Android thật. |
| `454:1810` | GV · Giáo viên · 06 — Ghi âm · Lỗi ghi âm | 390×844 | `screens/record_screens.dart:808`, `_showRecordingRecoveryDialog` | `teacher-recording-error-gv.png` | [ĐÃ PORT] Dialog `Thử lại` / `Đóng`; retry dùng lại `_startRecording` và giữ nguyên error path. Chưa kiểm tra lỗi phần cứng trên thiết bị thật. |
| `454:1204` | GV · Giáo viên · 20 — Sự cố phân tích | 390×844 | `screens/record_screens.dart:1694` | L827 | [PORT DỞ DANG] Asset 76px và recovery đã có; icon bắt đầu y116 trong capture thay vì y128 ở Figma, card gợi ý/spacing còn khác. Nội dung lỗi thật khác mẫu không phải lỗi nghiệp vụ. |

### 6. Lớp, điểm danh và lịch học — section `568:1934`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `564:1706` | GV · Giáo viên · Danh sách lớp | 390×844 | `screens/teacher_tabs.dart:147`, caller `screens/teacher_shell.dart:480` | `teacher-class-list-gv.png` | [ĐÃ PORT] Bọc `GardenVoiceScope`, hero minh họa `school_v2.png` + tên lớp/cô + chuông thông báo, thanh 4 class tabs (`Danh sách`, `Điểm danh`, `Đơn nghỉ`, `Lịch học`), ô tìm kiếm `class_search.svg`, thẻ danh sách trẻ bo `16px` (`reviewSurface` + `lineStrong`) với `Avatar`, phụ đề dị ứng/lưu ý và `StatusBadge` (`Chưa ghi` / `Đã ghi`) cùng `GardenVoiceTeacherNavigation`. |
| `453:801` | GV · Giáo viên · 04 — Điểm danh | 390×844 | `screens/attendance_screen.dart`, caller `screens/teacher_shell.dart:openAttendance` | `teacher-attendance-gv.png` · T:L960 | [ĐÃ PORT] Garden Voice header/tabs/nav, ngày có điều hướng, tóm tắt, tìm kiếm, hàng trẻ và CTA đơn nghỉ; giữ save/discard, khóa Có phép, gửi thông báo. Không có nguồn số đơn nghỉ để vẽ badge; capture dùng ngày hiện tại. |
| `454:931` | GV · Giáo viên · 13 — Thời khóa biểu | 390×844 | `screens/timetable_screens.dart`, caller `screens/teacher_shell.dart:openTimetable` | `teacher-timetable-gv.png` · T:L1056 | [ĐÃ PORT] Garden Voice class header/tabs/nav, dải tuần, ngày và hàng lịch; giữ `isReadOnly`, trạng thái/xung đột lấy từ lịch thật. Trạng thái “Đang diễn ra” phụ thuộc giờ capture. |

### 7. Tác vụ theo bé — section `568:1935`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `564:1818` | GV · Giáo viên · Tác vụ · Nguyễn Minh An | 390×844 | `screens/teacher_tabs.dart:365`, `_ChildActionsScreen` | `teacher-child-actions-gv.png` | [ĐÃ PORT] Full-screen header/back, lớp, ghi nhận từ `Child.allergy`/`careNotes` và hai callback ghi âm/soạn báo cáo; không dựng ghi nhận trẻ giả. |
| `564:1838` | GV · Giáo viên · Tác vụ · Trần Bảo Ngọc | 390×844 | `screens/teacher_tabs.dart:327` | — | [CHƯA PORT] Cùng action sheet A2, chưa có state GV theo bé. |
| `564:1856` | GV · Giáo viên · Ghi âm · Trần Bảo Ngọc | 390×844 | `screens/record_screens.dart:898` | —; L582 chỉ Minh An | [PORT DỞ DANG] Tái dùng recorder GV nhưng chưa kiểm tra biến thể card 70px/không nickname bằng fixture đúng bé. Không chép dị ứng demo sang dữ liệu thật. |
| `565:1905` | GV · Giáo viên · Bản ghi chờ duyệt · Trần Bảo Ngọc | 390×844 | `screens/record_screens.dart:2992`, `screens/report_editor.dart:170` | — | [CHƯA PORT] Chưa có state “Đã nhận bản ghi” với hai đích soạn thủ công/về lớp theo frame. |
| `564:1929` | GV · Giáo viên · Soạn nháp · Trần Bảo Ngọc | 390×844 | `screens/report_editor.dart:177`, caller `screens/teacher_shell.dart:243` | `teacher-report-editor-gv.png` | [PORT DỞ DANG] Full-screen GV fields, icon art, placeholders và CTA đôi; giữ repository/controllers/readOnly/draft/send. CTA vẫn khả dụng theo logic hiện có dù frame mẫu đang disabled; khoảng trống/gutters được đối chiếu capture. |
| `564:1998` | GV · Giáo viên · Tác vụ · Lê Hoàng Nam | 390×844 | `screens/teacher_tabs.dart:327` | — | [CHƯA PORT] Action sheet A2, chưa có composition GV. |
| `564:2016` | GV · Giáo viên · Ghi âm · Lê Hoàng Nam | 390×844 | `screens/record_screens.dart:898` | — | [PORT DỞ DANG] Recorder chung đã đổi; chưa có fixture/đối chiếu state riêng. |
| `565:1928` | GV · Giáo viên · Bản ghi chờ duyệt · Lê Hoàng Nam | 390×844 | `screens/record_screens.dart:2992`, `screens/report_editor.dart:170` | — | [CHƯA PORT] Thiếu UI waiting-record và hai đích tương ứng. |
| `564:2089` | GV · Giáo viên · Soạn nháp · Lê Hoàng Nam | 390×844 | `screens/report_editor.dart:170` | — | [CHƯA PORT] Editor thủ công A2, thiếu placeholder/field asset GV. |
| `564:2158` | GV · Giáo viên · Tác vụ · Phạm Thu Hà | 390×844 | `screens/teacher_tabs.dart:327` | — | [CHƯA PORT] Action sheet A2, chưa có composition GV. |
| `564:2176` | GV · Giáo viên · Ghi âm · Phạm Thu Hà | 390×844 | `screens/record_screens.dart:898` | — | [PORT DỞ DANG] Recorder chung GV, thiếu capture riêng và kiểm tra card/metadata theo bé. |
| `565:1951` | GV · Giáo viên · Bản ghi chờ duyệt · Phạm Thu Hà | 390×844 | `screens/record_screens.dart:2992`, `screens/report_editor.dart:170` | — | [CHƯA PORT] Thiếu UI waiting-record theo node. |
| `564:2249` | GV · Giáo viên · Soạn nháp · Phạm Thu Hà | 390×844 | `screens/report_editor.dart:170` | — | [CHƯA PORT] Editor thủ công A2; không tạo thêm class chỉ vì khác tên bé. |

### 8. Đơn nghỉ và báo trễ giáo viên — section `568:1936`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:1235` | GV · Giáo viên · 21 — Thông báo đơn mới (giáo viên) | 390×844 | `screens/teacher_shell.dart:321`; push ở `frontend/lib/core/notifications/push_notification_service.dart` | — | [CHƯA PORT] Frame mô phỏng notification trên màn khóa; UI thuộc OS, không phải thiếu một route Flutter. Kiểm tra payload/deep-link trên thiết bị, không dựng lock screen giả. |
| `454:1011` | GV · Giáo viên · 14 — Duyệt đơn xin nghỉ | 390×844 | `screens/leave_request_review_screen.dart:347`, `:367` | L1244, L1257 | [PORT DỞ DANG] Scope/class tabs/list/recent đã có; thiếu chuông header và nav còn khác. |
| `454:1251` | GV · Giáo viên · 22 — Duyệt đơn xin nghỉ (chi tiết) | 390×844 | `screens/leave_request_review_screen.dart:466`, `:482` | L1295 | [PORT DỞ DANG] `_buildFocusedDetail` đọc `State.context` ngoài scope mới; capture avatar/nút duyệt vẫn xanh A2. Cần kiểm tra cả helper `_detailSurface`/`_detailRow`, không chỉ wrapper. |
| `454:1307` | GV · Giáo viên · 23 — Từ chối đơn (lý do bắt buộc) | 390×844 | `screens/leave_request_review_screen.dart:249`, `widgets/reject_reason_dialog.dart` | L1275 | [PORT DỞ DANG] Hiện là dialog; Figma là full-screen form/header/CTA. Giữ validate lý do và draft khi API lỗi. |
| `454:1345` | GV · Giáo viên · 24 — Điểm danh sau khi duyệt (tự động) | 390×844 | `screens/attendance_approval_result_screen.dart`, caller `screens/leave_request_review_screen.dart:_handleApprove` | `teacher-attendance-approved-absence-gv.png` · T:L1189 | [ĐÃ PORT] Mở sau khi API approve thành công; tên bé/loại đơn lấy từ response. Không tuyên bố phụ huynh đã nhận push hoặc điểm danh đã đồng bộ nếu response không xác nhận. |
| `454:1673` | GV · Giáo viên · 26 — Điểm danh sau duyệt đi trễ (đồng bộ) | 390×844 | `screens/attendance_approval_result_screen.dart`, caller `screens/leave_request_review_screen.dart:_handleApprove` | `teacher-attendance-approved-late-gv.png` · T:L1189 | [ĐÃ PORT] ETA từ response được ghi là dự kiến; giờ đến thực tế do giáo viên xác nhận. Callback hỗ trợ ngày trong đơn ở entry trực tiếp; focused-detail và notification entry chưa truyền callback này, nên CTA hiện fallback về hôm nay. |

### 9. Thuốc và sự cố giáo viên — section `568:1937`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:1384` | GV · Giáo viên · M6 — Uống thuốc hôm nay (giáo viên) | 390×844 | `screens/teacher_medication_screen.dart`, entry `teacher_shell.dart:openMedications` + `/teacher/medications` | `teacher-medication-m6-gv.png` | [PORT DỞ DANG] Garden Voice header, cards, badge dots và nav; giữ date/session filters, section labels, và CTA báo sự cố đang có trong app nhưng không có trong frame. Ngày/lớp từ response. |
| `454:1445` | GV · Giáo viên · M7 — Đã cho uống (khóa trùng liều) | 390×844 | `screens/teacher_medication_screen.dart:_confirmationResult` | `teacher-medication-m7-gv.png` | [ĐÃ PORT] Chỉ chuyển sang kết quả sau mutation + reload canonical xác nhận `given`; thiếu actor/giờ vẫn hiện thiếu dữ liệu, 409 chỉ cập nhật danh sách. Không khẳng định phụ huynh đã nhận thông báo; cả CTA và header back quay về danh sách liều canonical. |
| `454:1487` | GV · Giáo viên · M8 — Báo cáo sự cố khẩn cấp | 390×844 | `widgets/teacher_emergency_sheet.dart`, `HttpMedicationRepository.getEmergencyContacts` | `teacher-emergency-m8-gv.png` | [PORT DỞ DANG] Contact phụ huynh tải từ API trước POST; không dựng hàng Ban giám hiệu vì API không trả trường. Giữ nhiệt độ tùy chọn dù frame không có field này; gọi chỉ dùng số hợp lệ. |
| `454:1532` | GV · Giáo viên · M9 — Đã phát cảnh báo (gọi phụ huynh) | 390×844 | `widgets/teacher_emergency_sheet.dart:_success` | `teacher-emergency-m9-gv.png` | [PORT DỞ DANG] SVG Figma local; xác nhận đã lưu biên bản nhưng không tuyên bố FCM đã giao. Danh bạ/điện thoại lấy từ API; call CTA chọn liên hệ API nếu có nhiều số. |

### 10. Tài khoản giáo viên/cài đặt chung — section `568:1938`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:827` | GV · Giáo viên · 12 — Tài khoản giáo viên | 390×844 | `screens/teacher_account_screen.dart:18`, caller `screens/teacher_shell.dart:524` | `teacher-account-gv.png` | [ĐÃ PORT] Bọc `GardenVoiceScope`, hero `books_v2.png` + `teacher_portrait.png` + thông tin cô/lớp/trường + link `Xem hồ sơ` + chuông thông báo, 3 nhóm thẻ (`Cá nhân`, `Tùy chọn`, `Hỗ trợ`) với SVG riêng từng hàng, pill chế độ giao diện và nút `Đăng xuất` đỏ dưới đáy cùng `GardenVoiceTeacherNavigation`. |
| `562:1668` | GV · Mobile · Chọn giao diện | 390×844 | `widgets.dart:787`, mở từ `screens/teacher_account_screen.dart:142` | `teacher-theme-selector-gv.png` | [ĐÃ PORT] Trong `GardenVoiceScope`, `ThemeSelector` render màn chọn giao diện đầy đủ (`hub_back.svg` + tiêu đề `Giao diện`, mô tả, hàng `Đang dùng` và 3 thẻ `Sáng` / `Tối` / `Theo máy` nền `surfaceSunken` bo `16px`) gắn `ThemeController.instance`. Ngoài GV giữ nguyên bộ chọn inline 3 cột cho `ParentAccount` A2. |
| `454:1111` | GV · Giáo viên · 17 — Đổi mật khẩu | 390×844 | `screens/change_password_screen.dart:107`, caller `teacher_account_screen.dart:356` → `/change-password` | `teacher-change-password-gv.png` | [PORT DỞ DANG] Teacher mở full-screen GV, Parent vẫn giữ sheet; giữ validation/API/default logout-other-devices và sheet test. Eye toggles còn để giữ password visibility dù frame không vẽ. |
| `454:1154` | GV · Giáo viên · 18 — Báo lỗi (sheet) | 390×844 | `screens/bug_report_sheet.dart:166`, callers Teacher/Parent/Recording | `teacher-bug-report-gv.png` | [PORT DỞ DANG] Header/form/64px attachment slots/CTA theo frame; giữ tối đa 5 ảnh, 5 MiB và device payload. Capture hiện chưa chọn ảnh nên chỉ thấy nút thêm, không sample thumbnail giả. |

### 11. Tổng quan, báo cáo, lịch phụ huynh — section `568:1939`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:1907` | GV · Phụ huynh · 01 — Tổng quan phụ huynh | 390×844 | `widgets/garden_voice_parent_overview.dart:37`, `screens/parent_screens.dart:435` | L519 | [PORT DỞ DANG] Minh họa/report/scope có; tint chuông/lịch, nav khác frame live. Không bịa giờ đến lớp/giờ event để lấp dữ liệu thiếu. |
| `454:2048` | GV · Phụ huynh · 02 — Thông báo (phụ huynh) | 390×844 | `screens/parent_notifications.dart:54`, caller `screens/parent_screens.dart:425` | L699 · `parent-inbox-gv.png` | [PORT DỞ DANG] Đã có inbox GV, filter có semantics và navigation; capture chỉ có report fixture. Figma đặt “Đánh dấu đã đọc” cùng hàng tiêu đề và có thêm loại/sự kiện, còn app đẩy action xuống hàng dưới; không bịa sự kiện hoặc giờ thiếu trong API. |
| `454:2216` | GV · Phụ huynh · 03 — Báo cáo ngày (sheet) | 390×844 | `screens/parent_screens.dart:563`, `:633` | L710 · `parent-daily-report-gv.png` | [PORT DỞ DANG] Có ảnh, nhóm ăn/ngủ/hoạt động, lời cô và read action; capture hiện là sheet thấp phủ overview thay vì khung report gần full-screen của Figma. Arrival/time không có trong report fixture nên được lược bỏ. |
| `454:2287` | GV · Phụ huynh · 04 — Thời khóa biểu (sheet) | 390×844 | `screens/parent_screens.dart:_openTimetable`, `screens/timetable_screens.dart:_buildParentSheetSchedule` | `parent-timetable-gv.png` · T:L1131 | [ĐÃ PORT] Mở dạng modal sheet chỉ xem; dải ngày và card dùng dữ liệu lịch của lớp. Nội dung capture là fixture; không có nút sửa/xóa/thêm trong luồng PH. |

### 12. Cảnh báo khẩn phụ huynh — section `568:1940`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `563:1649` | GV · Phụ huynh · Nhận cảnh báo khẩn | 390×844 | `screens/emergency_alert_summary_screen.dart`; router `frontend/lib/core/routing/app_router.dart` | `parent-emergency-alert-gv.png` | [PORT DỞ DANG] Bọc Garden Voice, màu theo `context.k`, gọi qua `phoneCallUri`, nút/header/system back đều dừng còi. Không bịa lớp vì payload không có class; chỉ capture/mock test, chưa thử siren trên thiết bị. |
| `563:1667` | GV · Phụ huynh · Gọi giáo viên (mô phỏng) | 390×844 | `screens/emergency_alert_summary_screen.dart` → `url_launcher` | Không chụp UI giả; `emergency_alert_listener_test.dart` kiểm tra `tel:` | [CHƯA PORT — có chủ đích] Frame là mock trình gọi điện ngoài app. Không dựng màn giả; OS handoff dùng số đã validate. Chưa xác minh gọi thật trên thiết bị. |

### 13. Tạo đơn nghỉ/báo trễ phụ huynh — section `568:1941`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:2526` | GV · Phụ huynh · 08 — Xin phép (đơn của bé) | 390×844 | `screens/parent_screens.dart:290`, `screens/parent_requests_screen.dart:118` | L1231, L1257 | [PORT DỞ DANG] List vào đúng scope; icon/header/nút tạo còn khác frame, route con không giữ scope. Giữ filter Đã hủy và nội dung sync trung thực. |
| `454:2586` | GV · Phụ huynh · 09 — Tạo đơn xin nghỉ | 390×844 | `screens/parent_requests_screen.dart:90`, `screens/parent_requests_form_screen.dart:284` | L1065, bọc GV trực tiếp | [PORT DỞ DANG] Layout đã đổi nhưng route production không bọc lại GV; capture pump form riêng đang che lỗi palette/font khi điều hướng thật. |
| `454:2637` | GV · Phụ huynh · 10 — Báo đi trễ | 390×844 | `screens/parent_requests_form_screen.dart:284`, `screens/parent_requests_form_fields.dart` | L1073, bọc GV trực tiếp | [PORT DỞ DANG] Cùng lỗi scope của form; cần capture vào từ ParentFlow và giữ ETA là dự kiến. |
| `454:2685` | GV · Phụ huynh · 11 — Đã gửi đơn | 390×844 | `screens/parent_requests_form_screen.dart:244`, `screens/parent_requests_submitted_screen.dart:12` | — | [PORT DỞ DANG] Có layout result nhưng push route mới không có scope và chưa có capture state. |
| `454:2706` | GV · Phụ huynh · 12 — Chi tiết đơn | 390×844 | `screens/parent_requests_screen.dart:107`, `screens/parent_requests_detail_screen.dart:136` | L1261 | [PORT DỞ DANG] Capture qua navigation thật hiện xanh A2 ở callout; `gardenVoice: true` chỉ đổi metric, không cài palette/font. |
| `454:2761` | GV · Phụ huynh · 13 — Cảnh báo gửi sau 7:30 | 390×844 | `screens/parent_requests_form_screen.dart:253`, `screens/parent_requests_widgets.dart:225` | — | [PORT DỞ DANG] Có modal theo lỗi API; thiếu scope qua flow/capture modal và đối chiếu nền form. |
| `454:2791` | GV · Phụ huynh · 14 — Đơn trùng (bị chặn) | 390×844 | `screens/parent_requests_form_screen.dart:268`, `screens/parent_requests_form_fields.dart` | — | [PORT DỞ DANG] Lỗi overlap hiện inline, không phải dialog hai đích của Figma; thiếu capture. Không bỏ validation overlap. |
| `454:3110` | GV · Phụ huynh · 18 — Kết quả đơn (đã duyệt · đồng bộ điểm danh) | 390×844 | `screens/parent_requests_detail_screen.dart:280`, `:340` | —; L1261 không phải capture riêng node 18 | [PORT DỞ DANG] Đã có approved branch nhưng rơi scope; thiếu card/timeline đúng state và fixture riêng. Không dùng mẫu Figma làm bằng chứng sync attendance. |

### 14. Hủy đơn chờ duyệt phụ huynh — section `568:1942`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:2823` | GV · Phụ huynh · 15 — Chi tiết đơn (chờ duyệt · có Hủy) | 390×844 | `screens/parent_requests_detail_screen.dart:136`, `:231` | —; L1261 là approved | [PORT DỞ DANG] Có cancel contract nhưng thiếu scope, thông tin/liên hệ và capture pending đúng node. |
| `454:2878` | GV · Phụ huynh · 16 — Xác nhận hủy đơn | 390×844 | `screens/parent_requests_detail_screen.dart:68`, `screens/parent_requests_widgets.dart:225` | — | [PORT DỞ DANG] Có dialog hủy; thiếu capture/đối chiếu layout và theme qua route thật. Giữ cutoff/khóa hủy từ API. |
| `454:2904` | GV · Phụ huynh · 17 — Đã hủy đơn | 390×844 | `screens/parent_requests_detail_screen.dart:95`, `screens/parent_requests_cancelled_screen.dart:24` | — | [PORT DỞ DANG] Đã có result layout, route replacement không bọc lại GV; chưa capture rollbacked/non-rollbacked. |

### 15. Dặn thuốc phụ huynh — section `568:1943`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:2925` | GV · Phụ huynh · M1 — Dặn thuốc (đợt của bé) | 390×844 | `screens/parent_medication_screen.dart`, caller `parent_screens.dart:_openMedication` | `parent-medication-m1-gv.png` | [PORT DỞ DANG] Scope/list/card/badges/CTA Garden Voice. Capture dùng fixture test; date range dùng en dash vì Nunito local không có glyph `→`. |
| `454:2969` | GV · Phụ huynh · M2 — Tạo đơn dặn thuốc | 390×844 | `screens/parent_medication_form_screen.dart` | `parent-medication-m2-gv.png` | [PORT DỞ DANG] CTA ghim dưới scroll và bù keyboard insets; upload ảnh bắt buộc, validation/7 ngày/API giữ nguyên. Capture để trống field thay vì hardcode nội dung mẫu. |
| `454:3026` | GV · Phụ huynh · M3 — Đã tạo đơn thuốc | 390×844 | `screens/parent_medication_submitted_screen.dart` | `parent-medication-m3-gv.png` | [ĐÃ PORT] Dùng success SVG local xuất từ frame; danh sách cữ và creator lấy từ API response. |
| `454:3046` | GV · Phụ huynh · M4 — Chi tiết đợt thuốc (hủy cữ) | 390×844 | `screens/parent_medication_detail_screen.dart` | `parent-medication-m4-gv.png` | [PORT DỞ DANG] Garden Voice cards/status; cữ đã uống vẫn disable hủy, status conflict vẫn reload canonical. Capture fixture date/status không cố định theo Figma sample. |
| `454:3084` | GV · Phụ huynh · M5 — Xác nhận hủy cữ thuốc | 390×844 | `screens/parent_medication_detail_screen.dart:_cancel` | `parent-medication-m5-gv.png` | [ĐÃ PORT] Dialog GV với `Giữ lại` / `Hủy cữ`; không đổi điều kiện `canCancel` hoặc API 409. |

### 16. Tài khoản và gia đình phụ huynh — section `568:1944`

| Node | Tên FRAME | Kích thước | Flutter / bằng chứng code | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:2445` | GV · Phụ huynh · 07 — Tài khoản phụ huynh | 390×844 | `screens/parent_account.dart:172`, `:189` | L722 · `parent-account-gv.png` | [PORT DỞ DANG] Có hero, nhóm gia đình/cài đặt/hỗ trợ, toggle và nav GV. Minh họa/hero thấp hơn và nội dung nhắc giờ của Figma không được dựng nếu không có dữ liệu/cấu hình tương ứng. |
| `562:1612` | GV · Phụ huynh · Thông tin liên hệ | 390×844 | `screens/parent_account.dart:287`, `ParentContactScreen` | L733 · `parent-contact-gv.png` | [PORT DỞ DANG] Có màn read-only, thông tin được che và action sửa; layout gần frame. Nội dung fixture (tên, email, quan hệ) khác mẫu Figma. |
| `562:1636` | GV · Phụ huynh · Sửa thông tin liên hệ | 390×844 | `widgets/parent_profile_sheet.dart:22`, `:109` | L747 · `parent-contact-edit-gv.png` | [PORT DỞ DANG] Có form GV và validation hiện có; app dùng outlined fields/helper text và action ghim đáy, khác field/card và vị trí CTA trong frame. |
| `563:1780` | GV · Phụ huynh · Chọn quan hệ với bé | 390×844 | `widgets/parent_profile_sheet.dart:141` | L762 · `parent-relationship-gv.png` | [PORT DỞ DANG] Đã có lựa chọn riêng và selected semantics; app hiện dấu check/radio và căn nhãn trái, khác hàng chọn đơn giản của Figma. |
| `454:2379` | GV · Phụ huynh · 05 — Thông tin bé (sheet) | 390×844 | `screens/parent_account.dart:315`, `:509` | L780 · `parent-child-details-gv.png` | [PORT DỞ DANG] Có thông tin bé, hồ sơ sức khỏe và gọi giáo viên; hiện là bottom sheet thấp hơn frame full-screen. Không có dữ liệu người đón/thuốc trong API nên không dựng các hàng mẫu Figma. |
| [`632:1535`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=632-1535) | GV · Phụ huynh · Chỉnh sửa thông tin bé | 390×844 | `screens/parent_child_edit_screen.dart`, bút chì trong `_ParentChildInfoSheet` (`parent_account.dart`) | `parent-child-edit-gv.png` | [ĐÃ TRIỂN KHAI] Frame Figma bổ sung từ code, dùng 10 instance Garden Voice và text/vector editable; đã đối chiếu layout với capture Flutter. Prototype: bút chì `632:1584` từ hồ sơ `454:2379` → frame này; Lưu/Hủy/Quay lại về hồ sơ. Dữ liệu Figma là mẫu; runtime vẫn gọi API, cập nhật ParentFlow và giữ form khi lỗi. |
| `454:2411` | GV · Phụ huynh · 06 — Hồ sơ sức khỏe | 390×844 | `screens/parent_health_profile_screen.dart:286` | L794 · `parent-health-profile-gv.png` | [PORT DỞ DANG] Có form dị ứng/lưu ý và trạng thái lưu; frame Flutter là form sửa, Figma là summary có chỉ số/tiêm chủng. Chỉ số và lịch tiêm chưa có mapping dữ liệu xác thực, không hardcode mẫu. |

### 17. Ba FRAME lồng 390×844 — đã có trong tổng raw 81

| Node | Tên FRAME | Kích thước | Flutter / frame cha | Capture trong T | Trạng thái / phần thiếu |
|---|---|---|---|---|---|
| `454:1775` | Overlay | 390×844 | `screens/record_screens.dart:713`; cha `454:1712` | — | [PORT DỞ DANG] Thiếu scrim + dialog quyền micro; không phải route riêng. |
| `454:1873` | Overlay | 390×844 | `screens/record_screens.dart:808`; cha `454:1810` | — | [PORT DỞ DANG] Thiếu scrim + dialog lỗi ghi âm; không phải route riêng. |
| `464:1697` | Viewport / vertical scroll | 390×844 | `widgets/teacher_emergency_sheet.dart:174`; cha `454:1487` | — | [CHƯA PORT] Vùng cuộn của M8; kiểm tra inset/keyboard cùng frame cha, không tạo màn thứ hai. |

### Phát hiện liên màn và giới hạn phải giữ

1. **Rơi scope qua Navigator:** `screens/parent_screens.dart:292` chỉ bọc list. `_create`/`_detail` ở `screens/parent_requests_screen.dart:90–113`, submit ở `screens/parent_requests_form_screen.dart:244`, cancel replacement ở `screens/parent_requests_detail_screen.dart:95` tạo route mới không có scope. `ParentRequestLayout.gardenVoice` chỉ đổi metric (`screens/parent_requests_widgets.dart:67–131`), không đổi palette/font. **Ảnh `parent-request-detail.png` mới đã cho thấy A2**, trong khi list là GV. Cần test chuyển route thực, không chỉ pump một form trong scope giả lập.
2. **Wrapper đúng, context đọc sai:** `_buildScreen(context)` nằm trong Builder của GV nhưng `_buildFocusedDetail(item)` và các helper lại đọc `State.context` (`screens/leave_request_review_screen.dart:482`, `:722–747`). **Ảnh `teacher-review-detail.png` mới còn xanh A2**. Kiểm tra cả màu được resolve trước khi widget được gắn vào subtree.
3. **Navigation dùng lại chưa khớp frame live:** `widgets/garden_voice_teacher_navigation.dart:45–48` và `widgets/garden_voice_parent_navigation.dart:38–41` dùng `line`/radius 30; frame live có viền/tint/radius khác, active-item có treatment riêng. Sửa component một lần, nhưng đối chiếu từng variant teacher/parent trong các node màn, không áp một nav cho mọi frame chỉ vì cùng canvas.
4. **Không đổi global A2:** `theme.dart:415` chỉ tạo scope; default input/card/divider vẫn có thể kế thừa theme A2. Không chỉ grep sự xuất hiện của `GardenVoiceScope`, phải xem context thực tế, effective Theme và metric từng field/card. Không thêm literal màu vào màn để che lỗi scope.
5. **Login là ngoại lệ ngay trong canvas:** `496:3859` dùng Be Vietnam Pro và token KL/Warm Sage (`#176B60`), có illustration `496:3864`. Không ép Nunito/GV palette chỉ để đạt điều kiện wrapper. Khi port phải ghi cách tái dùng theme/token mà vẫn đúng node này; không tự thêm đăng nhập demo hoặc làm lộ credentials từ khối “Khám phá” của Figma.
6. **State chưa có frame không phải state đã port:** OTP/reset không có frame riêng trong metadata này. Push `454:1235` và call `563:1667` là mô phỏng hệ điều hành/external app, không phải yêu cầu dựng màn giả. Logout sheet cũng chưa có target riêng trong canvas.
7. **Nghiệp vụ không đổi vì mẫu:** giữ “Bỏ duyệt”; edit lưu rồi quay lại review; giữ API ownership/cutoff/overlap/khóa liều, quyền mic, audio chưa hoàn tất, siren và gọi điện. Không hardcode attendance/push-delivered/medical data để làm ảnh giống thiết kế.

### Các batch đã triển khai và review — 2026-11-11

| Batch thực tế | Frames | Kết quả / giới hạn còn lại |
|---|---|---|
| 1 · Teacher Shell tabs | `564:1706`, `453:1389`, `454:827`, `562:1668` | Đã có scope, capture và đối chiếu; xem rows section 6/10 và VISUAL-QA. |
| 2 · Parent surfaces | `454:2048`, `454:2216`, `454:2445`, `562:1612`, `562:1636`, `563:1780`, `454:2379`, `454:2411` | Đã có capture; khác biệt composition/state còn lại được ghi trong VISUAL-QA. Không thêm event, giờ nhắc, người đón, chỉ số hoặc lịch tiêm thiếu nguồn. |
| 3 · Attendance & timetable | `453:801`, `454:1345`, `454:1673`, `454:931`, `454:2287` | Đã port/capture các state được giao; giữ API, `isReadOnly`, cảnh báo xung đột. Hai result không khẳng định push/check-in sync khi response không xác nhận. Chưa phải pixel sign-off; xem VISUAL-QA. |

### Lịch đề xuất ban đầu — 20 lô 3–4 màn/state (10/11/2026)

Đây là **đề xuất**, không phải các batch đã triển khai. Mỗi batch chỉ sửa các
widget/caller/fixture dùng chung của nhóm, không tạo class theo từng tên bé.
75 frame còn việc trong Flutter chia thành **20 batch**, mỗi batch 3–4 frame;
`453:1154` đã port là regression bắt buộc, không phải việc viết lại. Hai frame
mô phỏng `454:1235` / `563:1667` kiểm tra handoff riêng trên thiết bị, không tính
vào batch dựng UI. Ba frame lồng đi theo frame cha.

| Batch | Số frame | Node / màn-state | Mục tiêu trước khi sang batch tiếp |
|---|---|---|---|
| 01 | 4 | `454:2586`, `454:2637`, `454:2706`, `454:1251` — form nghỉ/trễ, detail PH, detail duyệt GV | Sửa đúng phạm vi theme/context; thêm test đi qua route thật và capture không được wrapper test che lỗi. Không tự bật GV cho nhóm thuốc đang A2 dùng chung layout. |
| 02 | 4 | `564:1706`, `453:801`, `454:1011`, `454:931` — lớp, điểm danh, duyệt đơn, lịch giáo viên | Tái dùng class tabs/header/bell/nav, giữ save/discard và callback hiện hữu. |
| 03 | 4 | `496:3859`, `454:1074`, `454:1190`, `454:1111` — login, quên mật khẩu, chưa phân lớp, đổi mật khẩu | Import đúng illustration/theme của từng node; giữ remember-login/OTP/reset. Xin target cho bước 2–3 trước khi tuyên bố parity. |
| 04 | 4 | `454:827`, `562:1668`, `454:1154`, `454:2445` — account GV, chọn giao diện, báo lỗi, account PH | Port nhóm cài đặt theo node; capture cả body trong shell, không chỉ nav. |
| 05 | 4 | `562:1612`, `562:1636`, `563:1780`, `454:2379` — liên hệ, sửa liên hệ, quan hệ, thông tin bé | Tái dùng profile form/options/validation, xác định read-only so với edit, không thêm dữ liệu mẫu production. |
| 06 | 4 | `454:1907`, `454:2048`, `454:2216`, `454:2287` — overview, inbox, report, lịch PH | Hoàn thiện shared parent nav/tint, sheet và static asset; giữ dữ liệu thiếu trung thực. |
| 07 | 4 | `454:2411`, `454:2925`, `454:2969`, `454:3026` — sức khỏe, danh sách/tạo/kết quả thuốc PH | Chốt mapping dữ liệu chỉ số; giữ form thuốc và các trạng thái lỗi/ảnh bắt buộc. |
| 08 | 4 | `454:3046`, `454:3084`, `454:1384`, `454:1445` — detail/hủy cữ PH, thuốc/đã uống GV | Port thuốc hai vai trò; kiểm tra given/locked/cancelled, không làm mất chống trùng liều. |
| 09 | 3 | `454:1487`, `454:1532`, `563:1649` — gửi/kết quả sự cố GV, nhận khẩn PH | Kiểm tra recipients, scroll/keyboard và CTA; tách lưu biên bản, gửi cảnh báo, nhận cảnh báo. |
| 10 | 4 | `454:1307`, `454:1345`, `454:1673`, `454:3110` — từ chối, kết quả duyệt nghỉ/trễ GV, kết quả PH | Đủ result state/capture; chỉ hiện sync mà dữ liệu thật chứng minh. |
| 11 | 4 | `454:2526`, `454:2685`, `454:2761`, `454:2791` — list đơn PH, submitted, cutoff, overlap | Chốt layout list/modal và route theme, giữ validation/API error. |
| 12 | 3 | `454:2823`, `454:2878`, `454:2904` — pending có hủy, xác nhận, đã hủy | Capture pending/cancel/rollback theo response, giữ kiểm tra cutoff từ máy chủ. |
| 13 | 4 | `453:584`, `453:918`, `453:1005`, `453:1092` — overview/hub/ghi âm/phân tích GV | Khớp nhãn, avatar, metric và nav; fixture roster/date/state phù hợp node. |
| 14 | 4 | `563:1688`, `563:1708`, `563:1722`, `563:1757` — unmatched, assign, classwide, sau bỏ qua | Sửa hierarchy/CTA/scope khi assign; gán không tự duyệt, giữ restore. |
| 15 | 4 | `453:1270`, `453:1350`, `563:1738`, `454:1204` — edit, done, done cả lớp, lỗi phân tích | Field metric đúng node, capture Done có audio, result cả lớp và spacing lỗi; không bypass approve/batch. |
| 16 | 4 | `453:1389`, `454:1557`, `454:1712`, `454:1810` — lịch sử, inbox GV, thiếu quyền/lỗi ghi âm | Port history/inbox composition; thêm hai overlay thật và capture tương ứng. |
| 17 | 4 | `564:1818`, `564:1838`, `564:1998`, `564:2158` — tác vụ bốn bé | Một implementation dùng dữ liệu hiện có, bốn fixture; không nhân bản screen. |
| 18 | 3 | `564:1856`, `564:2016`, `564:2176` — biến thể ghi âm ba bé | Tái dùng RecordingScreen; kiểm tra thiếu nickname/allergy, không copy allergy demo Figma. |
| 19 | 3 | `565:1905`, `565:1928`, `565:1951` — bản ghi chờ duyệt ba bé | Làm rõ state chưa phân tích bằng dữ liệu thật và nối đích soạn/về lớp, không giả STT thành công. |
| 20 | 3 | `564:1929`, `564:2089`, `564:2249` — soạn nháp ba bé | Port ReportEditor thủ công, không nhầm EditObservationScreen; giữ read-only/persist/send contract. |

**Cổng kiểm tra cho mỗi batch:** context + screenshot mới đúng node; bảng khối
Figma ↔ `file:line` ↔ token/widget; capture 390×844 cùng dữ liệu/state/inset;
320dp/chữ 200% và bàn phím nếu có form; test điều hướng thực/screen liên quan;
`flutter analyze`; xem ảnh trước–sau. Chỉ cập nhật trạng thái từng frame sau
khi kiểm tra đủ, không cập nhật golden để che diff. Shared nav/theme sửa ở batch
đầu tiên chạm tới phải chạy regression các màn đang dùng, kể cả Review đã port.

### Kiểm tra thực tế trong lượt audit

- `flutter analyze`: **No issues found**.
- `flutter test --no-pub --dart-define=UI_CAPTURE_DIR=build/ui-captures-gv-audit-2026-11-10 test/figma_request_layout_test.dart`: **18/18 pass**, tạo 22 PNG (20 màn/state + 2 component). Đã xem các capture màn mới; pass không chứng minh parity.
- `flutter test --no-pub test/garden_voice_parent_flow_test.dart test/forgot_password_test.dart test/leave_request_review_test.dart test/garden_voice_theme_test.dart`: **18/18 pass**. Các test hiện tại chưa bắt lỗi rơi scope/context ở trên.
- Chưa chạy lại full Flutter suite, chưa nghiệm thu mọi frame bằng ảnh hoặc mọi màn ở 320dp/200%, chưa chạy thiết bị Android/STT/PostgreSQL/FCM thật. Chỉ sửa tài liệu, không sửa Dart/test/asset hay file Figma; không stage/commit/revert công việc có sẵn. Không cần restart/rebuild Docker.

### Recheck sau implementation Batch 1–3 — 2026-11-11

- `flutter analyze`: **No issues found**.
- 12 test file liên quan chạy cùng: **89/90 pass**; một test `push_open_attendance_test.dart:269` còn tìm tooltip `Quay lại` không còn trong màn Garden Voice. Xem finding và hướng xác minh ở [VISUAL-QA.md](VISUAL-QA.md); chưa sửa theo yêu cầu review trước, fix sau.
- Capture `figma_request_layout_test.dart`: **34/34 pass**, gồm 5 ảnh Batch 3 trong `frontend/build/ui-captures-batch3/`.
- `impeccable detect --json`: `[]`; `git diff --check`: không báo whitespace error. Không có Android emulator/device trong `flutter devices`.
- Review tổng thể có các finding về attendance data provenance/save, route/discard/date, text scaling/touch targets, History timestamps/filter, school name fixture và visual parity; danh sách có mức ưu tiên trong VISUAL-QA. Không sửa Dart/backend trong lượt này.

## Garden Voice — các điểm vào đã chạm code (không phải bảng nghiệm thu)

Bảng lịch sử bên dưới giúp tìm implementation/test đã làm. **Trạng thái hiện
tại dùng bảng audit ở trên**; sự xuất hiện trong bảng này không đồng nghĩa đã
hoàn tất port hoặc scope đúng trên mọi đường điều hướng.

| Target Figma | Flutter / kiểm tra | Trạng thái và giới hạn |
|---|---|---|
| [GV · Giáo viên · 02 — Tổng quan](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-584) | `widgets/garden_voice_teacher_overview.dart`, `screens/teacher_tabs.dart`; `garden_voice_teacher_overview_test.dart`, `figma_request_layout_test.dart` | Dùng summary lớp, điểm danh và thuốc từ repository. Badge notification ẩn nếu caller chưa có unread count thật. |
| [GV · Navigation teacher](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=456-1725) | `widgets/garden_voice_teacher_navigation.dart`, `screens/teacher_shell.dart`; `garden_voice_teacher_navigation_test.dart` | 5 action: Tổng quan, Lớp, Ghi âm, Báo cáo, Tài khoản; ghi âm không phải tab. |
| [GV · Giáo viên · 14 — Duyệt đơn](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1011), [22 — Chi tiết đơn](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1251) | `screens/leave_request_review_screen.dart`; `leave_request_review_test.dart`, `figma_request_layout_test.dart` | Danh sách đã có class tabs, filter pending/reviewed, preview đơn, recent decision lấy từ API và nav teacher; các route được nối vào TeacherShell. Preview mở detail; duyệt/từ chối vẫn dùng repository và lý do bắt buộc. Capture mới: `build/ui-captures-leave-review-final/teacher-review.png`. Chưa sign-off pixel: header bell chưa port; recent row dùng ngày nghỉ + trạng thái, không khẳng định điểm danh đã đồng bộ. |
| [GV · Giáo viên · 25 — Thông báo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1557) | `screens/teacher_notifications_screen.dart`, `screens/parent_requests_widgets.dart`, `widgets/garden_voice_teacher_navigation.dart`; `teacher_notifications_test.dart`, `figma_request_layout_test.dart` | Frame 390×844 bên trong canvas duyệt `452:556`. Nền trắng, card bo 24px và navigation Teacher cố định; inbox dùng dữ liệu theo lớp từ API. Attendance/report không có event time thì không tự tạo giờ; đã đọc chỉ lưu trong phiên. |
| [GV · Giáo viên · 05 — Ghi nhận hoạt động](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-918) | `screens/record_screens.dart` → `RecordHubScreen`, `screens/teacher_shell.dart`; `push_open_attendance_test.dart`, `figma_request_layout_test.dart` | Overview CTA và nav Ghi âm mở hub; lớp/trẻ được chọn từ dữ liệu repository thật. |
| [GV · Giáo viên · 06 — Ghi âm](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-1005) | `screens/record_screens.dart` → `RecordingScreen`; `upload_file_test.dart`, `figma_request_layout_test.dart` | Giữ record plugin, permission, waveform/timer, chọn file và upload callback. Gửi xử lý bị khóa khi đang thu để không gửi audio chưa hoàn tất. |
| [GV · Giáo viên · 07 — Phân tích](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-1092), [20 — Sự cố phân tích](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1204) | `screens/record_screens.dart` → `ProcessingScreen`; `upload_file_test.dart`, `figma_request_layout_test.dart` | Đã port progress/error; “Sự cố” mở bug-report form hiện có, “Xem lại” quay lại bước ghi âm. Thiếu file là lỗi thật, không tạo transcript/extraction giả; lỗi STT/analyze không thành hoàn tất. |
| [GV · Giáo viên · 08 — Xem lại báo cáo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-1154), [09 — Chỉnh sửa báo cáo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-1270), [10 — Hoàn thành](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=453-1350), [đoạn chưa khớp `563:1688` / gán `563:1708`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=563-1688) | `screens/record_screens.dart` → `ReviewScreen`; `widgets/review/`; `review_screen_test.dart`, `figma_request_layout_test.dart` | Review dùng dữ liệu sau khi roster tải xong; count/CTA không còn giữ 0/0. Unmatched có màn tập trung và gán bé/cả lớp nhưng vẫn pending tới khi duyệt. Edit là full-screen; giữ “Lưu thay đổi” rồi quay lại review để không bypass approve/batch. Capture node 08 dùng đúng transcript Figma, kiểm tra geometry, waveform/accessibility; 320dp/200% không overflow. Giữ “Bỏ duyệt” vì nghiệp vụ dù node không có. Tile khớp 352px theo metadata; line-wrap transcript còn khác đôi chút trong Flutter. Done bỏ app bar, port summary/audio row; dòng sức khỏe ẩn khi count bằng 0. |
| [GV · Phụ huynh · 01 — Tổng quan](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1907) | `widgets/garden_voice_parent_overview.dart`, `screens/parent_screens.dart`; `garden_voice_parent_overview_test.dart`, `figma_request_layout_test.dart` | Báo cáo/shortcut/unread dùng dữ liệu hiện có. Parent chưa có quyền API điểm danh lớp, nên không hiển thị “Đã đến lớp lúc …” theo dữ liệu demo Figma. |
| [GV · Navigation parent](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=456-1834) | `widgets/garden_voice_parent_navigation.dart`, `screens/parent_screens.dart`; `garden_voice_parent_navigation_test.dart`, `garden_voice_parent_flow_test.dart` | 4 action: Tổng quan, Báo cáo, Thông báo, Tài khoản. Báo cáo mở sheet hiện có khi có report hôm nay. |
| [GV · PH · 02 Thông báo `454:2048`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2048), [03 Báo cáo ngày `454:2216`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2216) | `screens/parent_notifications.dart`, `screens/parent_screens.dart`; `parent_notifications_test.dart`, `figma_request_layout_test.dart` | Capture riêng `parent-inbox-gv.png` / `parent-daily-report-gv.png`. Filter có label/selected semantics; report read chỉ đổi sau API thành công. Xem VISUAL-QA batch 2026-11-10: composition inbox/report còn lệch, giờ/sự kiện không có trong API không được bịa. |
| [GV · PH · Tài khoản `454:2445`, liên hệ `562:1612` / sửa `562:1636`, quan hệ `563:1780`, bé `454:2379`, sức khỏe `454:2411`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2445) | `screens/parent_account.dart`, `widgets/parent_profile_sheet.dart`, `screens/parent_health_profile_screen.dart`; `parent_account_test.dart`, `parent_notifications_test.dart`, `figma_request_layout_test.dart` | Có 6 capture riêng dưới `build/ui-captures/`. Giữ validation/số gọi hợp lệ; không bịa người đón, chỉ số, lịch tiêm hay nhắc giờ. Các khác biệt bố cục/state được ghi trong VISUAL-QA; chưa pixel sign-off. |
| [GV · Phụ huynh · 08 — Xin phép](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2526), [09 — Tạo đơn nghỉ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2586), [10 — Báo trễ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2637) | `screens/parent_requests_screen.dart`, `parent_requests_form_screen.dart`, `parent_requests_form_fields.dart`, `parent_requests_widgets.dart`; `parent_requests_test.dart`, `figma_request_layout_test.dart` | Garden Voice scope begins at ParentFlow route. Keep API-driven records, loading/error/empty and existing late-arrival semantics. Repo includes `Đã hủy` filter absent from list frame. |
| [GV · Parent Requests · 11–18](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-2685) | `screens/parent_requests_submitted_screen.dart`, `parent_requests_detail_screen.dart`, `parent_requests_cancelled_screen.dart`, `parent_requests_attachment.dart` | Includes submit, detail, cutoff/overlap, cancel confirmation/result and approved detail. Teacher approve/reject now queues an FCM notification; tapping opens the correct child's API-backed request list. Figma's attendance-synced copy is not shown as fact unless API confirms it. |
| [GV · Giáo viên · 16 — Quên mật khẩu](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1074), [KInput `454:1077`](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1077) | `screens/forgot_password_screen.dart`; `forgot_password_test.dart`, `figma_request_layout_test.dart` | Step 1 maps to the current GV frame; email remains editable/empty instead of hardcoding the design sample. OTP/reset behavior remains intact; those visuals are not covered by this node-specific capture. |

## Danh mục đầy đủ các Section & Frame trong Canvas `452:556` (bóc tách từ `get_metadata` 10/11/2026)

> **Quy tắc bắt buộc cho Agent:** Canvas `452:556` và các `Section` (`568:1929`..`568:1947`) **không** truyền được trực tiếp vào `get_design_context`. Luôn truyền **Frame ID** ở cột thứ 2 vào `get_design_context` + `get_screenshot`. Mỗi lượt làm việc chỉ xử lý **1 Section (hoặc tối đa 3–4 Frame)** để tránh tràn ngữ cảnh.

| Section trong `452:556` | Frame ID (390×844) & Tên trên Figma | File Flutter tương ứng | Trạng thái Garden Voice |
|---|---|---|---|
| **568:1929** · Đăng nhập & khôi phục | `496:3859` — 01 — Đăng nhập | `screens/auth_screens.dart` → `LoginScreen` | **CHƯA PORT** (đang ở A2, thiếu illustration `496:3864`) |
| **568:1929** | `454:1074` — 16 — Quên mật khẩu | `screens/forgot_password_screen.dart` | **ĐÃ PORT** (bước 1 email; OTP/reset giữ luồng cũ) |
| **568:1929** | `454:1190` — 19 — Chưa được phân lớp | `screens/no_assignment_screen.dart` | **CHƯA PORT** |
| **568:1930** · GV Tổng quan & thông báo | `453:584` — 02 — Tổng quan giáo viên | `widgets/garden_voice_teacher_overview.dart` | **ĐÃ PORT** |
| **568:1930** | `454:1557` — 25 — Thông báo (giáo viên) | `screens/teacher_notifications_screen.dart` | **ĐÃ PORT** |
| **568:1931** · GV Ghi nhận & duyệt báo cáo | `453:918` (05 Hub), `453:1005` (06 Ghi âm), `453:1092` (07 Phân tích), `563:1688` (Đoạn chưa xác định), `563:1708` (Gán đoạn ghi), `453:1154` (08 Xem lại), `453:1270` (09 Chỉnh sửa), `453:1350` (10 Hoàn thành) | `screens/record_screens.dart`, `widgets/review/*` | **ĐÃ PORT** |
| **568:1931** | `453:1389` — 11 — Lịch sử báo cáo | `screens/teacher_tabs.dart` → `HistoryScreen` | **ĐÃ PORT** (capture `teacher-report-history-gv.png`, scope/nav GV) |
| **568:1932** · GV Gán cả lớp / bỏ qua | `563:1722` (Duyệt ghi nhận cả lớp), `563:1738` (Đã gửi báo cáo cả lớp), `563:1757` (Duyệt sau khi bỏ qua) | `screens/record_screens.dart` → `ReviewScreen` | **DỞ DANG** (đã có logic gán cả lớp/bỏ qua, cần đối chiếu chi tiết 3 frame state này) |
| **568:1933** · GV Lỗi ghi âm & phân tích | `454:1712` (06 Thiếu quyền micro), `454:1810` (06 Lỗi ghi âm) | `screens/record_screens.dart` → `RecordingScreen` | **DỞ DANG** (cần đối chiếu 2 state lỗi micro với `454:1712` / `454:1810`) |
| **568:1933** | `454:1204` — 20 — Sự cố phân tích | `screens/record_screens.dart` → `ProcessingScreen` | **ĐÃ PORT** |
| **568:1934** · GV Lớp, điểm danh & lịch | `564:1706` — Danh sách lớp | `screens/teacher_tabs.dart` → `ClassListScreen` | **ĐÃ PORT** (capture `teacher-class-list-gv.png`) |
| **568:1934** | `453:801` — 04 — Điểm danh | `screens/attendance_screen.dart` | **ĐÃ PORT** (Garden Voice scope/header/nav; capture `teacher-attendance-gv.png`) |
| **568:1934** | `454:931` — 13 — Thời khóa biểu | `screens/timetable_screens.dart` | **ĐÃ PORT** (Garden Voice header/nav; capture `teacher-timetable-gv.png`) |
| **568:1935** · GV Tác vụ theo bé | `564:1818`, `564:1838`, `564:1998`, `564:2158` (Tác vụ theo bé); `564:1856`, `564:2016`, `564:2176` (Ghi âm theo bé); `565:1905`, `565:1928`, `565:1951` (Bản ghi chờ duyệt); `564:1929`, `564:2089`, `564:2249` (Soạn nháp) | `screens/teacher_tabs.dart` (`_showActions`), `screens/report_editor.dart`, `screens/record_screens.dart` | **CHƯA PORT** (`ReportEditorScreen` và sheet tác vụ theo bé vẫn ở A2) |
| **568:1936** · GV Đơn nghỉ & báo trễ | `454:1011` (14 Duyệt đơn), `454:1251` (22 Chi tiết), `454:1307` (23 Từ chối) | `screens/leave_request_review_screen.dart`, `widgets/reject_reason_dialog.dart` | **ĐÃ PORT** (còn thiếu icon chuông header ở `454:1011`) |
| **568:1936** | `454:1235` (21 Thông báo đơn mới), `454:1345` (24 Điểm danh sau duyệt nghỉ), `454:1673` (26 Điểm danh sau duyệt trễ) | `screens/teacher_notifications_screen.dart`, `screens/attendance_approval_result_screen.dart` | **DỞ DANG** (24/26 có result/capture; 21 là notification OS, cần kiểm tra handoff trên thiết bị) |
| **568:1937** · GV Thuốc & báo sự cố | `454:1384` (M6 Uống thuốc hôm nay), `454:1445` (M7 Đã cho uống) | `screens/teacher_medication_screen.dart` | **CHƯA PORT** |
| **568:1937** | `454:1487` (M8 Báo cáo sự cố khẩn cấp), `454:1532` (M9 Đã phát cảnh báo) | `widgets/teacher_emergency_sheet.dart`, `screens/emergency_alert_summary_screen.dart` | **CHƯA PORT** |
| **568:1938** · Tài khoản GV & cài đặt | `454:827` (12 Tài khoản GV), `562:1668` (Chọn giao diện), `454:1111` (17 Đổi mật khẩu), `454:1154` (18 Báo lỗi sheet) | `screens/teacher_account_screen.dart`, `widgets.dart` (`ThemeSelector`), `screens/change_password_screen.dart`, `screens/bug_report_sheet.dart` | **DỞ DANG** (account/theme đã port/capture; đổi mật khẩu và báo lỗi còn việc) |
| **568:1939** · PH Tổng quan, báo cáo & lịch | `454:1907` — 01 — Tổng quan phụ huynh | `widgets/garden_voice_parent_overview.dart` | **ĐÃ PORT** |
| **568:1939** | `454:2048` (02 Thông báo PH), `454:2216` (03 Báo cáo ngày sheet), `454:2287` (04 Thời khóa biểu sheet) | `screens/parent_notifications.dart`, `screens/parent_screens.dart`, `screens/timetable_screens.dart` | **DỞ DANG** (cả 3 có capture; còn sai khác composition/state, xem VISUAL-QA 2026-11-11) |
| **568:1940** · PH Cảnh báo khẩn | `563:1649` (Nhận cảnh báo khẩn), `563:1667` (Gọi giáo viên) | `screens/emergency_alert_summary_screen.dart` | **CHƯA PORT** |
| **568:1941** & **568:1942** · PH Đơn nghỉ / trễ & Hủy đơn | `454:2526` (08), `454:2586` (09), `454:2637` (10), `454:2685` (11), `454:2706` (12), `454:2761` (13), `454:2791` (14), `454:3110` (18), `454:2823` (15), `454:2878` (16), `454:2904` (17) | `screens/parent_requests_*.dart` | **ĐÃ PORT** |
| **568:1943** · PH Dặn thuốc | `454:2925` (M1 Đợt thuốc), `454:2969` (M2 Tạo đơn), `454:3026` (M3 Đã tạo), `454:3046` (M4 Chi tiết/hủy cữ), `454:3084` (M5 Xác nhận hủy cữ) | `screens/parent_medication_*.dart` | **CHƯA PORT** (`_openMedication` tại `parent_screens.dart:302` chưa bọc `GardenVoiceScope`) |
| **568:1944** · PH Tài khoản & gia đình | `454:2445` (07 Tài khoản PH), `562:1612` (Thông tin liên hệ), `562:1636` (Sửa liên hệ), `563:1780` (Chọn quan hệ), `454:2379` (05 Thông tin bé sheet), `454:2411` (06 Hồ sơ sức khỏe) | `screens/parent_account.dart`, `widgets/parent_profile_sheet.dart`, `screens/parent_health_profile_screen.dart` | **DỞ DANG** (đã có 6 capture; còn khác biệt bố cục/state, xem VISUAL-QA 2026-11-10) |
| **568:1947** · Thành phần & minh họa | `452:686` (KButton), `452:723` (KInput), `452:745` (KStatusBadge), `452:761` (KChip), `452:766` (KCard), `452:781` (KAvatar), `452:813` (KPageHeader), `452:836` (KSettingsRow), `452:854` (KSearchField), `452:867` (KListRow), `456:1725` (Nav GV), `456:1834` (Nav PH) | `theme.dart`, `widgets.dart`, `widgets/garden_voice_*_navigation.dart` | **DỞ DANG** (đã port KButton, KInput bước 1, KStatusBadge, 2 thanh Nav; còn KChip, KCard, KPageHeader, KSettingsRow, KSearchField, KListRow) |

## Cách dùng bảng

- Mọi đường dẫn code trong bảng tính từ
  `frontend/lib/features/kindergarten_dashboard/`; test tính từ `frontend/test/`.
- Các frame màn hình bên dưới đều **390×844** theo metadata. Thứ tự/số hiệu frame
  không phải route. Một frame có thể tương ứng với một sheet hoặc state trong
  cùng class, không cần tạo một screen/route mới cho mỗi frame.
- Entry ở cột cuối mô tả luồng app hiện tại. Tên test là nơi bắt đầu kiểm tra,
  không khẳng định test đã bao phủ tất cả chi tiết hoặc state trong thiết kế.

## Giáo viên — trang `0:1`

| Frame Figma | Code cần đọc | Entry / test liên quan |
|---|---|---|
| [01 — Đăng nhập](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=1-2) | `screens/auth_screens.dart` | `/login`; `login_and_parent_test.dart` |
| [02 — Tổng quan](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=1-22) | `screens/teacher_tabs.dart` → `OverviewScreen` | `/teacher`, tab Tổng quan; `figma_request_layout_test.dart` |
| [03 — Lớp](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-14) | `screens/teacher_tabs.dart` → `ClassListScreen` | TeacherShell, tab Lớp |
| [04 — Điểm danh](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-28) | `screens/attendance_screen.dart` | Từ lớp/notification; `attendance_test.dart` |
| [05 — Ghi nhận hoạt động](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-44) | `screens/record_screens.dart` → `RecordHubScreen` | Mic trên TeacherShell; `upload_file_test.dart` |
| [06 — Ghi âm](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-58) | `screens/record_screens.dart` → `RecordingScreen` | `RecordFlowScreen`; `upload_file_test.dart` |
| [07 — Phân tích](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-72) | `screens/record_screens.dart` → `ProcessingScreen` | Sau upload; `review_screen_test.dart` |
| [08 — Xem lại báo cáo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-86) | `screens/record_screens.dart` → `ReviewScreen`, `widgets/review/` | Sau phân tích; `review_screen_test.dart`; unmatched segments được gán rồi vẫn cần duyệt riêng. |
| [09 — Chỉnh sửa báo cáo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-100) | `screens/report_editor.dart` | Từ báo cáo; `report_editor_and_history_test.dart` |
| [10 — Hoàn thành](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-112) | `widgets/review/done_screen_view.dart`, `screens/record_screens.dart` | Sau lưu/gửi; `review_screen_test.dart` |
| [11 — Lịch sử](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-124) | `screens/teacher_tabs.dart` → `HistoryScreen` | TeacherShell, tab Lịch sử; `report_editor_and_history_test.dart` |
| [12 — Tài khoản](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-136) | `screens/teacher_account_screen.dart` | TeacherShell, tab Tài khoản |
| [13 — Thời khóa biểu](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-150) | `screens/timetable_screens.dart` → `TimetableScreen` | `/timetable`; `timetable_test.dart` |
| [14 — Duyệt đơn](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-162) | `screens/leave_request_review_screen.dart` | Từ lớp/thông báo; `leave_request_review_test.dart` |
| [16 — Quên mật khẩu](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-174) | `screens/forgot_password_screen.dart` | `/forgot-password`; `forgot_password_test.dart` |
| [17 — Đổi mật khẩu](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-188) | `screens/change_password_screen.dart` | Từ tài khoản; `change_password_test.dart` |
| [18 — Báo lỗi](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-202) | `screens/bug_report_sheet.dart` | Sheet từ tài khoản; `bug_report_sheet_test.dart` |
| [19 — Chưa được phân lớp](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-216) | `screens/no_assignment_screen.dart` | Trạng thái chưa có lớp |
| [20 — Sự cố phân tích](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=8-228) | `screens/record_screens.dart` → `ProcessingScreen` | State lỗi; `review_screen_test.dart` |
| [21 — Thông báo đơn mới](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=53-2) | `screens/teacher_shell.dart`, `screens/teacher_notifications_screen.dart` | Push/list; `push_open_attendance_test.dart`, `teacher_notifications_test.dart` |
| [22 — Chi tiết duyệt đơn](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=53-19) | `screens/leave_request_review_screen.dart`, `widgets/leave_request_card.dart` | `leave_request_review_test.dart`; mở từ inbox dùng focused detail layout, còn tab duyệt dùng danh sách. Status, attachment, contact và actions lấy từ API thật. |
| [23 — Từ chối đơn](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=53-67) | `widgets/reject_reason_dialog.dart` | Từ nút Từ chối; `figma_request_layout_test.dart` |
| [24 — Điểm danh sau duyệt nghỉ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=53-90) | `screens/attendance_screen.dart`, `screens/leave_request_review_screen.dart` | State đồng bộ; `push_open_attendance_test.dart` |
| [25 — Thông báo (Garden Voice)](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/Redesign-Kindergarten-Management-Dashboard?node-id=454-1557) | `screens/teacher_notifications_screen.dart`, `backend/app/api/endpoints/health_incident.py` | Frame hiện hành là `454:1557` trong canvas `452:556`; inbox lấy đơn nghỉ, thuốc, sự cố, điểm danh và tổng hợp báo cáo ngày từ API theo lớp. Attendance/report không có event time nên không tự tạo giờ. Đã đọc chỉ lưu trong phiên; backend tests chưa xác minh được tại môi trường này. |
| [26 — Điểm danh sau duyệt trễ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=101-158) | `screens/attendance_screen.dart`, `screens/leave_request_review_screen.dart` | Đối chiếu nghiệp vụ API; ETA không phải check-in |
| [M6 — Uống thuốc](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-152), [M7 — Đã cho uống](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-200) | `screens/teacher_medication_screen.dart` | `/teacher/medications`; `teacher_medication_flow_test.dart` |
| [M8 — Báo sự cố](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-226), [M9 — Đã cảnh báo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-252) | `widgets/teacher_emergency_sheet.dart`, `screens/emergency_alert_summary_screen.dart` | Lối tắt Sự cố; `teacher_emergency_test.dart` |
| [06 — Thiếu quyền mic](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=156-32), [06 — Lỗi ghi âm](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=156-125) | `screens/record_screens.dart` → `RecordingScreen` | State lỗi/quyền của luồng ghi âm |

## Phụ huynh — trang `2:2`

| Frame Figma | Code cần đọc | Entry / test liên quan |
|---|---|---|
| [01 — Tổng quan](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=2-3) | `screens/parent_screens.dart` → `ParentFlow`, `_ParentOverview` | `/parent`; `parent_data_test.dart` |
| [02 — Thông báo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=2-44) | `screens/parent_notifications.dart` | Chuông trên ParentFlow; `parent_notifications_test.dart` |
| [03 — Báo cáo ngày](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=9-2) | `screens/parent_screens.dart` → `showParentReportSheet` | Mở báo cáo; `push_open_report_test.dart` |
| [04 — Thời khóa biểu](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=9-18) | `screens/timetable_screens.dart` | Từ Tổng quan, chế độ chỉ đọc; `timetable_test.dart` |
| [05 — Thông tin bé](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=9-34) | `screens/parent_account.dart`, `widgets/parent_profile_sheet.dart` | Mở hồ sơ bé; `parent_account_test.dart` |
| [06 — Hồ sơ sức khỏe](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=9-48) | `screens/parent_health_profile_screen.dart` | Từ hồ sơ bé; `parent_account_test.dart` |
| [07 — Tài khoản](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=9-60) | `screens/parent_account.dart` → `ParentAccount` | ParentFlow, tab Tài khoản; `parent_account_test.dart` |
| [08 — Đơn của bé](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=25-8) | `screens/parent_requests_screen.dart` | Xin nghỉ/Báo trễ trên Tổng quan; `parent_requests_test.dart` |
| [09 — Tạo đơn nghỉ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=25-53), [10 — Báo trễ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=29-2) | `screens/parent_requests_form_screen.dart`, `parent_requests_form_fields.dart` | Tạo đơn mới; `figma_request_layout_test.dart`, `parent_requests_test.dart` |
| [11 — Đã gửi](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=29-39) | `screens/parent_requests_submitted_screen.dart` | Sau API thành công; `parent_requests_test.dart` |
| [12 — Chi tiết](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=29-60), [15 — Chờ duyệt/có Hủy](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=52-43) | `screens/parent_requests_detail_screen.dart` | Từ danh sách đơn; `parent_requests_test.dart` |
| [13 — Cảnh báo sau 7:30](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=52-2), [14 — Trùng đơn](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=52-22) | `screens/parent_requests_form_screen.dart` | State phản hồi API; `parent_requests_test.dart` |
| [16 — Xác nhận hủy](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=52-87) | `screens/parent_requests_detail_screen.dart` | Nút Hủy đơn; `parent_requests_test.dart` |
| [17 — Đã hủy](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=52-103) | `screens/parent_requests_cancelled_screen.dart` | Sau hủy thành công; `parent_requests_test.dart` |
| [18 — Kết quả đã duyệt](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=101-206) | `screens/parent_requests_detail_screen.dart` | Từ thông báo; `push_open_attendance_test.dart` |
| [M1 — Đợt thuốc](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-2) | `screens/parent_medication_screen.dart` | Dặn thuốc; `parent_medication_test.dart` |
| [M2 — Tạo đơn thuốc](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-35) | `screens/parent_medication_form_screen.dart` | Tạo đợt mới; `parent_medication_test.dart` |
| [M3 — Đã tạo](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-81) | `screens/parent_medication_submitted_screen.dart` | Sau API thành công; `parent_medication_test.dart` |
| [M4 — Chi tiết/hủy cữ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-101), [M5 — Xác nhận hủy cữ](https://www.figma.com/design/9RurF0HiJlYLVDV7ljp2bH/KinderLog?node-id=56-128) | `screens/parent_medication_detail_screen.dart` | Từ danh sách đợt; `parent_medication_test.dart` |

## Hợp đồng layout cần kiểm tra cho từng task

Metadata của Tổng quan/Thông báo phụ huynh hiện chia nội dung cuộn **390×730**
và điều hướng cố định **390×114**. Đây là kích thước layer tổng, chưa xác nhận
114 tương ứng bao nhiêu navigation và bao nhiêu system inset. Không cộng thêm
SafeArea từ phỏng đoán hoặc crop khác nhau khi so ảnh.

Mỗi task ghi kèm: URL node + state, ngày đọc, viewport/DPR/text scale, locale,
insets, nội dung mẫu, hành động vào màn, phần cuộn/cố định và ảnh Figma/Flutter.
Đọc lại context khi thực hiện task; bảng này không thay thế dữ liệu live.
Nếu thiếu một state trong Figma, ghi rõ phần dùng hành vi sẵn có của app.

## Bảo trì

Khi đổi tên/move màn hoặc có frame mới, cập nhật đúng dòng liên quan. Khi một
trang concept được chọn để implement, bổ sung node cụ thể của trang đó và phạm vi
áp dụng; không đổi toàn bộ bảng chỉ vì trang mới hơn. Xem [VISUAL-QA.md](VISUAL-QA.md)
để lưu ảnh và phân biệt kiểm tra layout, đối chiếu thiết kế và golden regression.
