import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class ParentFlow extends StatefulWidget {
  const ParentFlow({super.key, this.repository});
  final HttpDashboardRepository? repository;
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
  }

  // Loads parent-linked child and report history from existing endpoints.
  Future<_ParentData> _load() async {
    final parent = await repository.getCurrentParent();
    final overview = await repository.getPrimaryChildOverview(parent.parentId);
    final reports = await repository.getRecentReports(overview.child.childId);
    final today = DateTime.now();
    final todayReport = await repository.getTodayReport(overview.child.childId, today);
    return _ParentData(parent.fullName, overview, reports, todayReport);
  }

  // Renders loading, error, empty, and fetched parent data states.
  @override
  Widget build(BuildContext context) => FutureBuilder<_ParentData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _loadError(() => setState(() => future = _load()));
          final data = snapshot.data;
          if (data == null) return _loadError(() => setState(() => future = _load()));
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
                  onBack: () => setState(() {
                    showReport = false;
                    selectedReport = null;
                  }),
                )
              : _ParentHome(
                  data: data,
                  child: child,
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
            const Text('Không tải được dữ liệu phụ huynh.'),
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

class _ParentHome extends StatelessWidget {
  const _ParentHome({required this.data, required this.child, required this.onOpen});
  final _ParentData data;
  final Child child;
  final ValueChanged<DailyReport> onOpen;

  @override
  Widget build(BuildContext context) {
    final overview = data.overview;
    final date = _dateLabel(DateTime.now());
    final hasTodayReport = data.today != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Xin chào,', style: TextStyle(fontSize: 13, color: KColors.inkSoft)),
                  Text(
                    data.parentName.isEmpty ? 'Phụ huynh bé ${child.name}' : data.parentName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thông báo chưa được hỗ trợ.')),
              ),
              tooltip: 'Thông báo chưa được hỗ trợ',
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
        ),
        if (hasTodayReport) ...[
          const SizedBox(height: 14),
          KCard(
            color: KColors.brandTint,
            onTap: () => onOpen(data.today!),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: KColors.brand,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.notifications_outlined, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Báo cáo hôm nay của ${child.name} đã sẵn sàng',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${overview.teacherName} đã gửi báo cáo hoạt động ngày $date.',
                        style: const TextStyle(fontSize: 12, color: KColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: KColors.brand),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        KCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Avatar(name: child.name, size: 48),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                  Text('Lớp ${overview.className} · ${overview.teacherName}', style: const TextStyle(fontSize: 12, color: KColors.inkFaint)),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 10),
          child: Text('Báo cáo hôm nay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        KCard(
          onTap: hasTodayReport ? () => onOpen(data.today!) : null,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: KColors.brandTint,
                foregroundColor: KColors.brand,
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
                    Text(date, style: const TextStyle(fontSize: 12, color: KColors.inkFaint)),
                  ],
                ),
              ),
              if (hasTodayReport) ...[
                const Text('Xem báo cáo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: KColors.brand)),
                const Icon(Icons.chevron_right, size: 18, color: KColors.brand),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 10),
          child: Text('Báo cáo gần đây', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (data.reports.isEmpty)
          const KCard(padding: EdgeInsets.all(16), child: Text('Chưa có báo cáo gần đây.'))
        else
          KCard(
            child: Column(
              children: [
                for (var index = 0; index < data.reports.length; index++) ...[
                  ListTile(
                    onTap: () => onOpen(data.reports[index]),
                    leading: const Icon(Icons.description_outlined, color: KColors.inkSoft),
                    title: Text(_dateLabel(data.reports[index].reportDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          uiReportStatusFromBackend(data.reports[index].status.name).label,
                          style: TextStyle(
                            fontSize: 12,
                            color: data.reports[index].status.name == 'sent' ? KColors.brand : KColors.inkFaint,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: KColors.inkFaint),
                      ],
                    ),
                  ),
                  if (index < data.reports.length - 1) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ParentReport extends StatefulWidget {
  const _ParentReport({required this.data, required this.child, required this.report, required this.onBack});
  final _ParentData data;
  final Child child;
  final DailyReport? report;
  final VoidCallback onBack;

  @override
  State<_ParentReport> createState() => _ParentReportState();
}

class _ParentReportState extends State<_ParentReport> {
  @override
  Widget build(BuildContext context) {
    final summary = widget.report?.summaryText?.trim();
    final date = _dateLabel(widget.report?.reportDate ?? DateTime.now());

    return Scaffold(
      appBar: KAppBar(
        title: 'Báo cáo hằng ngày',
        subtitle: date,
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Avatar(name: widget.child.name, size: 56),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.child.name, style: Theme.of(context).textTheme.titleLarge),
                  Text('Báo cáo hoạt động · ${widget.data.overview.teacherName}', style: const TextStyle(fontSize: 13, color: KColors.inkFaint)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          KCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              summary == null || summary.isEmpty ? 'Chưa có nội dung chi tiết trong báo cáo này.' : summary,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Formats dates using the app's Vietnamese day/month/year display convention.
String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
