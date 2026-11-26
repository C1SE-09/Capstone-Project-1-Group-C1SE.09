import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/child/child.dart'
    as domain_child;
import 'package:adark_frontend/domain/entities/class/class_info.dart'
    as domain_class;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';

import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/audio_player_card.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/analyzed_text_card.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/edit_observation_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/review_common_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/done_screen_view.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/review_sub_views.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.onBack,
    required this.onCompleted,
    this.mode = RecordMode.classroom,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.child,
    this.className = 'Mầm 1',
    this.repository,
    this.teacherRepository,
    this.extraction,
    this.transcript,
    this.voiceRecord,
    this.recordedBytes,
    this.audioPlayerFactory,
  });

  final VoidCallback onBack;
  final VoidCallback onCompleted;
  final RecordMode mode;
  final String classId;
  final Child? child;
  final String className;
  final HttpDashboardRepository? repository;
  final TeacherRepository? teacherRepository;
  final ExtractionData? extraction;
  final String? transcript;
  final VoiceRecord? voiceRecord;

  /// Bytes của file ghi âm gốc, dùng để phát lại ở màn hình done.
  final Uint8List? recordedBytes;
  final AudioPlayerFactory? audioPlayerFactory;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late final TeacherRepository teacherRepository =
      widget.teacherRepository ?? TeacherRepository();
  late Future<List<Child>> childrenFuture;
  List<ObservationItem> items = [];
  List<Child> roster = [];
  bool isDone = false;
  bool isSubmitting = false;
  int savedReportsCount = 0;
  int savedHealthCount = 0;

  /// Map từ item.id → list draft_report_id đã được tạo (sau khi gọi approve-item).
  /// Dùng để gom lại và gửi 1 lần qua send-batch.
  final Map<String, List<String>> approvedDraftIds = {};
  final Set<String> sentDraftIds = {};

  /// Set các item.id đang trong quá trình approve (disable button tránh double-click).
  final Set<String> approvingIds = <String>{};

  /// True khi đang gọi send-batch.
  bool isSendingBatch = false;

  ExtractionData? currentExtraction;
  String? editedTranscript;

  String get effectiveTranscript =>
      (editedTranscript != null && editedTranscript!.trim().isNotEmpty)
          ? editedTranscript!.trim()
          : (widget.transcript != null && widget.transcript!.trim().isNotEmpty)
              ? widget.transcript!.trim()
              : (currentExtraction?.transcript != null &&
                      currentExtraction!.transcript!.trim().isNotEmpty)
                  ? currentExtraction!.transcript!.trim()
                  : '';

  @override
  void initState() {
    super.initState();
    currentExtraction = widget.extraction;
    childrenFuture = _loadChildren().then((children) {
      if (mounted) {
        setState(() {
          roster = children;
          items = _buildObservations(children);
        });
      }
      return children;
    }).catchError((Object e, StackTrace st) {
      debugPrint('ReviewScreen childrenFuture error: $e\n$st');
      throw e;
    });
  }

  bool _hasAnyLegacyContent(ExtractionData ext) {
    return (ext.meals?.trim().isNotEmpty ?? false) ||
        (ext.sleeping?.trim().isNotEmpty ?? false) ||
        (ext.activities?.trim().isNotEmpty ?? false) ||
        (ext.mood?.trim().isNotEmpty ?? false) ||
        (ext.health?.trim().isNotEmpty ?? false) ||
        (ext.rawJson?['teacher_note']?.toString().trim().isNotEmpty ?? false) ||
        (ext.rawJson?['notes']?.toString().trim().isNotEmpty ?? false) ||
        (ext.rawJson?['note']?.toString().trim().isNotEmpty ?? false);
  }

  List<ObservationItem> _buildObservations(List<Child> children,
      [ExtractionData? customExtraction]) {
    try {
      final ext = customExtraction ?? currentExtraction ?? widget.extraction;

      // Legacy single-child mode (RecordMode.child không còn dùng trong flow mới,
      // nhưng giữ lại để không vỡ các entry-point cũ nếu còn gọi tới).
      if (widget.mode == RecordMode.child && widget.child != null) {
        final c = widget.child!;
        final meals =
            ext?.meals?.trim().isNotEmpty == true ? ext!.meals!.trim() : '';
        final sleep = ext?.sleeping?.trim().isNotEmpty == true
            ? ext!.sleeping!.trim()
            : '';
        final activities = ext?.activities?.trim().isNotEmpty == true
            ? ext!.activities!.trim()
            : '';
        final mood =
            ext?.mood?.trim().isNotEmpty == true ? ext!.mood!.trim() : '';
        final health =
            ext?.health?.trim().isNotEmpty == true ? ext!.health!.trim() : '';
        final note =
            ext?.rawJson?['teacher_note']?.toString().trim().isNotEmpty == true
                ? ext!.rawJson!['teacher_note']!.toString().trim()
                : (ext?.rawJson?['notes']?.toString().trim().isNotEmpty == true
                    ? ext!.rawJson!['notes']!.toString().trim()
                    : (ext?.rawJson?['note']?.toString().trim().isNotEmpty ==
                            true
                        ? ext!.rawJson!['note']!.toString().trim()
                        : ''));

        return [
          ObservationItem(
            id: c.id,
            name: c.name,
            childId: c.id,
            nickname: c.nickname,
            matched: true,
            eating: meals,
            sleep: sleep,
            activities: activities,
            mood: mood,
            health: health,
            note: note,
            severity: c.severity,
          ),
        ];
      }

      // ====================================================================
      // Classroom mode - Auto-detect flow (mới)
      // ====================================================================
      // Cấu trúc items:
      //   1. Classwide item (1) - nếu backend có classWideExtraction có nội dung
      //   2. Child items (N) - chỉ các bé CÓ override trong childExtractions
      //   3. Unmatched items (M) - các segments không gắn được với bé nào
      // ====================================================================
      final result = <ObservationItem>[];

      final childMap = ext?.childExtractions;
      final hasChildOverrides = childMap != null && childMap.isNotEmpty;

      // -------- 1. Classwide item -----------------------------------------
      if (ext?.hasClassWideContent == true) {
        final cw = ext!.classWideExtraction!;
        result.add(_classwideItemFromExtraction(cw));
      } else if (widget.mode == RecordMode.classroom &&
          !hasChildOverrides &&
          ext != null &&
          ext.classWideExtraction != null &&
          _hasAnyLegacyContent(ext)) {
        // Fallback: BE trả class_wide_extraction là dict hợp lệ (không null)
        // nhưng rỗng content (hasClassWideContent = false). Khi đó thử dùng
        // top-level legacy fields (ext.meals, ext.sleeping, ...). Nếu cũng
        // rỗng hết thì KHÔNG tạo item — để Unmatched items từ segments là
        // đầu mục duy nhất giáo viên cần review.
        // Chỉ thêm fallback "Chung cả lớp" nếu không có bất kỳ override nào theo từng bé

        result.add(
          ObservationItem(
            id: 'classwide',
            name: 'Chung cả lớp',
            matched: true,
            kind: ObservationKind.classwide,
            decision: ObservationDecision.pending,
            eating:
                ext.meals?.trim().isNotEmpty == true ? ext.meals!.trim() : '',
            sleep: ext.sleeping?.trim().isNotEmpty == true
                ? ext.sleeping!.trim()
                : '',
            activities: ext.activities?.trim().isNotEmpty == true
                ? ext.activities!.trim()
                : '',
            mood: ext.mood?.trim().isNotEmpty == true ? ext.mood!.trim() : '',
            health:
                ext.health?.trim().isNotEmpty == true ? ext.health!.trim() : '',
            note: ext.rawJson?['teacher_note']?.toString().trim().isNotEmpty ==
                    true
                ? ext.rawJson!['teacher_note']!.toString().trim()
                : (ext.rawJson?['notes']?.toString().trim().isNotEmpty == true
                    ? ext.rawJson!['notes']!.toString().trim()
                    : (ext.rawJson?['note']?.toString().trim().isNotEmpty ==
                            true
                        ? ext.rawJson!['note']!.toString().trim()
                        : '')),
          ),
        );
      }

      // -------- 2. Child items (chỉ các bé có override) -------------------
      if (childMap != null && childMap.isNotEmpty) {
        for (final child in children) {
          // Tìm override theo id hoặc theo name (backend có thể trả key là name)
          dynamic data;
          if (childMap.containsKey(child.id)) {
            data = childMap[child.id];
          } else if (childMap.containsKey(child.name)) {
            data = childMap[child.name];
          }
          if (data is! Map) {
            continue; // Bé này không có override → KHÔNG tạo item (dùng classwide default)
          }
          result.add(_childItemFromExtraction(child, data));
        }
      }

      // -------- 3. Unmatched items ----------------------------------------
      bool hasExtractionContent(dynamic seg) {
        if (seg is! Map) return false;
        final extr = seg['extraction'];
        if (extr is! Map) return false;
        return extr.values.any((v) {
          if (v == null) return false;
          final s = v.toString().trim();
          return s.isNotEmpty;
        });
      }

      final rawUnmatched = ext?.rawJson?['unmatched_segments'];

      if (rawUnmatched is List && rawUnmatched.isNotEmpty) {
        for (var i = 0; i < rawUnmatched.length; i++) {
          final seg = rawUnmatched[i];

          if (!hasExtractionContent(seg)) {
            continue;
          }

          final text =
              seg is Map ? (seg['text']?.toString() ?? '') : seg.toString();
          if (text.trim().isNotEmpty) {
            result.add(_unmatchedItem(
              'unmatched_$i',
              text,
              seg is Map && seg['extraction'] is Map
                  ? (seg['extraction'] as Map<dynamic, dynamic>)
                  : null,
            ));
          }
        }
      } else if (ext?.segments != null) {
        var uIdx = 0;
        for (final seg in ext!.segments!) {
          if (seg is Map) {
            final isClassWide = seg['is_class_wide'] == true;
            final matches = seg['child_matches'];
            final hasMatches = matches is List && matches.isNotEmpty;
            if (!isClassWide && !hasMatches) {
              if (!hasExtractionContent(seg)) {
                continue;
              }
              final text = seg['text']?.toString() ?? '';
              if (text.trim().isNotEmpty) {
                result.add(_unmatchedItem(
                  'unmatched_${uIdx++}',
                  text,
                  seg['extraction'] is Map
                      ? (seg['extraction'] as Map<dynamic, dynamic>)
                      : null,
                ));
              }
            }
          }
        }
      }

      return result;
    } catch (e, st) {
      debugPrint('Error in _buildObservations: $e\n$st');
      // Fallback an toàn: 1 classwide item duy nhất
      return [
        ObservationItem(
          id: 'classwide',
          name: 'Chung cả lớp',
          matched: true,
          kind: ObservationKind.classwide,
          eating: '',
          sleep: '',
          activities: '',
          mood: '',
          health: '',
        ),
      ];
    }
  }

  /// Tạo classwide ObservationItem từ classWideExtraction map.
  ObservationItem _classwideItemFromExtraction(Map<String, dynamic> cw) {
    String pick(String key, [String fallback = '']) {
      final v = cw[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : fallback;
    }

    final noteVal = pick('notes') != ''
        ? pick('notes')
        : (pick('teacher_note') != ''
            ? pick('teacher_note')
            : (pick('note') != '' ? pick('note') : ''));

    return ObservationItem(
      id: 'classwide',
      name: 'Chung cả lớp',
      matched: true,
      kind: ObservationKind.classwide,
      decision: ObservationDecision.pending,
      eating: pick('meals'),
      sleep: pick('sleeping'),
      activities: pick('activities'),
      mood: pick('mood'),
      health: pick('health'),
      note: noteVal,
    );
  }

  /// Tạo child ObservationItem từ childExtractions[childId/name].
  ObservationItem _childItemFromExtraction(Child child, Map data) {
    String pick(String key) {
      final v = data[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : '';
    }

    return ObservationItem(
      id: child.id,
      name: child.name,
      childId: child.id,
      nickname: child.nickname,
      matched: true,
      kind: ObservationKind.normal,
      decision: ObservationDecision.pending,
      eating: pick('meals'),
      sleep: pick('sleeping'),
      activities: pick('activities'),
      mood: pick('mood'),
      health: pick('health'),
      note: pick('notes').isNotEmpty
          ? pick('notes')
          : (pick('teacher_note').isNotEmpty
              ? pick('teacher_note')
              : pick('note')),
      severity: child.severity,
    );
  }

  /// Tạo unmatched ObservationItem cho 1 segment không gắn được với bé nào.
  ObservationItem _unmatchedItem(String id, String text, [Map? extraction]) {
    String pick(String key) {
      if (extraction == null) return '';
      final v = extraction[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : '';
    }

    return ObservationItem(
      id: id,
      name: 'Chưa rõ bé nào',
      matched: false,
      kind: ObservationKind.unmatched,
      decision: ObservationDecision.pending,
      snippet: text,
      eating: pick('meals'),
      sleep: pick('sleeping'),
      activities: pick('activities'),
      mood: pick('mood'),
      health: pick('health'),
      note: pick('notes').isNotEmpty
          ? pick('notes')
          : (pick('teacher_note').isNotEmpty
              ? pick('teacher_note')
              : pick('note')),
    );
  }

  Future<List<Child>> _loadChildren() async {
    try {
      if (widget.mode == RecordMode.child && widget.child != null) {
        return [widget.child!];
      }
      final results = await Future.wait([
        repository.getClassChildren(widget.classId),
        repository
            .getClassDashboard(widget.classId, DateTime.now())
            .catchError((err) {
          debugPrint(
              'ReviewScreen getClassDashboard error (fallback to defaults): $err');
          return ClassDashboardSummary(
            classInfo: domain_class.ClassInfo(
              classId: widget.classId,
              schoolId: '',
              name: widget.className,
            ),
            teacherName: '',
            totalChildren: 0,
            completedCount: 0,
            draftCount: 0,
            missingCount: 0,
            pendingChildren: const [],
          );
        }),
      ]);
      final classRoster = results[0] as List<domain_child.Child>;
      final dashboard = results[1] as ClassDashboardSummary;
      final statuses = {
        for (final item in dashboard.pendingChildren) item.child.childId: item
      };
      return classRoster.map((child) {
        final item = statuses[child.childId];
        return item == null
            ? uiChildFromDomain(
                child: child,
                reportStatus: ReportStatus.none,
                severity: severityFromDescription(null))
            : uiChildFromDomainWithReport(
                child: child,
                reportStatus: item.status,
                severity: severityFromDescription(null),
                updatedAt: item.updatedAt);
      }).toList();
    } catch (e, st) {
      debugPrint('Error in _loadChildren: $e\n$st');
      rethrow;
    }
  }

  /// Approve 1 item (gọi POST /api/teacher/reports/approve-item).
  /// Item được approve sẽ được backend tạo draft NGAY và trả về list draft_report_ids.
  /// Lưu vào [approvedDraftIds] để gom lại gửi batch.
  Future<void> _approveItem(ObservationItem item) async {
    if (approvingIds.contains(item.id)) return; // tránh double-click

    String teacherId;
    try {
      final t = await repository.getCurrentTeacher();
      teacherId = t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
    } catch (_) {
      teacherId = AuthRepository.currentUser?.teacherId ?? repository.teacherId;
    }

    // Phải có voiceRecordId để backend biết lấy extraction từ đâu.
    final voiceRecordId = widget.voiceRecord?.id;
    if (voiceRecordId == null || voiceRecordId.isEmpty) {
      await _approveItemManualFallback(item, teacherId);
      return;
    }

    setState(() => approvingIds.add(item.id));

    try {
      // Map item.kind → API kind
      String kind;
      String? childId;
      String? classId;
      Map<String, String?>? extraction;

      if (item.kind == ObservationKind.classwide) {
        kind = 'classwide';
        classId = widget.classId;
        extraction = {
          if (item.eating.isNotEmpty) 'meals': item.eating,
          if (item.sleep.isNotEmpty) 'sleeping': item.sleep,
          if (item.health.isNotEmpty) 'health': item.health,
          if (item.activities.isNotEmpty) 'activities': item.activities,
          if (item.mood.isNotEmpty) 'mood': item.mood,
          if (item.note.isNotEmpty) 'teacher_note': item.note,
        };
      } else if (item.kind == ObservationKind.unmatched) {
        // Unmatched: backend hiện tại KHÔNG tạo draft (theo doc),
        // chỉ echo lại để user biết segment này được chấp nhận.
        // Vẫn gọi API để đồng bộ trạng thái, nhưng draft_ids sẽ rỗng.
        kind = 'unmatched';
        classId = widget.classId;
        extraction = {
          'transcript': item.snippet,
          'teacher_note': item.snippet,
        };
      } else {
        // normal / child
        kind = 'child';
        childId = item.childId;
        extraction = {
          if (item.eating.isNotEmpty) 'meals': item.eating,
          if (item.sleep.isNotEmpty) 'sleeping': item.sleep,
          if (item.health.isNotEmpty) 'health': item.health,
          if (item.activities.isNotEmpty) 'activities': item.activities,
          if (item.mood.isNotEmpty) 'mood': item.mood,
          if (item.note.isNotEmpty) 'teacher_note': item.note,
        };
      }

      final res = await teacherRepository.approveItem(
        voiceRecordId: voiceRecordId,
        teacherId: teacherId,
        kind: kind,
        childId: childId,
        classId: classId,
        extraction: extraction,
      );

      // Parse draft_report_ids từ response (List<dynamic> các UUID string)
      final draftIdsRaw = res['draft_report_ids'];
      final newDraftIds = <String>[];
      if (draftIdsRaw is List) {
        for (final v in draftIdsRaw) {
          final s = v?.toString();
          if (s != null && s.isNotEmpty) newDraftIds.add(s);
        }
      }

      // Classwide có thể trả child_id_to_report_id (map) thay vì list
      if (newDraftIds.isEmpty && kind == 'classwide') {
        final map = res['child_id_to_report_id'];
        if (map is Map) {
          map.forEach((k, v) {
            final s = v?.toString();
            if (s != null && s.isNotEmpty) newDraftIds.add(s);
          });
        }
      }

      if (newDraftIds.isEmpty && kind == 'classwide') {
        // Nếu API trả rỗng cho classwide, fallback manual để lấy draft ids
        await _approveItemManualFallback(item, teacherId);
        return;
      }

      if (!mounted) return;
      setState(() {
        approvedDraftIds[item.id] = newDraftIds;
        item.decision = ObservationDecision.approved;
      });

      if (kind == 'classwide') {
        for (final childItem in items) {
          if (childItem.kind != ObservationKind.classwide &&
              childItem.decision == ObservationDecision.approved &&
              childItem.id != item.id) {
            _approveItem(childItem);
          }
        }
      }
    } catch (e) {
      debugPrint('Approve item error: $e, trying manual fallback...');
      await _approveItemManualFallback(item, teacherId);
    } finally {
      if (mounted) setState(() => approvingIds.remove(item.id));
    }
  }

  Future<void> _approveItemManualFallback(
      ObservationItem item, String teacherId) async {
    setState(() => approvingIds.add(item.id));
    final newDraftIds = <String>[];
    try {
      if (item.kind == ObservationKind.classwide) {
        for (final child in roster) {
          try {
            final res = await teacherRepository.createManualReport(
              teacherId: teacherId,
              childId: child.id,
              eating: item.eating,
              sleeping: item.sleep,
              health: item.health,
              activities: item.activities,
              mood: item.mood,
              teacherNote: item.note,
              overwrite: true,
            );
            final id = res['report_id']?.toString() ??
                res['daily_report_id']?.toString();
            if (id != null && id.isNotEmpty) newDraftIds.add(id);
          } catch (err) {
            debugPrint('Manual fallback error for child ${child.id}: $err');
          }
        }
      } else {
        final targetChildId = item.childId ?? item.id;
        final res = await teacherRepository.createManualReport(
          teacherId: teacherId,
          childId: targetChildId,
          eating: item.eating,
          sleeping: item.sleep,
          health: item.health,
          activities: item.activities,
          mood: item.mood,
          teacherNote: item.note,
          overwrite: true,
        );
        final id =
            res['report_id']?.toString() ?? res['daily_report_id']?.toString();
        if (id != null && id.isNotEmpty) newDraftIds.add(id);
      }
      if (mounted) {
        setState(() {
          approvedDraftIds[item.id] = newDraftIds;
          item.decision = ObservationDecision.approved;
        });
      }
    } catch (err) {
      debugPrint('Fallback manual report failed: $err');
      if (mounted) {
        _showError('Không thể tạo bản nháp báo cáo. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => approvingIds.remove(item.id));
    }
  }

  void _discardItem(ObservationItem item) {
    final draftIds = List<String>.from(
      approvedDraftIds[item.id] ?? <String>[],
    );
    if (draftIds.any(sentDraftIds.contains)) {
      _showError('Báo cáo đã gửi một phần nên không thể loại bỏ mục này.');
      return;
    }
    setState(() {
      item.decision = ObservationDecision.discarded;
      approvedDraftIds.remove(item.id);
    });
    if (draftIds.isNotEmpty) teacherRepository.deleteDraftReports(draftIds);
  }

  void _restoreItem(ObservationItem item) {
    final draftIds = List<String>.from(
      approvedDraftIds[item.id] ?? <String>[],
    );
    setState(() {
      item.decision = ObservationDecision.pending;
      approvedDraftIds.remove(item.id);
    });
    if (draftIds.isNotEmpty) teacherRepository.deleteDraftReports(draftIds);
  }

  /// Duyệt tất cả các mục chưa được duyệt.
  Future<void> _approveAll() async {
    for (final item in items) {
      if (item.decision != ObservationDecision.approved &&
          item.decision != ObservationDecision.discarded) {
        await _approveItem(item);
      }
    }
  }

  /// Bỏ duyệt 1 item đã được duyệt.
  /// Nếu cả lớp đang được duyệt, bé này sẽ được gán lại nội dung cả lớp thay vì xóa bỏ hoàn toàn khỏi báo cáo.
  Future<void> _unapproveItem(ObservationItem item) async {
    if (approvingIds.contains(item.id)) return;
    final draftIdsToDelete =
        List<String>.from(approvedDraftIds[item.id] ?? <String>[]);
    if (draftIdsToDelete.any(sentDraftIds.contains)) {
      _showError('Báo cáo đã gửi một phần nên không thể bỏ duyệt mục này.');
      return;
    }
    setState(() {
      item.decision = ObservationDecision.pending;
      approvedDraftIds.remove(item.id);
    });

    // Kiểm tra xem mục "Chung cả lớp" có đang được duyệt hay không
    ObservationItem? classwideItem;
    for (final it in items) {
      if (it.kind == ObservationKind.classwide &&
          it.decision == ObservationDecision.approved) {
        classwideItem = it;
        break;
      }
    }

    if (item.kind != ObservationKind.classwide && classwideItem != null) {
      // Bé này có thẻ riêng nhưng vừa bị hủy duyệt, trong khi cả lớp vẫn duyệt:
      // Gán lại nội dung cả lớp cho bé này thay vì xóa báo cáo!
      try {
        String teacherId;
        try {
          final t = await repository.getCurrentTeacher();
          teacherId =
              t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
        } catch (_) {
          teacherId =
              AuthRepository.currentUser?.teacherId ?? repository.teacherId;
        }
        final voiceRecordId =
            widget.voiceRecord?.id ?? '00000000-0000-0000-0000-000000000000';
        await teacherRepository.approveItem(
          voiceRecordId: voiceRecordId,
          teacherId: teacherId,
          kind: 'child',
          childId: item.childId,
          extraction: {
            if (classwideItem.eating.isNotEmpty) 'meals': classwideItem.eating,
            if (classwideItem.sleep.isNotEmpty) 'sleeping': classwideItem.sleep,
            if (classwideItem.health.isNotEmpty) 'health': classwideItem.health,
            if (classwideItem.activities.isNotEmpty)
              'activities': classwideItem.activities,
            if (classwideItem.mood.isNotEmpty) 'mood': classwideItem.mood,
            if (classwideItem.note.isNotEmpty)
              'teacher_note': classwideItem.note,
          },
        );
      } catch (e) {
        debugPrint('Lỗi gán lại classwide cho bé khi bỏ duyệt: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocaleController.instance.isEnglish
                  ? 'Unapproved specific section for "${item.name}". The child will receive the class-wide report.'
                  : 'Đã bỏ duyệt mục riêng của "${item.name}". Bé sẽ nhận báo cáo chung của cả lớp.',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (draftIdsToDelete.isNotEmpty) {
      try {
        await teacherRepository.deleteDraftReports(draftIdsToDelete);
      } catch (e) {
        debugPrint('Lỗi xóa bản nháp khi bỏ duyệt: $e');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Đã bỏ duyệt mục "${item.name}". Đã xóa khỏi bản nháp.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Bỏ duyệt tất cả các mục đã duyệt. Xóa tất cả draft reports khỏi backend DB.
  Future<void> _unapproveAll() async {
    if (approvedDraftIds.values
        .expand((ids) => ids)
        .any(sentDraftIds.contains)) {
      _showError('Đã có báo cáo được gửi nên không thể bỏ duyệt tất cả.');
      return;
    }
    final allDraftIdsToDelete = <String>[];
    for (final ids in approvedDraftIds.values) {
      allDraftIdsToDelete.addAll(ids);
    }
    setState(() {
      for (final item in items) {
        if (item.decision == ObservationDecision.approved) {
          item.decision = ObservationDecision.pending;
        }
      }
      approvedDraftIds.clear();
    });
    if (allDraftIdsToDelete.isNotEmpty) {
      try {
        await teacherRepository.deleteDraftReports(allDraftIdsToDelete);
      } catch (e) {
        debugPrint('Lỗi xóa tất cả bản nháp khi bỏ duyệt: $e');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã bỏ duyệt tất cả các mục và xóa khỏi bản nháp.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Gửi batch tất cả draft đã thu được từ các mục ĐÃ ĐƯỢC DUYỆT.
  /// Gọi POST /api/teacher/reports/send-batch với list tất cả draft_report_ids.
  Future<void> _sendBatch() async {
    if (isSendingBatch) return;

    // CHỈ gom draft ids từ các mục có decision == approved
    final allDraftIds = <String>[];
    for (final item in items) {
      if (item.decision == ObservationDecision.approved) {
        final ids = approvedDraftIds[item.id];
        if (ids != null) allDraftIds.addAll(ids);
      }
    }
    // dedupe (giữ thứ tự)
    final allUniqueDraftIds = <String>[];
    final seen = <String>{};
    for (final id in allDraftIds) {
      if (seen.add(id)) allUniqueDraftIds.add(id);
    }

    final pendingCount = items
        .where((i) =>
            i.decision != ObservationDecision.discarded &&
            i.decision != ObservationDecision.approved)
        .length;
    if (pendingCount > 0) {
      _showError(
          'Còn $pendingCount mục chưa duyệt hoặc loại bỏ. Vui lòng xử lý tất cả các mục trước khi gửi.');
      return;
    }

    // Tuyệt đối không tự ý duyệt ngầm - chỉ mục nào được duyệt mới gửi.
    final uniqueDraftIds = allUniqueDraftIds
        .where((id) => !sentDraftIds.contains(id))
        .toList();
    if (uniqueDraftIds.isEmpty) {
      if (allUniqueDraftIds.isNotEmpty &&
          allUniqueDraftIds.every(sentDraftIds.contains)) {
        _finishBatchSend();
      } else {
        _showError(
            'Chưa có mục nào được duyệt. Hãy bấm "Duyệt" ít nhất 1 mục để gửi.');
      }
      return;
    }

    String teacherId;
    try {
      final t = await repository.getCurrentTeacher();
      teacherId = t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
    } catch (_) {
      teacherId = AuthRepository.currentUser?.teacherId ?? repository.teacherId;
    }

    setState(() {
      isSendingBatch = true;
      isSubmitting = true;
    });

    try {
      final res = await teacherRepository.sendBatch(
        teacherId: teacherId,
        reportIds: uniqueDraftIds,
      );

      final sent = (res['sent'] is num) ? (res['sent'] as num).toInt() : 0;
      final skipped =
          (res['skipped'] is num) ? (res['skipped'] as num).toInt() : 0;
      final failed =
          (res['failed'] is num) ? (res['failed'] as num).toInt() : 0;
      final results = res['results'];
      final failedIds = <String>{};
      if (results is List) {
        for (final result in results) {
          if (result is! Map) continue;
          final id = result['daily_report_id']?.toString();
          if (id == null || !uniqueDraftIds.contains(id)) continue;
          if (result['result'] == 'sent' || result['result'] == 'skipped') {
            sentDraftIds.add(id);
          } else if (result['result'] == 'failed') {
            failedIds.add(id);
          }
        }
      }
      if (failed == 0 && sent + skipped == uniqueDraftIds.length) {
        sentDraftIds.addAll(uniqueDraftIds);
      }

      if (failed > 0 && sent == 0) {
        debugPrint(
            'sendBatch returned failed=$failed (${res['results']}), publishing individually...');
        final fallbackIds = failedIds.isEmpty
            ? uniqueDraftIds.where((id) => !sentDraftIds.contains(id))
            : failedIds;
        for (final repId in fallbackIds) {
          try {
            await teacherRepository.publishReport(
                reportId: repId, teacherId: teacherId);
            sentDraftIds.add(repId);
          } catch (e) {
            debugPrint('Individual publish error for $repId: $e');
          }
        }
      }

      final remaining =
          allUniqueDraftIds.where((id) => !sentDraftIds.contains(id)).length;
      if (remaining > 0) {
        _showError(
            'Đã gửi ${sentDraftIds.length} báo cáo; còn $remaining báo cáo chưa gửi. Vui lòng thử lại.');
        return;
      }
      _finishBatchSend();
    } catch (e) {
      // ponytail: timeout có thể che lần commit; cần idempotency/status lookup trước khi retry tự động.
      debugPrint('send-batch error: $e, trying publishReport fallback...');
      for (final repId in uniqueDraftIds.where((id) => !sentDraftIds.contains(id))) {
        try {
          await teacherRepository.publishReport(
              reportId: repId, teacherId: teacherId);
          sentDraftIds.add(repId);
        } catch (_) {}
      }
      final remaining =
          allUniqueDraftIds.where((id) => !sentDraftIds.contains(id)).length;
      if (remaining == 0 && allUniqueDraftIds.isNotEmpty) {
        _finishBatchSend();
        return;
      }
      _showError(
          'Đã gửi ${sentDraftIds.length} báo cáo; còn $remaining báo cáo chưa gửi. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          isSendingBatch = false;
          isSubmitting = false;
        });
      }
    }
  }

  void _finishBatchSend() {
    if (!mounted) return;
    final healthCount = items
        .where((item) =>
            item.health.isNotEmpty &&
            (approvedDraftIds[item.id] ?? const <String>[])
                .any(sentDraftIds.contains))
        .length;
    setState(() {
      savedReportsCount = sentDraftIds.length;
      savedHealthCount = healthCount;
      isDone = true;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _assignChild(ObservationItem item,
      {required VoidCallback onAssignClass}) {
    Navigator.of(context)
        .push<Child>(MaterialPageRoute(
            builder: (_) => AssignChildScreen(
                  card: item,
                  roster: roster,
                  className: widget.className,
                  onAssignClass: onAssignClass,
                )))
        .then((selected) {
      if (selected != null && mounted) {
        setState(() {
          final idx = items.indexWhere((i) => i.id == item.id);
          if (idx != -1) {
            items[idx] = item.assign(selected);
          }
        });
      }
    });
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleController.instance.isEnglish;
    final cleanClass = widget.className.replaceFirst(RegExp(r'^(Lớp|Class)\s*', caseSensitive: false), '');
    final classLabel = isEn
        ? (cleanClass.isEmpty ? 'Class' : 'Class $cleanClass')
        : (widget.className.startsWith('Lớp ')
            ? widget.className
            : 'Lớp ${widget.className}');
    if (isDone) {
      final classwideItems =
          items.where((item) => item.kind == ObservationKind.classwide).toList();
      final classwideDraftIds = classwideItems.length == 1
          ? approvedDraftIds[classwideItems.single.id] ?? const <String>[]
          : const <String>[];
      if (classwideItems.length == 1 &&
          classwideItems.single.decision == ObservationDecision.approved &&
          classwideDraftIds.isNotEmpty &&
          classwideDraftIds.every(sentDraftIds.contains)) {
        return ClasswideDoneScreen(
          classLabel: classLabel,
          onBack: widget.onCompleted,
        );
      }
      return _DoneScreenView(
        parentReportsCount: savedReportsCount,
        healthRecordsCount: savedHealthCount,
        recordingTime: _timeNow(),
        recordedBytes: widget.recordedBytes,
        onBack: widget.onCompleted,
      );
    }

    // Counters cho header + bottom sheet
    final totalCount = items.length;
    final approvedCount = items
        .where((i) =>
            i.decision == ObservationDecision.approved &&
            approvedDraftIds.containsKey(i.id))
        .length;
    final pendingCount = items
        .where((i) =>
            i.decision != ObservationDecision.discarded &&
            i.decision != ObservationDecision.approved)
        .length;
    final discardedCount =
        items.where((i) => i.decision == ObservationDecision.discarded).length;

    // Unmatched còn lại (chưa được gán/lọc) - phải = 0 mới cho confirm
    final unmatchedActiveCount = items
        .where((i) =>
            i.kind == ObservationKind.unmatched &&
            i.decision != ObservationDecision.discarded)
        .length;
    final hasUnmatchedActive = unmatchedActiveCount > 0;
    final classwideItems = items
        .where((item) => item.kind == ObservationKind.classwide)
        .toList();
    final classwideChildItems = items
        .where((item) =>
            item.kind != ObservationKind.classwide &&
            item.kind != ObservationKind.unmatched)
        .toList();
    final isClasswideReview = classwideItems.length == 1 &&
        classwideChildItems.length == 1 &&
        items.length == 2 &&
        !hasUnmatchedActive &&
        discardedCount == 0 &&
        items.every(
          (item) => item.decision == ObservationDecision.approved,
        );
    final skippedItems = items
        .where((item) =>
            item.kind == ObservationKind.unmatched &&
            item.decision == ObservationDecision.discarded)
        .toList();
    final isSkippedReview = skippedItems.isNotEmpty &&
        !hasUnmatchedActive &&
        skippedItems.length == 1 &&
        items.length == 2 &&
        !items.any((item) => item.kind == ObservationKind.classwide) &&
        classwideChildItems.length == 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n?.commonBack ?? 'Quay lại',
                    onPressed: widget.onBack,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: SvgPicture.asset('assets/garden_voice/edit_back.svg'),
                  ),
                  const SizedBox(width: 0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClasswideReview
                              ? (isEn ? 'Review class-wide report' : 'Duyệt báo cáo cả lớp')
                              : isSkippedReview
                                  ? (isEn ? 'Review report' : 'Duyệt báo cáo')
                                  : hasUnmatchedActive
                                      ? (isEn ? 'Review recording' : 'Xem lại bản ghi')
                                      : (isEn ? 'Review report' : 'Xem lại báo cáo'),
                          style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: context.k.ink),
                        ),
                        if (!isClasswideReview && !isSkippedReview)
                          Text(
                            hasUnmatchedActive
                                ? (context.l10n?.unmatchedSegmentsNeedConfirm(classLabel, unmatchedActiveCount) ??
                                    (isEn
                                        ? '$classLabel · $unmatchedActiveCount segment(s) need confirmation'
                                        : '$classLabel · $unmatchedActiveCount đoạn cần cô xác nhận'))
                                : (context.l10n?.sttSeparatedByChild ??
                                    (isEn ? 'Separated information by child' : 'Đã tách thông tin theo từng bé')),
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: context.k.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Child>>(
                future: childrenFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          childrenFuture = _loadChildren().then((children) {
                            roster = children;
                            items = _buildObservations(children);
                            return children;
                          });
                        }),
                        child: const Text(
                            'Không tải được danh sách trẻ · Thử lại'),
                      ),
                    );
                  }

                  Widget reviewTile(
                    ObservationItem item, {
                    bool summaryStyle = false,
                    bool showApproveAction = false,
                    String? summaryLabel,
                  }) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ObservationTile(
                          card: item,
                          className: widget.className,
                          showSegmentPreview: false,
                          summaryStyle: summaryStyle,
                          showApproveAction: showApproveAction,
                          summaryLabel: summaryLabel,
                          isApproving: approvingIds.contains(item.id),
                          onToggleApprove: () {
                            if (item.decision == ObservationDecision.approved) {
                              _unapproveItem(item);
                            } else {
                              _approveItem(item);
                            }
                          },
                          onUnapprove: () => _unapproveItem(item),
                          onDiscard: () => _discardItem(item),
                          onRestore: () => _restoreItem(item),
                          onAssign: () => _assignChild(
                            item,
                            onAssignClass: () {},
                          ),
                          onEdit: () => _editObservation(item),
                        ),
                      );

                  if (isClasswideReview) {
                    final childItem = classwideChildItems.single;
                    final classwideItem = classwideItems.single;
                    final actionLabel = pendingCount > 0
                        ? (isEn ? 'Approve all' : 'Duyệt tất cả')
                        : approvedCount > 0
                            ? (isEn ? 'Confirm send to entire class' : 'Xác nhận gửi cho cả lớp')
                            : (isEn ? 'No items approved to send' : 'Chưa duyệt mục nào để gửi');
                    final VoidCallback? action = isSubmitting
                        ? null
                        : pendingCount > 0
                            ? _approveAll
                            : approvedCount > 0
                                ? _sendBatch
                                : null;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isEn
                                ? '$classLabel · All audio segments processed'
                                : '$classLabel · Đã xử lý tất cả đoạn ghi',
                            style: TextStyle(
                              color: context.k.inkSoft,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          reviewTile(
                            childItem,
                            summaryStyle: true,
                            summaryLabel: isEn
                                ? 'Specific to ${childItem.fullNameWithNickname}'
                                : 'Riêng ${childItem.fullNameWithNickname}',
                          ),
                          reviewTile(
                            classwideItem,
                            summaryStyle: true,
                            summaryLabel: isEn
                                ? 'Apply to entire class'
                                : 'Áp dụng cho cả lớp',
                          ),
                          SizedBox(
                            height: 48,
                            child: KButton(
                              label: actionLabel,
                              onPressed: action,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (isSkippedReview) {
                    final skipped = skippedItems.single;
                    final skippedDetail = skipped.snippet.trim();
                    final skippedMessage = skippedDetail.isEmpty
                        ? 'Đoạn chưa rõ đã được bỏ qua.'
                        : 'Đoạn chưa rõ “$skippedDetail” đã được bỏ qua.';
                    final activeItems = items
                        .where((item) => item.id != skipped.id)
                        .toList();
                    final canSend = !isSubmitting &&
                        approvedCount > 0 &&
                        pendingCount == 0 &&
                        unmatchedActiveCount == 0;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            skippedMessage,
                            style: TextStyle(
                              color: context.k.inkSoft,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final item in activeItems)
                            reviewTile(
                              item,
                              summaryStyle: true,
                              showApproveAction: true,
                              summaryLabel: item.fullNameWithNickname,
                            ),
                          SizedBox(
                            height: 48,
                            child: KButton(
                              label: context.l10n?.sttSendToParents ??
                                  'Gửi báo cáo cho phụ huynh',
                              onPressed: canSend ? _sendBatch : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: KButton(
                              label: context.l10n?.sttReprocessClip ??
                                  'Xử lý lại đoạn ghi',
                              secondary: true,
                              onPressed: () => _restoreItem(skipped),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Widget contentWidth(Widget child) => Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: child,
                        ),
                      );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hasUnmatchedActive) ...[
                          contentWidth(
                            Row(
                              children: List.generate(
                                3,
                                (index) => Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: EdgeInsets.only(
                                        right: index == 2 ? 0 : 6),
                                    decoration: BoxDecoration(
                                      color: context.k.brand,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.l10n?.sttStepReview ?? 'Bước 3/3 · Xem lại',
                              style: TextStyle(
                                  fontSize: 12, color: context.k.inkSoft),
                            ),
                          ),
                          const SizedBox(height: 0),
                        ] else
                          const SizedBox(height: 14),
                        if (items.length > 1 && !hasUnmatchedActive) ...[
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Từ 1 lần nói · ${items.length} ghi nhận',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    color: context.k.ink),
                              ),
                              if (pendingCount > 0) ...[
                                TextButton.icon(
                                  onPressed: _approveAll,
                                  icon: Icon(Icons.done_all_rounded,
                                      size: 14, color: context.k.brand),
                                  label: Text(
                                    'Duyệt tất cả',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.k.brand,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (approvedCount > 0) ...[
                                TextButton.icon(
                                  onPressed: _unapproveAll,
                                  icon: Icon(Icons.undo_rounded,
                                      size: 14, color: context.k.warn),
                                  label: Text(
                                    'Bỏ duyệt tất cả',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.k.warn,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              _CounterPill(
                                approved: approvedCount,
                                total: totalCount - discardedCount,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n?.readInSpokenOrder ??
                                'Đọc lại theo đúng thứ tự cô đã kể.',
                            style: TextStyle(
                                fontSize: 12, color: context.k.inkSoft),
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 17),
                        if (!hasUnmatchedActive) ...[
                          if (widget.recordedBytes != null &&
                              widget.recordedBytes!.isNotEmpty)
                            contentWidth(
                              _AudioPlayerCard(
                                recordedBytes: widget.recordedBytes!,
                                audioPlayerFactory: widget.audioPlayerFactory,
                              ),
                            ),
                          if (effectiveTranscript.isNotEmpty)
                            contentWidth(
                              _AnalyzedTextCard(
                                text: effectiveTranscript,
                                matchedChildCount: items
                                    .where((item) =>
                                        item.childId != null &&
                                        item.matched &&
                                        item.kind == ObservationKind.normal)
                                    .length,
                                onEdit: _editAndReanalyzeTranscript,
                              ),
                            ),
                        ],
                        for (var i = 0; i < items.length; i++)
                          _AnimatedObservationWrapper(
                            key: ValueKey(items[i].id),
                            decision: items[i].decision,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ObservationTile(
                                card: items[i],
                                className: widget.className,
                                showSegmentPreview: hasUnmatchedActive,
                                isApproving: approvingIds.contains(items[i].id),
                                onToggleApprove: () {
                                  if (items[i].decision ==
                                      ObservationDecision.approved) {
                                    _unapproveItem(items[i]);
                                  } else {
                                    _approveItem(items[i]);
                                  }
                                },
                                onUnapprove: () => _unapproveItem(items[i]),
                                onDiscard: () => _discardItem(items[i]),
                                onRestore: () => _restoreItem(items[i]),
                                onAssign: () =>
                                    _assignChild(items[i], onAssignClass: () {
                                  final draftIds = List<String>.from(
                                      approvedDraftIds[items[i].id] ??
                                          <String>[]);
                                  setState(() {
                                    items[i].kind = ObservationKind.classwide;
                                    items[i].name = 'Chung cả lớp';
                                    items[i].matched = true;
                                    items[i].decision =
                                        ObservationDecision.pending;
                                    approvedDraftIds.remove(items[i].id);
                                  });
                                  if (draftIds.isNotEmpty) {
                                    teacherRepository
                                        .deleteDraftReports(draftIds);
                                  }
                                }),
                                onEdit: () => _editObservation(items[i]),
                              ),
                            ),
                          ),
                        if (!hasUnmatchedActive) ...[
                          const SizedBox(height: 0),
                          if (pendingCount > 0 || approvedCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                approvedCount == 0
                                    ? 'Chưa có mục nào được duyệt. Duyệt hoặc loại bỏ từng mục để tiếp tục.'
                                    : 'Còn $pendingCount mục chưa xử lý. Vui lòng duyệt hoặc loại bỏ tất cả các mục để có thể gửi.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: approvedCount == 0
                                      ? context.k.brand
                                      : context.k.warn,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          contentWidth(
                            FilledButton(
                              onPressed: !isSubmitting &&
                                      approvedCount > 0 &&
                                      pendingCount == 0 &&
                                      unmatchedActiveCount == 0
                                  ? _sendBatch
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: context.k.brand,
                                foregroundColor: context.k.surface,
                                disabledBackgroundColor:
                                    context.k.surfaceSunken,
                                disabledForegroundColor: context.k.inkSoft,
                                minimumSize: const Size(double.infinity, 48),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(isSubmitting
                                  ? 'Đang gửi báo cáo…'
                                  : approvedCount > 0 &&
                                          pendingCount == 0 &&
                                          unmatchedActiveCount == 0
                                      ? 'Hoàn thành'
                                      : approvedCount == 0
                                          ? 'Chưa duyệt mục nào để gửi'
                                          : pendingCount > 0
                                              ? 'Còn $pendingCount mục chưa duyệt hoặc loại bỏ'
                                              : 'Hoàn thành'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sleepDurationMinutes(String value) {
    final duration = RegExp(r'(\d+)\s*phút', caseSensitive: false)
        .firstMatch(value)
        ?.group(1);
    if (duration != null) return duration;
    final numeric = int.tryParse(value.trim());
    if (numeric != null) return '$numeric';
    final times = RegExp(
      r'(\d{1,2}):(\d{2})\s*(?:đến|[-–])\s*(\d{1,2}):(\d{2})',
      caseSensitive: false,
    ).firstMatch(value);
    if (times == null) return '';
    final startHour = int.parse(times.group(1)!);
    final startMinute = int.parse(times.group(2)!);
    final endHour = int.parse(times.group(3)!);
    final endMinute = int.parse(times.group(4)!);
    if (startHour > 23 || endHour > 23 || startMinute > 59 || endMinute > 59) {
      return '';
    }
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    final minutes = (end - start + 1440) % 1440;
    return minutes == 0 ? '' : '$minutes';
  }

  String _sleepNarrative(String value) => value
      .replaceAll(
          RegExp(r'\s*(?:[·,]\s*)?\d+\s*phút', caseSensitive: false), '')
      .trim();

  String _editedSleep(String narrative, String duration) {
    final description = _sleepNarrative(narrative);
    final minutes = duration.trim().isNotEmpty
        ? duration.trim()
        : _sleepDurationMinutes(narrative);
    return [description, if (minutes.isNotEmpty) '$minutes phút']
        .where((value) => value.isNotEmpty)
        .join(' · ');
  }

  Future<void> _editObservation(ObservationItem item) async {
    if ((approvedDraftIds[item.id] ?? const <String>[])
        .any(sentDraftIds.contains)) {
      _showError('Báo cáo đã gửi một phần nên không thể sửa mục này.');
      return;
    }
    final eatingCtrl = TextEditingController(text: item.eating);
    final sleepCtrl =
        TextEditingController(text: _sleepDurationMinutes(item.sleep));
    final sleepDescriptionCtrl =
        TextEditingController(text: _sleepNarrative(item.sleep));
    final activitiesCtrl = TextEditingController(text: item.activities);
    final moodCtrl = TextEditingController(text: item.mood);
    final healthCtrl = TextEditingController(text: item.health);
    final noteCtrl = TextEditingController(text: item.note);
    final snippetCtrl = TextEditingController(text: item.snippet);

    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => GardenVoiceScope(
        child: EditObservationScreen(
          title: item.fullNameWithNickname,
          isUnmatched: item.kind == ObservationKind.unmatched,
          eatingCtrl: eatingCtrl,
          sleepCtrl: sleepCtrl,
          sleepDescriptionCtrl: sleepDescriptionCtrl,
          activitiesCtrl: activitiesCtrl,
          moodCtrl: moodCtrl,
          healthCtrl: healthCtrl,
          noteCtrl: noteCtrl,
          snippetCtrl: snippetCtrl,
        ),
      ),
    ));

    if (saved == true && mounted) {
      setState(() {
        item.eating = eatingCtrl.text.trim();
        item.sleep = _editedSleep(sleepDescriptionCtrl.text, sleepCtrl.text);
        item.activities = activitiesCtrl.text.trim();
        item.mood = moodCtrl.text.trim();
        item.health = healthCtrl.text.trim();
        item.note = noteCtrl.text.trim();
        if (item.kind == ObservationKind.unmatched) {
          item.snippet = snippetCtrl.text.trim();
        }
      });

      // Nếu item đã được approve trước đó, gọi lại approveItem để sync với backend
      if (item.decision == ObservationDecision.approved) {
        await _approveItem(item);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật nội dung cho "${item.name}".'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    eatingCtrl.dispose();
    sleepCtrl.dispose();
    sleepDescriptionCtrl.dispose();
    activitiesCtrl.dispose();
    moodCtrl.dispose();
    healthCtrl.dispose();
    noteCtrl.dispose();
    snippetCtrl.dispose();
  }

  Future<void> _editAndReanalyzeTranscript() async {
    final textCtrl = TextEditingController(text: effectiveTranscript);
    bool? shouldReanalyze;
    String newText = '';
    try {
      shouldReanalyze = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: context.k.brand),
              const SizedBox(width: 8),
              const Text('Chỉnh sửa văn bản ghi âm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn có thể chỉnh sửa lại nội dung văn bản dưới đây rồi bấm "Phân tích lại" để AI trích xuất lại thông tin:',
                  style: TextStyle(fontSize: 12, color: context.k.inkSoft),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 6,
                  minLines: 3,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                  decoration: InputDecoration(
                    hintText: context.l10n?.sttEnterTextHint ??
                        'Nhập nội dung văn bản...',
                    filled: true,
                    fillColor: context.k.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.k.line),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n?.commonCancel ?? 'Hủy'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text(context.l10n?.sttReanalyze ?? 'Phân tích lại'),
            ),
          ],
        ),
      );
      newText = textCtrl.text.trim();
    } finally {
      textCtrl.dispose();
    }

    if (shouldReanalyze == true && mounted) {
      if (newText.isEmpty) {
        _showError('Văn bản không được để trống.');
        return;
      }

      final voiceRecordId = widget.voiceRecord?.id;
      if (voiceRecordId == null || voiceRecordId.isEmpty) {
        setState(() {
          editedTranscript = newText;
        });
        return;
      }

      String teacherId;
      try {
        final t = await repository.getCurrentTeacher();
        teacherId = t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
      } catch (_) {
        teacherId =
            AuthRepository.currentUser?.teacherId ?? repository.teacherId;
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang phân tích lại với văn bản mới...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final newExtraction = await teacherRepository.analyzeTranscript(
          voiceId: voiceRecordId,
          teacherId: teacherId,
          editedTranscript: newText,
        );

        if (!mounted) return;
        Navigator.pop(context); // close loading dialog

        final oldDraftIds = <String>[];
        for (final ids in approvedDraftIds.values) {
          oldDraftIds.addAll(ids);
        }
        if (oldDraftIds.isNotEmpty) {
          try {
            await teacherRepository.deleteDraftReports(oldDraftIds);
          } catch (e) {
            debugPrint('Lỗi xóa bản nháp cũ khi phân tích lại: $e');
          }
        }

        if (!mounted) return;

        setState(() {
          editedTranscript = newText;
          currentExtraction = newExtraction;
          approvedDraftIds.clear();
          items = _buildObservations(roster, newExtraction);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã phân tích lại thành công!'),
            backgroundColor: context.k.brand,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // close loading dialog
        _showError('Lỗi khi phân tích lại: $e');
      }
    }
  }
}

// ===========================================================================
// Audio Player Card & Analyzed Text Card (delegated to extracted widgets)
// ===========================================================================

typedef _AudioPlayerCard = AudioPlayerCard;
typedef _AnalyzedTextCard = AnalyzedTextCard;

typedef SegmentationScreen = ReviewScreen;


typedef _DoneScreenView = DoneScreenView;

// ===========================================================================
// Counter pill "X / Y đã duyệt" ở header
// ===========================================================================

typedef _CounterPill = CounterPill;
typedef _AnimatedObservationWrapper = AnimatedObservationWrapper;
