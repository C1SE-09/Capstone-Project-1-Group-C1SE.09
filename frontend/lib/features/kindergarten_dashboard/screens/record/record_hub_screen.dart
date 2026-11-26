import 'dart:async';

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/child/child.dart'
    as domain_child;
import 'package:adark_frontend/domain/entities/class/class_info.dart'
    as domain_class;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_models.dart';

class RecordHubScreen extends StatefulWidget {
  const RecordHubScreen(
      {super.key,
      required this.onClass,
      required this.onChild,
      this.classId = '',
      this.repository,
      this.classRepository,
      this.onNavigationSelected});
  final VoidCallback onClass;
  final ValueChanged<Child> onChild;
  final String classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;
  final ValueChanged<GardenVoiceTeacherDestination>? onNavigationSelected;

  @override
  State<RecordHubScreen> createState() => _RecordHubScreenState();
}

class _RecordHubScreenState extends State<RecordHubScreen> {
  String query = '';
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository =
      widget.classRepository ?? HttpClassDataRepository();
  late Future<_RecordHubData> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  // Loads class roster, dashboard statuses, and class display information.
  Future<_RecordHubData> _load() async {
    final values = await Future.wait([
      repository.getClassChildren(widget.classId),
      repository.getClassDashboard(widget.classId, DateTime.now()),
      classRepository.getClassInfo(widget.classId)
    ]);
    final rawChildren = values[0] as List<domain_child.Child>;
    final dashboard = values[1] as ClassDashboardSummary;
    final classInfo = values[2] as domain_class.ClassInfo;
    final statuses = {
      for (final item in dashboard.pendingChildren) item.child.childId: item
    };
    final converted = rawChildren.map((child) {
      final item = statuses[child.childId];
      final severity = severityFromDescription(null);
      return item == null
          ? uiChildFromDomain(
              child: child, reportStatus: ReportStatus.none, severity: severity)
          : uiChildFromDomainWithReport(
              child: child,
              reportStatus: item.status,
              severity: severity,
              updatedAt: item.updatedAt);
    }).toList();
    return _RecordHubData(converted, classInfo.name, dashboard.totalChildren,
        dashboard.notCompletedCount);
  }

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: FutureBuilder<_RecordHubData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Scaffold(
                  body: Center(
                      child: TextButton(
                          onPressed: () => setState(() => future = _load()),
                          child: Text(
                            context.l10n?.sttCannotLoadClassRetry ??
                                'Không tải được lớp · Thử lại',
                          ))));
            }
            final data = snapshot.data!;
            final list = data.children
                .where((child) =>
                    child.fullNameWithNickname
                        .toLowerCase()
                        .contains(query.toLowerCase()) ||
                    (child.nickname ?? '')
                        .toLowerCase()
                        .contains(query.toLowerCase()))
                .toList();
            final k = context.k;
            final l10n = context.l10n;
            return Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    GardenVoiceRecordHeader(
                      title: l10n?.sttRecordActivityTitle ?? 'Ghi nhận hoạt động',
                      subtitle: l10n?.sttSelectChildToStart ?? 'Chọn trẻ để bắt đầu ghi nhận',
                      onBack: () => Navigator.pop(context),
                      backAsset: 'assets/garden_voice/hub_back.svg',
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: k.brandTint,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: widget.onClass,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 82),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: k.lineStrong),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                  'assets/garden_voice/class_group.svg'),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        LocaleController.instance.isEnglish
                                            ? 'All Class ${data.className.replaceFirst(RegExp(r'^(Lớp|Class)\s*', caseSensitive: false), '')}'
                                            : 'Cả Lớp ${data.className.replaceFirst(RegExp(r'^Lớp\s+'), '')}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700,
                                          color: k.ink,
                                        )),
                                    Text(
                                        LocaleController.instance.isEnglish
                                            ? 'Record once, generate reports for all children.'
                                            : 'Ghi một lần, tạo báo cáo cho tất cả trẻ.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                          color: k.inkSoft,
                                        )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SvgPicture.asset(
                                  'assets/garden_voice/caret_filled.svg'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: k.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                                l10n?.sttOrSelectEachChild ?? 'hoặc chọn từng trẻ',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: k.inkFaint,
                                )),
                          ),
                          Expanded(child: Divider(color: k.line)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        onChanged: (value) => setState(() => query = value),
                        style: TextStyle(fontSize: 14, color: k.ink),
                        decoration: InputDecoration(
                          hintText: l10n?.sttSearchChild ?? 'Tìm trẻ…',
                          hintStyle: TextStyle(color: k.inkSoft),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(11),
                            child: SvgPicture.asset(
                                'assets/garden_voice/record_search.svg'),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          filled: true,
                          fillColor: const Color(0xFFEDF4F7),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF9FC3CF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: k.brand, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${data.className} · ${data.totalChildren} trẻ',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: k.inkSoft,
                              ),
                            ),
                          ),
                          Text('${data.pendingCount} chưa xong',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: k.inkFaint,
                              )),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 257,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FCFB),
                          border: Border.all(color: k.lineStrong),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF212E2B)
                                  .withValues(alpha: .05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: list.isEmpty
                            ? Center(
                                child: Text(
                                  'Không tìm thấy trẻ phù hợp.',
                                  style: TextStyle(color: k.inkSoft),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: k.line),
                                itemBuilder: (context, index) {
                                  final child = list[index];
                                  final allergy = child.allergy == null
                                      ? null
                                      : recordAllergy(child.allergy!);
                                  return InkWell(
                                    onTap: () => widget.onChild(child),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        children: [
                                          Avatar(name: child.name),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(child.fullNameWithNickname,
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.4,
                                                      color: k.ink,
                                                    )),
                                                if (allergy != null &&
                                                    allergy.isNotEmpty)
                                                  Text('Dị ứng: $allergy',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        height: 1.4,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: k.warn,
                                                      )),
                                                if ((child.careNotes ?? '')
                                                    .trim()
                                                    .isNotEmpty)
                                                  Text(
                                                      'Lưu ý: ${child.careNotes!.trim()}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        height: 1.4,
                                                        color: k.inkSoft,
                                                      )),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _GardenVoiceRecordStatus(
                                              status: child.status),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: GardenVoiceTeacherNavigation(
                selected: GardenVoiceTeacherDestination.record,
                onSelected: (destination) {
                  if (destination == GardenVoiceTeacherDestination.record) {
                    return;
                  }
                  if (widget.onNavigationSelected != null) {
                    widget.onNavigationSelected!(destination);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            );
          },
        ),
      );
}

class _RecordHubData {
  const _RecordHubData(
      this.children, this.className, this.totalChildren, this.pendingCount);
  final List<Child> children;
  final String className;
  final int totalChildren;
  final int pendingCount;
}

class GardenVoiceRecordHeader extends StatelessWidget {
  const GardenVoiceRecordHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backAsset = 'assets/garden_voice/record_back.svg',
    this.showProgress = false,
    this.progressStep = 0,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String backAsset;
  final bool showProgress;
  final int progressStep;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: context.l10n?.commonBack ?? 'Quay lại',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: SvgPicture.asset(backAsset),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: k.ink,
                      )),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: k.inkSoft,
                      )),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        if (showProgress) ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index <= progressStep ? k.brand : k.brandTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
              'Bước ${progressStep + 1}/3 · ${const [
                'Ghi âm',
                'Phân tích',
                'Xem lại'
              ][progressStep]}',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: k.inkSoft,
              )),
        ],
      ],
    );
  }
}

class _GardenVoiceRecordStatus extends StatelessWidget {
  const _GardenVoiceRecordStatus({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (label, background, foreground) = switch (status) {
      ReportStatus.none => ('Chưa ghi', k.surfaceSunken, k.inkSoft),
      ReportStatus.draft || ReportStatus.processing => (
          'Đang xử lý',
          k.infoTint,
          k.info
        ),
      ReportStatus.submitted || ReportStatus.read => ('Đã ghi', k.okTint, k.ok),
      ReportStatus.attention => ('Cần xử lý', k.badTint, k.bad),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: foreground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: foreground,
              )),
        ],
      ),
    );
  }
}

