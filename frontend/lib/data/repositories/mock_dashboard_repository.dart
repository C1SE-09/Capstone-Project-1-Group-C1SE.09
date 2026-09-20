// frontend/lib/data/repositories/mock_dashboard_repository.dart
// =========================================================
// MOCK IMPLEMENTATION của DashboardRepository.
//
// Bây giờ trả về DATA CỨNG để UI chạy được ngay.
// SAU NÀY khi backend có API đầy đủ, tạo 1 class mới
// `HttpDashboardRepository implements DashboardRepository`
// và đổi 1 dòng ở chỗ khởi tạo controller. View không đổi.
//
//   repository: MockDashboardRepository()   ← bây giờ
//   repository: HttpDashboardRepository()   ← sau này (Dio)

import 'package:adark_frontend/domain/entities/activity_item.dart';
import 'package:adark_frontend/domain/entities/child.dart';
import 'package:adark_frontend/domain/entities/child_overview.dart';
import 'package:adark_frontend/domain/entities/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class_info.dart';
import 'package:adark_frontend/domain/entities/class_report_overview.dart';
import 'package:adark_frontend/domain/entities/daily_report.dart';
import 'package:adark_frontend/domain/entities/parent.dart';
import 'package:adark_frontend/domain/entities/report_status.dart';
import 'package:adark_frontend/domain/entities/teacher.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';

class MockDashboardRepository implements DashboardRepository {
  /// Giả lập độ trễ mạng để thấy được trạng thái loading.
  static const _fakeLatency = Duration(milliseconds: 600);

  Future<void> _delay() => Future.delayed(_fakeLatency);

  // ══════════════════════════════════════════════════════════
  // Teacher
  // ══════════════════════════════════════════════════════════

  @override
  Future<List<ClassReportOverview>> getTeacherClasses() async {
    await _delay();
    return const [
      ClassReportOverview(
        classInfo: ClassInfo(
          classId: 'class-001',
          schoolId: 'school-001',
          name: 'Lớp Mầm 1',
          gradeLabel: 'Mầm',
          roomNumber: 'Phòng A1',
          capacity: 25,
        ),
        teacherName: 'Cô Hà',
        totalChildren: 20,
        completedCount: 15,
        draftCount: 3,
        missingCount: 2,
      ),
      ClassReportOverview(
        classInfo: ClassInfo(
          classId: 'class-002',
          schoolId: 'school-001',
          name: 'Lớp Chồi 1',
          gradeLabel: 'Chồi',
          roomNumber: 'Phòng B1',
          capacity: 24,
        ),
        teacherName: 'Cô Lan',
        totalChildren: 18,
        completedCount: 12,
        draftCount: 4,
        missingCount: 2,
      ),
      ClassReportOverview(
        classInfo: ClassInfo(
          classId: 'class-003',
          schoolId: 'school-001',
          name: 'Lớp Lá 1',
          gradeLabel: 'Lá',
          roomNumber: 'Phòng C1',
          capacity: 22,
        ),
        teacherName: 'Cô Mai',
        totalChildren: 16,
        completedCount: 16,
        draftCount: 0,
        missingCount: 0,
      ),
    ];
  }

  @override
  Future<Teacher> getCurrentTeacher() async {
    await _delay();
    return const Teacher(
      teacherId: 'teacher-001',
      schoolId: 'school-001',
      classId: 'class-001',
      fullName: 'Cô Hà',
      email: 'coha@adark.vn',
      isVerified: true,
    );
  }

  @override
  Future<ClassDashboardSummary> getClassDashboard(
    String classId,
    DateTime date,
  ) async {
    await _delay();
    final now = DateTime.now();

    return ClassDashboardSummary(
      classInfo: const ClassInfo(
        classId: 'class-001',
        schoolId: 'school-001',
        name: 'Lớp Mầm 1',
        gradeLabel: 'Mầm',
        capacity: 25,
      ),
      teacherName: 'Cô Hà',
      totalChildren: 20,
      completedCount: 15,
      draftCount: 3,
      missingCount: 2,
      // 3 trẻ cần giáo viên xử lý (khớp mockup "Cần xử lý")
      pendingChildren: [
        ChildReportItem(
          child: const Child(
            childId: 'child-003',
            classId: 'class-001',
            fullName: 'Lê Thị Mèo',
            nickname: 'Mèo',
          ),
          status: ReportStatus.draft,
          updatedAt: now.subtract(const Duration(minutes: 20)),
        ),
        const ChildReportItem(
          child: Child(
            childId: 'child-007',
            classId: 'class-001',
            fullName: 'Phạm Minh Đức',
          ),
          status: null, // chưa có báo cáo → "Chưa có"
        ),
        const ChildReportItem(
          child: Child(
            childId: 'child-008',
            classId: 'class-001',
            fullName: 'Hoàng Thị Lan',
          ),
          status: null,
        ),
      ],
    );
  }

  @override
  Future<List<ActivityItem>> getRecentActivities(
    String classId, {
    int limit = 10,
  }) async {
    await _delay();
    final now = DateTime.now();
    return [
      ActivityItem(
        type: ActivityType.reportSent,
        message: 'Báo cáo của Nguyễn Thị Nhím đã được gửi',
        occurredAt: now.subtract(const Duration(minutes: 15)),
      ),
      ActivityItem(
        type: ActivityType.reportReviewing,
        message: 'Báo cáo của Nguyễn Minh Khang đang chờ xem lại',
        occurredAt: now.subtract(const Duration(minutes: 48)),
      ),
      ActivityItem(
        type: ActivityType.audioRecorded,
        message: 'Đã ghi âm cho Lê Thị Mèo',
        occurredAt: now.subtract(const Duration(hours: 1)),
      ),
    ];
  }

  @override
  Future<List<Child>> getClassChildren(String classId) async {
    await _delay();
    return const [
      Child(
        childId: 'child-001',
        parentId: 'parent-001',
        classId: 'class-001',
        fullName: 'Nguyễn Thị Nhím',
        nickname: 'Nhím',
      ),
      Child(
        childId: 'child-002',
        classId: 'class-001',
        fullName: 'Nguyễn Minh Khang',
        nickname: 'Khang',
      ),
      Child(
        childId: 'child-003',
        classId: 'class-001',
        fullName: 'Lê Thị Mèo',
        nickname: 'Mèo',
      ),
      Child(
        childId: 'child-004',
        classId: 'class-001',
        fullName: 'Trần Gia Hân',
        nickname: 'Hân',
      ),
      Child(
        childId: 'child-005',
        classId: 'class-001',
        fullName: 'Phạm Đức Anh',
        nickname: 'Đức',
      ),
      Child(
        childId: 'child-006',
        classId: 'class-001',
        fullName: 'Vũ Khánh Linh',
        nickname: 'Linh',
      ),
      Child(
        childId: 'child-007',
        classId: 'class-001',
        fullName: 'Phạm Gia Hân',
        nickname: 'Hân',
      ),
      Child(
        childId: 'child-008',
        classId: 'class-001',
        fullName: 'Trần Ngọc Anh',
        nickname: 'Anh',
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════
  // Parent
  // ══════════════════════════════════════════════════════════

  @override
  Future<Parent> getCurrentParent() async {
    await _delay();
    return const Parent(
      parentId: 'parent-001',
      fullName: 'Phụ huynh bé Nhím',
      phone: '0912345678',
      isVerified: true,
    );
  }

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async {
    await _delay();
    return const ChildOverview(
      child: Child(
        childId: 'child-001',
        parentId: 'parent-001',
        classId: 'class-001',
        fullName: 'Nguyễn Thị Nhím',
        nickname: 'Nhím',
      ),
      className: 'Lớp Mầm 1',
      teacherName: 'Cô Hà',
    );
  }

  @override
  Future<DailyReport?> getTodayReport(String childId, DateTime date) async {
    await _delay();
    // Hôm nay ĐÃ có báo cáo published → banner "đã sẵn sàng"
    return DailyReport(
      dailyReportId: 'report-001',
      childId: childId,
      teacherId: 'teacher-001',
      reportDate: date,
      summaryText: 'Hôm nay bé ăn ngoan, ngủ đủ giấc.',
      status: ReportStatus.published,
      publishedAt: date,
    );
  }

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
  }) async {
    await _delay();
    final today = DateTime.now();
    return [
      DailyReport(
        dailyReportId: 'report-001',
        childId: childId,
        reportDate: today,
        status: ReportStatus.published,
        publishedAt: today,
      ),
      DailyReport(
        dailyReportId: 'report-002',
        childId: childId,
        reportDate: today.subtract(const Duration(days: 1)),
        status: ReportStatus.published,
        publishedAt: today.subtract(const Duration(days: 1)),
      ),
      DailyReport(
        dailyReportId: 'report-003',
        childId: childId,
        reportDate: today.subtract(const Duration(days: 2)),
        status: ReportStatus.published,
        publishedAt: today.subtract(const Duration(days: 2)),
      ),
    ];
  }
}