// UI model declarations for the kindergarten dashboard feature.
enum ReportStatus { none, draft, submitted, read, attention, processing }
enum Severity { none, mild, moderate }
enum AttendanceStatus { arrived, absent, late }

extension AttendanceStatusLabel on AttendanceStatus {
  String get label => switch (this) {
        AttendanceStatus.arrived => 'Có mặt',
        AttendanceStatus.absent => 'Vắng',
        AttendanceStatus.late => 'Đi muộn',
      };
}

extension ReportStatusLabel on ReportStatus {
  String get label => switch (this) {
        ReportStatus.none => 'Chưa có',
        ReportStatus.draft => 'Bản nháp',
        ReportStatus.submitted => 'Đã gửi',
        ReportStatus.read => 'Đã đọc',
        ReportStatus.attention => 'Cần xử lý',
        ReportStatus.processing => 'Đang xử lý',
      };
}

extension SeverityLabel on Severity {
  String get label => switch (this) {
        Severity.none => 'Bình thường',
        Severity.mild => 'Nhẹ',
        Severity.moderate => 'Trung bình',
      };
}

class Child {
  const Child({
    required this.id,
    required this.name,
    required this.status,
    required this.present,
    required this.time,
    required this.severity,
    this.nickname,
    this.allergy,
    this.careNotes,
  });

  final String id;
  final String name;
  final String? nickname;
  final ReportStatus status;
  final bool present;
  final String time;
  final String? allergy;
  final String? careNotes;
  final Severity severity;
}

class ClassInfo {
  const ClassInfo(this.id, this.name, this.school, this.count, this.role);

  final String id;
  final String name;
  final String school;
  final int count;
  final String role;
}

class Segment {
  const Segment({
    required this.id,
    required this.name,
    required this.matched,
    required this.eating,
    required this.sleep,
    required this.health,
    required this.severity,
    required this.mood,
    this.childId,
  });

  final String id;
  final String? childId;
  final String name;
  final bool matched;
  final String eating;
  final String sleep;
  final String health;
  final Severity severity;
  final String mood;

  Segment assign(Child child) => Segment(
        id: id,
        childId: child.id,
        name: child.name,
        matched: true,
        eating: eating,
        sleep: sleep,
        health: health,
        severity: severity,
        mood: mood,
      );
}
