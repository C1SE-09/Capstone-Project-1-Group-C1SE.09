// frontend/lib/domain/entities/bug_report/bug_report_list_response.dart
// =========================================================
// Entity BugReportListResponse — MIRROR backend
// app/schemas/bug_report.py (BugReportListResponse).
//
// Response phân trang cho 2 list endpoint:
//   GET /api/bug-reports           → list report (admin)
//   GET /api/bug-reports        → admin list tất cả (có filter)

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report.dart';

class BugReportListResponse extends BaseEntity {
  const BugReportListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  final List<BugReport> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory BugReportListResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return BugReportListResponse(
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) =>
                  BugReport.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }
}
