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
  _FakeScheduleRepository(
    this.items, {
    this.slots = const [],
    this.subjects = const [],
  });
  final List<ClassSchedule> items;
  final List<TimeSlot> slots;
  final List<Subject> subjects;

  @override
  Future<List<ClassSchedule>> getClassSchedule(String classId) async => items;

  @override
  Future<List<TimeSlot>> getTimeSlots() async => slots;

  @override
  Future<List<Subject>> getSubjects() async => subjects;

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
  Future<void> deleteSchedule(String scheduleId) async =>
      throw UnimplementedError();
}

void main() {
  // The tests select Monday explicitly so they stay deterministic on weekends.

  ClassSchedule buildItem(
    String id,
    String name,
    String slotId, {
    int dayOfWeek = 2,
    String? customStartTime,
    String? customEndTime,
    TimeSlot? customSlot,
  }) =>
      ClassSchedule(
        scheduleId: id,
        classId: 'c1',
        subjectId: 's1',
        slotId: slotId,
        customStartTime: customStartTime,
        customEndTime: customEndTime,
        dayOfWeek: dayOfWeek,
        activityName: name,
        teacherName: 'Cô Mai',
        roomName: 'Phòng tạo hình',
        timeSlot: customSlot ??
            TimeSlot(
              slotId: slotId,
              name: slotId == 'slot1' ? '07:30 - 08:10' : '09:00 - 09:40',
              startTime: slotId == 'slot1' ? '07:30' : '09:00',
              endTime: slotId == 'slot1' ? '08:10' : '09:40',
            ),
        subject: const Subject(
            subjectId: 's1', name: 'Vẽ sáng tạo', colorCode: '#4CAF50'),
      );

  Widget wrap(Widget child) => MaterialApp(theme: kinderTheme(), home: child);

  Widget gardenVoiceWrap(Widget child) => MaterialApp(
        theme: kinderTheme(),
        home: Material(child: GardenVoiceScope(child: child)),
      );

  testWidgets(
      'hiển thị danh sách hoạt động và chip xung đột khi trùng khung giờ',
      (tester) async {
    final repo = _FakeScheduleRepository([
      buildItem('a', 'Vẽ sáng tạo', 'slot1'),
      buildItem('b', 'Tạo hình đất nặn', 'slot1'),
    ]);

    await tester.pumpWidget(wrap(TimetableScreen(
        classId: 'c1', className: 'Lớp Mầm A', repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T2').first);
    await tester.pumpAndSettle();

    expect(find.text('Vẽ sáng tạo'), findsOneWidget);
    expect(find.text('Tạo hình đất nặn'), findsOneWidget);
    expect(find.text('2 xung đột'), findsOneWidget);
  });

  testWidgets('hiển thị trạng thái trống khi tuần chưa có hoạt động',
      (tester) async {
    final repo = _FakeScheduleRepository(const []);

    await tester.pumpWidget(wrap(TimetableScreen(
        classId: 'c1', className: 'Lớp Mầm A', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Tuần này chưa có hoạt động nào.'), findsOneWidget);
    expect(find.text('Thêm hoạt động'), findsOneWidget);
  });

  testWidgets('isReadOnly=true không cho phép phụ huynh thêm/sửa/xóa lịch',
      (tester) async {
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
    await tester.tap(find.text('T2').first);
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

  testWidgets(
      'isReadOnly=true khi danh sách trống không hiển thị nút thêm hoạt động',
      (tester) async {
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

  testWidgets('lịch giáo viên có header lớp, tab Lịch học và nav Garden Voice',
      (tester) async {
    final repo = _FakeScheduleRepository([
      buildItem('today', 'Vẽ sáng tạo', 'slot1'),
    ]);

    await tester.pumpWidget(gardenVoiceWrap(TimetableScreen(
      classId: 'c1',
      className: 'Lớp Mầm 1',
      repository: repo,
      isReadOnly: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Danh sách'), findsOneWidget);
    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Lớp Mầm 1'), findsWidgets);
    expect(
      find.byKey(const ValueKey('garden-voice-teacher-navigation')),
      findsOneWidget,
    );
    expect(find.text('Thêm hoạt động'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GV timetable exposes the meal category to screen readers',
      (tester) async {
    final dayIndex = DateTime.now().weekday - 1;
    final repo = _FakeScheduleRepository([
      buildItem(
        'meal',
        'Ăn sáng',
        'slot1',
        dayOfWeek: (dayIndex <= 5 ? dayIndex : 0) + 2,
      ),
    ]);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(gardenVoiceWrap(TimetableScreen(
      classId: 'c1',
      className: 'Lớp Mầm 1',
      repository: repo,
      isReadOnly: true,
    )));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('timetable-icon-meal')))
          .label,
      contains('Bữa ăn'),
    );
    semantics.dispose();
  });

  testWidgets('lịch phụ huynh hiển thị sheet Garden Voice chỉ xem',
      (tester) async {
    final repo = _FakeScheduleRepository([
      buildItem('today', 'Vẽ sáng tạo', 'slot1'),
    ]);

    await tester.pumpWidget(gardenVoiceWrap(TimetableScreen(
      classId: 'c1',
      className: 'Lớp Mầm 1',
      repository: repo,
      isReadOnly: true,
      embedded: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Thời khóa biểu của lớp'), findsOneWidget);
    expect(find.byTooltip('Đóng'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsNothing);
    expect(find.text('Xóa'), findsNothing);
    expect(find.text('Thêm hoạt động'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet lịch phụ huynh cuộn được ở 320dp với chữ 200%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeScheduleRepository([
      buildItem('today', 'Vẽ sáng tạo', 'slot1'),
    ]);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: GardenVoiceScope(
          child: TimetableScreen(
            classId: 'c1',
            className: 'Lớp Mầm 1',
            repository: repo,
            isReadOnly: true,
            embedded: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Thời khóa biểu của lớp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lịch giáo viên cuộn được ở 320dp với chữ 200%', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dayIndex = DateTime.now().weekday - 1;
    final repo = _FakeScheduleRepository([
      buildItem(
        'today',
        'Hoạt động tạo hình ngoài trời',
        'slot1',
        dayOfWeek: (dayIndex <= 5 ? dayIndex : 0) + 2,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: GardenVoiceScope(
          child: TimetableScreen(
            classId: 'c1',
            className: 'Lớp Mầm 1',
            repository: repo,
            isReadOnly: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lịch học'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor cảnh báo xung đột nhưng không chặn lưu', (tester) async {
    const slot = TimeSlot(
      slotId: 'slot1',
      name: '08:00 - 08:40',
      startTime: '08:00',
      endTime: '08:40',
    );
    const subject = Subject(
      subjectId: 's1',
      name: 'Mỹ thuật',
      colorCode: '#328DD3',
    );
    final existing = ClassSchedule(
      scheduleId: 'existing',
      classId: 'c1',
      subjectId: subject.subjectId,
      slotId: slot.slotId,
      dayOfWeek: 2,
      activityName: 'Vẽ sáng tạo',
      timeSlot: slot,
      subject: subject,
    );
    final repository = _FakeScheduleRepository(
      [existing],
      slots: [slot],
      subjects: const [subject],
    );

    await tester.pumpWidget(gardenVoiceWrap(Scaffold(
      body: ScheduleEditorSheet(
        data: TimetableData(
          items: [existing],
          slots: [slot],
          subjects: const [subject],
        ),
        classId: 'c1',
        repository: repository,
        onSaved: (_, __) {},
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T2'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Khung giờ này đã có "Vẽ sáng tạo"'),
        findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lưu hoạt động'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'hai hoạt động giờ tự do khác giờ trong cùng ngày không bị báo trùng giờ giả',
      (tester) async {
    final customEarly = buildItem(
      'c-early',
      'Thể dục sáng tự do',
      '',
      customStartTime: '07:15',
      customEndTime: '07:45',
      customSlot: const TimeSlot(
        slotId: 'c-early',
        name: '07:15 - 07:45',
        startTime: '07:15',
        endTime: '07:45',
      ),
    );
    final customLate = buildItem(
      'c-late',
      'Đọc truyện tự do',
      '',
      customStartTime: '10:15',
      customEndTime: '10:45',
      customSlot: const TimeSlot(
        slotId: 'c-late',
        name: '10:15 - 10:45',
        startTime: '10:15',
        endTime: '10:45',
      ),
    );
    final repo = _FakeScheduleRepository([customLate, customEarly]);

    await tester.pumpWidget(wrap(TimetableScreen(
      classId: 'c1',
      className: 'Lớp Mầm 1',
      repository: repo,
      isReadOnly: true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T2'));
    await tester.pumpAndSettle();

    expect(find.text('Thể dục sáng tự do'), findsOneWidget);
    expect(find.text('Đọc truyện tự do'), findsOneWidget);
    expect(find.textContaining('Trùng giờ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor giữ nguyên giờ tự do (slotId null) khi chỉnh sửa tên hoạt động',
      (tester) async {
    const standardSlot = TimeSlot(
      slotId: 'slot1',
      name: '07:30 - 08:10',
      startTime: '07:30',
      endTime: '08:10',
    );
    const subject = Subject(
      subjectId: 's1',
      name: 'Mỹ thuật',
      colorCode: '#328DD3',
    );
    final existingCustom = ClassSchedule(
      scheduleId: 'sched-custom-1',
      classId: 'c1',
      subjectId: subject.subjectId,
      slotId: '',
      customStartTime: '07:15',
      customEndTime: '07:45',
      dayOfWeek: 2,
      activityName: 'Hoạt động sáng',
      timeSlot: const TimeSlot(
        slotId: 'sched-custom-1',
        name: '07:15 - 07:45',
        startTime: '07:15',
        endTime: '07:45',
      ),
      subject: subject,
    );

    String? capturedSlotId = 'UNSET';
    String? capturedActivity;
    final repo = _RecordingUpdateScheduleRepository(
      [existingCustom],
      slots: const [standardSlot],
      subjects: const [subject],
      onUpdate: ({String? slotId, String? activityName}) {
        capturedSlotId = slotId;
        capturedActivity = activityName;
      },
    );

    await tester.pumpWidget(gardenVoiceWrap(Scaffold(
      body: ScheduleEditorSheet(
        data: TimetableData(
          items: [existingCustom],
          slots: const [standardSlot],
          subjects: const [subject],
        ),
        existing: existingCustom,
        classId: 'c1',
        repository: repo,
        onSaved: (_, __) {},
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang giữ giờ tự do: 07:15 – 07:45'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Hoạt động sáng mới');
    final saveFinder = find.text('Lưu hoạt động');
    await tester.ensureVisible(saveFinder);
    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    expect(capturedActivity, 'Hoạt động sáng mới');
    expect(capturedSlotId, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingUpdateScheduleRepository extends _FakeScheduleRepository {
  _RecordingUpdateScheduleRepository(
    super.items, {
    super.slots,
    super.subjects,
    required this.onUpdate,
  });

  final void Function({String? slotId, String? activityName}) onUpdate;

  @override
  Future<ClassSchedule> updateSchedule(
    String scheduleId, {
    String? subjectId,
    String? slotId,
    int? dayOfWeek,
    String? activityName,
    String? roomName,
    bool? isActive,
  }) async {
    onUpdate(slotId: slotId, activityName: activityName);
    return items.first;
  }
}
