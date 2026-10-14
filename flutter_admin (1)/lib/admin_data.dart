import 'models.dart';

const dayLabels = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6'];
const availableClasses = [
  'Lớp Mầm A',
  'Lớp Mầm B',
  'Lớp Chồi A',
  'Lớp Chồi B',
  'Lớp Lá 1',
  'Lớp Lá 2',
];
const availableRooms = [
  'Phòng tạo hình',
  'Phòng âm nhạc',
  'Phòng học Mầm A',
  'Phòng học Mầm B',
  'Sân chơi ngoài trời',
  'Phòng ăn lớn',
  'Phòng ngủ Mầm A',
  'Vườn trường',
  'Phòng Stem',
];

const initialTeachers = [
  Teacher(id: 't-1', name: 'Cô Nguyễn Thị Mai', classes: ['Lớp Mầm A', 'Lớp Chồi B'], phone: '0987 654 321', email: 'mai.nguyen@kinderlog.edu.vn', role: 'Giáo viên chủ nhiệm'),
  Teacher(id: 't-2', name: 'Cô Trần Thị Lan', classes: ['Lớp Mầm B'], phone: '0912 345 678', email: 'lan.tran@kinderlog.edu.vn', role: 'Giáo viên chủ nhiệm'),
  Teacher(id: 't-3', name: 'Cô Lê Bích Hạnh', classes: ['Lớp Mầm A', 'Lớp Chồi A'], phone: '0903 214 567', email: 'hanh.le@kinderlog.edu.vn', role: 'Giáo viên Âm nhạc & Tạo hình'),
  Teacher(id: 't-4', name: 'Thầy Đỗ Văn Nam', classes: ['Khối Mầm', 'Khối Chồi', 'Khối Lá'], phone: '0938 765 432', email: 'nam.do@kinderlog.edu.vn', role: 'Giáo viên Thể chất'),
];

const initialStudents = [
  Student(id: 'c-1', name: 'Lê Ngọc Ánh', className: 'Lớp Mầm A', nickname: 'Bé Bơ', medicalNotes: 'Dị ứng đậu phộng, hen suyễn nhẹ khi thời tiết lạnh'),
  Student(id: 'c-2', name: 'Phạm Minh Khang', className: 'Lớp Mầm A', nickname: 'Bé Sóc', medicalNotes: 'Dị ứng tôm cua, hải sản vỏ cứng'),
  Student(id: 'c-3', name: 'Trần Gia Bảo', className: 'Lớp Mầm A', nickname: 'Bé Tôm', medicalNotes: 'Sức khỏe tốt, không có tiền sử dị ứng'),
  Student(id: 'c-4', name: 'Vũ Thùy Chi', className: 'Lớp Mầm A', nickname: 'Bé Miu', medicalNotes: 'Cận thị nhẹ, cần ngồi dãy bàn đầu'),
  Student(id: 'c-5', name: 'Đỗ Đức Anh', className: 'Lớp Mầm A', nickname: 'Bé Bắp', medicalNotes: 'Viêm mũi dị ứng phấn hoa & thời tiết'),
  Student(id: 'c-6', name: 'Hoàng Gia Linh', className: 'Lớp Mầm B', nickname: 'Bé Nhím', medicalNotes: 'Bình thường, thể lực phát triển tốt'),
];

const initialParents = [
  ParentAccount(id: 'p-1', name: 'Anh Lê Hoàng Long', linkedChildren: ['Lê Ngọc Ánh'], phone: '0909 123 456', email: 'long.le@gmail.com', relationship: 'Phụ huynh bé Ánh'),
  ParentAccount(id: 'p-2', name: 'Chị Trần Thu Thảo', linkedChildren: ['Phạm Minh Khang'], phone: '0918 889 900', email: 'thao.tran@outlook.com', relationship: 'Phụ huynh bé Khang'),
  ParentAccount(id: 'p-3', name: 'Anh Vũ Đình Toàn', linkedChildren: ['Vũ Thùy Chi'], phone: '0934 567 890', email: 'toan.vu@kinderlog.vn', relationship: 'Phụ huynh bé Chi'),
  ParentAccount(id: 'p-4', name: 'Chị Nguyễn Phương Nga', linkedChildren: ['Trần Gia Bảo'], phone: '0982 112 233', email: 'phuongnga.ng@gmail.com', relationship: 'Phụ huynh bé Bảo'),
  ParentAccount(id: 'p-5', name: 'Anh Đỗ Mạnh Hùng', linkedChildren: ['Đỗ Đức Anh'], phone: '0977 445 566', email: 'hung.do@fpt.com.vn', relationship: 'Phụ huynh bé Đức Anh'),
];

const initialSchedules = [
  Schedule(id: 'sch-m1', day: 0, name: 'Vẽ sáng tạo', start: '07:30', end: '08:10', room: 'Phòng tạo hình', teacherName: 'Cô Nguyễn Thị Mai', description: 'Tập vẽ chủ đề gia đình và tô màu sáp mềm'),
  Schedule(id: 'sch-m2', day: 0, name: 'Thể dục buổi sáng', start: '08:20', end: '08:50', room: 'Sân chơi ngoài trời', teacherName: 'Thầy Đỗ Văn Nam', description: 'Các bài tập khởi động và kéo giãn thể lực'),
  Schedule(id: 'sch-m3', day: 0, name: 'Làm quen chữ cái', start: '09:10', end: '09:40', room: 'Phòng học Mầm A', teacherName: 'Cô Nguyễn Thị Mai', description: 'Nhận diện phát âm mặt chữ O, Ô, Ơ qua tranh'),
  Schedule(id: 'sch-t1', day: 1, name: 'Hát và vận động', start: '07:30', end: '08:10', room: 'Phòng âm nhạc', teacherName: 'Cô Lê Bích Hạnh', description: 'Học hát và gõ phách bài Cháu yêu bà'),
  Schedule(id: 'sch-t2', day: 1, name: 'Chơi ngoài trời', start: '08:20', end: '08:50', room: 'Sân chơi ngoài trời', teacherName: 'Thầy Đỗ Văn Nam', description: 'Vui chơi cát nước và trò chơi cầu trượt'),
  Schedule(id: 'sch-t3', day: 1, name: 'Tạo hình bằng đất nặn', start: '09:00', end: '09:40', room: 'Phòng tạo hình', teacherName: 'Cô Trần Thị Lan', description: 'Nặn các loại trái cây đơn giản'),
  Schedule(id: 'sch-t4', day: 1, name: 'Hoạt động góc', start: '09:30', end: '10:10', room: 'Phòng tạo hình', teacherName: 'Cô Trần Thị Lan', description: 'Góc đóng vai và phân loại đồ vật'),
  Schedule(id: 'sch-w1', day: 2, name: 'Làm quen với toán', start: '07:30', end: '08:10', room: 'Phòng học Mầm A', teacherName: 'Cô Nguyễn Thị Mai', description: 'Đếm số lượng đồ vật trong phạm vi 5'),
  Schedule(id: 'sch-w2', day: 2, name: 'Kể chuyện theo tranh', start: '08:20', end: '09:00', room: 'Góc thư viện', teacherName: 'Cô Nguyễn Thị Mai', description: 'Truyện ngụ ngôn đạo đức Tích Chu'),
  Schedule(id: 'sch-h1', day: 3, name: 'Khám phá vườn rau', start: '08:30', end: '09:30', room: 'Vườn trường', teacherName: 'Cô Nguyễn Thị Mai', description: 'Quan sát cây mầm và tưới nước cho cây'),
  Schedule(id: 'sch-f1', day: 4, name: 'Hát múa tổng hợp', start: '07:30', end: '08:10', room: 'Phòng âm nhạc', teacherName: 'Cô Lê Bích Hạnh', description: 'Đồng diễn các tiết mục văn nghệ cuối tuần'),
  Schedule(id: 'sch-f2', day: 4, name: 'Lắp ghép lego thông minh', start: '08:30', end: '09:10', room: 'Phòng Stem', teacherName: 'Cô Trần Thị Lan', description: 'Phát triển tư duy không gian'),
];

const classProgress = [
  ClassProgress(className: 'Mầm 1', grade: 'Khối 2–3 tuổi', teacher: 'Cô Nguyễn Thu Thảo', total: 25, reported: 23),
  ClassProgress(className: 'Mầm 2', grade: 'Khối 2–3 tuổi', teacher: 'Cô Trần Thị Lan', total: 24, reported: 24),
  ClassProgress(className: 'Chồi 1', grade: 'Khối 3–4 tuổi', teacher: 'Cô Phạm Mai Anh', total: 28, reported: 25),
  ClassProgress(className: 'Chồi 2', grade: 'Khối 3–4 tuổi', teacher: 'Cô Lê Ngọc Hà', total: 27, reported: 21),
  ClassProgress(className: 'Lá 1', grade: 'Khối 4–5 tuổi', teacher: 'Cô Đỗ Minh Hương', total: 30, reported: 29),
];
