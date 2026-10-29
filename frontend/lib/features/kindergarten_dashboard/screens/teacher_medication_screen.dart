// frontend/lib/features/kindergarten_dashboard/screens/teacher_medication_screen.dart
// ==============================================================================
// Màn hình Lịch dặn uống thuốc trong ngày của lớp - Dành cho Giáo viên (Task #295).
// - Gom nhóm theo buổi: Sáng (morning) / Trưa (noon) / Chiều (afternoon).
// - Xác nhận 1-chạm "Đã cho uống thuốc".
// - Khóa mờ nút (Grayed out) khi cô giáo khác cùng lớp đã xác nhận trước đó.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class TeacherMedicationScreen extends StatefulWidget {
  const TeacherMedicationScreen({
    super.key,
    this.repository,
    this.initialDate,
  });

  final HttpMedicationRepository? repository;
  final String? initialDate;

  @override
  State<TeacherMedicationScreen> createState() => _TeacherMedicationScreenState();
}

class _TeacherMedicationScreenState extends State<TeacherMedicationScreen>
    with SingleTickerProviderStateMixin {
  late final HttpMedicationRepository _repository =
      widget.repository ?? HttpMedicationRepository();

  late TabController _tabController;
  late Future<MedicationsTodayData> _future;
  final Set<String> _confirmingRequestIds = {};

  final List<String> _sessions = ['all', 'morning', 'noon', 'afternoon'];
  final List<String> _sessionLabels = ['Tất cả', 'Buổi Sáng', 'Buổi Trưa', 'Buổi Chiều'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sessions.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _future = _repository.getTodayMedications(date: widget.initialDate);
    });
  }

  Future<void> _confirmMedication(MedicationItem item) async {
    final key = '${item.requestId}_${item.session}';
    if (_confirmingRequestIds.contains(key)) return;

    setState(() => _confirmingRequestIds.add(key));

    try {
      final res = await _repository.confirmMedication(
        requestId: item.requestId,
        session: item.session,
      );

      final givenByName = res['given_by_name']?.toString() ?? 'Tôi';
      final givenAt = res['given_at'] != null
          ? DateTime.tryParse(res['given_at'].toString()) ?? DateTime.now()
          : DateTime.now();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xác nhận cho bé ${item.childName} uống thuốc thành công!'),
            backgroundColor: const Color(0xFF389E0D),
          ),
        );
      }

      // Cập nhật trạng thái item ngay lập tức trên UI
      _updateItemLocally(item.requestId, item.session, true, givenByName, givenAt);
    } on MedicationAlreadyConfirmedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFFA8C16),
          ),
        );
      }
      // Reload lại dữ liệu mới nhất từ server
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xác nhận uống thuốc: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _confirmingRequestIds.remove(key));
      }
    }
  }

  void _updateItemLocally(
    String requestId,
    String session,
    bool isGiven,
    String givenByName,
    DateTime givenAt,
  ) {
    _future = _future.then((data) {
      List<MedicationItem> updateList(List<MedicationItem> list) {
        return list.map((it) {
          if (it.requestId == requestId && it.session == session) {
            return it.copyWith(
              isGiven: isGiven,
              givenByName: givenByName,
              givenAt: givenAt,
            );
          }
          return it;
        }).toList();
      }

      return MedicationsTodayData(
        date: data.date,
        classId: data.classId,
        className: data.className,
        totalRequests: data.totalRequests,
        completedCount: data.completedCount + (isGiven ? 1 : 0),
        pendingCount: (data.pendingCount - (isGiven ? 1 : 0)).clamp(0, 999),
        morning: updateList(data.morning),
        noon: updateList(data.noon),
        afternoon: updateList(data.afternoon),
      );
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Scaffold(
      backgroundColor: k.canvas,
      appBar: AppBar(
        backgroundColor: k.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: k.ink),
        title: Text(
          'Lịch Uống Thuốc Của Lớp',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: k.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: k.ink),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: k.brand,
          unselectedLabelColor: k.inkSoft,
          indicatorColor: k.brand,
          indicatorWeight: 3.0,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: _sessionLabels.map((lbl) => Tab(text: lbl)).toList(),
        ),
      ),
      body: FutureBuilder<MedicationsTodayData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: k.bad),
                  const SizedBox(height: 12),
                  Text('Không tải được lịch uống thuốc: ${snapshot.error}', style: TextStyle(color: k.inkSoft)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(child: Text('Không có dữ liệu.', style: TextStyle(color: k.inkSoft)));
          }

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: Column(
              children: [
                _buildSummaryHeader(data, k),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(data.allItems, k, emptyMessage: 'Hôm nay không có bé nào cần uống thuốc!'),
                      _buildList(data.morning, k, emptyMessage: 'Không có bé nào cần uống thuốc buổi sáng!'),
                      _buildList(data.noon, k, emptyMessage: 'Không có bé nào cần uống thuốc buổi trưa!'),
                      _buildList(data.afternoon, k, emptyMessage: 'Không có bé nào cần uống thuốc buổi chiều!'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(MedicationsTodayData data, KPalette k) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: k.surface,
        border: Border(bottom: BorderSide(color: k.line, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: k.brandTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medication_outlined, color: k.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.className ?? "Lớp học"} · Hôm nay',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: k.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tổng số: ${data.totalRequests} lượt · Đã uống: ${data.completedCount} · Chưa uống: ${data.pendingCount}',
                  style: TextStyle(fontSize: 12, color: k.inkSoft),
                ),
              ],
            ),
          ),
          if (data.pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: k.warn,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Còn ${data.pendingCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<MedicationItem> items, KPalette k, {String emptyMessage = 'Không có bé nào cần uống thuốc trong buổi này!'}) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 54, color: k.ok),
                const SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: TextStyle(color: k.inkSoft, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMedicationCard(item, k);
      },
    );
  }

  Widget _buildMedicationCard(MedicationItem item, KPalette k) {
    final key = '${item.requestId}_${item.session}';
    final isConfirming = _confirmingRequestIds.contains(key);

    String sessionLabel = 'Buổi Sáng';
    Color sessionColor = const Color(0xFF1890FF);
    if (item.session == 'noon') {
      sessionLabel = 'Buổi Trưa';
      sessionColor = const Color(0xFFFA8C16);
    } else if (item.session == 'afternoon') {
      sessionLabel = 'Buổi Chiều';
      sessionColor = const Color(0xFF722ED1);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: k.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: k.line, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row thông tin bé + Badge buổi
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: sessionColor.withValues(alpha: 0.15),
                  child: Text(
                    item.childName.isNotEmpty ? item.childName[0].toUpperCase() : 'B',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sessionColor,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.childName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: k.ink),
                      ),
                      if (item.childNickname != null && item.childNickname!.isNotEmpty)
                        Text(
                          '(${item.childNickname})',
                          style: TextStyle(fontSize: 12, color: k.inkSoft),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sessionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sessionLabel,
                    style: TextStyle(
                      color: sessionColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: k.line),
            const SizedBox(height: 12),

            // Thông tin thuốc & liều lượng
            Row(
              children: [
                Icon(Icons.medication, size: 18, color: k.inkSoft),
                const SizedBox(width: 8),
                Text(
                  'Thuốc: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: k.inkSoft),
                ),
                Expanded(
                  child: Text(
                    item.medicationName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: k.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.straighten, size: 18, color: k.inkSoft),
                const SizedBox(width: 8),
                Text(
                  'Liều lượng: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: k.inkSoft),
                ),
                Text(
                  item.dosage,
                  style: TextStyle(fontSize: 13, color: k.ink),
                ),
              ],
            ),

            if (item.instructions != null && item.instructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: k.surfaceSunken,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: k.line),
                ),
                child: Text(
                  'Dặn dò: ${item.instructions}',
                  style: TextStyle(fontSize: 13, color: k.ink),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Nút xác nhận 1-chạm hoặc Khóa nếu cô khác đã cho uống ────────
            if (item.isGiven)
              // Đã uống -> Nút xám mờ (Grayed out) hiển thị tên cô và giờ uống
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: k.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: k.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: k.ok, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${item.givenByName ?? "Giáo viên"} đã cho uống lúc ${item.givenAt != null ? DateFormat("HH:mm").format(item.givenAt!) : "vừa xong"}',
                        style: TextStyle(
                          color: k.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Chưa uống -> Nút xanh nổi bật bấm 1-chạm
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isConfirming ? null : () => _confirmMedication(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52C41A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  icon: isConfirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.done_all, size: 20),
                  label: Text(
                    isConfirming ? 'Đang xác nhận...' : 'ĐÃ CHO UỐNG THUỐC',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
