# KinderLog — Chụp và đối chiếu UI

Mục tiêu là kiểm tra **đúng node, đúng state, đúng nội dung**. Analyze kiểm tra mã,
layout test kiểm tra các điều kiện đã viết, capture tạo ảnh để xem, golden phát
hiện ảnh khác baseline. Chỉ một lượt đối chiếu Figma/Flutter mới xác nhận độ khớp
thiết kế tại thời điểm review.

## Môi trường chuẩn

### [Fix][Flutter UI] Giữ Login/navigation đã duyệt khi tích hợp develop — 12/11/2026

- Đã fast-forward `fix/flutter-ui-review` tới `origin/develop` `8f5bbe0`, rồi
  giải quyết ba file conflict từ autostash. Login đối chiếu bản dự phòng: chỉ
  khác bốn khai báo font `BeVietnamPro` → `Nunito`; layout/hành vi local giữ nguyên.
  Nunito toàn app theo quyết định mới của người dùng; rules để lượt sau.
- Navigation giữ pill local, motion 220ms/ease-out, tab retention, action return,
  auto-hide toàn bộ tab chính và vùng đáy dùng được. SVG dùng
  `SvgPicture(SvgAssetLoader(..., colorMapper: ...))` tương thích `flutter_svg`
  2.0.10 của upstream; không nâng dependency hoặc thay lockfile upstream.
- Giữ implementation ghi âm nhiều clip và thảo luận của teammate. Test ghi âm
  bị treo do I/O thật trong fake-async: tạo fixture đồng bộ và dừng ghi trong
  `tester.runAsync`, theo test upload hiện có. Không skip hoặc bỏ assertion.
- Regression mở báo cáo từ nav bắt được header thảo luận tràn 144px tại
  `report_discussion_section.dart`; đổi Row sang Wrap để giữ đầy đủ nhãn khi
  thiếu chỗ. Test parent action-return đã RED trước sửa và GREEN sau sửa.
- Kiểm tra cuối: `flutter analyze --no-pub` sạch; UI capture suite **50/50 pass**;
  full suite **441 pass / 10 fail / 0 skip** (`build/integration-final.jsonl`).
  Chín tên lỗi trùng baseline trước tích hợp; lỗi thêm `Hiển thị tab và thẻ thuốc
  đầy đủ thông tin` đã tái hiện ở bản archive upstream nguyên trạng `8f5bbe0`
  (`teacher_medication_test.dart:189`, thiếu `Buổi trưa`). Vì vậy full suite vẫn
  đỏ; không tuyên bố toàn bộ test xanh. Differential: `build/integration-test-differential.json`.
- APK debug ARM64 từ `lib/main.dart` build thành công sau sửa cuối. Không cài lại
  hoặc thao tác điện thoại trong lượt tích hợp này. Ảnh mới tại
  `build/integration-ui-captures/`; đã xem Login 390, Login bàn phím 320/chữ200%,
  teacher home390 và parent overview: role labels/pill còn nguyên, không thấy
  tràn trong các ảnh này. Không phải lượt nghiệm thu pixel mới với Figma live.
- Chỉ thay Flutter và tài liệu bằng chứng; không cần restart/rebuild Docker.
  Đổi font/asset: dừng rồi bấm ▶ chạy lại Flutter. Chưa commit/push tại lượt ghi này;
  giữ backup và autostash `8333c66`, không đưa config cá nhân/build output vào staging.

| Thuộc tính | Capture hiện có | Khi review một màn từ Figma |
|---|---|---|
| Flutter | CI pin **3.47.5**; SDK local được kiểm kê cùng version | Dùng cùng SDK; không tự cập nhật baseline khi đổi SDK |
| Nền tảng render | CI Ubuntu; local task này Windows | Golden font khác OS có thể khác pixel; tạo/chạy golden trên cùng môi trường |
| Viewport / DPR | 390×844 logical pixels, DPR 1 | Theo frame được giao; không suy ra dp từ kích thước PNG bị scale |
| Theme / locale | Light, `vi` | Dùng đúng mode và nội dung của node; dark cần target riêng |
| Text scale | 1 trong wrapper hiện có | Review chuẩn ở 1; kiểm tra chữ lớn 2 riêng |
| Font | FontLoader nạp BeVietnamPro và MaterialIcons | Nếu node dùng Quicksand/asset riêng, nạp đúng bản local trước khi so |
| Insets / bàn phím | Test view mặc định zero; form capture không mở bàn phím | Xác định Figma có status/nav system bars không; ghi inset và crop rõ ràng |
| Dữ liệu | Repository/transport giả trong test; không gọi backend thật | Dữ liệu demo tiếng Việt, đúng độ dài/số dòng/trạng thái thiết kế |
| Ngày giờ | Một số UI/fixture vẫn dùng `DateTime.now()` | Ghi thời điểm capture; chưa dùng ảnh này làm golden cố định cho màn có ngày động |

Môi trường capture chưa cố định được ngày giờ trên mọi màn. Khi thêm golden cho
màn có ngày/giờ, truyền clock/date qua điểm phụ thuộc phù hợp và dùng fixture cố
định; không thay dữ liệu production bằng mẫu để ổn định ảnh.

## Lệnh chạy từ `frontend/`

```powershell
flutter pub get
flutter analyze
flutter test --no-pub test/figma_request_layout_test.dart
flutter test --no-pub --dart-define=UI_CAPTURE_DIR=build/ui-captures test/figma_request_layout_test.dart
```

Lệnh cuối ghi PNG vào `frontend/build/ui-captures/` (đã được ignore). Test đã có
FontLoader và RepaintBoundary; không cần Docker/Firebase/backend để chạy nhóm này.
Không truyền `UI_CAPTURE_DIR` thì vẫn chạy assertions nhưng không ghi ảnh.

| Ảnh đầu ra | Fixture/state hiện có | Node để bắt đầu đối chiếu |
|---|---|---|
| `gv-kbutton-primary.png` | Component primary default at 170×48, Nunito loaded, GardenVoiceScope | `452:686`; geometry/shape assertion; Loading variant remains unaudited |
| `teacher-forgot-password-kinput.png` | Teacher forgot-password step 1 at 390×844; editable email is empty | `454:1074`; capture visually compared; uses a placeholder instead of Figma's sample email |
| `gv-status-badge-success.png` | Success report status (“Đã gửi”) in GardenVoiceScope, 140×48 | `452:746`; assertions cover success/error/info/neutral badges and the warning severity-chip colors. Figma variant text is “Thành công”, app copy is domain-specific, so this capture verifies styling—not text/pixel parity. |
| `teacher-overview.png` | Tổng quan Garden Voice với điểm danh/thuốc từ repository giả | `453:584`; badge notification chỉ hiện khi có unread count thật |
| `teacher-record-hub.png` | Chọn cả lớp/trẻ, fixture roster và trạng thái thật từ repository giả | `453:918` |
| `teacher-recording.png` | Thu âm cho một trẻ, đang ghi ở 01:24, fixture permission/recorder | `453:1005`; nút gửi khóa trong lúc ghi để giữ quy tắc file hoàn tất trước khi xử lý |
| `teacher-processing-gv.png` | Đang chuyển giọng nói thành văn bản; fixture mô phỏng tiến trình, không gọi STT/backend | `453:1092`; CTA quay lại/bug report nối hành vi thật, ảnh không xác nhận poll STT |
| `teacher-processing-error.png` | Upload lỗi trình duyệt; thử lại/quay lại, không giả thành công | `454:1204` |
| `teacher-unmatched-review-gv.png` | Một observation đã match + một đoạn chưa khớp từ extraction fixture | `563:1688`; gán/bỏ qua dùng item thật trong ReviewScreen, chưa duyệt |
| `teacher-unmatched-assign-gv.png` | Roster thật từ fixture và tùy chọn gán cả lớp | `563:1708`; chọn bé/cả lớp chỉ gán đích, không giả duyệt |
| `teacher-report-review-gv.png` | Một report đã duyệt bằng action/repository fixture; transcript và roster là fixture; player giả xác minh header/độ dài WAV im lặng 84 giây tạo trong test | `453:1154`; waveform hỗ trợ tap/drag, phím mũi tên và Semantics slider, không vẽ Slider riêng. Capture không xác minh giải mã/phát audio trên thiết bị. Giữ thêm “Bỏ duyệt” để không làm mất thao tác hoàn tác hiện có. |
| `teacher-report-edit-gv.png` | Edit full-screen từ một observation thật trong extraction fixture | `453:1270`; nút giữ “Lưu thay đổi” theo hợp đồng hiện có, không gửi lẻ ngoài approve/batch |
| `teacher-done-gv.png` | Hoàn tất với số báo cáo/sổ sức khỏe từ fixture; capture không truyền audio bytes | `453:1350`; audio row chỉ xuất hiện khi có bản ghi thực |
| `parent-overview.png` | Tổng quan Garden Voice với report/shortcut thật từ repository giả | `454:1907`; không giả trạng thái điểm danh vì Parent chưa có quyền endpoint lớp |
| `parent-absence.png` | Form xin nghỉ đã nhập lý do | `454:2586` |
| `parent-late.png` | Form báo trễ đã nhập lý do | `454:2637` |
| `parent-history.png` | Danh sách 3 đơn: chờ duyệt/đã duyệt/từ chối | `454:2526`; app giữ thêm filter `Đã hủy` có trong API/repo nhưng chưa có trong frame |
| `parent-request-detail.png` | Chi tiết đơn đã duyệt; giữ thông tin điểm danh trung thực theo API | `454:2706`; không hiển thị câu Figma tự khẳng định điểm danh đã đồng bộ |
| `teacher-inbox.png` | Capture fixture có đơn nghỉ, thuốc, sự cố, attendance và daily summary qua transport API giả; navigation Teacher hiển thị cố định dưới màn | `454:1557` (frame 390×844 trong canvas `452:556`); data thật được lấy theo class APIs. Attendance/report không có event time nên capture không vẽ giờ cho hai loại này; read chỉ lưu trong phiên. |
| `teacher-review.png` | Danh sách từ fixture API: 2 đơn pending, 1 gần nhất approved; preview mở detail; nav Teacher hiển thị cố định | `454:1011`; capture `frontend/build/ui-captures-leave-review-final/teacher-review.png`; chưa đạt pixel sign-off |
| `teacher-review-detail.png` | Chi tiết một đơn nghỉ pending từ API fixture, có contact/attachment thật theo fixture | `454:1251`; nền trắng, palette Garden Voice; actions duyệt/từ chối giữ callback repository |
| `teacher-reject.png` | Mở dialog từ chối và nhập lý do | `454:1307`; app đang dùng dialog, cần kiểm tra khác biệt trình bày |
| `teacher-class-list-gv.png` | Danh sách lớp 4 bé (`Nguyễn Minh An`, `Trần Bảo Ngọc`, `Lê Hoàng Nam`, `Phạm Thu Hà`), 2 đơn nghỉ chờ duyệt, `GardenVoiceTeacherNavigation` chọn tab Lớp | `564:1706`; đã đối chiếu trực quan với screenshot Figma (hero `school_v2.png`, 4 class tabs, search bar, card danh sách bé và badge `Chưa ghi`/`Đã ghi`) |
| `teacher-report-history-gv.png` | Lịch sử báo cáo nhóm theo `Hôm nay` / `Hôm qua` với 4 trạng thái (`Đã gửi`, `Bản nháp`, `Đã đọc`, `Cần chú ý`), `GardenVoiceTeacherNavigation` chọn tab Báo cáo | `453:1389`; đã đối chiếu trực quan với screenshot Figma (header, `SearchField`, 4 `FilterChipButton`, nhóm ngày và thẻ lịch sử) |
| `teacher-account-gv.png` | Tài khoản giáo viên (`Cô Nguyễn Thị Hương`, `Lớp Mầm A · Mầm non Hoa Hướng Dương`), 3 nhóm cài đặt và nút Đăng xuất, `GardenVoiceTeacherNavigation` chọn tab Tài khoản | `454:827`; đã đối chiếu trực quan với screenshot Figma (hero `books_v2.png` + `teacher_portrait.png`, nhóm `Cá nhân`/`Tùy chọn`/`Hỗ trợ`, pill `Sáng` và nút `Đăng xuất`) |
| `teacher-theme-selector-gv.png` | Màn chọn giao diện mở từ dòng `Giao diện` của `TeacherAccountScreen`, trạng thái `Đang dùng: Sáng` | `562:1668`; đã đối chiếu trực quan với screenshot Figma (nút back `44×44`, tiêu đề `Giao diện`, mô tả, dòng `Đang dùng` và 3 thẻ `Sáng`/`Tối`/`Theo máy`) |
| `parent-inbox-gv.png` | ParentFlow inbox, một report mới từ repository giả; 4 filter, read action và nav PH | `454:2048`; đối chiếu batch 2026-11-10; fixture không giả đơn nghỉ/sự cố/giờ event |
| `parent-daily-report-gv.png` | Report fixture mở từ shortcut Báo cáo; meal/sleep/activity/note và API-backed read action | `454:2216`; đối chiếu batch 2026-11-10; không có arrival/event-time trong fixture |
| `parent-account-gv.png` | Tài khoản phụ huynh, thông tin contact/child, push preference, theme và nav PH | `454:2445`; đối chiếu batch 2026-11-10; không thêm reminder schedule không có trong dữ liệu |
| `parent-contact-gv.png` | Trang contact read-only với phone/email/relationship fixture | `562:1612`; đối chiếu batch 2026-11-10 |
| `parent-contact-edit-gv.png` | Contact editor với dữ liệu test, validation/helper và action lưu/hủy | `562:1636`; đối chiếu batch 2026-11-10; không mở bàn phím trong capture |
| `parent-relationship-gv.png` | Màn chọn quan hệ, `Mẹ` được chọn | `563:1780`; đối chiếu batch 2026-11-10 |
| `parent-child-details-gv.png` | Child detail sheet với ngày sinh, lớp, giáo viên, allergy summary và số điện thoại test hợp lệ | `454:2379`; đối chiếu batch 2026-11-10; người đón/thuốc không được dựng nếu API không có |
| `parent-child-edit-gv.png` | Bút chì từ sheet hồ sơ mở trang sửa bé; tên/biệt danh/ngày sinh/giới tính/dị ứng từ fixture, Lưu/Hủy cố định dưới vùng cuộn | Frame mới `632:1535`, entry `454:2379` qua bút chì `632:1584`. Đã xem ảnh Figma và Flutter: Nunito, field bo 14, ô dị ứng 88px, Lưu/Hủy ghim đáy; nội dung mẫu/giới tính khác fixture nên không khẳng định pixel parity toàn ảnh. Capture tại `frontend/build/ui-captures-child-edit/`; test hồ sơ kiểm tra 320dp, chữ 200%, bàn phím, hủy/lưu/lỗi/thử lại và giữ giới tính chưa khai báo. |
| `parent-health-profile-gv.png` | Health profile form fixture có allergy/care notes và save disabled khi không đổi | `454:2411`; đối chiếu batch 2026-11-10; không có measurements/vaccination fixture |
| `teacher-attendance-gv.png` | AttendanceScreen với roster/status fixture 5 trẻ; ngày capture theo ngày hiện tại | `453:801`; lớp/tên cô/status là fixture, ngày production vẫn động; không có nguồn số đơn nghỉ để dựng badge |
| `teacher-attendance-approved-absence-gv.png` | Result sau approve absence với `LeaveRequestEntity` response fixture | `454:1345`; capture mô phỏng API thành công, không xác minh FCM hoặc đồng bộ backend thật |
| `teacher-attendance-approved-late-gv.png` | Result sau approve late arrival, ETA `08:30` từ response fixture | `454:1673`; ETA được ghi là dự kiến; không khẳng định giờ check-in thực tế |
| `teacher-timetable-gv.png` | TimetableScreen với schedule repository fixture của tuần hiện tại | `454:931`; lịch thật trong production; trạng thái “Đang diễn ra” phụ thuộc đồng hồ chạy, capture không đại diện một giờ cố định |
| `parent-timetable-gv.png` | ParentFlow mở modal timetable sheet chỉ xem, 5 schedule fixture cards | `454:2287`; test đi qua entry PH và sheet thật; thời gian/nội dung là fixture, không có thao tác ghi lịch |
| `teacher-login-gv.png` | Login ở 390×844 với tài khoản nhớ giả trong test; không gửi login | `496:3859`; Be Vietnam Pro/KL Warm Sage và illustration `496:3864`; checkbox nhớ + reveal password được giữ dù frame không vẽ |
| `teacher-no-assignment-gv.png` | Giáo viên không có lớp, CTA đăng xuất | `454:1190`; dùng SVG `454:1193`; Parent fallback vẫn là A2 |
| `teacher-change-password-gv.png` | Full-screen đổi mật khẩu với trường xác nhận không khớp | `454:1111`; API không được gọi vì validation; eye toggles hiện có được giữ |
| `teacher-bug-report-gv.png` | Bug report sheet chưa chọn file; payload giả chưa được gửi | `454:1154`; cap 5 ảnh/5 MiB được test riêng; không dùng ảnh mẫu Figma làm attachment thật |
| `teacher-child-actions-gv.png` | Tác vụ của Nguyễn Minh An với dị ứng từ fixture thật trong test | `564:1818`; cả hai callback ghi âm/soạn báo cáo được bấm kiểm tra |
| `teacher-report-editor-gv.png` | Soạn nháp với các field trống, ngày “Hôm nay” | `564:1929`; placeholder là nội dung rỗng, test riêng xác nhận populate từ report/extraction giữ nguyên |
| `teacher-review-classwide-gv.png` | Review classwide sau khi duyệt các item qua fake repository | `563:1722`; capture giữ bước approve hiện có trước CTA gửi |
| `teacher-done-classwide-gv.png` | Done sau `sendBatch` giả xác nhận số gửi | `563:1738`; không gọi API/backend thật |
| `teacher-review-after-skip-gv.png` | Đoạn không khớp được bỏ qua; report trẻ đã được duyệt trong fixture | `563:1757`; copy trích transcript fixture, CTA send/reprocess được kiểm tra |
| `teacher-recording-permission-gv.png` | Permission denied trên fake recorder | `454:1712`; capture không gọi Settings của thiết bị |
| `teacher-recording-error-gv.png` | Recorder `start` ném lỗi trên fake recorder | `454:1810`; retry/close là UI fixture, chưa kiểm tra phần cứng |

### Đối chiếu đại diện Garden Voice — 2026-11-09

- Đọc lại context + screenshot live `453:584` (Teacher overview) và `454:1907`
  (Parent overview); xem cùng capture Flutter 390×844/light trong bảng trên.
- Bố cục, minh họa, thẻ nội dung và navigation của hai capture theo đúng hierarchy
  Figma. Dữ liệu động khác mẫu Figma (ngày, unread count, nội dung báo cáo).
- Parent overview hiện ghi “Chưa có cập nhật điểm danh hôm nay” thay vì câu giờ đến
  trong Figma vì API Parent chưa cung cấp điểm danh; đây là khác biệt nghiệp vụ có
  chủ đích, không thay bằng dữ liệu giả. Teacher capture ẩn unread badge khi chưa
  có unread count thật.
- Đây là đối chiếu định tính cho hai route đại diện, không phải pixel-parity sign-off
  cho toàn bộ refactor. Capture Review là widget capture; phát audio trên thiết bị
  vẫn chưa được xác minh.

### Đối chiếu flow Review — 2026-11-09

- Figma live node `453:1154` (390×844) được đọc lại cùng screenshot; đối chiếu với
  `teacher-report-review-gv.png` (390×844, DPR 1, Nunito, state đã duyệt).
- Header/progress, audio row (`01:24`), transcript, card quan sát, minh họa và CTA
  theo đúng thứ tự/phân cấp. Sai khác nhỏ đo bằng mắt: observation card bắt đầu
  thấp hơn khoảng 3dp, CTA thấp hơn khoảng 4dp; nội dung transcript là fixture nên
  không có dấu ngoặc kép/mẫu chữ nguyên văn Figma.
- App giữ action “Bỏ duyệt” để hoàn tác draft; action này không có trong frame Figma.
  Đã giữ lại để không làm mất nghiệp vụ hiện hữu. Widget test xác nhận state đã duyệt,
  player duration và điều khiển seek; audio WAV im lặng 84 giây chỉ là fixture, không
  chứng minh phát/giải mã audio thật trên thiết bị.
- Đây chưa phải sign-off flow: chưa xác minh persist/send với PostgreSQL/service thật
  hoặc phát audio trên thiết bị. Các phần đó tiếp tục ở trạng thái NOT VERIFIED.

### Đối chiếu inbox Teacher — 2026-11-09

- Đọc lại live Figma `454:1557` (390×844, trong canvas `452:556`) và so với
  `teacher-inbox.png` (390×844, DPR 1, light, locale vi, text scale 1).
- Nền trắng, card bo 24px, navigation Teacher cố định, thứ tự nguồn và hierarchy
  các card nghỉ, thuốc, sự cố, điểm danh, báo cáo ngày khớp frame; category badges
  dùng các màu trạng thái riêng. App cố ý không hiện
  giờ trên card điểm danh/tổng hợp báo cáo vì các API hiện có không trả event time.
- Capture dùng dữ liệu giả ở transport để ổn định ảnh; test xác nhận repository gọi
  đúng class-scoped endpoint. Chưa xác minh các bản ghi với PostgreSQL/service thật.
  API danh sách sự cố có test authorization mới nhưng test chưa chạy được vì máy
  không có Python/Docker/Ruff. Đọc bền vững chưa có API; dấu đã đọc chỉ sống trong
  phiên, và inbox đang đọc tối đa 100 đơn thuốc + 50 sự cố mới nhất.

### Chỉnh palette Teacher leave review — 2026-11-09

- Đọc live Figma `454:1011` (danh sách) và `454:1251` (chi tiết), 390×844.
- `LeaveRequestReviewScreen` trước đó đặt màu canvas cũ `#F5F4F0` trực tiếp trong
  focused detail; capture `teacher-review-detail.png` thể hiện nền kem. Đã chuyển
  canvas sang trắng và màu action/status sang Garden Voice; capture mới ở
  `frontend/build/ui-captures-teacher-review-fixed/`.
- `teacher-review.png` cũng đã chuyển khỏi màu xanh A2 sang màu Garden Voice.
  Cấu trúc class tabs/recent row/fixed navigation được bổ sung ở lượt
  “Bố cục Teacher leave review” bên dưới; pixel sign-off vẫn còn mở.

### Bố cục Teacher leave review — 2026-11-09

- Đọc live frame `454:1011`, type FRAME, 390×844 và đối chiếu screenshot; node
  `454:1251` tiếp tục là detail. Screenshot Flutter dùng DPR 1, light, locale vi,
  scale 1, fixture transport, hai pending + một reviewed.
- Khối đối chiếu: header Figma 24/700, padding 20/20 → app 24/700, padding 20;
  class tabs 42h/radius 16/viền lineStrong → app 42h/radius 16; preview 350w,
  padding 16, gap 10, radius 24, brandTint → app dùng cùng kích thước/radius;
  request filters và recent row lấy status/data từ API; nav chọn Class từ component
  `GardenVoiceTeacherNavigation` và ở cố định đáy.
- `teacher-review.png` đã được thay đồng bộ ở cả 7 thư mục capture trong
  `frontend/build/` (SHA-256 giống nhau). Ảnh mới được xem lại: hierarchy, class
  tabs, hai pending cards, recent section và bottom nav đều hiện đúng.
- Sai khác còn lại: Figma có icon chuông ở header, app chưa nối inbox từ màn này;
  sample Figma ghi “Đã đồng bộ vắng có phép”, app chỉ ghi “Nghỉ dd/MM” để không
  tuyên bố attendance sync khi API không xác nhận. Khoảng trắng/card height và
  nav tint chưa pixel-compare; chưa sign-off toàn màn.
- `flutter test --no-pub test/leave_request_review_test.dart` và capture suite
  `figma_request_layout_test.dart` đã pass; chưa xác minh backend/PostgreSQL thật.

### Đối chiếu Batch 1 Teacher Shell Tabs (`564:1706`, `453:1389`, `454:827`, `562:1668`) — 2026-11-10

- Đã gọi song song `get_design_context` + `get_screenshot` + `get_variable_defs` cho 4 frame mục tiêu trong file `9RurF0HiJlYLVDV7ljp2bH` và đối chiếu trực tiếp với 4 ảnh PNG xuất từ `figma_request_layout_test.dart` ở 390×844, DPR 1, light, locale `vi`, font Nunito:
  - `teacher-class-list-gv.png` ↔ `564:1706`: khớp bố cục hero `school_v2.png`, tên lớp + chevron + tên giáo viên, nút chuông thông báo `46×46`, 4 class tabs (`Danh sách` active, `Điểm danh`, `Đơn nghỉ` kèm badge, `Lịch học`), thanh tìm kiếm `class_search.svg`, thẻ danh sách trẻ bo `16px` (`reviewSurface` + `lineStrong`) với 4 hàng trẻ, phụ đề dị ứng/lưu ý, `StatusBadge` (`Chưa ghi`/`Đã ghi`) và `GardenVoiceTeacherNavigation`.
  - `teacher-report-history-gv.png` ↔ `453:1389`: khớp tiêu đề `Báo cáo`, `SearchField` 48px, 4 `FilterChipButton` (`Tất cả`, `Bản nháp`, `Đã gửi`, `Đã đọc`), nhóm ngày `Hôm nay` / `Hôm qua`, thẻ bo `18px` viền `lineStrong`, hàng lịch sử 66px với `Avatar`, giờ báo cáo và `_HistoryStatusPill` (`Đã gửi`, `Bản nháp`, `Đã đọc`, `Cần chú ý`).
  - `teacher-account-gv.png` ↔ `454:827`: khớp hero `books_v2.png` + `teacher_portrait.png` (`90×90`), tiêu đề `Tài khoản`, nút chuông thông báo, thông tin giáo viên + link `Xem hồ sơ`, 3 nhóm thẻ `Cá nhân` / `Tùy chọn` / `Hỗ trợ` bo `20px` với icon SVG trong ô tròn `38×38`, pill trạng thái giao diện `Sáng` và nút `Đăng xuất` dưới đáy.
  - `teacher-theme-selector-gv.png` ↔ `562:1668`: khớp nút back `44×44` (`hub_back.svg`), tiêu đề `Giao diện`, câu mô tả, dòng `Đang dùng` — `Sáng` và 3 thẻ tùy chọn `Sáng` / `Tối` / `Theo máy` nền `surfaceSunken` bo `16px`.
- Đã kiểm tra thêm ở màn hẹp `320×844` với `TextScaler.linear(2.0)` cho `ClassListScreen`, `HistoryScreen` và `TeacherAccountScreen`: không xảy ra lỗi tràn bố cục (`takeException() == null`).

### Đối chiếu Batch 2 Parent (`454:2048`, `454:2216`, `454:2445`, `562:1612`, `562:1636`, `563:1780`, `454:2379`, `454:2411`) — 2026-11-10

- Đã xem trực tiếp 8 screenshot frame Figma đã lưu cùng 8 PNG Flutter trong
  `frontend/build/ui-captures/`. Flutter: 390×844 logical px, DPR 1, light, locale
  `vi`, Nunito trong `GardenVoiceScope`; fixture dùng dữ liệu test, ngày report
  hiện tại và không mở bàn phím. Capture là bằng chứng bố cục/state, chưa phải
  pixel-diff hoặc sign-off thiết bị.
- `parent-inbox-gv.png` ↔ `454:2048`: hierarchy card/filter/nav GV đã có; Figma đặt
  `Đánh dấu đã đọc` cùng hàng với title, còn app đẩy xuống dưới title. Fixture chỉ
  có report nên không có các card đơn nghỉ/sức khỏe/nhà trường ở phần `Trước đó`;
  không thêm giờ/sự kiện vắng mặt khỏi API để lấp ảnh.
- `parent-daily-report-gv.png` ↔ `454:2216`: app hiển thị ảnh, ăn/ngủ/hoạt động,
  lời cô và read action; khác biệt lớn là app mở sheet thấp phủ overview, Figma
  frame gần full-screen với CTA sát đáy. App không dựng arrival row/time vì report
  không cung cấp dữ liệu ấy.
- `parent-account-gv.png` ↔ `454:2445`: nhóm mục và nav tương ứng; hero/minh họa
  landscape thấp/gọn hơn Figma. Figma có nhãn nhắc giờ và theme `Sáng`, còn app
  fixture dùng push-device preference và `Theo máy`; không giả lịch nhắc.
- `parent-contact-gv.png` ↔ `562:1612`: card read-only và action sửa theo cùng
  hierarchy; tên/email/quan hệ khác vì dùng fixture hiện có.
- `parent-contact-edit-gv.png` ↔ `562:1636`: app giữ validation, nhưng dùng
  outlined fields/helper text và hai action ghim đáy; Figma dùng bố cục label/field
  gọn hơn với actions ngay sau các field. Capture không xác minh bàn phím thiết bị.
- `parent-relationship-gv.png` ↔ `563:1780`: app có selection state/check rõ ràng
  và semantics, trong khi Figma dùng các hàng lựa chọn ít trang trí hơn; giữ
  affordance chọn hiện tại để state vẫn nhìn thấy/truy cập được.
- `parent-child-details-gv.png` ↔ `454:2379`: app mở bottom sheet phủ account,
  còn Figma frame là khung trắng full-height. Dòng người đón và thông tin thuốc
  trong mẫu không hiển thị vì chưa có dữ liệu được xác minh; call action chỉ bật
  với phone hợp lệ.
- `parent-health-profile-gv.png` ↔ `454:2411`: app hiện form sửa allergy/care
  notes, Figma là summary có allergy detail, measurements và vaccination. Giữ các
  chỉ số/lịch tiêm ngoài UI đến khi có nguồn dữ liệu hợp lệ; cần xác định riêng
  state read-only/edit trước khi coi node đã port.
- Màn hẹp 320dp / chữ 200% đã có regression test trong capture suite; account hero
  tăng chiều cao chỉ khi text scale lớn. Chưa kiểm tra bàn phím thật hoặc gọi điện
  trên thiết bị; không có dark Figma target cho batch này.

### Đối chiếu Batch 3 Attendance & Timetable (`453:801`, `454:1345`, `454:1673`, `454:931`, `454:2287`) — 2026-11-11

- Đã đọc cặp context/screenshot/variables cho 5 frame trong file
  `9RurF0HiJlYLVDV7ljp2bH`; xem các PNG Flutter mới trong
  `frontend/build/ui-captures-batch3/` ở 390×844, DPR 1, light, locale `vi`,
  Nunito. Đây là widget capture, không phải ảnh emulator hoặc pixel-diff.
- `teacher-attendance-gv.png` ↔ `453:801`: header lớp/tabs, summary, ngày, tìm trẻ,
  danh sách, đơn nghỉ và nav có trong capture. Ngày là `DateTime.now()`; badge số
  đơn nghỉ được bỏ vì không có count từ repository. Fixture trẻ/status không dùng
  trong production.
- `teacher-attendance-approved-absence-gv.png` ↔ `454:1345` và
  `teacher-attendance-approved-late-gv.png` ↔ `454:1673`: mở result sau response
  approve thành công. Tên/loại/ETA lấy từ `LeaveRequestEntity`; copy không nói phụ
  huynh đã nhận thông báo hoặc check-in đã đồng bộ. Với báo trễ, ETA được ghi rõ là
  dự kiến, giờ thực tế do giáo viên xác nhận.
- `teacher-timetable-gv.png` ↔ `454:931`: có class header, dải tuần/ngày, các hàng
  hoạt động và nav. `isReadOnly` vẫn khóa thao tác; cảnh báo xung đột được giữ.
  Nội dung capture là fixture, còn trạng thái “Đang diễn ra” trong app phụ thuộc
  đồng hồ thực.
- `parent-timetable-gv.png` ↔ `454:2287`: capture mở qua action Lịch học trong
  ParentFlow, hiển thị modal sheet chỉ xem và fixture schedule. Không có thao tác
  sửa/xóa/thêm; không dùng giờ/nội dung trong fixture làm dữ liệu production.
- Các capture xác nhận composition/state và không overflow ở viewport chuẩn; chưa
  là pixel sign-off. Không có Android emulator/thiết bị trong môi trường hiện tại.

### Review tổng thể Batch 1–3 — 2026-11-11 (chưa sửa finding)

**Phạm vi:** Teacher Shell tabs (Batch 1), parent surfaces (Batch 2), attendance
và timetable (Batch 3), cùng caller/test liên quan. Có thêm read-only review độc
lập; các finding dưới đây đã được đối chiếu lại với source/caller. Không thay đổi
code ứng dụng trong lượt review này. Chưa có finding Critical xác nhận được.

| Hạng mục audit | Điểm / 4 | Bằng chứng |
|---|---:|---|
| Accessibility | 2 | Có semantics và một số test chữ 200%, nhưng class tabs cao 37dp, nút ngày 32×32dp, status pill 28dp và chip ngày PH tối thiểu 36dp (<48dp Android); row có subtitle chưa được test ở scale 200%. |
| Performance | 3 | Danh sách lịch có cuộn; plant detail 2172×724 được decode cho vùng hiển thị nhỏ khoảng 47×65dp. |
| Appearance & theming | 2 | Token/scope dùng rộng, nhưng focused leave detail vẫn đọc A2 `State.context`; nav shell/edge/selected chưa trùng semantic colors từ node live. |
| Platform conformance | 3 | Có SafeArea/system back và Material controls; chưa thử gesture/touch trên Android thật, navigation custom theo frame GV. |
| Adaptivity | 2 | Có kiểm tra 320dp/200% cho một số trạng thái; row Attendance có subtitle cao hơn fixed 57dp, chưa có bằng chứng tablet/landscape/emulator. |
| **Tổng** | **12/20 — Acceptable** | Điểm chỉ áp dụng cho phạm vi 3 batch và các giới hạn xác minh nêu trên; không phải điểm toàn ứng dụng. |

**Findings giữ lại cho lượt fix sau (theo yêu cầu, chưa sửa):**

### P1 · Cần xử lý trước sign-off

1. **Attendance có thể trình bày bản ghi chưa xác minh như đã đến.**
   `attendance_screen.dart:96–117,274–306` giữ fallback từ roster khi GET lỗi/rỗng
   hoặc thiếu một trẻ trong ngày đã chọn; `child_adapter.dart:21` mặc định
   `present: true`. `_fetchLatest` nuốt lỗi/không phân biệt rỗng và UI vẫn hiện
   “Đã cập nhật”. Không suy ra trạng thái từ roster chung.
2. **Giờ báo cáo có thể bị trình bày thành giờ đến thực tế.**
   `attendance_screen.dart:871–879` fallback `student.time` khi thiếu `checkInTime`;
   `child_adapter.dart:36–45` tạo `student.time` từ report `updatedAt`. Chỉ check-in
   của ngày đang xem mới được gọi là giờ đến thực tế.
3. **Lưu điểm danh có thể xóa check-in đã có.**
   `http_attendance_repository.dart:158–165` luôn gửi `check_in_time: null`, còn
   `backend/app/api/endpoints/attendance.py:207–216` upsert giá trị đó vào bản ghi
   hiện có. Đổi một status có thể làm mất timestamp các trẻ khác trong batch. Đây
   là lỗi hợp đồng sẵn có, không phải sửa backend trong batch UI; cần regression test
   persistence ở lượt fix riêng.
4. **Summary tính đơn báo trễ chưa check-in là đã đến.**
   `attendance_screen.dart:132–137` tính arrived bằng tổng trừ absent/excused; API
   tạo `late` record với `check_in_time == null` cho đơn được duyệt tại
   `backend/app/services/attendance_sync_service.py:27–71`. Vì thế “bé đã đến lớp”
   có thể khẳng định quá mức; tách “dự kiến đến” khỏi check-in đã xác nhận.
5. **Điều hướng khỏi Attendance bỏ qua confirm discard/đang lưu.**
   `teacher_shell.dart:332–343,403–424` pop trực tiếp khi bấm class/global navigation;
   `attendance_screen.dart:322–325` chỉ bảo vệ đường Back qua `PopScope`. Flutter
   `Navigator.pop` là imperative pop, không đi qua `maybePop` disposition; đường
   điều hướng trực tiếp có thể bỏ draft không hỏi.
6. **Route class sibling tích lũy và CTA có thể trở lại màn sai.**
   `teacher_shell.dart:302–307,338–343,371–400` push timetable/attendance/leave
   request lồng nhau; global navigation chỉ pop route trên cùng. Cần thống nhất
   owner/stack của class tabs và bảo toàn discard guard.
7. **CTA result có thể mở điểm danh hôm nay thay vì ngày đơn.**
   `leave_request_review_screen.dart:919–929` khi mở focused detail không truyền
   `onOpenAttendanceForDate`; `teacher_notifications_screen.dart:188–203` cũng chỉ
   truyền `onOpenAttendance`. `Về Điểm danh` vì vậy fallback sang hôm nay ở các
   entry này. Test date hiện khởi tạo detail trực tiếp nên chưa bắt list/notification
   → detail → approve → ngày yêu cầu.

### P2 · Hành vi, nội dung và parity

8. **Row điểm danh có thể overflow khi scale 200%.** Row bị cố định 57dp
   (`attendance_screen.dart:494–500`) trong khi tên + subtitle check-in/ETA ở 200%
   cần khoảng 72dp; test hẹp hiện không truyền `checkInTime`/ETA. Cho row tăng chiều
   cao và test trạng thái có subtitle.
9. **History dùng timestamp fallback không có bằng chứng event.**
   `teacher_tabs.dart:550–562` lấy `student.time` rồi literal `08:00` nếu thiếu
   publish/report time; `student.time` có thể là `updatedAt` của báo cáo khác.
   `:591–596` còn cho `attention` của draft vào filter `Đã gửi`. Dùng domain status
   riêng cho filter và lược bỏ giờ không có nguồn.
10. **Account giáo viên có thể hiện tên trường demo.**
    `teacher_account_screen.dart:26,279` mặc định `Mầm non Hoa Hướng Dương`, trong
    khi production `TeacherShell` không truyền school name. Cần lấy từ repository
    hoặc bỏ khi thiếu; capture hiện truyền fixture tường minh.
11. **Back-button test cũ làm suite CI đỏ.**
    `push_open_attendance_test.dart:269` tìm tooltip `Quay lại` của AppBar A2 không
    còn trong frame GV; lỗi tái hiện. Cập nhật test theo class navigation/system
    Back, không thêm affordance ngoài Figma chỉ để thỏa test cũ.
12. **Hit area nhỏ hơn chuẩn Android 48dp.** Class tabs cao 37dp; ngày điểm danh
    32×32dp; status dropdown 28dp; ngày PH 36dp. Giữ artwork gọn nhưng mở rộng vùng
    chạm.
13. **Một số điểm parity Batch 1/3 còn khác Figma.**
    `garden_voice_teacher_navigation.dart:45–48,152` đang dùng `surface`/`line`/
    `brandTint` thay vì colors `#F1F7F6/#B5D4CE/#CBE9DE` của node live. Focused
    leave detail còn resolve A2 colors qua `State.context` ở helpers
    `leave_request_review_screen.dart:475,721–756`.
14. **Search clear không xóa text trong ô.**
    `attendance_screen.dart:456–474` chỉ đặt `_query = ''` nhưng không cập nhật
    controller; list lọc reset trong khi query cũ vẫn hiện.
15. **Parent report sheet còn khác composition.**
    `parent_screens.dart:610,707–711`: capture là content-height sheet phủ overview,
    còn `454:2216` gần full-height với grouped activity card và CTA ghim đáy. Giữ
    dữ liệu arrival/event thiếu ở trạng thái lược bỏ.

**Đường capture chưa chứng minh route parity:** Batch 1 dùng Scaffold/fixture dựng
trực tiếp; attendance/timetable capture pump screen riêng với scope giả lập; approval
capture dùng fake repository và không đi qua mọi entry list/notification. Parent
timetable có đi qua ParentFlow. Passing capture chưa phủ các navigation finding trên.

**Khác biệt thị giác đã biết từ Batch 1–2, chưa sign-off:** Parent inbox đặt action
“Đánh dấu đã đọc” dưới title thay vì cùng hàng; report PH là sheet thấp thay vì frame
gần full-screen; account hero thấp hơn và không dựng nhắc giờ; contact editor,
relationship selection, child detail sheet và health profile khác composition/state
như mô tả từng node ở trên. Các khác biệt liên quan dữ liệu thiếu được giữ có chủ ý.

**Lượt xác minh 2026-11-11:** `flutter analyze` — No issues found; 12 bộ test liên
quan chạy chung **89/90 pass** (một lỗi tooltip cũ nêu trên); capture suite
`figma_request_layout_test.dart` **34/34 pass**, ghi 5 ảnh Batch 3; `impeccable
detect --json` trả `[]`; `git diff --check` không báo whitespace error. `flutter
devices` chỉ có Windows/Chrome/Edge, không có Android emulator. Chưa chạy full
Flutter suite hoặc xác minh backend/PostgreSQL/FCM/thao tác gesture trên thiết bị.

Các fixture này được viết để kiểm tra layout/hành động, **chưa đồng nhất nội dung
và mọi slot với Figma live**. Những screen được pump riêng không có đủ shell/nav
như app thật. Khi nghiệm thu cả màn, capture cả shell liên quan và bổ sung state
thiếu; không coi một capture widget con là ảnh toàn màn đã đạt.

CI chạy nhóm layout này và upload PNG thành artifact `flutter-ui-captures`.
Job không tự sửa hoặc duyệt ảnh. Test/assertion fail vẫn làm CI fail; ảnh còn tạo
được giúp xem lỗi. Khi thay UI khác nhóm này, chạy test màn tương ứng và bổ sung
capture đúng màn thay vì chỉ dựa vào nhóm request.

## Lượt đối chiếu Figma

1. Đọc context và screenshot **mới** của node trong [FIGMA-MAP.md](FIGMA-MAP.md).
   Nếu connector trả context thưa, lấy các child node nhìn thấy trước khi sửa.
2. Ghi viewport, DPR, scale, insets, theme, locale, ngày giờ và dữ liệu. Chọn cùng
   state/scroll offset; phân biệt shell, dialog, bàn phím và system bars.
3. Chụp app sau khi font/ảnh đã load. Kiểm tra cùng tỉ lệ hoặc overlay hai ảnh;
   không kéo giãn screenshot để làm layout có vẻ khớp.
4. Kiểm tra geometry trước: gutter, baseline chữ, khoảng cách, width/height,
   radius, border, vùng cuộn, CTA cố định. Sau đó kiểm tra font/weight/line height,
   màu, asset, icon và nội dung. Asset đúng file nhưng bị méo vẫn là sai khác.
5. Thử tương tác vào/ra màn, loading/empty/error/disabled có liên quan. Kiểm tra
   320dp, chữ 200%, bàn phím với form; không ép chúng giống ảnh 390×844 bằng cách
   tắt scaling hoặc che overflow. Dark là lượt kiểm tra riêng khi có scope.
6. Sửa sai khác trong phạm vi task rồi chụp lại. Nêu riêng sai khác ngoài phạm vi,
   thiếu asset hoặc state chưa có thiết kế; không báo “pixel-perfect” khi chưa xem ảnh.

## Đối chiếu Batch 5 — 2026-11-11

- Đã đọc cặp context + screenshot + variables live cho 11 frame Batch 5 và đối
  chiếu các capture `teacher-*-gv.png` trong `frontend/build/ui-captures/` ở
  390×844, DPR 1, light, locale `vi`; ảnh là widget capture, không phải emulator.
- `teacher-login-gv.png`, `teacher-no-assignment-gv.png`,
  `teacher-change-password-gv.png`, `teacher-bug-report-gv.png`,
  `teacher-child-actions-gv.png` và `teacher-report-editor-gv.png` đã được xem
  trực tiếp. Login dùng đúng Be Vietnam Pro/KL Warm Sage và illustration local;
  remember/reveal controls được giữ vì thuộc luồng hiện có.
- Recorder permission/error dùng SVG local và dialog đúng node. `Mở cài đặt` gọi
  URL scheme `app-settings:` qua `url_launcher`; chưa xác minh handler trên Android
  thật. Các capture không mô phỏng microphone phần cứng.
- Review classwide chỉ gửi sau thao tác duyệt; trang Done đặc biệt chỉ hiện khi
  item cả lớp còn approved và mọi report ID của item được `sendBatch`/fallback
  xác nhận sent hoặc skipped. Kết quả một phần giữ màn Review, ghi nhớ ID đã gửi
  để lần thử sau chỉ gửi ID thất bại. Capture dùng repository giả. Sau khi bỏ qua,
  copy trích transcript fixture và gửi chỉ bật khi item còn lại đã duyệt. Không
  dùng dữ liệu trẻ thật.
- Test kiểm tra màn hẹp 320dp và chữ 200% cho Login, NoAssignment,
  ChangePassword, ReportEditor và BugReportSheet. Dark mode không có frame mục tiêu
  trong batch nên chưa tuyên bố khớp.
- Sai khác còn lại có chủ đích: Login giữ checkbox nhớ/eye toggle dù frame không
  vẽ; password form giữ eye toggles; BugReport capture không có ảnh đính kèm nên
  không dựng thumbnail mẫu; classwide có bước “Duyệt tất cả” trước CTA để không
  tự duyệt ngầm. Đây là đối chiếu bằng mắt, chưa phải pixel-diff hoặc thiết bị sign-off.
- Xác minh cuối 11/11/2026: `flutter analyze` không có issue; capture suite **40/40**;
  `garden_voice_batch5_layout_test.dart` **13/13**; `impeccable detect --json`
  trả `[]`. Full `flutter test` **385 pass / 9 fail**; 9 lỗi còn lại thuộc các test
  ParentFlow, push-open report/attendance và teacher medication (xem ledger), không
  phải test Batch 5. `git diff --check` không báo whitespace error; Git chỉ cảnh báo
  line ending LF→CRLF ở các file dirty sẵn. Chưa xác minh `app-settings:` hoặc mic
  thật trên Android; timeout sau khi server commit nhưng trước khi client nhận kết
  quả vẫn có thể làm fallback publish gửi lại report (cần idempotency/status API).

## Khi thêm golden regression

Dùng matcher có sẵn trong `flutter_test`, không cần thêm thư viện chỉ để so ảnh:

```dart
await expectLater(
  find.byKey(const ValueKey('capture')),
  matchesGoldenFile('goldens/ten_man_light.png'),
);
```

Đây là mẫu cho test màn sau khi chốt baseline, chưa phải golden đã được thêm vào
suite. Bọc đúng RepaintBoundary, nạp font, cố định dữ liệu/clock/insets và giữ ảnh
trong `frontend/test/goldens/`. Ảnh Figma tham chiếu và ảnh Flutter golden là hai
nguồn riêng: golden được duyệt sau khi đối chiếu, không tự lấy screenshot Figma
làm ảnh baseline để đòi rasterizer khác nhau phải giống từng pixel.

### Garden Voice Batch 4 — Medication & Emergency (2026-11-11)

- Đã đọc context/screenshot/variables cho 11 node trong file
  `9RurF0HiJlYLVDV7ljp2bH`; capture Flutter ở 390×844, DPR 1, light, locale `vi`,
  Garden Voice scope, fixture repositories. PNG nằm trong
  `frontend/build/ui-captures-batch4/`.
- `parent-medication-m1-gv.png` ↔ `454:2925`; M2 `parent-medication-m2-gv.png` ↔
  `454:2969`; M3 `parent-medication-m3-gv.png` ↔ `454:3026`; M4/M5
  `parent-medication-m4-gv.png` / `parent-medication-m5-gv.png` ↔ `454:3046` /
  `454:3084`. M3 dùng SVG success xuất từ node; M2 fixture để trống, không dùng
  dữ liệu mẫu Figma làm nội dung production; nút gửi ghim dưới scroll và regression
  xác nhận nó vẫn nằm trên bàn phím ở 320dp/chữ 200%.
- `teacher-medication-m6-gv.png` / `teacher-medication-m7-gv.png` ↔ `454:1384` /
  `454:1445`. M7 chỉ xuất hiện sau mutation và canonical reload `given`; `givenAt`/
  `givenByName` thiếu thì UI nói rõ là thiếu, không tự thêm thời điểm/actor hoặc báo
  phụ huynh đã nhận push. App giữ filter buổi/nhãn nhóm và CTA báo sự cố đã có, nên
  khác flat list trong frame M6; nav component hiện tại cũng còn màu nền/viền/selected
  khác các variables live của Figma (xem COMPONENT-MAP §Garden Voice).
- `teacher-emergency-m8-gv.png` / `teacher-emergency-m9-gv.png` ↔ `454:1487` /
  `454:1532`. M8 giữ field nhiệt độ tùy chọn dù frame không có field này; danh bạ
  chỉ gồm contact API trả về (fixture capture có một phụ huynh, không dựng Ban giám
  hiệu). M9 ghi “Đã lưu biên bản sự cố” và nêu chưa xác nhận giao FCM; các hàng
  `đã gửi thông báo` trong Figma không được coi là receipt backend.
- `parent-emergency-alert-gv.png` ↔ `563:1649`. Payload không có tên lớp nên capture
  bỏ dòng lớp. Còi được disable trong widget capture; các test xác nhận dismiss/header
  back xử lý callback và dừng còi. `563:1667` không capture: node là mock trình gọi
  điện ngoài app; test kiểm tra `url_launcher` nhận URI `tel:`. Chưa xác minh gọi điện
  hoặc phát/dừng còi trên Android thiết bị thật.
- Đã xem cả 10 PNG và screenshot Figma: composition chính, hierarchy, CTA, assets
  M3/M7/M8/M9 và trạng thái khóa liều đều rõ; đây là review định tính, không phải
  pixel diff/sign-off. Range date dùng en dash thay cho ký tự `→` vì font Nunito local
  render ký tự đó thành ô vuông. Capture dates/creator names là fixture, không phải
  dữ liệu production.
- Xác minh: `flutter analyze` — No issues found; `parent_medication_test.dart`
  16/16; `teacher_medication_flow_test.dart` 11/11;
  `teacher_emergency_test.dart` 18/18; `emergency_alert_listener_test.dart` 11/11;
  capture suite `figma_request_layout_test.dart` 39/39. Không chạy full Flutter test
  suite, không có Android emulator/thiết bị hoặc backend/FCM thật trong lượt này.

```powershell
# Chỉ tạo/cập nhật trên môi trường golden chuẩn sau khi review diff thiết kế.
flutter test --update-goldens test/ten_man_golden_test.dart
flutter test test/ten_man_golden_test.dart
```

Tên `ten_man_golden_test.dart` là ví dụ, thay bằng test thật của task. CI chỉ chạy
so sánh; không chạy `--update-goldens`. Không tăng tolerance hoặc bỏ vùng ảnh để
che một thay đổi bố cục chưa giải thích. Thay SDK/font cần review lại baseline.
Xem [Flutter matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html).

## Bằng chứng trong kết quả task / PR

### [Fix][Login Screen] Sửa layout mật khẩu và màu gợi ý — 12/11/2026

- Branch `fix/flutter-ui-review`, Figma live `496:3859` (390×844), đọc metadata,
  context, screenshot và variables. Các ô `496:3869/3872` cao 58dp; nhãn demo
  `496:3882/3884` không có fill riêng, khung ngoài `496:3879` vẫn nền `#F7FBFA`.
- `screens/auth_screens.dart`: đưa icon mắt sang cạnh cả nhãn + input thay vì
  `suffixIcon` dưới nhãn. Test tái hiện ô cũ cao 79dp; sau sửa hai ô cao 58dp ở
  chữ thường, icon có vùng bấm 48×48dp và căn giữa. Chiều cao vẫn tự giãn khi
  chữ lớn; không ép `TextScaler` hay bỏ hiện/ẩn mật khẩu.
- Hint rỗng dùng `context.k.inkFaint`, weight 400 theo yêu cầu, khác chữ nhập
  weight 600. Test kiểm tra tương phản ít nhất 4.5:1 trên nền input. Figma đang
  có dữ liệu điền sẵn, không cung cấp state hint riêng.
- Bỏ fill riêng của hai nhãn demo; min-height 44 thay fixed-height để không cắt
  chữ ở 200%. Giữ nhãn tĩnh hiện có, không thêm demo-login/credential.
- Ảnh trước: `frontend/build/ui-captures-login-before/teacher-login-gv.png`.
  Ảnh sau: `frontend/build/ui-captures-login/teacher-login-gv.png`,
  `login-empty-390.png`, `login-empty-320.png`, `login-keyboard-390.png`,
  `login-keyboard-320.png`. Đã xem ảnh có dữ liệu, hint rỗng và keyboard/chữ 200%.
  Render bằng widget test Windows, Flutter 3.47.5, font local BeVietnamPro;
  keyboard mô phỏng inset 300dp. Không cài/chạy bản sửa lên Android thật.
- `flutter analyze`: No issues found; capture login 390dp/320dp + Batch 5:
  3/3 pass; test geometry/hint mới: 2/2 pass. Ba file
  `garden_voice_batch5_layout_test.dart`, `remember_login_test.dart`,
  `figma_request_layout_test.dart` chạy cùng: **77/77 pass**; detector layout:
  `[]`. Full `flutter test --no-pub`:
  **391 pass / 9 fail** ngoài login, giữ nguyên assertions và test hiện có:
  - `login_and_parent_test.dart`: `ParentFlow opening report marks it as read and displays Đã đọc status badge`;
    `ParentFlow clicking logout shows confirmation popup and handles Cancel/Logout`;
    `ParentFlow displays timetable action and navigates to TimetableScreen`.
  - `push_open_report_test.dart`: `mở đúng báo cáo cũ của bé thứ hai thay vì báo cáo hôm nay`;
    `initialOpenReport = true mở thẳng báo cáo hôm nay`;
    `chạm thông báo khi màn phụ huynh đang mở vẫn mở báo cáo`.
  - `push_open_attendance_test.dart`: `nhắc điểm danh đợi dữ liệu rồi mở đúng lớp/ngày và danh sách bé`.
  - `teacher_medication_test.dart`: `Bấm 1-chạm xác nhận gọi API và cập nhật trạng thái`;
    `Hiển thị form báo sự cố và phát cảnh báo thành công`.
- Chưa sửa các lỗi ngoài login, chưa sign-off pixel toàn màn (subtitle vẫn khác
  line-wrap Figma, mật khẩu dùng glyph/input thực và giữ icon mắt). Không thay
  theme toàn app, asset, nghiệp vụ hoặc golden; không cần restart/rebuild Docker.

### [UI][Bottom Navigation] Khớp navigation theo vai trò — Batch A, 12/11/2026

**Đã triển khai layout, chờ người dùng duyệt ảnh; dừng trước Batch B.** Không sửa
Figma, route, trạng thái tab, action sheet/ghi âm, dependency hoặc golden. Giữ nguyên
các thay đổi Login có trước; chưa commit/push.

#### Đối chiếu nguồn → code

File Figma `9RurF0HiJlYLVDV7ljp2bH`; context/screenshot live đã đọc trong lượt này.

| Vai trò/state | Frame / navigation instance | Flutter |
|---|---|---|
| Teacher Home | `453:584` / `618:2046` | `GardenVoiceTeacherNavigation`, Home selected |
| Teacher Class | `564:1706` / `618:2203` | Wrapper trên, Class selected |
| Teacher Reports | `453:1389` / `618:2165` | Wrapper trên, Reports selected |
| Teacher Account | `454:827` / `618:2354` | Wrapper trên, Account selected |
| Parent Home | `454:1907` / `463:1701` | `GardenVoiceParentNavigation`, Home selected |
| Parent Notifications | `454:2048` / `464:1664` | Wrapper trên, Notifications selected |
| Parent Account | `454:2445` / `463:1828` | Wrapper trên, Account selected |

- `widgets/garden_voice_navigation.dart` dùng renderer chung, giữ enum/callback của
  từng wrapper. Auto Layout → Row gap 3, inset 6 (padding 5 + stroke trong 1), shell
  60dp, selected 48dp/radius 24, bottom 16dp + SafeArea một lần. Teacher shell radius
  30, 5 item bằng nhau; Parent shell radius 24, selected có border 1 và rộng hơn 2dp.
- `theme.dart` bổ sung token navigation riêng, không đổi `brandTint`; SVG local đã
  xuất lại 7 state sai fill (xem COMPONENT-MAP). Shell/edge/selected light lần lượt
  `#F1F7F6/#B5D4CE/#CBE9DE`; selected border Parent `#A1CFC0`.
- Live properties: shell **FIXED 362**, không min/maxWidth hoặc fill-container.
  Teacher constraints `MIN`, không có frame responsive >390dp để xác nhận alignment
  màn rộng. App giữ cách căn giữa sẵn có, max362, lề tối thiểu14; đây là adaptation
  của Flutter, **không phải quy tắc responsive do Figma chứng minh**. Kiểm tra
  geometry ở 320/390/412/480/768dp, capture thêm 412dp. Rộng 390dp: teacher item
  67.6dp; Parent selected 86.75dp, inactive 84.75dp.
- Parent Reports là action mở sheet; không có screen-instance Reports-selected để
  dùng làm target. Component `456:1754` khác radius/border screen-instance, không
  dùng nó ghi đè thiết kế màn. Các thuộc tính dark và quy tắc responsive từ designer
  ngoài 390dp: **chưa xác minh**. Shadow blur CSS/Figma/Flutter khác renderer nên
  chưa kết luận tương đương từng pixel.

#### Ảnh bàn giao

Thư mục local (git-ignored): `frontend/build/nav-batch-a/`.

- `compare-{teacher-home,teacher-class,teacher-reports,teacher-account,parent-home,parent-notifications,parent-account}.png`:
  Figma bên trái / Flutter bên phải, mỗi nguồn **390×844**, không scale pixel.
  `nav-compare-*.png` crop phần navigation cùng state để dễ duyệt. Đã xem đủ 7 crop;
  màu, pill, gap, inset và icon đúng state; shadow/raster vẫn có sai khác nhìn thấy.
  Dữ liệu/ngày/nội dung thân màn khác fixture, không tuyên bố cả màn pixel-perfect.
- `{teacher,parent}-home-{390,320,412,dark}.png`: widget capture Windows,
  Flutter 3.47.5, DPR1, locale vi, text1, font local; zero system insets. Dark capture
  390×844 chỉ chứng minh navigation đổi màu theo palette tối. Nền/body Garden Voice
  còn sáng do scope cũ; chưa có node dark để xác nhận thiết kế.
- `android-{teacher,parent}-320.png`: Android emulator API37/x86_64 (system image37.1),
  framebuffer 640×1688, density320 → viewport320×844 logical, gesture inset thực;
  navigation co còn292dp, không cắt icon. Preview `test/support/navigation_review_app.dart`
  dùng repository giả, không login/backend/FCM hoặc trẻ thật. Thân màn có khác biệt
  sẵn có ở320dp (hero Parent che một phần tên), ngoài phạm vi sửa navigation.
  Ảnh Parent có viền xanh bao viewport sau điều khiển bàn phím preview; không thuộc
  thiết kế navigation. Có thêm `android-*-dark-320.png`; không coi emulator là máy thật.
- Ảnh và JSON kết quả chỉ ở build local, không tự có trong git/CI artifact. Không
  đưa URL asset Figma tạm vào runtime. Chưa tạo golden hoặc nghiệm thu pixel.

#### Xác minh

```powershell
flutter analyze --no-pub
flutter test --no-pub test/garden_voice_navigation_layout_test.dart test/garden_voice_teacher_navigation_test.dart test/garden_voice_parent_navigation_test.dart test/garden_voice_theme_test.dart test/navigation_review_app_test.dart
flutter test --no-pub --dart-define=UI_CAPTURE_DIR=build/nav-batch-a test/figma_request_layout_test.dart --plain-name "Batch A navigation captures"
flutter test --no-pub --reporter json
flutter build apk --debug --no-pub --target-platform android-x64 -t test/support/navigation_review_app.dart
```

- Analyze: **No issues found**. Navigation/theme/preview: **21/21 pass**;
  Batch A capture: **8/8 pass**. Geometry/theme assertions mới đã thấy fail trước
  implementation rồi pass; kiểm tra 200% text, bottom inset24, touch target48.
- Full suite trước Batch A: **391 pass / 9 fail**; sau Batch A: **414 pass / 9 fail**,
  **không thêm lỗi**, không skip test. Đếm JSON loại sự kiện loading/hidden. Chín
  tên test lỗi giữ nguyên như danh sách Login ngay trên (3 ParentFlow, 3 push report,
  1 push attendance, 2 teacher medication/emergency). Log `build/batch-a-baseline.jsonl`,
  `build/batch-a-final.jsonl`; differential `build/nav-batch-a/test-differential.json`.
- APK preview build thành công và đã chạy trên emulator. Có warning toolchain cũ
  Gradle/AGP/Kotlin và `l10n.yaml` synthetic-package; không nâng toolchain trong batch.
- Review độc lập đã thử nhưng không chạy được do giới hạn quota; không nhận là đã
  được agent khác duyệt. Tự đọc diff và xem ảnh, vẫn cần người dùng duyệt hình.
- Chưa kiểm tra máy Android vật lý, backend thật, audio/push hoặc Batch B return
  context/motion. Chỉ thay Flutter/tài liệu: không cần restart/rebuild Docker;
  dừng app rồi bấm ▶ chạy lại để chắc asset SVG mới được nạp.

### [UI][Bottom Navigation] Motion và giữ ngữ cảnh — Batch B, 12/11/2026

**Batch A đã được người dùng duyệt trước khi bắt đầu Batch B.** Giữ geometry,
palette và SVG của từng vai trò đã duyệt; không sửa Figma, Login hoặc merge PR
teammate. Chưa commit/push. Hide/show chỉ pilot hai danh sách đã chốt, chưa nhân
rộng sang mọi màn có thanh điều hướng.

| Yêu cầu đã duyệt | Điểm triển khai / bằng chứng |
|---|---|
| Pill trượt ngang220ms/ease-out, retarget từ vị trí hiện tại | `garden_voice_navigation.dart`: một indicator `AnimatedPositioned` dùng chung; test cả hai vai trò bấm đổi đích2lần trước khi animation kết thúc, kết thúc đúng slot cuối |
| Icon cũ nhạt dần, icon mới teal | `TweenAnimationBuilder` crossfade hai SVG local, giữ ColorMapper theo theme; không nhuộm một màu lên toàn icon |
| Micro/Báo cáo là action, giữ tab nguồn | Teacher không pop màn con trước khi mở RecordHub; LeaveRequest bỏ pop kép. Parent vẫn mở report sheet, không đổi selected. Test root Micro, Micro từ Điểm danh (giữ cùng State instance), sheet PH và offset sau khi đóng |
| Vuốt lên ẩn xuống / vuốt xuống hiện lên,20dp | `GardenVoiceNavigationFrame`: tích lũy drag dọc cùng hướng, reset khi đổi hướng/đầu list/đổi tab; bỏ qua horizontal, programmatic, rebound; metrics list ngắn hiện thanh lại |
| Không dải trắng khi ẩn, không nhảy khi hiện | Pilot dùng Stack overlay; viewport giữ nguyên; padding76dp cuối nằm trong list, gesture inset tách riêng. Test tap tại y780 trong vùng thanh cũ, với inset24; test mục cuối cuộn lên trên thanh và bấm được |
| Giữ tab/filter/scroll | Lazy `IndexedStack` trong TeacherShell/ParentFlow; same-class refresh giữ cây đang mount; health filter không reset khi đổi tab. Parent subtree keyed bằng childId; regression đổi trẻ reset filter/scroll cũ |
| Reduced motion/trợ năng | DisableAnimations chuyển selected tức thời/bỏ micro scale và giữ thanh hiện; accessibleNavigation giữ thanh hiện. Hidden nav loại khỏi hit-test/focus/semantics; SDK3.47.5 IndexedStack tự ExcludeFocus cho tab ẩn, có test focus thực |

**Hai video local:**

- [Giáo viên — Lịch sử báo cáo](../../frontend/build/nav-batch-b/teacher-motion.mp4),
  MP4 H.264,780×1688, khoảng33.28giây.
- [Phụ huynh — Thông báo](../../frontend/build/nav-batch-b/parent-motion.mp4),
  MP4 H.264,780×1688, khoảng37.62giây.
- Quay Android emulator API37, density320 →390×844logical; fixture30báo cáo trong
  `test/support/navigation_review_app.dart`, không backend/FCM/login hoặc trẻ thật.
  Mỗi video có bấm nhanh nhiều tab, list dài vuốt lên ẩn/vuốt xuống hiện, đổi tab
  quay lại, mở/đóng action. Bản quay đầu khi app chưa nạp xong không dùng; bản bàn
  giao quay sau warm-up. `*-events.json` là mốc script, không timestamp tuyệt đối MP4.
- Đã giải mã cả2MP4 bằng Chrome local và xem frame mẫu2–28s cùng checkpoint PNG:
  teacher20s mở RecordHub; parent22s mở sheet/24s trở lại Notifications; các frame
  hidden có nội dung đến gesture inset và shown giữ viewport. Đây là kiểm tra frame
  mẫu, không đo hiệu năng máy thật hoặc tuyên bố mọi frame đạt60fps. SwiftShader/AVC
  có frame chuyển động mờ; PNG trực tiếp rõ hơn. Parent preview có contour xanh
  ngoài viewport sau keyboard role-switch, không thuộc navigation thiết kế.
- `frontend/build/nav-batch-b/README.md` có link video/giới hạn; `static/` giữ capture
  mới390/320/412/dark. Đã xem Home390/light/dark cả2vai trò; Dark vẫn chỉ navigation,
  chưa migrate nền toàn màn. Build/media bị git-ignore, không tự đi theo commit/CI.

**Kiểm tra cuối:**

- `flutter analyze --no-pub`: **No issues found**.
- Bảy file navigation motion/scroll/flow/layout + role wrappers + preview:
  **25/25 pass**. Nhóm8test capture Batch A chạy lại sau B: **8/8 pass**.
- Full `flutter test --no-pub --reporter json`: **422 pass / 9 fail / 0 skip**;
  baseline sau A **414 pass / 9 fail**; cùng9tên lỗi đã liệt kê ở mục Login,
  **không thêm lỗi**. Log `build/batch-b-final.jsonl`, differential
  `build/nav-batch-b/test-differential.json`. Hai regression shortcut từ overlay
  blanket đã được test bắt và sửa ở production, không đổi/skip assertions cũ.
- APK preview debug Android x64 build thành công và đã cài/chạy để quay video.
  Gradle/AGP/Kotlin vẫn có warning toolchain cũ, không nâng trong batch.
- Có review độc lập:3vấn đề được tái hiện RED→GREEN (refresh mất State, filter bị
  reset, đổi trẻ giữ state cũ). Lo ngại focus đã đối chiếu SDK và test: IndexedStack
  hiện có ExcludeFocus, không thêm wrapper trùng. Thêm test Micro từ màn con và
  identity source; không có lượt re-review sau fix, dùng regression + full suite.
- Chưa kiểm tra Android vật lý/TalkBack thủ công/audio/push thật. Không merge
  `origin/develop` vì PR22file còn cần tích hợp riêng theo quyết định giữ Login và
  navigation local; chi phí là chưa chứng minh tương thích với PR mới đó.
- Flutter bấm ▶ chạy lại; không cần restart/rebuild Docker.

### [Fix][Android Navigation] Tạm khóa Light, đối chiếu qua main.dart — 12/11/2026

Người dùng báo video preview đúng nhưng app chạy main.dart đổi nền navigation và
không có motion; **chưa nghiệm thu Batch B trên Android người dùng**. Yêu cầu mới
ưu tiên: bỏ Dark khỏi UI trước, không tự thiết kế hoặc bật nền tối chưa duyệt.

- Tái hiện bằng test **MyApp thật + router /parent + repository HTTP production**,
  chỉ mock biên HttpClient: preference Dark + platformBrightness Dark làm nav dark.
  Test này RED trước sửa. `main.dart` nay bỏ darkTheme/cố định Light; controller bỏ
  áp Dark/System cũ và không cho chọn, selector chỉ Sáng; sau sửa GREEN. Không xóa
  preference cũ hoặc palette/test legacy, không sửa authentication/router/API.
- Test motion qua cùng MyApp/router **pass cả trước sửa theme**: pill có vị trí
  trung gian80ms rồi về slot Notifications; vuốt lên ẩn, xuống hiện; viewport tới
  bottom844. Vì vậy **không kết luận đổi theme sửa được lỗi motion trên máy thật**.
  Đã thêm dòng log debug-only ở cold start main: entrypoint,Light,disableAnimations,
  accessibleNavigation; không token/user/audio. Chưa có thiết bị ADB để đọc flag
  thực tế, không ép bỏ qua trợ năng để làm giống video.
- Ảnh `frontend/build/nav-main-runtime/main-parent-{before,moving-80ms,selected,hidden,shown}.png`
  là390×844 widget capture, font local, zero systeminsets, JSON giả30report. Đã xem
  before/80ms/hidden; có pill đang trượt và list dùng vùng đáy. Không phải video
  bản Android thật và khác data/insets so với MP4. Không dùng preview làm bằng
  chứng thay thế app đăng nhập qua main. README trong thư mục ghi chính xác phạm vi.
- Build `flutter build apk --debug --no-pub --target-platform android-arm64,android-x64 -t lib/main.dart`
  thành công; file output hiện là **entrypoint main**, không preview. Chưa cài/test
  bản này trên máy Android người dùng. Toolchain có warning cũ, không nâng trong fix.
- Test theme selector cũ từng đòi description Dark/System đã được đổi thành assertions
  **không được xuất hiện**, theo yêu cầu Light-only; giữ nguyên các check khác,
  không skip hoặc xóa test. Chạy 3test main/runtime và capture tabs/theme liên quan.
- Sau sửa cần **Stop app rồi Run main.dart lại**, không chỉ Hot Reload vì có init/
  singleton preferences. Chỉ Flutter, không cần restart/rebuild Docker; chưa merge/
  commit/push. Motion Android vẫn cần xác minh trực tiếp trước khi báo hoàn tất.
- Xác minh cuối: `flutter analyze --no-pub` không issue; 3test root/runtime + test
  capture tabs/theme liên quan **4/4 pass**. Full **425 pass / 9 fail / 0 skip**,
  cùng9lỗi baseline422pass/9fail, không thêm lỗi. Differential trong
  `build/nav-main-runtime/test-differential.json`; `git diff --check` không lỗi
  whitespace. Lượt analyze đầu timeout khi build/test chạy song song; lượt chạy
  riêng sau sửa lint test đã sạch, không bỏ qua check.

### [Fix][Bottom Navigation] Bật auto-hide trên Tổng quan và các tab chính

- Người dùng xác nhận màn không ẩn là **Tổng quan**. Samsung đã kết nối ADB;
  log main báo `disableAnimations=false`, `accessibleNavigation=false`, animation
  scales1.0. Không phải giả định máy tắt animation: nguyên nhân code là Teacher
  `autoHide: tab == TeacherTab.history`, Parent `autoHide: _notificationsOpen`.
  Hai cờ giới hạn pilot đã bị mình báo hoàn tất quá rộng so với trải nghiệm người dùng.
- Sửa nhỏ ở hai shell: bật auto-hide cho mọi tab chính. Bổ sung3regression test:
  Teacher/Parent Overview và MyApp/router Overview. Đã thấy cả3RED (viewport640
  bị chặn còn564), sau sửaGREEN: viewport640, drag ẩn/hiện, không đổi rect khi
  thanh dịch ra/vào. Reuse cơ chế hit-test y780 với gesture inset24 và last item
  bấm được ở phía trên nav; không tạo dải trắng76dp cố định ngoài list.
- Hai test shortcut trên Overview dùng `scrollUntilVisible` không tính vùng nav nổi
  đã được cập nhật thêm ensureVisible(alignment.5) và assertion **hitTestable** trước
  khi tap. Giữ toàn bộ assertion nghiệp vụ; không tắt cảnh báo hay skip test.
- Phạm vi: Teacher Tổng quan/Lớp/Báo cáo/Tài khoản; Parent Tổng quan/Thông báo/
  Tài khoản. Màn con có Scaffold/nav riêng không được báo là đã rollout trong fix này.
  List ngắn không thực sự cuộn vẫn giữ thanh hiện; Dark tiếp tục tắt theo quyết định mới.
- `flutter analyze --no-pub`: không issue. Nhóm runtime/flow/scroll/notifications
  **28/28 pass**; full **428 pass / 9 baseline fail / 0 skip**, cùng9tên lỗi đã liệt
  kê, không thêm lỗi. Log `build/overview-navigation-final.jsonl`; differential
  `build/nav-main-runtime/overview-test-differential.json`.
- Build debug ARM64 từ **lib/main.dart** thành công; đã cài bằng `adb install -r`
  lên Samsung đang kết nối (Success), không uninstall/clear-data; đã gọi mở app.
  Ảnh debug thiết bị chỉ ở thư mục Temp, không dùng dữ liệu thật làm fixture/commit.
- **Chưa nghiệm thu cuộn trực tiếp trên Samsung:** các ảnh kiểm tra ban đầu là
  AOD/home; sau cài bản mới, người dùng chọn **Tôi tự kiểm tra**, nên đã dừng thao
  tác trên điện thoại. Không coi việc install thành công là native acceptance.
  Không quay video thay thế hoặc tuyên bố đã kiểm tra tay khi chưa có bằng chứng.
- Không cần restart/rebuild Docker; APK mới đã cập nhật. Chưa merge/commit/push.

Ghi node + state đã dùng, screenshot Figma/app, môi trường render, lệnh kiểm tra
và kết quả, sai khác còn lại. Nếu chỉ chạy analyze/test mà chưa xem ảnh, ghi đúng
giới hạn đó. Không tạo tracker riêng cho task: commit/PR vẫn theo title trong
AGENTS.md; các tài liệu này là hợp đồng bàn giao thiết kế dùng lâu dài.
