import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_notifications_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_health_profile_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/emergency_alert_summary_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_detail_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_submitted_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/no_assignment_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/report_editor.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show KButton, StatusBadge, ThemeSelector;
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/teacher_emergency_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    show ReportStatus;
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart'
    show ExtractionData, TeacherRepository, VoiceRecord;
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:adark_frontend/domain/entities/health/emergency_alert_data.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart'
    as domain_status;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    show AttendanceStatus;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adark_frontend/core/notifications/emergency_siren_service.dart';

import 'parent_request_repository_test.dart'
    show RequestTransport, jsonBody, requestJson;
import 'parent_requests_test.dart' show app, child;
import 'parent_medication_test.dart' show tapVisible;
import 'upload_file_test.dart' show FailingTeacherRepo;

void _noop() {}

Future<void> captureUi(WidgetTester tester, String name,
    {bool settle = true}) async {
  const directory = String.fromEnvironment('UI_CAPTURE_DIR');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    for (final asset in [
      'assets/request_timeline/complete.png',
      'assets/garden_voice/teacher_garden.png',
      'assets/garden_voice/report_clipboard.png',
      'assets/garden_voice/parent_child_reading.png',
      'assets/garden_voice/parent_teacher.png',
      'assets/garden_voice/school_v2.png',
      'assets/garden_voice/plant_detail.png',
      'assets/garden_voice/books_v2.png',
    'assets/garden_voice/teacher_portrait.png',
    'assets/garden_voice/login_classroom.png',
  ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')));
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Dashboard extends HttpDashboardRepository {
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
      teacherId: 'teacher-1',
      fullName: 'Cô Nguyễn Thị Mai',
      email: 'teacher@example.com');
  @override
  Future<List<Child>> getClassChildren(String classId) async => const [
        Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Minh An',
          medicalAllergies: 'Dị ứng đậu phộng',
        ),
        Child(
          childId: 'child-2',
          classId: 'class-1',
          fullName: 'Bảo Châu',
        ),
      ];

  @override
  Future<ClassDashboardSummary> getClassDashboard(
          String classId, DateTime date) async =>
      const ClassDashboardSummary(
        classInfo: ClassInfo(
            classId: 'class-1', schoolId: 'school-1', name: 'Lớp Mầm 1'),
        teacherName: 'Cô Nguyễn Thị Mai',
        totalChildren: 5,
        completedCount: 0,
        draftCount: 0,
        missingCount: 5,
        pendingChildren: [
          ChildReportItem(
            child: Child(
              childId: 'child-1',
              fullName: 'Minh An',
              medicalAllergies: 'Dị ứng đậu phộng',
            ),
          ),
          ChildReportItem(
            child: Child(childId: 'child-2', fullName: 'Bảo Châu'),
          ),
        ],
      );
}

class _ReviewCaptureDashboard extends _Dashboard {
  @override
  Future<List<Child>> getClassChildren(String classId) async => const [
        Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Nguyễn Minh An',
        ),
      ];
}

class _Batch1TeacherDashboard extends HttpDashboardRepository {
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
        teacherId: 'teacher-1',
        fullName: 'Cô Nguyễn Thị Hương',
        email: 'huong.nguyen@school.test',
        phone: '0905123456',
      );

  @override
  Future<List<Child>> getClassChildren(String classId) async => const [
        Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Nguyễn Minh An',
          medicalAllergies: 'Đậu phộng',
        ),
        Child(
          childId: 'child-2',
          classId: 'class-1',
          fullName: 'Trần Bảo Ngọc',
          careNotes: 'Mới quen lớp',
        ),
        Child(
          childId: 'child-3',
          classId: 'class-1',
          fullName: 'Lê Hoàng Nam',
        ),
        Child(
          childId: 'child-4',
          classId: 'class-1',
          fullName: 'Phạm Thu Hà',
        ),
      ];

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async =>
      switch (childId) {
        'child-1' => [
            DailyReport(
              dailyReportId: 'rep-1',
              childId: 'child-1',
              reportDate: DateTime(2026, 11, 5, 10, 24),
              publishedAt: DateTime(2026, 11, 5, 10, 24),
              status: domain_status.ReportStatus.published,
            ),
            DailyReport(
              dailyReportId: 'rep-4',
              childId: 'child-1',
              reportDate: DateTime(2026, 11, 4, 16, 10),
              publishedAt: DateTime(2026, 11, 4, 16, 10),
              status: domain_status.ReportStatus.read,
            ),
          ],
        'child-2' => [
            DailyReport(
              dailyReportId: 'rep-2',
              childId: 'child-2',
              reportDate: DateTime(2026, 11, 5, 9, 50),
              status: domain_status.ReportStatus.draft,
            ),
            DailyReport(
              dailyReportId: 'rep-5',
              childId: 'child-2',
              reportDate: DateTime(2026, 11, 4, 15, 45),
              status: domain_status.ReportStatus.draft,
              health: 'Mức độ sức khỏe: mild',
            ),
          ],
        'child-3' => [
            DailyReport(
              dailyReportId: 'rep-3',
              childId: 'child-3',
              reportDate: DateTime(2026, 11, 5, 9, 30),
              publishedAt: DateTime(2026, 11, 5, 9, 30),
              status: domain_status.ReportStatus.read,
            ),
          ],
        'child-4' => [
            DailyReport(
              dailyReportId: 'rep-6',
              childId: 'child-4',
              reportDate: DateTime(2026, 11, 4, 15, 30),
              publishedAt: DateTime(2026, 11, 4, 15, 30),
              status: domain_status.ReportStatus.read,
            ),
          ],
        _ => const [],
      };
}

class _Batch1ClassRepo extends HttpClassDataRepository {
  @override
  Future<ClassInfo> getClassInfo(String classId) async => const ClassInfo(
        classId: 'class-1',
        schoolId: 'school-1',
        name: 'Lớp Mầm A',
      );
}

class _ProcessingCaptureRepo extends TeacherRepository {
  @override
  Future<VoiceRecord> uploadAudio({
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async =>
      const VoiceRecord(id: 'voice-1', status: 'processing');

  @override
  Future<VoiceRecord> getVoiceRecord({
    required String voiceId,
    String? teacherId,
  }) async =>
      const VoiceRecord(
          id: 'voice-1',
          status: 'completed',
          transcription: 'Hôm nay bé ăn cơm ngoan.');

  @override
  Future<ExtractionData> analyzeTranscript({
    required String voiceId,
    required String teacherId,
    required String editedTranscript,
  }) async =>
      const ExtractionData(
          transcript: 'Hôm nay bé ăn cơm ngoan.',
          classWideExtraction: {'meals': 'Ăn cơm ngoan'});
}

class _ReviewCaptureRepo extends TeacherRepository {
  @override
  Future<Map<String, dynamic>> approveItem({
    required String voiceRecordId,
    required String teacherId,
    required String kind,
    String? childId,
    String? classId,
    Map<String, String?>? extraction,
  }) async =>
      {
        'draft_report_ids': ['draft-1']
      };
}

class _ReviewCaptureAudioPlayer extends AudioPlayer {
  bool sourceLoaded = false;
  Duration? lastSeek;

  @override
  Stream<PlayerState> get playerStateStream =>
      Stream.value(PlayerState(false, ProcessingState.ready));

  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(seconds: 58));

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(seconds: 84));

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    if (source is! BytesAudioSource) {
      throw StateError('Review capture requires in-memory WAV bytes');
    }
    final response = await source.request();
    final bytes = Uint8List.fromList(await response.stream.single);
    final data = ByteData.sublistView(bytes);
    final isValidWav = bytes.length >= 44 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 16)) == 'WAVEfmt ' &&
        String.fromCharCodes(bytes.sublist(36, 40)) == 'data' &&
        data.getUint16(20, Endian.little) == 1 &&
        data.getUint16(22, Endian.little) == 1 &&
        data.getUint32(28, Endian.little) == 8000 &&
        data.getUint16(34, Endian.little) == 8 &&
        data.getUint32(40, Endian.little) == bytes.length - 44;
    if (!isValidWav) throw StateError('Invalid silent WAV fixture');
    sourceLoaded = true;
    return Duration(seconds: data.getUint32(40, Endian.little) ~/ 8000);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    lastSeek = position;
  }

  @override
  Future<void> dispose() async {}
}

Uint8List _silentWav84Seconds() {
  const sampleRate = 8000;
  const dataLength = sampleRate * 84;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);

  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate, Endian.little);
  data.setUint16(32, 1, Endian.little);
  data.setUint16(34, 8, Endian.little);
  text(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  bytes.fillRange(44, bytes.length, 128);
  return bytes;
}

class _Attendance extends HttpAttendanceRepository {
  @override
  Future<Map<String, AttendanceChildRecord>> getClassAttendanceDetails(
          String classId, DateTime date) async =>
      const {
        'child-1': AttendanceChildRecord(
          childId: 'child-1',
          status: AttendanceStatus.arrived,
        ),
        'child-2': AttendanceChildRecord(
          childId: 'child-2',
          status: AttendanceStatus.late,
          checkInTime: '08:30',
        ),
        'child-3': AttendanceChildRecord(
          childId: 'child-3',
          status: AttendanceStatus.arrived,
        ),
        'child-4': AttendanceChildRecord(
          childId: 'child-4',
          status: AttendanceStatus.arrived,
        ),
        'child-5': AttendanceChildRecord(
          childId: 'child-5',
          status: AttendanceStatus.arrived,
        ),
      };
}

class _Medication extends HttpMedicationRepository {
  @override
  Future<MedicationsTodayData> getTodayMedications({String? date}) async =>
      const MedicationsTodayData(
        date: '2026-11-05',
        classId: 'class-1',
        totalRequests: 2,
        completedCount: 0,
        pendingCount: 2,
        morning: [],
        noon: [],
        afternoon: [],
      );
}

class _CaptureRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

class _Class extends HttpClassDataRepository {
  @override
  Future<ClassInfo> getClassInfo(String classId) async => const ClassInfo(
        classId: 'class-1',
        schoolId: 'school-1',
        name: 'Lớp Mầm 1',
      );
}

class _ParentDashboard extends HttpDashboardRepository {
  @override
  Future<Parent> getCurrentParent() async =>
      const Parent(parentId: 'parent-1', fullName: 'Nguyễn Văn Tuấn');

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async =>
      const ChildOverview(
        child: Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Nguyễn Minh An',
        ),
        className: 'Mầm 1',
        teacherName: 'Cô Nguyễn Thị Mai',
      );

  DailyReport _report(DateTime date) => DailyReport(
        dailyReportId: 'report-1',
        childId: 'child-1',
        teacherId: 'teacher-1',
        reportDate: date,
        status: domain_status.ReportStatus.published,
        eating: 'Ăn hết suất cơm, uống đủ nước',
        sleeping: 'Ngủ ngon · 12:00 – 13:45',
        activitiesText: 'Vẽ tranh mùa thu · rất hứng thú',
        summaryText: 'Hôm nay An ăn ngoan, gia đình theo dõi thêm giúp cô nhé.',
      );

  @override
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  }) async =>
      _report(date);

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async =>
      [_report(DateTime.now())];
}

class _ParentCaptureDashboard extends _ParentDashboard {
  @override
  Future<Parent> getCurrentParent() async => Parent(
        parentId: 'parent-capture',
        fullName: 'Nguyễn Văn An',
        phone: '0901234567',
        email: 'an.nguyen@example.com',
        relationship: 'Mẹ',
        createdAt: DateTime.now().subtract(const Duration(days: 128)),
      );

  Child get _child => Child(
        childId: 'child-capture',
        classId: 'class-capture',
        fullName: 'Nguyễn Minh An',
        nickname: 'Bé An',
        dateOfBirth: DateTime(2023, 3, 12),
        gender: 'female',
        medicalAllergies: 'Đậu phộng',
        allergyStatus: 'present',
        careNotes: 'Báo cô nếu bé khó chịu.',
      );

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async =>
      ChildOverview(
        child: _child,
        className: 'Mầm A',
        teacherName: 'Cô Nguyễn Thị Mai',
        teacherId: 'teacher-capture',
        teacherPhone: '0987654321',
        roomNumber: 'Phòng 1',
      );

  @override
  Future<Child> getChildHealthProfile(String childId) async => _child;

  @override
  Future<DailyReport> markReportAsRead(String reportId) async =>
      _report(DateTime.now()).copyWith(status: domain_status.ReportStatus.read);
}

class _FigmaScheduleRepository implements ScheduleRepository {
  _FigmaScheduleRepository(this.items);
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
  Future<void> deleteSchedule(String scheduleId) async =>
      throw UnimplementedError();
}

class _ApprovalCaptureRepository extends HttpLeaveRequestRepository {
  _ApprovalCaptureRepository(this.request);
  final LeaveRequestEntity request;

  @override
  Future<LeaveRequestBatchResult> getLeaveRequests({
    required String classId,
    required String tab,
    int offset = 0,
    int limit = 50,
  }) async =>
      LeaveRequestBatchResult(
        pendingCount: request.status == LeaveStatus.pending ? 1 : 0,
        reviewedCount: request.status == LeaveStatus.approved ? 1 : 0,
        items: [request],
      );

  @override
  Future<LeaveRequestEntity> approveLeaveRequest(String requestId) async =>
      LeaveRequestEntity(
        requestId: request.requestId,
        childId: request.childId,
        parentId: request.parentId,
        classId: request.classId,
        fromDate: request.fromDate,
        toDate: request.toDate,
        reason: request.reason,
        status: LeaveStatus.approved,
        createdAt: request.createdAt,
        childName: request.childName,
        requestType: request.requestType,
        expectedArrivalTime: request.expectedArrivalTime,
        reviewedAt: DateTime(2026, 11, 5, 8, 0),
      );
}

ClassSchedule _timetableFixture(
        String id, String activity, String start, String end, int dayIndex,
        {String? content}) =>
    ClassSchedule(
      scheduleId: id,
      classId: 'class-1',
      subjectId: 'subject-1',
      slotId: 'slot-$id',
      dayOfWeek: dayIndex + 2,
      activityName: activity,
      content: content ?? 'Hoạt động của lớp',
      roomName: 'Phòng Mầm 1',
      teacherName: 'Cô Nguyễn Thị Mai',
      timeSlot: TimeSlot(
        slotId: 'slot-$id',
        name: '$start - $end',
        startTime: start,
        endTime: end,
      ),
      subject: const Subject(
        subjectId: 'subject-1',
        name: 'Mỹ thuật',
        colorCode: '#328DD3',
      ),
    );

MedicationDose _batch4Dose({
  required String id,
  required String batchId,
  required String status,
  required String timeSlot,
  String name = 'Paracetamol 250mg',
  String dosage = '5ml/lần',
  DateTime? requestDate,
  String? givenByName,
  DateTime? givenAt,
}) =>
    MedicationDose(
      id: id,
      batchId: batchId,
      childId: 'child-1',
      childName: 'Nguyễn Minh An',
      classId: 'class-1',
      name: name,
      dosage: dosage,
      status: status,
      category: 'prescription',
      notes: 'Uống khi sốt trên 38.5°',
      requestDate: requestDate ?? DateTime(2026, 11, 11),
      startDate: requestDate ?? DateTime(2026, 11, 11),
      endDate: requestDate ?? DateTime(2026, 11, 11),
      timeSlot: timeSlot,
      creatorName: 'Mẹ Minh An',
      createdAt: DateTime(2026, 11, 11, 7, 2),
      givenByName: givenByName,
      givenAt: givenAt,
    );

MedicationsTodayData _batch4TeacherToday({bool confirmed = false}) {
  final first = MedicationItem(
    requestId: 'dose-1',
    childId: 'child-1',
    childName: 'Nguyễn Minh An',
    childNickname: 'An',
    medicationName: 'Thuốc ho Prospan',
    dosage: '5ml',
    session: 'morning',
    isGiven: confirmed,
    givenAt: confirmed ? DateTime(2026, 11, 11, 8, 32) : null,
    givenByName: confirmed ? 'Cô Nguyễn Thị Mai' : null,
    timeSlot: '08:30',
    requestDate: DateTime(2026, 11, 11),
  );
  final second = MedicationItem(
    requestId: 'dose-2',
    childId: 'child-2',
    childName: 'Phạm Thu Hà',
    medicationName: 'Men tiêu hóa Biolactovin',
    dosage: '1 gói',
    instructions: 'Uống sau ăn trưa',
    session: 'noon',
    timeSlot: '11:00',
    requestDate: DateTime(2026, 11, 11),
  );
  final third = MedicationItem(
    requestId: 'dose-3',
    childId: 'child-3',
    childName: 'Trần Bảo Ngọc',
    medicationName: 'Vitamin D3',
    dosage: 'Chờ xác minh',
    session: 'afternoon',
    timeSlot: '14:30',
    requestDate: DateTime(2026, 11, 11),
  );
  return MedicationsTodayData(
    date: '2026-11-11',
    classId: 'class-1',
    className: 'Lớp Mầm 1',
    totalRequests: 3,
    completedCount: confirmed ? 1 : 0,
    pendingCount: confirmed ? 2 : 3,
    morning: [first],
    noon: [second],
    afternoon: [third],
  );
}

class _Batch4MedicationRepository extends HttpMedicationRepository {
  _Batch4MedicationRepository({
    required this.history,
    required this.today,
    this.confirmedToday,
    this.contacts = const [],
  });

  final List<MedicationDose> history;
  final MedicationsTodayData today;
  final MedicationsTodayData? confirmedToday;
  final List<Map<String, dynamic>> contacts;
  bool confirmed = false;

  @override
  Future<List<MedicationDose>> getMedicationRequests({
    required String childId,
    String? batchId,
  }) async =>
      history
          .where((dose) =>
              dose.childId == childId &&
              (batchId == null || dose.batchId == batchId))
          .toList();

  @override
  Future<MedicationsTodayData> getTodayMedications({String? date}) async =>
      confirmed ? confirmedToday ?? today : today;

  @override
  Future<Map<String, dynamic>> confirmMedication({
    required String requestId,
    required String session,
    String? date,
    String? notes,
  }) async {
    confirmed = true;
    return {'request_id': requestId, 'is_given': true};
  }

  @override
  Future<List<Map<String, dynamic>>> getEmergencyContacts(
          String childId) async =>
      contacts;

  @override
  Future<Map<String, dynamic>> createHealthIncident({
    required String childId,
    required String incidentType,
    String? description,
    double? temperature,
    String? actionTaken,
  }) async =>
      {
        'incident_id': 'incident-1',
        'child_id': childId,
        'child_name': 'Bảo Châu',
        'incident_type': incidentType,
        'incident_type_label': 'Sốt cao',
        'description': description ?? 'Cần phối hợp với gia đình.',
        'temperature': temperature,
        'reported_at': '2026-11-11T03:24:00Z',
        'reported_by_name': 'Cô Nguyễn Thị Mai',
        'emergency_contacts': contacts,
      };
}

Future<void> _pumpParentCapture(
  WidgetTester tester, {
  _ParentCaptureDashboard? repository,
  ScheduleRepository? scheduleRepository,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(RepaintBoundary(
    key: const ValueKey('capture'),
    child: app(
      ParentFlow(
        repository: repository ?? _ParentCaptureDashboard(),
        scheduleRepository: scheduleRepository,
        onLogout: _noop,
      ),
      textScale: textScale,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpBatch4Capture(
    WidgetTester tester, Widget screen, String captureName,
    {bool settle = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: const ValueKey('capture'),
    child: app(GardenVoiceScope(child: screen)),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await captureUi(tester, captureName);
}

void main() {
  testWidgets('forgot-password email input capture uses the live KInput',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(const ForgotPasswordScreen()),
    ));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-forgot-password-kinput');
    expect(find.text('Email đăng nhập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GV success status badge matches its Figma component tokens',
      (tester) async {
    tester.view.physicalSize = const Size(140, 48);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(
        const Align(
          alignment: Alignment.center,
          child: GardenVoiceScope(
            child: StatusBadge(ReportStatus.submitted),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await captureUi(tester, 'gv-status-badge-success');
    expect(tester.takeException(), isNull);
  });

  testWidgets('GV primary KButton matches its Figma component frame',
      (tester) async {
    tester.view.physicalSize = const Size(170, 48);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(
        const Center(
          child: SizedBox(
            width: 170,
            child: GardenVoiceScope(
              child: KButton(label: 'Nút bấm', onPressed: _noop),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(tester.getSize(find.byType(FilledButton)), const Size(170, 48));
    expect(
      (button.style!.shape!.resolve({})! as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.circular(24),
    );
    await captureUi(tester, 'gv-kbutton-primary');
    expect(tester.takeException(), isNull);
  });

  setUpAll(() async {
    final fonts = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await fonts.load();
    final nunito = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'));
    await nunito.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
      'tổng quan Garden Voice có dữ liệu thật, shell và không dựng badge giả',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture'),
        child: app(TeacherShell(
          onLogout: () {},
          classId: 'class-1',
          repository: _Dashboard(),
          classRepository: _Class(),
          attendanceRepository: _Attendance(),
          medicationRepository: _Medication(),
        ))));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Ghi lại một ngày\ncủa bé'), findsOneWidget);
    expect(find.text('Bắt đầu báo cáo'), findsOneWidget);
    expect(find.text('5/5 bé đã đến'), findsOneWidget);
    expect(find.text('2 việc cần xử lý'), findsOneWidget);
    expect(find.textContaining('3 mới'), findsNothing);
    expect(find.text('Báo sự cố'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-voice-teacher-navigation')),
        findsOneWidget);
    await captureUi(tester, 'teacher-overview');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tổng quan phụ huynh Garden Voice dùng report thật, không bịa điểm danh',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(
        ParentFlow(repository: _ParentDashboard(), onLogout: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn Tuấn'), findsOneWidget);
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.textContaining('Đã đến lớp'), findsNothing);
    await captureUi(tester, 'parent-overview');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent inbox capture — Figma 454:2048', (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Mở thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('BÁO CÁO'), findsOneWidget);
    await captureUi(tester, 'parent-inbox-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent daily-report sheet capture — Figma 454:2216',
      (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Báo cáo'));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo ngày'), findsOneWidget);
    expect(find.text('Ăn uống'), findsWidgets);
    await captureUi(tester, 'parent-daily-report-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent account capture — Figma 454:2445', (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Thông tin liên hệ'), findsOneWidget);
    await captureUi(tester, 'parent-account-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent contact details capture — Figma 562:1612',
      (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Thông tin liên hệ'), findsOneWidget);
    expect(find.text('0901 ••• 567'), findsOneWidget);
    await captureUi(tester, 'parent-contact-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent contact editor capture — Figma 562:1636', (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();

    expect(find.text('Sửa thông tin liên hệ'), findsOneWidget);
    expect(find.byKey(const ValueKey('parent-profile-phone')), findsOneWidget);
    await captureUi(tester, 'parent-contact-edit-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent relationship selection capture — Figma 563:1780',
      (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-profile-relationship')));
    await tester.pumpAndSettle();

    expect(find.text('Quan hệ với bé'), findsOneWidget);
    expect(find.text('Mẹ'), findsOneWidget);
    await captureUi(tester, 'parent-relationship-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent child-details sheet capture — Figma 454:2379',
      (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Thông tin bé'), findsOneWidget);
    expect(find.text('Gọi giáo viên chủ nhiệm'), findsOneWidget);
    await captureUi(tester, 'parent-child-details-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent child editor capture — Garden Voice form pattern',
      (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa thông tin bé'), findsOneWidget);
    expect(find.byKey(const ValueKey('child-edit-name')), findsOneWidget);
    expect(find.widgetWithText(KButton, 'Hủy'), findsOneWidget);
    await captureUi(tester, 'parent-child-edit-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent health-profile capture — Figma 454:2411', (tester) async {
    await _pumpParentCapture(tester);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ sức khỏe'));
    await tester.pumpAndSettle();

    expect(find.byType(ParentHealthProfileScreen), findsOneWidget);
    expect(find.text('Thông tin sức khỏe'), findsOneWidget);
    await captureUi(tester, 'parent-health-profile-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent screens remain usable at 320dp and 200% text',
      (tester) async {
    await _pumpParentCapture(
      tester,
      size: const Size(320, 844),
      textScale: 2,
    );
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester
        .ensureVisible(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin liên hệ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Chỉnh sửa thông tin'));
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('parent-profile-phone')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Attendance capture — Figma 453:801', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const roster = [
      ui.Child(
        id: 'an',
        name: 'Nguyễn Minh An',
        status: ui.ReportStatus.none,
        present: true,
        time: '07:12',
        severity: ui.Severity.none,
      ),
      ui.Child(
        id: 'chau',
        name: 'Bảo Châu',
        status: ui.ReportStatus.none,
        present: true,
        time: '08:30',
        severity: ui.Severity.none,
      ),
      ui.Child(
        id: 'linh',
        name: 'Phương Linh',
        status: ui.ReportStatus.none,
        present: true,
        time: '07:25',
        severity: ui.Severity.none,
      ),
      ui.Child(
        id: 'khang',
        name: 'Minh Khang',
        status: ui.ReportStatus.none,
        present: true,
        time: '07:18',
        severity: ui.Severity.none,
      ),
      ui.Child(
        id: 'vy',
        name: 'Thảo Vy',
        status: ui.ReportStatus.none,
        present: true,
        time: '07:30',
        severity: ui.Severity.none,
      ),
    ];
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: AttendanceScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          teacherName: 'Cô Nguyễn Thị Mai',
          date: DateTime.now().toIso8601String().substring(0, 10),
          roster: roster,
          initialRecords: {
            'an': AttendanceStatus.arrived,
            'chau': AttendanceStatus.late,
            'linh': AttendanceStatus.arrived,
            'khang': AttendanceStatus.arrived,
            'vy': AttendanceStatus.arrived,
          },
          initialDetails: {
            'an': const AttendanceChildRecord(
                childId: 'an',
                status: AttendanceStatus.arrived,
                checkInTime: '07:12'),
            'chau': const AttendanceChildRecord(
                childId: 'chau',
                status: AttendanceStatus.late,
                checkInTime: '08:30',
                expectedArrivalTime: '08:30:00'),
            'linh': const AttendanceChildRecord(
                childId: 'linh',
                status: AttendanceStatus.arrived,
                checkInTime: '07:25'),
            'khang': const AttendanceChildRecord(
                childId: 'khang',
                status: AttendanceStatus.arrived,
                checkInTime: '07:18'),
            'vy': const AttendanceChildRecord(
                childId: 'vy',
                status: AttendanceStatus.arrived,
                checkInTime: '07:30'),
          },
        ),
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Danh sách'), findsOneWidget);
    expect(find.text('5/5 bé đã đến lớp'), findsOneWidget);
    await captureUi(tester, 'teacher-attendance-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher timetable capture — Figma 454:931', (tester) async {
    final day = DateTime.now().weekday - 1;
    final repository = _FigmaScheduleRepository([
      _timetableFixture(
        'arrival',
        'Đón trẻ & điểm danh',
        '07:00',
        '07:30',
        day,
        content: 'Cô Mai đón bé tại lớp',
      ),
      _timetableFixture(
        'breakfast',
        'Ăn sáng',
        '08:00',
        '08:30',
        day,
        content: 'Bữa sáng của lớp',
      ),
      _timetableFixture(
        'art',
        'Khám phá & học tập',
        '09:00',
        '09:30',
        day,
        content: 'Hoạt động góc · xếp hình, vẽ tranh',
      ),
      _timetableFixture(
        'outside',
        'Vui chơi ngoài trời',
        '10:30',
        '11:00',
        day,
        content: 'Sân trường · vận động nhẹ',
      ),
      _timetableFixture(
        'lunch',
        'Ăn trưa',
        '11:30',
        '12:00',
        day,
        content: 'Bữa trưa tại lớp',
      ),
      _timetableFixture(
        'sleep',
        'Ngủ trưa',
        '12:00',
        '13:45',
        day,
        content: 'Giấc ngủ trưa của bé',
      ),
    ]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: TimetableScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          teacherName: 'Cô Nguyễn Thị Mai',
          repository: repository,
          isReadOnly: true,
        ),
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Đón trẻ & điểm danh'), findsOneWidget);
    await captureUi(tester, 'teacher-timetable-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent timetable sheet capture — Figma 454:2287',
      (tester) async {
    final day = DateTime.now().weekday - 1;
    final repository = _FigmaScheduleRepository([
      _timetableFixture(
        'breakfast',
        'Đón bé & ăn sáng',
        '07:30',
        '08:00',
        day,
        content: 'Cô Mai đón bé tại lớp · điểm danh đầu giờ',
      ),
      _timetableFixture(
        'art',
        'Khám phá & học tập',
        '08:30',
        '09:00',
        day,
        content: 'Hoạt động góc · xếp hình, vẽ tranh',
      ),
      _timetableFixture(
        'outside',
        'Vui chơi ngoài trời',
        '09:30',
        '10:00',
        day,
        content: 'Sân trường · vận động nhẹ',
      ),
      _timetableFixture(
        'lunch',
        'Ăn trưa · nghỉ trưa',
        '11:00',
        '13:45',
        day,
        content: 'Thực đơn: cơm, thịt kho, canh bí',
      ),
      _timetableFixture(
        'story',
        'Ăn nhẹ & đọc truyện',
        '15:00',
        '15:30',
        day,
        content: 'Sữa + bánh · cô đọc truyện tranh',
      ),
    ]);
    await _pumpParentCapture(tester, scheduleRepository: repository);
    await tester.tap(find.text('Lịch học'));
    await tester.pumpAndSettle();

    expect(find.text('Thời khóa biểu của lớp'), findsOneWidget);
    expect(find.text('Đón bé & ăn sáng'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsNothing);
    await captureUi(tester, 'parent-timetable-gv');
    expect(tester.takeException(), isNull);
  });

  for (final requestType in LeaveRequestType.values) {
    testWidgets(
        'Approval result capture — ${requestType == LeaveRequestType.absence ? '454:1345' : '454:1673'}',
        (tester) async {
      final isLate = requestType == LeaveRequestType.lateArrival;
      final pending = LeaveRequestEntity(
        requestId: isLate ? 'late-1' : 'absence-1',
        childId: isLate ? 'child-late' : 'child-absence',
        parentId: 'parent-1',
        classId: 'class-1',
        fromDate: DateTime(2026, 11, 5),
        toDate: DateTime(2026, 11, 5),
        reason: isLate ? 'Gia đình sẽ đưa bé đến muộn.' : 'Bé bị sốt.',
        status: LeaveStatus.pending,
        createdAt: DateTime(2026, 11, 4, 17),
        childName: isLate ? 'Lê Hoàng Nam' : 'Nguyễn Minh An',
        requestType: requestType,
        expectedArrivalTime: isLate ? '08:30:00' : null,
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture'),
        child: app(LeaveRequestReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          repository: _ApprovalCaptureRepository(pending),
          initialRequest: pending,
          onOpenAttendance: _noop,
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt đơn'));
      await tester.pumpAndSettle();

      expect(
        find.text(isLate ? 'Đã duyệt báo trễ' : 'Đã duyệt đơn'),
        findsOneWidget,
      );
      await captureUi(
        tester,
        isLate
            ? 'teacher-attendance-approved-late-gv'
            : 'teacher-attendance-approved-absence-gv',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hub ghi nhận Garden Voice dùng roster và trạng thái thật',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(RecordHubScreen(
        classId: 'class-1',
        repository: _Dashboard(),
        classRepository: _Class(),
        onClass: () {},
        onChild: (_) {},
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cả Lớp Mầm 1'), findsOneWidget);
    expect(find.text('Minh An'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Minh An')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(find.text('Dị ứng: đậu phộng'), findsOneWidget);
    expect(find.text('5 chưa xong'), findsOneWidget);
    await captureUi(tester, 'teacher-record-hub');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ghi âm Garden Voice giữ luồng mic thật và hiển thị thông tin bé',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(RecordingScreen(
        mode: RecordMode.child,
        child: const ui.Child(
          id: 'child-1',
          name: 'Nguyễn Minh An',
          nickname: 'Bé An',
          status: ui.ReportStatus.none,
          present: true,
          time: '',
          severity: ui.Severity.none,
          allergy: 'Đậu phộng',
        ),
        className: 'Lớp Mầm 1',
        audioRecorder: _CaptureRecorder(),
        pathProvider: (_) async => 'capture.m4a',
        onSubmit: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bắt đầu ghi âm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 84));

    expect(find.text('Đang ghi âm · Nói tự nhiên'), findsOneWidget);
    expect(find.text('01:24'), findsOneWidget);
    expect(find.text('Dị ứng: Đậu phộng'), findsOneWidget);
    await captureUi(tester, 'teacher-recording', settle: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('processing and approved review render in Garden Voice',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var processingCompleted = false;
    final reviewAudioPlayer = _ReviewCaptureAudioPlayer();
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(ProcessingScreen(
        mode: RecordMode.classroom,
        file: PlatformFile(
          name: 'ghi-am-minh-an.m4a',
          size: 4,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
        teacherRepository: _ProcessingCaptureRepo(),
        onBack: () {},
        onDone: (_, __) => processingCompleted = true,
      )),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Phân tích bản ghi âm'), findsOneWidget);
    expect(find.text('Đang chuyển giọng nói thành văn bản'), findsNWidgets(2));
    await captureUi(tester, 'teacher-processing-gv', settle: false);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));
    expect(processingCompleted, isTrue);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            transcript:
                '"Hôm nay Minh An ăn hết suất cơm với thịt kho và canh bí. Ngủ trưa từ 12:00 đến 13:45, ngủ ngon không quấy khóc. Chiều bé vẽ tranh mùa thu, rất hứng thú…"',
            childExtractions: {
              'child-1': {
                'meals': 'Ăn hết suất · cơm, thịt kho, canh bí',
                'sleeping': '12:00 – 13:45 · ngủ ngon',
                'activities': 'Vẽ tranh mùa thu · rất hứng thú',
              },
            },
          ),
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          recordedBytes: _silentWav84Seconds(),
          audioPlayerFactory: () => reviewAudioPlayer,
          repository: _ReviewCaptureDashboard(),
          teacherRepository: _ReviewCaptureRepo(),
          onBack: () {},
          onCompleted: () {},
        ),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    expect(find.text('Xem lại báo cáo'), findsOneWidget);
    expect(find.text('Bước 3/3 · Xem lại'), findsOneWidget);
    expect(find.text('Đã tách 1 bé'), findsOneWidget);
    expect(
      find.text(
        '"Hôm nay Minh An ăn hết suất cơm với thịt kho và canh bí. Ngủ trưa từ 12:00 đến 13:45, ngủ ngon không quấy khóc. Chiều bé vẽ tranh mùa thu, rất hứng thú…"',
      ),
      findsOneWidget,
    );
    final transcriptFinder = find.text(
      '"Hôm nay Minh An ăn hết suất cơm với thịt kho và canh bí. Ngủ trưa từ 12:00 đến 13:45, ngủ ngon không quấy khóc. Chiều bé vẽ tranh mùa thu, rất hứng thú…"',
    );
    final transcriptStyle = tester.widget<Text>(transcriptFinder).style!;
    final inheritedTranscriptStyle =
        DefaultTextStyle.of(tester.element(transcriptFinder)).style;
    expect(
      inheritedTranscriptStyle.merge(transcriptStyle).fontFamily,
      'Nunito',
    );
    expect(inheritedTranscriptStyle.merge(transcriptStyle).fontSize, 14);
    expect(find.byTooltip('Xem text đã phân tích'), findsNothing);
    expect(find.textContaining('thịt kho và canh bí'), findsOneWidget);
    expect(find.text('12:00 – 13:45 · ngủ ngon'), findsOneWidget);
    expect(find.text('Vẽ tranh mùa thu · rất hứng thú'), findsOneWidget);
    expect(find.text('Bản ghi gốc'), findsOneWidget);
    expect(find.text('01:24'), findsOneWidget);
    expect(reviewAudioPlayer.sourceLoaded, isTrue);
    expect(find.byKey(const ValueKey('analyzed-text-card')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('analyzed-text-card'))),
        const Offset(20, 197));
    expect(tester.getSize(find.byKey(const ValueKey('analyzed-text-card'))),
        const Size(350, 187)); // card 173px + 14px bottom gap
    expect(find.byType(Slider), findsNothing);
    final waveformBars = find.descendant(
      of: find.byKey(const ValueKey('audio-waveform')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(99),
      ),
    );
    expect(waveformBars, findsNWidgets(16));
    expect(
      tester.getTopLeft(waveformBars.at(1)).dx -
          tester.getTopLeft(waveformBars.first).dx,
      5,
    );
    expect(
        find.byKey(const ValueKey('analyzed-text-badge-pill')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('analyzed-text-badge-dot')), findsOneWidget);
    expect(find.byKey(const ValueKey('analyzed-text-divider')), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('analyzed-text-badge-pill')))
          .contains(tester
              .getRect(find.byKey(const ValueKey('analyzed-text-badge-dot')))
              .center),
      isTrue,
    );
    final semantics = tester.ensureSemantics();
    final slider = find.bySemanticsLabel('Tiến trình bản ghi âm');
    final waveform = find.byKey(const ValueKey('audio-waveform'));
    try {
      expect(slider, findsOneWidget);
      final sliderData = tester.getSemantics(slider).getSemanticsData();
      expect(sliderData.hasAction(SemanticsAction.increase), isTrue);
      expect(sliderData.hasAction(SemanticsAction.decrease), isTrue);
      expect(sliderData.hasAction(SemanticsAction.tap), isFalse);
      expect(sliderData.hasAction(SemanticsAction.scrollLeft), isFalse);
      expect(sliderData.hasAction(SemanticsAction.scrollRight), isFalse);
      expect(sliderData.increasedValue, '01:02 / 01:24');
      expect(sliderData.decreasedValue, '00:53 / 01:24');
      final sliderNode = tester.getSemantics(slider);
      sliderNode.owner!.performAction(sliderNode.id, SemanticsAction.increase);
      expect(reviewAudioPlayer.lastSeek, const Duration(milliseconds: 62200));
      sliderNode.owner!.performAction(sliderNode.id, SemanticsAction.decrease);
      expect(reviewAudioPlayer.lastSeek, const Duration(milliseconds: 53800));
    } finally {
      semantics.dispose();
    }

    Focus.of(tester.element(waveform)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(reviewAudioPlayer.lastSeek, const Duration(milliseconds: 62200));

    await tester.tap(waveform);
    expect(reviewAudioPlayer.lastSeek, const Duration(seconds: 42));
    final waveformSize = tester.getSize(waveform);
    await tester.drag(waveform, Offset(waveformSize.width / 4, 0));
    expect(reviewAudioPlayer.lastSeek!.inSeconds, greaterThan(50));
    final waveformTopLeft = tester.getTopLeft(waveform);
    await tester.dragFrom(
      waveformTopLeft + Offset(waveformSize.width - 3, waveformSize.height / 2),
      const Offset(30, 0),
    );
    expect(reviewAudioPlayer.lastSeek, const Duration(seconds: 84));
    await tester.dragFrom(
      waveformTopLeft + Offset(3, waveformSize.height / 2),
      const Offset(-30, 0),
    );
    expect(reviewAudioPlayer.lastSeek, Duration.zero);
    Focus.of(tester.element(waveform)).unfocus();
    await tester.ensureVisible(find.text('Duyệt'));
    await tester.tap(find.text('Duyệt'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-approved-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-approved-dot')), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('review-approved-pill')))
          .contains(
            tester
                .getRect(find.byKey(const ValueKey('review-approved-dot')))
                .center,
          ),
      isTrue,
    );
    expect(find.text('Hoàn thành'), findsOneWidget);
    expect(find.text('Bỏ duyệt'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(SurfaceBox)), const Offset(20, 384));
    expect(tester.getSize(find.byType(SurfaceBox)), const Size(352, 246));
    expect(tester.getSize(find.byType(AudioPlayerCard)), const Size(350, 82));
    final discardButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Loại bỏ'));
    expect(
      discardButton.style!.foregroundColor!.resolve({}),
      KPalette.gardenVoice.badText,
    );
    expect(
      tester.getTopLeft(find.widgetWithText(FilledButton, 'Hoàn thành')),
      const Offset(20, 644),
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Hoàn thành')),
      const Size(350, 48),
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Hoàn thành'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Loại bỏ'), findsOneWidget);
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).bottomNavigationBar,
        isNull);
    await captureUi(tester, 'teacher-report-review-gv', settle: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('processing failure uses the Garden Voice recovery screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(ProcessingScreen(
        mode: RecordMode.classroom,
        file: PlatformFile(
          name: 'ghi-am-minh-an.m4a',
          size: 4,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
        teacherRepository: FailingTeacherRepo(),
        onBack: () {},
        onDone: (_, __) {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chưa xử lý được bản ghi âm'), findsOneWidget);
    expect(find.text('Quay lại'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'teacher-processing-error');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmatched segment uses a data-driven confirmation header',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            transcript: 'Hôm nay Minh An ăn cơm. Chiều bé vẽ tranh mùa thu.',
            childExtractions: {
              'child-1': {'meals': 'Ăn cơm ngoan'},
            },
            rawJson: {
              'unmatched_segments': [
                {
                  'text': 'Chiều bé vẽ tranh mùa thu.',
                  'extraction': {'activities': 'Vẽ tranh mùa thu'},
                },
              ],
            },
          ),
          repository: _Dashboard(),
          onBack: () {},
          onCompleted: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Xem lại bản ghi'), findsOneWidget);
    expect(find.text('Lớp Mầm 1 · 1 đoạn cần cô xác nhận'), findsOneWidget);
    expect(find.text('Đã nhận ra · Minh An'), findsOneWidget);
    expect(find.text('Chưa xác định bé'), findsOneWidget);
    expect(find.text('Văn bản đã phân tích'), findsNothing);
    expect(find.text('Đã nhận ra · Minh An'), findsOneWidget);
    expect(find.text('Gán đoạn này'), findsOneWidget);
    expect(find.text('Bỏ qua đoạn này'), findsOneWidget);
    expect(find.text('Duyệt'), findsNothing);
    await captureUi(tester, 'teacher-unmatched-review-gv', settle: false);
    await tester.tap(find.text('Gán đoạn này'));
    await tester.pumpAndSettle();
    expect(find.text('Gán đoạn ghi'), findsOneWidget);
    expect(find.text('Cả lớp Mầm 1'), findsOneWidget);
    await captureUi(tester, 'teacher-unmatched-assign-gv');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('report editing uses the Garden Voice full-screen form',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            transcript: 'Hôm nay Minh An ăn hết suất cơm và ngủ ngon.',
            childExtractions: {
              'child-1': {
                'meals':
                    'Ăn hết suất cơm với thịt kho và canh bí, uống đủ nước.',
                'sleeping':
                    'Ngủ từ 12:00 đến 13:45, ngủ ngon, không quấy khóc.',
                'health': 'Bình thường, không sốt, chơi ngoan cả ngày.',
                'mood': 'Vui vẻ, hợp tác với cô và các bạn.',
                'activities': 'Vẽ tranh mùa thu, tập thể dục buổi sáng.',
                'notes':
                    'Chiều bé hơi ho nhẹ, gia đình theo dõi thêm giúp cô nhé.',
              },
            },
          ),
          repository: _Dashboard(),
          onBack: () {},
          onCompleted: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chỉnh sửa'));
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa báo cáo'), findsOneWidget);
    expect(find.text('Thời lượng (phút)'), findsOneWidget);
    expect(find.text('Sức khỏe'), findsOneWidget);
    expect(find.text('Gửi báo cáo'), findsNothing);
    await captureUi(tester, 'teacher-report-edit-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('processing issue and review CTAs open real flows',
      (tester) async {
    var returnedToRecording = false;
    await tester.pumpWidget(app(GardenVoiceScope(
      child: ProcessingScreen(
        mode: RecordMode.classroom,
        file: PlatformFile(
          name: 'ghi-am-minh-an.m4a',
          size: 4,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
        teacherRepository: _ProcessingCaptureRepo(),
        onBack: () => returnedToRecording = true,
        onDone: (_, __) {},
      ),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sự cố'), findsOneWidget);
    expect(find.text('Xem lại'), findsOneWidget);
    await tester.tap(find.text('Sự cố'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Báo lỗi & góp ý'), findsOneWidget);
    Navigator.of(tester.element(find.text('Báo lỗi & góp ý'))).pop();
    await tester.pump();
    await tester.tap(find.text('Xem lại'));
    expect(returnedToRecording, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion uses the Garden Voice mascot and real summary counts',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: DoneScreenView(
          parentReportsCount: 1,
          healthRecordsCount: 1,
          recordingTime: '10:24',
          onBack: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi thành công.'), findsOneWidget);
    expect(find.text('Xác nhận lúc 10:24'), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
        find.widgetWithText(FilledButton, 'Về tổng quan lớp'), findsOneWidget);
    await captureUi(tester, 'teacher-done-gv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion hides the health summary when no health record saved',
      (tester) async {
    await tester.pumpWidget(app(GardenVoiceScope(
      child: DoneScreenView(
        parentReportsCount: 1,
        healthRecordsCount: 0,
        recordingTime: '10:24',
        onBack: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('ghi nhận vào sổ sức khỏe'), findsNothing);
    expect(find.textContaining('Sổ sức khỏe có 0 dòng mới'), findsOneWidget);
  });

  testWidgets('completion remains scrollable at 320dp and 200% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2)),
      child: GardenVoiceScope(
        child: DoneScreenView(
          parentReportsCount: 2,
          healthRecordsCount: 1,
          recordingTime: '10:24',
          onBack: _noop,
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('analyzed text card fits 320dp at 200% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2)),
      child: GardenVoiceScope(
        child: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AnalyzedTextCard(
              text: 'Bản ghi tiếng Việt cần kiểm tra ở màn hình hẹp.',
              matchedChildCount: 1,
            ),
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('frame 09 và 10 giữ bố cục gọn ở 390 với font thật',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture'),
        child: app(const GardenVoiceScope(
            child: ParentRequestFormScreen(
                child: child,
                className: 'Lớp Mầm 1',
                teacherName: 'Cô Nguyễn Ngọc Anh')))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField),
        'Bé bị sốt, gia đình xin cho bé nghỉ để theo dõi thêm.');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('GỬI ĐƠN')).bottom, lessThan(750));
    await captureUi(tester, 'parent-absence');
    await tester.tap(find.text('Báo đi trễ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField),
        'Gia đình có việc buổi sáng, sẽ đưa bé đến lớp muộn hơn thường lệ.');
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Minh An'), findsNothing);
    expect(tester.getRect(find.text('GỬI THÔNG BÁO')).bottom, lessThan(600));
    await captureUi(tester, 'parent-late');
    expect(tester.takeException(), isNull);
  });

  testWidgets('frame 08, 22, 23, 25 render từ cùng dữ liệu đơn thật',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pendingRequest = {
      ...requestJson(),
      'from_date': '2026-11-06',
      'to_date': '2026-11-07',
      'child_name': 'Nguyễn Minh An',
      'reason': 'Bé bị sốt, nghỉ theo dõi',
      'created_at': '2026-10-29T07:05:00+07:00',
      'attachment_url': 'leave-requests/child-1/attachment-1.jpg',
      'contact_phone': '0905123123'
    };
    final transport = RequestTransport((request) {
      final items = [
        pendingRequest,
        {
          ...requestJson(status: 'approved'),
          'request_id': 'request-2',
          'child_name': 'Trần Bảo Ngọc',
          'parent_name': 'Mẹ Bảo Ngọc',
          'from_date': '2026-11-03',
          'to_date': '2026-11-03',
          'reason': 'Gia đình có việc riêng, xin cho bé nghỉ một ngày.',
          'reviewer_name': 'Cô Thị Mai',
          'reviewed_at': '2026-11-03T06:45:00+07:00'
        },
        {
          ...requestJson(status: 'rejected'),
          'request_id': 'request-3',
          'from_date': '2026-10-28',
          'to_date': '2026-10-28',
          'reason': 'Xin nghỉ để bé đi chơi cùng gia đình.',
          'reject_reason':
              'Thông tin chưa rõ ràng, phụ huynh bổ sung giúp cô thời gian cụ thể nhé.',
          'reviewed_at': '2026-10-27T09:00:00+07:00'
        },
      ];
      if (request.path.endsWith('/request-1')) {
        return jsonBody({
          ...requestJson(status: 'approved'),
          'from_date': '2026-11-03',
          'to_date': '2026-11-03',
          'reason': 'Gia đình có việc riêng, xin cho bé nghỉ một ngày.',
          'reviewer_name': 'Cô Thị Mai',
          'reviewed_at': '2026-11-03T06:45:00+07:00'
        });
      }
      return jsonBody(request.path.endsWith('/mine')
          ? {'items': items, 'total': 3, 'offset': 0, 'limit': 20}
          : {
              'items': request.queryParameters['tab'] == 'reviewed'
                  ? [items[1]]
                  : [
                      items.first,
                      {
                        ...requestJson(),
                        'request_id': 'request-4',
                        'child_name': 'Lê Hoàng Nam',
                        'parent_name': 'Bố Hoàng Nam',
                        'from_date': '2026-11-07',
                        'to_date': '2026-11-08',
                        'reason':
                            'Gia đình có việc riêng, xin cho bé nghỉ hai ngày.',
                      },
                    ],
              'pending_count': 2,
              'reviewed_count': 2
            });
    });
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    final medicationRepository = HttpMedicationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = RequestTransport((request) {
            if (request.path == '/api/medication-requests') {
              return jsonBody([
                {
                  'id': 'dose-1',
                  'child_id': 'child-1',
                  'class_id': 'class-1',
                  'child_name': 'Bé Bình',
                  'medicine_name': 'Siro ho',
                  'dosage': '5ml',
                  'status': 'pending',
                  'created_at': '2026-11-09T08:00:00+07:00',
                }
              ]);
            }
            if (request.path == '/api/teacher/health-incidents') {
              return jsonBody([
                {
                  'incident_id': 'incident-1',
                  'child_id': 'child-2',
                  'child_name': 'Bé Chi',
                  'class_id': 'class-1',
                  'incident_type': 'high_fever',
                  'incident_type_label': 'Sốt cao',
                  'description': 'Bé sốt cao, cô đã liên hệ gia đình.',
                  'temperature': 39,
                  'action_taken': 'Chườm ấm',
                  'reported_at': '2026-11-09T09:00:00+07:00',
                  'reported_by_name': 'Cô Mai',
                }
              ]);
            }
            return transport.respond(request);
          }));
    final attendanceRepository = HttpAttendanceRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = RequestTransport((request) => jsonBody({
                'class_id': 'class-1',
                'date': '2026-11-09',
                'total_children': 1,
                'present_count': 0,
                'absent_count': 0,
                'excused_absent_count': 0,
                'late_count': 1,
                'children': [
                  {
                    'child_id': 'child-3',
                    'full_name': 'Minh An',
                    'status': 'late',
                    'expected_arrival_time': '08:30:00',
                  }
                ],
              })));
    final dashboardRepository = HttpDashboardRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = RequestTransport((request) => jsonBody({
                'class_info': {
                  'class_id': 'class-1',
                  'school_id': 'school-1',
                  'name': 'Mầm 1',
                },
                'teacher_name': 'Cô Mai',
                'total_children': 5,
                'completed_count': 4,
                'draft_count': 0,
                'missing_count': 1,
                'pending_children': [
                  {
                    'child': {
                      'child_id': 'child-4',
                      'full_name': 'Gia Hân',
                    },
                    'status': null,
                  }
                ],
              })));
    for (final entry in <String, Widget>{
      'parent-history': GardenVoiceScope(
          child: ParentRequestsScreen(
              child: child,
              className: 'Lớp Mầm 1',
              teacherName: 'Cô Mai',
              repository: repository)),
      'teacher-inbox': TeacherNotificationsScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          repository: repository,
          medicationRepository: medicationRepository,
          attendanceRepository: attendanceRepository,
          dashboardRepository: dashboardRepository),
      'teacher-review': LeaveRequestReviewScreen(
          classId: 'class-1', className: 'Lớp Mầm 1', repository: repository),
    }.entries) {
      await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('capture'), child: app(entry.value)));
      await tester.pumpAndSettle();
      if (entry.key == 'teacher-inbox') {
        final navigation =
            find.byKey(const ValueKey('garden-voice-teacher-navigation'));
        expect(navigation, findsOneWidget);
        expect(tester.getTopLeft(navigation).dy, inInclusiveRange(740, 790));
      }
      expect(find.textContaining('3 mới'), findsNothing);
      await captureUi(tester, entry.key);
      if (entry.key == 'parent-history') {
        await tester.tap(find.text('Thứ 6, 06/11 – Thứ 7, 07/11 · 2 ngày'));
        await tester.pumpAndSettle();
        await captureUi(tester, 'parent-request-detail');
        Navigator.of(tester.element(find.text('Chi tiết đơn'))).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    }
    await tester
        .tap(find.byKey(const ValueKey('leave-request-preview-request-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        'Gia đình vui lòng bổ sung giấy khám bệnh của bé rồi gửi lại giúp cô nhé.');
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-reject');
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(LeaveRequestReviewScreen(
        classId: 'class-1',
        className: 'Lớp Mầm 1',
        repository: repository,
        initialRequest: LeaveRequestEntity.fromJson(pendingRequest),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đơn · Lớp Mầm 1'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      Colors.white,
    );
    await captureUi(tester, 'teacher-review-detail');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Batch 1 Teacher Shell tabs (564:1706, 453:1389, 454:827, 562:1668) render in Garden Voice',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const roster = <ui.Child>[
      ui.Child(
        id: 'child-1',
        name: 'Nguyễn Minh An',
        status: ui.ReportStatus.none,
        present: true,
        time: '08:00',
        severity: ui.Severity.none,
        allergy: 'Đậu phộng',
      ),
      ui.Child(
        id: 'child-2',
        name: 'Trần Bảo Ngọc',
        status: ui.ReportStatus.none,
        present: true,
        time: '08:05',
        severity: ui.Severity.none,
        careNotes: 'Mới quen lớp',
      ),
      ui.Child(
        id: 'child-3',
        name: 'Lê Hoàng Nam',
        status: ui.ReportStatus.submitted,
        present: true,
        time: '07:55',
        severity: ui.Severity.none,
      ),
      ui.Child(
        id: 'child-4',
        name: 'Phạm Thu Hà',
        status: ui.ReportStatus.submitted,
        present: true,
        time: '08:00',
        severity: ui.Severity.none,
      ),
    ];

    // 1. 564:1706 — Danh sách lớp (ClassListScreen)
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: Scaffold(
          body: ClassListScreen(
            initialHealthOnly: false,
            children: roster,
            className: 'Lớp Mầm A',
            teacherName: 'Cô Nguyễn Thị Hương',
            pendingLeaveCount: 2,
            onRecord: (_) {},
            onEdit: (_) {},
            onOpenAttendance: () {},
            onOpenLeaveRequests: () {},
            onOpenTimetable: () {},
            onOpenNotifications: () {},
          ),
          bottomNavigationBar: GardenVoiceTeacherNavigation(
            selected: GardenVoiceTeacherDestination.classList,
            onSelected: (_) {},
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Lớp Mầm A'), findsOneWidget);
    expect(find.text('Cô Nguyễn Thị Hương'), findsOneWidget);
    expect(find.text('Danh sách'), findsOneWidget);
    expect(find.text('Điểm danh'), findsOneWidget);
    expect(find.text('Đơn nghỉ'), findsOneWidget);
    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Chưa ghi'), findsNWidgets(2));
    expect(find.text('Đã ghi'), findsNWidgets(2));
    await captureUi(tester, 'teacher-class-list-gv');
    expect(tester.takeException(), isNull);

    // 2. 453:1389 — 11 — Lịch sử báo cáo (HistoryScreen)
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: Scaffold(
          body: HistoryScreen(
            children: roster,
            repository: _Batch1TeacherDashboard(),
            referenceDate: DateTime(2026, 11, 5, 12, 0),
            onOpenReport: (_, __) {},
          ),
          bottomNavigationBar: GardenVoiceTeacherNavigation(
            selected: GardenVoiceTeacherDestination.reports,
            onSelected: (_) {},
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('Báo cáo ngày · 10:24'), findsOneWidget);
    expect(find.text('Cần chú ý'), findsOneWidget);
    await captureUi(tester, 'teacher-report-history-gv');
    expect(tester.takeException(), isNull);

    // 3. 454:827 — 12 — Tài khoản giáo viên (TeacherAccountScreen)
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: Scaffold(
          body: TeacherAccountScreen(
            onLogout: () {},
            classId: 'class-1',
            schoolName: 'Mầm non Hoa Hướng Dương',
            repository: _Batch1TeacherDashboard(),
            classRepository: _Batch1ClassRepo(),
            onOpenNotifications: () {},
          ),
          bottomNavigationBar: GardenVoiceTeacherNavigation(
            selected: GardenVoiceTeacherDestination.account,
            onSelected: (_) {},
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cô Nguyễn Thị Hương'), findsOneWidget);
    expect(find.text('Giáo viên chủ nhiệm'), findsOneWidget);
    expect(find.text('Lớp Mầm A · Mầm non Hoa Hướng Dương'), findsOneWidget);
    expect(find.text('Xem hồ sơ'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Tùy chọn'), findsOneWidget);
    expect(find.text('Hỗ trợ'), findsOneWidget);
    expect(find.text('Giao diện'), findsNothing);
    await captureUi(tester, 'teacher-account-gv');
    expect(tester.takeException(), isNull);

    // 4. 562:1668 — Chọn giao diện (ThemeSelector widget)
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(const GardenVoiceScope(
        child: Scaffold(body: ThemeSelector()),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chọn cách hiển thị KinderLog trên thiết bị.'),
        findsOneWidget);
    expect(find.text('Đang dùng'), findsOneWidget);
    expect(find.text('Nền giấy ấm, rõ trong lớp học'), findsOneWidget);
    expect(find.text('Giảm chói khi xem buổi tối'), findsOneWidget);
    expect(find.text('Tự đổi theo cài đặt điện thoại'), findsOneWidget);
    await captureUi(tester, 'teacher-theme-selector-gv');
    expect(tester.takeException(), isNull);

    // 5. Kiểm tra 320dp + 200% text scale không tràn bố cục
    tester.view.physicalSize = const Size(320, 844);
    for (final screen in <Widget>[
      ClassListScreen(
        initialHealthOnly: false,
        children: roster,
        className: 'Lớp Mầm A',
        teacherName: 'Cô Nguyễn Thị Hương',
        pendingLeaveCount: 2,
        onRecord: (_) {},
        onEdit: (_) {},
      ),
      HistoryScreen(
        children: roster,
        repository: _Batch1TeacherDashboard(),
        referenceDate: DateTime(2026, 11, 5, 12, 0),
        onOpenReport: (_, __) {},
      ),
      TeacherAccountScreen(
        onLogout: () {},
        classId: 'class-1',
        schoolName: 'Mầm non Hoa Hướng Dương',
        repository: _Batch1TeacherDashboard(),
        classRepository: _Batch1ClassRepo(),
      ),
    ]) {
      await tester.pumpWidget(app(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: GardenVoiceScope(child: Scaffold(body: screen)),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Batch 4 captures parent medication frames M1 to M3',
      (tester) async {
    final today = medicationDateInVietnam(DateTime.now());
    final history = [
      _batch4Dose(
        id: 'given-1',
        batchId: 'batch-1',
        status: 'given',
        timeSlot: '08:30',
        requestDate: today,
        givenByName: 'Cô Thị Mai',
        givenAt: DateTime.utc(2026, 11, 4, 1, 32),
      ),
      _batch4Dose(
        id: 'pending-1',
        batchId: 'batch-1',
        status: 'pending',
        timeSlot: '11:30',
        requestDate: today.add(const Duration(days: 2)),
      ),
      _batch4Dose(
        id: 'done-1',
        batchId: 'batch-2',
        status: 'given',
        timeSlot: '08:30',
        name: 'Vitamin D3',
        dosage: 'Chờ xác minh liều dùng',
        requestDate: DateTime(2026, 10, 27),
        givenByName: 'Cô Nguyễn Thị Mai',
        givenAt: DateTime.utc(2026, 10, 27, 1, 32),
      ),
      _batch4Dose(
        id: 'done-2',
        batchId: 'batch-2',
        status: 'given',
        timeSlot: '11:30',
        name: 'Vitamin D3',
        dosage: 'Chờ xác minh liều dùng',
        requestDate: DateTime(2026, 10, 31),
        givenByName: 'Cô Nguyễn Thị Mai',
        givenAt: DateTime.utc(2026, 10, 31, 4, 30),
      ),
    ];
    final repo = _Batch4MedicationRepository(
      history: history,
      today: _batch4TeacherToday(),
    );
    await _pumpBatch4Capture(
      tester,
      ParentMedicationScreen(
        child: child,
        className: 'Mầm 1',
        repository: repo,
      ),
      'parent-medication-m1-gv',
    );
    expect(find.text('Dặn dò uống thuốc'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);

    await _pumpBatch4Capture(
      tester,
      ParentMedicationFormScreen(
        child: child,
        className: 'Mầm 1',
        repository: repo,
      ),
      'parent-medication-m2-gv',
    );
    expect(find.text('Khung giờ uống (chọn nhiều)'), findsOneWidget);
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).bottomNavigationBar,
        isNotNull);

    await _pumpBatch4Capture(
      tester,
      ParentMedicationSubmittedScreen(
        result: MedicationBatchCreateResult(
          'batch-new',
          [
            _batch4Dose(
              id: 'new-1',
              batchId: 'batch-new',
              status: 'pending',
              timeSlot: '08:30',
              requestDate: DateTime(2026, 11, 4),
            ),
            _batch4Dose(
              id: 'new-2',
              batchId: 'batch-new',
              status: 'pending',
              timeSlot: '11:30',
              requestDate: DateTime(2026, 11, 6),
            ),
          ],
        ),
      ),
      'parent-medication-m3-gv',
    );
    expect(find.text('Đã tạo đơn dặn thuốc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batch 4 captures parent medication detail and cancel M4/M5',
      (tester) async {
    final repo = _Batch4MedicationRepository(
      history: [
        _batch4Dose(
          id: 'given-1',
          batchId: 'batch-1',
          status: 'given',
          timeSlot: '08:30',
          requestDate: DateTime(2026, 11, 11),
          givenByName: 'Cô Nguyễn Thị Mai',
          givenAt: DateTime.utc(2026, 11, 11, 1, 32),
        ),
        _batch4Dose(
          id: 'pending-1',
          batchId: 'batch-1',
          status: 'pending',
          timeSlot: '11:30',
          requestDate: DateTime(2026, 11, 11),
        ),
      ],
      today: _batch4TeacherToday(),
    );
    await _pumpBatch4Capture(
      tester,
      ParentMedicationDetailScreen(
        child: child,
        className: 'Mầm 1',
        batchId: 'batch-1',
        repository: repo,
      ),
      'parent-medication-m4-gv',
    );
    expect(
        find.textContaining('Cô Nguyễn Thị Mai đã cho uống'), findsOneWidget);
    final cancelButtons = find.widgetWithText(FilledButton, 'Hủy cữ này');
    expect(
        tester.widgetList<FilledButton>(cancelButtons).first.onPressed, isNull);

    await tapVisible(tester, cancelButtons.last);
    await tester.pumpAndSettle();
    await captureUi(tester, 'parent-medication-m5-gv');
    expect(find.text('Giữ lại'), findsOneWidget);
    expect(find.text('Hủy cữ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batch 4 captures teacher medication M6/M7 after server reload',
      (tester) async {
    final repo = _Batch4MedicationRepository(
      history: const [],
      today: _batch4TeacherToday(),
      confirmedToday: _batch4TeacherToday(confirmed: true),
    );
    await _pumpBatch4Capture(
      tester,
      TeacherMedicationScreen(
        repository: repo,
        initialDate: '2026-11-11',
      ),
      'teacher-medication-m6-gv',
    );
    expect(find.text('Nguyễn Minh An'), findsOneWidget);
    expect(find.byKey(const ValueKey('medication-status-dot')), findsWidgets);
    expect(find.byKey(const ValueKey('garden-voice-teacher-navigation')),
        findsOneWidget);

    await tapVisible(tester, find.text('Xác nhận đã cho uống thuốc').first);
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-medication-m7-gv');
    expect(find.text('Xác nhận đã khóa để tránh trùng liều'), findsOneWidget);
    expect(find.textContaining('Chưa có xác nhận giao'), findsOneWidget);
    expect(repo.confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batch 4 captures teacher emergency M8/M9 from API contacts',
      (tester) async {
    const contacts = [
      {
        'name': 'Mẹ Minh An',
        'relationship': 'Mẹ',
        'phone': '0909123456',
      },
    ];
    final repo = _Batch4MedicationRepository(
      history: const [],
      today: _batch4TeacherToday(),
      contacts: contacts,
    );
    const student = ui.Child(
      id: 'child-1',
      name: 'Nguyễn Minh An',
      status: ui.ReportStatus.none,
      present: true,
      time: '',
      severity: ui.Severity.none,
    );
    await _pumpBatch4Capture(
      tester,
      TeacherEmergencySheet(
        children: const [student],
        initialChildId: 'child-1',
        repository: repo,
      ),
      'teacher-emergency-m8-gv',
    );
    expect(find.text('Người nhận cảnh báo'), findsOneWidget);
    expect(find.textContaining('Mẹ Minh An'), findsOneWidget);
    expect(find.text('Ban giám hiệu'), findsNothing);

    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-emergency-m9-gv');
    expect(find.textContaining('Chưa có xác nhận giao thông báo đẩy'),
        findsOneWidget);
    expect(find.text('Gọi phụ huynh ngay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batch 4 captures parent emergency alert 563:1649',
      (tester) async {
    EmergencySirenService.instance.enabled = false;
    addTearDown(() => EmergencySirenService.instance.enabled = true);
    await _pumpBatch4Capture(
      tester,
      EmergencyAlertSummaryScreen(
        alert: EmergencyAlertData(
          incidentId: 'incident-1',
          childId: 'child-1',
          childName: 'Nguyễn Minh An',
          incidentType: 'Nôn ói',
          teacherName: 'Cô Nguyễn Thị Mai',
          teacherPhone: '0909123456',
          description: 'Bé nôn sau khi uống thuốc 10 phút.',
          createdAt: DateTime.utc(2026, 11, 11, 3, 47),
        ),
        onDismiss: () {},
      ),
      'parent-emergency-alert-gv',
      settle: false,
    );
    expect(find.text('Cảnh báo khẩn'), findsOneWidget);
    expect(find.text('Đã nắm thông tin · Tắt chuông'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batch 5 captures the assigned auth, report, and recorder states',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(LoginScreen(
        authRepository: _Batch5AuthRepository(),
        onLogin: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-login-gv');
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(const NoAssignmentScreen(
        title: 'Chưa được phân lớp',
        message:
            'Tài khoản của bạn chưa được Ban giám hiệu phân vào lớp nào. Vui lòng liên hệ nhà trường để được hỗ trợ, hoặc thử đăng nhập lại sau.',
        onBack: _noop,
        gardenVoice: true,
      )),
    ));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-no-assignment-gv');
    expect(find.text('Đăng xuất'), findsOneWidget);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(ChangePasswordScreen(
        authRepository: _Batch5AuthRepository(),
        onBack: _noop,
      )),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'current123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'different123');
    await tester.tap(find.widgetWithText(KButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-change-password-gv');
    expect(find.text('Yêu cầu mật khẩu mới'), findsOneWidget);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showBugReportBottomSheet(context),
              child: const Text('Mở góp ý'),
            ),
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở góp ý'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-bug-report-gv');
    expect(find.text('Ảnh đính kèm · tối đa 5 ảnh, mỗi ảnh ≤ 5MB'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();

    const actionChild = ui.Child(
      id: 'child-1',
      name: 'Nguyễn Minh An',
      status: ui.ReportStatus.none,
      present: true,
      time: '',
      severity: ui.Severity.none,
      allergy: 'Đậu phộng',
    );
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(Scaffold(
        body: ClassListScreen(
          initialHealthOnly: false,
          children: const [actionChild],
          className: 'Lớp Mầm 1',
          onRecord: (_) {},
          onEdit: (_) {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nguyễn Minh An'));
    await tester.tap(find.text('Nguyễn Minh An'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-child-actions-gv');
    expect(find.text('Ghi âm cho bé'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(ReportEditorScreen(
        child: const ui.Child(
          id: '',
          name: 'Trần Bảo Ngọc',
          status: ui.ReportStatus.draft,
          present: true,
          time: '',
          severity: ui.Severity.none,
        ),
        classId: 'class-1',
        repository: _Batch1TeacherDashboard(),
        classRepository: _Batch1ClassRepo(),
        onSent: _noop,
      )),
    ));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-report-editor-gv');
    expect(find.text('Chỉnh sửa báo cáo'), findsOneWidget);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(RecordingScreen(
        mode: RecordMode.child,
        child: actionChild,
        className: 'Lớp Mầm 1',
        audioRecorder: _Batch5DeniedRecorder(),
        onSubmit: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bắt đầu ghi âm'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-recording-permission-gv');
    expect(find.text('Chưa có quyền micro'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có quyền micro'), findsNothing);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(RecordingScreen(
        key: const ValueKey('recording-error-capture'),
        mode: RecordMode.child,
        child: actionChild,
        className: 'Lớp Mầm 1',
        audioRecorder: _Batch5FailingRecorder(),
        pathProvider: (_) async => 'capture.m4a',
        onSubmit: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bắt đầu ghi âm'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-recording-error-gv');
    expect(find.text('Chưa thể ghi âm'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    final classwideReview = ReviewScreen(
      classId: 'class-1',
      className: 'Lớp Mầm 1',
      extraction: const ExtractionData(
        classWideExtraction: {
          'activities': 'Vẽ tranh mùa thu, rất hứng thú.',
        },
        childExtractions: {
          'child-1': {
            'meals': 'Ăn hết suất cơm.',
            'sleeping': 'Ngủ từ 12:00 đến 13:45.',
          },
        },
      ),
      voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
      repository: _ReviewCaptureDashboard(),
      teacherRepository: _Batch5ReviewRepo(),
      onBack: _noop,
      onCompleted: _noop,
    );
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(child: classwideReview)),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Duyệt tất cả'));
    await tester.tap(find.text('Duyệt tất cả'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-review-classwide-gv');
    expect(find.text('Xác nhận gửi cho cả lớp'), findsOneWidget);
    await tester.tap(find.text('Xác nhận gửi cho cả lớp'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-done-classwide-gv');
    expect(find.text('Về tổng quan lớp'), findsOneWidget);

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('capture'),
      child: app(GardenVoiceScope(
        child: ReviewScreen(
          key: const ValueKey('review-after-skip'),
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            childExtractions: {
              'child-1': {
                'meals': 'Ăn hết suất cơm.',
                'sleeping': 'Ngủ từ 12:00 đến 13:45.',
              },
            },
            rawJson: {
              'unmatched_segments': [
                {
                  'text': 'vẽ tranh mùa thu',
                  'extraction': {'activities': 'Vẽ tranh mùa thu.'},
                },
              ],
            },
          ),
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: _ReviewCaptureDashboard(),
          teacherRepository: _Batch5ReviewRepo(),
          onBack: _noop,
          onCompleted: _noop,
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bỏ qua đoạn này'));
    await tester.tap(find.text('Bỏ qua đoạn này'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Duyệt'));
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'teacher-review-after-skip-gv');
    expect(find.text('Xử lý lại đoạn ghi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Batch5ReviewRepo extends _ReviewCaptureRepo {
  @override
  Future<Map<String, dynamic>> sendBatch({
    required String teacherId,
    List<String>? reportIds,
    String? classId,
    String? reportDate,
  }) async =>
      {
        'sent': reportIds?.length ?? 0,
        'skipped': 0,
        'failed': 0,
      };
}

class _Batch5AuthRepository extends AuthRepository {
  @override
  Future<({String username, String password})?> readRememberedLogin() async =>
      (username: 'giaovien', password: 'fixture-password');
}

class _Batch5DeniedRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> dispose() async {}
}

class _Batch5FailingRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    throw StateError('recorder unavailable');
  }

  @override
  Future<void> dispose() async {}
}
