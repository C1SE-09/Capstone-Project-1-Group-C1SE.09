# AGENTS.md — Flutter UI theo Figma

Mục tiêu: triển khai đúng màn hình và trạng thái được giao, giữ đúng thiết kế,
đồng thời dùng lại kiến trúc và widget Flutter của KinderLog.

## Đọc trước khi sửa UI

1. `../design-system/kinderlog/FIGMA-MAP.md`: nguồn Figma, node, màn/code/test.
2. `../design-system/kinderlog/MASTER.md`: baseline hiện tại và chênh lệch đã biết.
3. `../design-system/kinderlog/COMPONENT-MAP.md`: widget, variant, font và asset.
4. `../design-system/kinderlog/VISUAL-QA.md`: môi trường render và kiểm tra ảnh.
5. `../.agents/rules/figma-mcp-workflow.md`: gọi Figma MCP (bóc tách node,
   thu thập kép, bảng đối chiếu, map Auto Layout → Flutter).
6. `../.agents/rules/flutter-design-system.md`: token và widget bắt buộc tái dùng.

## Ưu tiên nguồn

- Yêu cầu và quyết định hiện tại của người dùng đứng đầu.
- Với giao diện, frame/node cụ thể được giao cùng context, variables và screenshot
  vừa đọc từ Figma là mục tiêu. Không chọn một trang concept chỉ vì có số lớn hơn.
- `MASTER.md` ghi những gì Flutter đang dùng; không dùng baseline cũ để ghi đè
  Figma hiện tại. Chênh lệch giữa hai bên phải được nêu rõ trong kết quả task.
- Nghiệp vụ, phân quyền và dữ liệu theo domain/repository/API hiện có. Chữ demo
  trong thiết kế không phải bằng chứng API đã gửi push, thu tiền hoặc lưu dữ liệu.
- Prompt Make cũ và audit có ngày trong `docs/design/` là lịch sử tham khảo.
  Không lấy palette, font hoặc layout của chúng thay cho node được giao.

## Trước khi implement

- Xác định file key, node ID và state từ link được giao hoặc `FIGMA-MAP.md`.
  Nếu task chưa rõ màn nào, chỉ hỏi phần định danh còn thiếu; vẫn rà code được.
- Dùng Figma connector theo `figma-mcp-workflow.md`: link Page/Section hoặc lỗi
  "nothing selected" → `get_metadata` trước để lấy FRAME/COMPONENT/INSTANCE con;
  mỗi frame gọi song song design context + screenshot. Nếu context quá thưa,
  đọc các child node nhìn thấy; không đoán thông số từ tên.
- Lập bảng đối chiếu Figma ↔ code hiện tại ↔ token/widget trước khi sửa `.dart`.
- Kiểm tra variables, typography (family/weight/size/line height/letter spacing),
  component variants, vùng cuộn, vùng cố định, clipping và SafeArea.
- Đọc `theme.dart`, `widgets.dart`, widget chuyên biệt, router và test của màn.
  Mở rộng component có sẵn khi phù hợp; không sao chép nguyên code React/Tailwind
  từ Figma vào Flutter. Không thêm dependency khi khả năng hiện có đã đáp ứng.
- Frame 390×844 là kích thước thiết kế, không phải lý do hardcode toàn bộ vị trí.
  Dùng Row/Column/Flex/constraints; Stack chỉ cho thành phần cần chồng lớp.

## Khi sửa code

- Màu lấy qua `context.k`; spacing/radius dùng token hiện có (`KSpace`, `KRadii`,
  `context.k.buttonRadius`) khi khớp thiết kế; widget dùng chung xem
  `flutter-design-system.md`.
  Nếu token không khớp, ghi rõ phạm vi thay đổi. Sửa theme chung phải kiểm tra các
  màn dùng nó; không đổi toàn app chỉ để sửa một khác biệt cục bộ.
- Không tự thêm global font size hoặc font family chưa kiểm chứng. `fontSize`
  cơ sở vẫn scale theo hệ thống; không khóa `TextScaler` để ép giống screenshot.
- Giữ đúng nội dung tiếng Việt, kiểu chữ, thứ tự, hình ảnh và trạng thái của node.
  Icon/ảnh riêng trong thiết kế cần asset local đúng nguồn, tỉ lệ và vị trí;
  không thay bằng emoji hoặc Material icon gần giống. Ảnh dữ liệu vẫn là dữ liệu.
- Không dùng screenshot toàn màn làm giao diện, không để URL asset Figma tạm
  trong runtime. Khai báo asset/font local trong `pubspec.yaml` khi thêm mới.
- Dữ liệu giả chỉ nằm trong test/preview. UI production lấy số lượng, trạng thái
  và hành động từ repository; giữ loading/empty/error/disabled theo luồng hiện có.

## Kiểm tra và bàn giao

- Chạy `flutter analyze` và test phù hợp; với thay đổi UI chạy thêm capture theo
  `VISUAL-QA.md`. So ảnh app và Figma cùng viewport/state/content/insets.
- Kiểm tra layout ở 390×844 và màn hẹp 320dp, chữ 200%, bàn phím khi có form.
  Đối chiếu light với Figma; dark chỉ tuyên bố khớp khi đã có node dark mục tiêu.
- Golden chỉ được tạo sau khi ảnh app đã được review đối chiếu Figma; không chạy
  `--update-goldens` để che một diff chưa được giải thích.
- Báo rõ node đã dùng, file sửa, lệnh/kết quả kiểm tra, ảnh và sai khác còn lại.
  Nếu chưa xem ảnh render, nói rõ chưa xác minh bằng mắt; analyze xanh chưa đủ.
- Cập nhật mapping/component/asset khi thay đổi liên quan. Không sửa file Figma
  khi task chỉ yêu cầu implement code. Không dùng dữ liệu trẻ thật làm fixture.
- Flutter: bấm ▶ để chạy lại; đổi font/asset có thể cần dừng rồi chạy lại app.
  Chỉ sửa Flutter/tài liệu không cần restart hoặc rebuild Docker.
