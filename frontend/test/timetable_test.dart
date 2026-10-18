// Widget tests cho màn hình Thời khóa biểu (dùng repository giả).
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduleRepository implements ScheduleRepository {
  _FakeScheduleRepository(this.items);
  final List<ClassSchedule> items;

  @override
  Future<List<ClassSchedule>> getClassSchedule(String classId) async => items;

  @override
  Future<List<TimeSlot>> getTimeSlots() async => const [];

  @override
  Future<List<Subject>> getSubjects() async => const [];

  @override
  Future<ClassSchedule> createSchedule({
    required String classId,
    required String subjectId,
    required String slotId,
    required int dayOfWeek,
    String? activityName,
    String? roomName,
    String? teacherId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ClassSchedule> updateSchedule(
    String scheduleId, {
    String? subjectId,
    String? slotId,
    int? dayOfWeek,
    String? activityName,
    String? roomName,
    bool? isActive,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteSchedule(String scheduleId) async => throw UnimplementedError();
}

void main() {
  // Đặt dữ liệu vào đúng ngày hôm nay để chế độ Ngày hiển thị.
  final todayDayOfWeek = DateTime.now().weekday + 1; // backend: 2=Thứ 2

  ClassSchedule buildItem(String id, String name, String slotId) => ClassSchedule(
        scheduleId: id,
        classId: 'c1',
        subjectId: 's1',
        slotId: slotId,
        dayOfWeek: todayDayOfWeek,
        activityName: name,
        teacherName: 'Cô Mai',
        roomName: 'Phòng tạo hình',
        timeSlot: TimeSlot(
          slotId: slotId,
          name: slotId == 'slot1' ? '07:30 - 08:10' : '09:00 - 09:40',
          startTime: slotId == 'slot1' ? '07:30' : '09:00',
          endTime: slotId == 'slot1' ? '08:10' : '09:40',
        ),
        subject: const Subject(subjectId: 's1', name: 'Vẽ sáng tạo', colorCode: '#4CAF50'),
      );

  Widget wrap(Widget child) => MaterialApp(theme: kinderTheme(), home: child);

  testWidgets('hiển thị danh sách hoạt động và chip xung đột khi trùng khung giờ', (tester) async {
    final repo = _FakeScheduleRepository([
      buildItem('a', 'Vẽ sáng tạo', 'slot1'),
      buildItem('b', 'Tạo hình đất nặn', 'slot1'),
    ]);

    await tester.pumpWidget(wrap(TimetableScreen(classId: 'c1', className: 'Lớp Mầm A', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Vẽ sáng tạo'), findsOneWidget);
    expect(find.text('Tạo hình đất nặn'), findsOneWidget);
    expect(find.text('2 xung đột'), findsOneWidget);
  });

  testWidgets('hiển thị trạng thái trống khi tuần chưa có hoạt động', (tester) async {
    final repo = _FakeScheduleRepository(const []);

    await tester.pumpWidget(wrap(TimetableScreen(classId: 'c1', className: 'Lớp Mầm A', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Tuần này chưa có hoạt động nào.'), findsOneWidget);
    expect(find.text('Thêm hoạt động'), findsOneWidget);
  });

  testWidgets('isReadOnly=true không cho phép phụ huynh thêm/sửa/xóa lịch', (tester) async {
    final repo = _FakeScheduleRepository([
      buildItem('a', 'Vẽ sáng tạo', 'slot1'),
    ]);

    await tester.pumpWidget(wrap(TimetableScreen(
      classId: 'c1',
      className: 'Lớp Mầm A',
      repository: repo,
      isReadOnly: true,
    )));
    await tester.pumpAndSettle();

    // Không có nút Thêm hoạt động
    expect(find.text('Thêm hoạt động'), findsNothing);

    // Bấm vào hoạt động để mở chi tiết
    await tester.tap(find.text('Vẽ sáng tạo'));
    await tester.pumpAndSettle();

    // Hiển thị nút Đóng, KHÔNG hiển thị Chỉnh sửa hay Xóa
    expect(find.text('Đóng'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsNothing);
    expect(find.text('Xóa'), findsNothing);

    // Bấm Đóng để đóng sheet
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Đóng'), findsNothing);
  });

  testWidgets('isReadOnly=true khi danh sách trống không hiển thị nút thêm hoạt động', (tester) async {
    final repo = _FakeScheduleRepository(const []);

    await tester.pumpWidget(wrap(TimetableScreen(
      classId: 'c1',
      className: 'Lớp Mầm A',
      repository: repo,
      isReadOnly: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Tuần này chưa có hoạt động nào.'), findsOneWidget);
    expect(find.text('Lớp chưa có hoạt động nào trong tuần.'), findsOneWidget);
    expect(find.text('Thêm hoạt động'), findsNothing);
  });
}
