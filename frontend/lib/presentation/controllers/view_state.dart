// frontend/lib/presentation/controllers/view_state.dart
// =========================================================
// Trạng thái chung khi tải dữ liệu từ repository.
//
// View sẽ dựa vào enum này để quyết định hiển thị:
//   loading → vòng xoay
//   error   → thông báo lỗi + nút thử lại
//   success → nội dung chính

enum ViewState {
  loading, // đang tải dữ liệu từ repository
  success, // tải xong, có dữ liệu
  error, // tải lỗi
}