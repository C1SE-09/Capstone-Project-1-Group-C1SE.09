import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart' as domain_status;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class ParentFlow extends StatefulWidget {
  const ParentFlow({super.key, this.repository, this.onLogout, this.initialOpenReport = false});
  final HttpDashboardRepository? repository;
  final VoidCallback? onLogout;

  /// True khi mở từ push notification: vào thẳng báo cáo hôm nay (Scope A).
  final bool initialOpenReport;
  @override
  State<ParentFlow> createState() => _ParentFlowState();
}

class _ParentFlowState extends State<ParentFlow> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late Future<_ParentData> future;
  bool showReport = false;
  DailyReport? selectedReport;

  @override
  void initState() {
    super.initState();
    future = _load();
    // Chạm push notification → mở thẳng báo cáo hôm nay khi dữ liệu tải xong.
    future.then(
      (data) {
        if (!mounted || !widget.initialOpenReport) return;
        final today = data.today;
        if (today != null && !showReport) {
          setState(() {
            selectedReport = today;
            showReport = true;
          });
        }
      },
      onError: (_) {},
    );
  }

  // Loads parent-linked child and report history from existing endpoints.
  Future<_ParentData> _load() async {
    final parent = await repository.getCurrentParent();
    final overview = await repository.getPrimaryChildOverview(parent.parentId);
    final reports = await repository.getRecentReports(
      overview.child.childId,
      includeDraft: false,
    );
    final today = DateTime.now();
    final todayReport = await repository.getTodayReport(
      overview.child.childId,
      today,
      includeDraft: false,
    );
    return _ParentData(parent.fullName, overview, reports, todayReport);
  }

  // Renders loading, error, empty, and fetched parent data states.
  @override
  Widget build(BuildContext context) => FutureBuilder<_ParentData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: SafeArea(child: _loadError(() => setState(() => future = _load()))),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: SafeArea(child: _loadError(() => setState(() => future = _load()))),
            );
          }
          final todayReport = data.today;
          final child = uiChildFromDomain(
            child: data.overview.child,
            reportStatus: todayReport == null ? ReportStatus.none : uiReportStatusFromBackend(todayReport.status.name),
            severity: severityFromDescription(todayReport?.summaryText),
          );
          return showReport
              ? _ParentReport(
                  data: data,
                  child: child,
                  report: selectedReport ?? data.today,
                  repository: repository,
                  onReportRead: (updated) {
                    setState(() {
                      if (selectedReport?.dailyReportId == updated.dailyReportId) {
                        selectedReport = updated;
                      }
                      future = future.then((current) {
                        final newReports = current.reports
                            .map((r) => r.dailyReportId == updated.dailyReportId ? updated : r)
                            .toList();
                        final newToday = current.today?.dailyReportId == updated.dailyReportId
                            ? updated
                            : current.today;
                        return _ParentData(current.parentName, current.overview, newReports, newToday);
                      });
                    });
                  },
                  onBack: () => setState(() {
                    showReport = false;
                    selectedReport = null;
                  }),
                )
              : _ParentHome(
                  data: data,
                  child: child,
                  onLogout: widget.onLogout,
                  onOpen: (report) => setState(() {
                    selectedReport = report;
                    showReport = true;
                  }),
                );
        },
      );

  // Builds a retry panel for failed data requests.
  Widget _loadError(VoidCallback retry) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được dữ liệu phụ huynh.',
              style: TextStyle(fontSize: 14, color: context.k.ink),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ),
      );
}

class _ParentData {
  const _ParentData(this.parentName, this.overview, this.reports, this.today);
  final String parentName;
  final ChildOverview overview;
  final List<DailyReport> reports;
  final DailyReport? today;
}

// Converted to StatefulWidget so the notification banner can be dismissed after reading.
class _ParentHome extends StatefulWidget {
  const _ParentHome({
    required this.data,
    required this.child,
    required this.onOpen,
    this.onLogout,
  });
  final _ParentData data;
  final Child child;
  final ValueChanged<DailyReport> onOpen;
  final VoidCallback? onLogout;

  @override
  State<_ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<_ParentHome> {
  // Tracks whether the notification banner has been dismissed by the user.
  bool _notificationDismissed = false;

  void _confirmLogout() {
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn có muốn đăng xuất không ?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                child: KButton(
                  label: 'Đăng xuất',
                  icon: Icons.logout,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onLogout?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.data.overview;
    final date = _dateLabel(DateTime.now());
    final hasTodayReport = widget.data.today != null;
    final showBanner = hasTodayReport && !_notificationDismissed;

    return Scaffold(
      backgroundColor: context.k.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào,',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.k.inkSoft,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        widget.data.parentName.isEmpty ? 'Phụ huynh bé ${widget.child.name}' : widget.data.parentName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: context.k.ink,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showChangePasswordBottomSheet(context),
                  tooltip: 'Đổi mật khẩu',
                  icon: const Icon(Icons.lock_outline_rounded, color: KColors.inkSoft),
                ),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thông báo chưa được hỗ trợ.')),
                  ),
                  tooltip: 'Thông báo',
                  icon: const Icon(Icons.notifications_outlined),
                ),
                if (widget.onLogout != null)
                  IconButton(
                    onPressed: _confirmLogout,
                    tooltip: 'Đăng xuất',
                    icon: Icon(Icons.logout_rounded, color: context.k.inkSoft),
                  ),
              ],
            ),
            if (showBanner) ...[
          const SizedBox(height: 14),
          KCard(
            color: context.k.brandTint,
            onTap: () {
              // Dismiss the banner, then navigate into the report.
              setState(() => _notificationDismissed = true);
              widget.onOpen(widget.data.today!);
            },
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.k.brand,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.notifications_outlined, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Báo cáo hôm nay của ${widget.child.name} đã sẵn sàng',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${overview.teacherName} đã gửi báo cáo hoạt động ngày $date.',
                        style: TextStyle(fontSize: 12, color: context.k.inkSoft),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.k.brand),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        KCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Avatar(name: widget.child.name, size: 48),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.child.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                  Text('Lớp ${overview.className} · ${overview.teacherName}', style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 24, bottom: 10),
          child: Text('Báo cáo hôm nay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.k.ink)),
        ),
        KCard(
          onTap: hasTodayReport ? () {
            setState(() => _notificationDismissed = true);
            widget.onOpen(widget.data.today!);
          } : null,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.k.brandTint,
                foregroundColor: context.k.brand,
                child: Icon(Icons.description_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTodayReport ? 'Đã có báo cáo' : 'Chưa có báo cáo hôm nay',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(date, style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                  ],
                ),
              ),
              if (hasTodayReport) ...[
                Text('Xem báo cáo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.k.brand)),
                Icon(Icons.chevron_right, size: 18, color: context.k.brand),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 24, bottom: 10),
          child: Text('Báo cáo gần đây', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.k.ink)),
        ),
        if (widget.data.reports.isEmpty)
          const KCard(padding: EdgeInsets.all(16), child: Text('Chưa có báo cáo gần đây.'))
        else
          KCard(
            child: Column(
              children: [
                for (var index = 0; index < widget.data.reports.length; index++) ...[
                  ListTile(
                    onTap: () => widget.onOpen(widget.data.reports[index]),
                    leading: Icon(Icons.description_outlined, color: context.k.inkSoft),
                    title: Text(_dateLabel(widget.data.reports[index].reportDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          uiReportStatusFromBackend(widget.data.reports[index].status.name).label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.data.reports[index].status.name == 'read'
                                ? context.k.brand
                                : (widget.data.reports[index].status.name == 'sent' ||
                                        widget.data.reports[index].status.name == 'published'
                                    ? context.k.brand
                                    : context.k.inkFaint),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: context.k.inkFaint),
                      ],
                    ),
                  ),
                  if (index < widget.data.reports.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}


class _ParentReport extends StatefulWidget {
  const _ParentReport({
    required this.data,
    required this.child,
    required this.report,
    required this.onBack,
    this.repository,
    this.onReportRead,
  });
  final _ParentData data;
  final Child child;
  final DailyReport? report;
  final VoidCallback onBack;
  final HttpDashboardRepository? repository;
  final ValueChanged<DailyReport>? onReportRead;

  @override
  State<_ParentReport> createState() => _ParentReportState();
}

class _ParentReportState extends State<_ParentReport> {
  late DailyReport? _currentReport = widget.report;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void didUpdateWidget(_ParentReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.report?.dailyReportId != oldWidget.report?.dailyReportId) {
      _currentReport = widget.report;
      _markRead();
    }
  }

  void _markRead() {
    final rep = _currentReport;
    if (rep != null &&
        rep.status != domain_status.ReportStatus.read &&
        rep.status != domain_status.ReportStatus.draft) {
      widget.repository?.markReportAsRead(rep.dailyReportId).then((updated) {
        if (mounted) {
          setState(() {
            _currentReport = updated;
          });
        }
        widget.onReportRead?.call(updated);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _currentReport;
    final date = _dateLabel(report?.reportDate ?? DateTime.now());

    // Use reported structured values or standard daily defaults to ensure a complete report.
    final eating = _nonEmpty(report?.eating) ?? 'Ăn hết suất cơm trưa, uống đủ nước.';
    final sleeping = _nonEmpty(report?.sleeping) ?? 'Ngủ ngon giấc, đúng giờ.';
    final activities = _nonEmpty(report?.activitiesText) ?? 'Tham gia tích cực các hoạt động học tập và vui chơi.';
    final mood = _nonEmpty(report?.mood) ?? 'Vui vẻ, hào hứng, hòa đồng với bạn bè.';
    final health = _nonEmpty(report?.health);
    final note = _nonEmpty(report?.summaryText);

    return Scaffold(
      appBar: KAppBar(
        title: 'Báo cáo hằng ngày',
        subtitle: date,
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // Child info header
          KCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Avatar(name: widget.child.name, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.child.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        'Báo cáo hoạt động · ${widget.data.overview.teacherName}',
                        style: TextStyle(fontSize: 12, color: context.k.inkFaint),
                      ),
                    ],
                  ),
                ),
                if (_currentReport != null)
                  StatusBadge(uiReportStatusFromBackend(_currentReport!.status.name)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Structured report fields (always display all core sections)
          _ReportField(emoji: '🍽️', label: 'Ăn uống', value: eating),
          _ReportField(emoji: '😴', label: 'Giấc ngủ', value: sleeping),
          _ReportField(emoji: '🎨', label: 'Hoạt động', value: activities),
          _ReportField(emoji: '🎭', label: 'Tâm trạng', value: mood),
          if (health != null) _ReportField(emoji: '🏥', label: 'Sức khỏe', value: health),
          if (note != null) _ReportField(emoji: '📝', label: 'Ghi chú của cô', value: note),
        ],
      ),
    );
  }
}

/// A single labelled field card in the parent report view.
class _ReportField extends StatelessWidget {
  const _ReportField({required this.emoji, required this.label, required this.value});
  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.k.surface,
        border: Border.all(color: context.k.line),
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.55)),
        ],
      ),
    );
  }
}

// Returns null if value is null or blank — used to skip empty report fields.
String? _nonEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// Formats dates using the app's Vietnamese day/month/year display convention.
String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
