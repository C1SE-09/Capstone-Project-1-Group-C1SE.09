// frontend/lib/features/kindergarten_dashboard/screens/leave_request_review_screen.dart
// ======================================================================================
// Màn hình Duyệt đơn xin nghỉ học dành cho Giáo viên (Teacher UI)
// Tuân thủ:
// - Refactor-safely: Tách sub-widgets riêng, build method gọn gàng
// - Giữ nguyên 100% UI và trải nghiệm người dùng
// - Design System: KColors, KSpace, KRadii

import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/leave_request_card.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/reject_reason_dialog.dart';
import 'package:flutter/material.dart';

class LeaveRequestReviewScreen extends StatefulWidget {
  const LeaveRequestReviewScreen({
    super.key,
    required this.classId,
    this.className,
    this.repository,
  });

  final String classId;
  final String? className;
  final HttpLeaveRequestRepository? repository;

  @override
  State<LeaveRequestReviewScreen> createState() =>
      _LeaveRequestReviewScreenState();
}

class _LeaveRequestReviewScreenState extends State<LeaveRequestReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final HttpLeaveRequestRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  int _pendingCount = 0;
  int _reviewedCount = 0;
  List<LeaveRequestEntity> _items = [];
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpLeaveRequestRepository();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadRequests(tab: 'pending');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final tabName = _tabController.index == 0 ? 'pending' : 'reviewed';
    _loadRequests(tab: tabName);
  }

  Future<void> _loadRequests({required String tab}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _repository.getLeaveRequests(
        classId: widget.classId,
        tab: tab,
      );
      if (!mounted) return;
      setState(() {
        _pendingCount = result.pendingCount;
        _reviewedCount = result.reviewedCount;
        _items = result.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Không thể tải danh sách đơn. Vui lòng kiểm tra kết nối mạng.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(LeaveRequestEntity item) async {
    if (_processing.contains(item.requestId)) return;
    setState(() => _processing.add(item.requestId));
    try {
      await _repository.approveLeaveRequest(item.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item.requestType == LeaveRequestType.lateArrival
              ? 'Đã duyệt báo đi trễ của ${item.childName ?? "bé"}. Giờ đến thực tế do giáo viên xác nhận.'
              : 'Đã duyệt đơn xin nghỉ của ${item.childName ?? "bé"}.'),
          backgroundColor: KColors.ok,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadRequests(
          tab: _tabController.index == 0 ? 'pending' : 'reviewed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phê duyệt đơn thất bại. Vui lòng thử lại sau.'),
          backgroundColor: KColors.bad,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(item.requestId));
    }
  }

  Future<void> _handleReject(LeaveRequestEntity item) async {
    if (_processing.contains(item.requestId)) return;
    setState(() => _processing.add(item.requestId));
    try {
      final confirmedReason = await RejectReasonDialog.show(
        context,
        childName: item.childName ?? 'Học sinh',
      );
      if (!mounted || confirmedReason == null || confirmedReason.isEmpty) {
        return;
      }
      await _repository.rejectLeaveRequest(
        requestId: item.requestId,
        rejectReason: confirmedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Đã từ chối đơn. Phụ huynh có thể xem lý do trong ứng dụng.'),
          backgroundColor: KColors.warnDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadRequests(
          tab: _tabController.index == 0 ? 'pending' : 'reviewed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Từ chối đơn thất bại. Vui lòng kiểm tra lại.'),
          backgroundColor: KColors.bad,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(item.requestId));
    }
  }

  Future<void> _openAttachment(LeaveRequestEntity item) async {
    final path = item.attachmentUrl;
    if (path == null) return;
    try {
      final bytes = await _repository.getAttachmentBytes(path);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight: MediaQuery.sizeOf(context).height * .8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Đóng ảnh',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )),
                    Flexible(
                        child: InteractiveViewer(
                            child: Image.memory(
                      bytes,
                      errorBuilder: (context, error, stack) => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Không thể hiển thị ảnh này.'),
                      ),
                    ))),
                  ]),
                ),
              ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không tải được ảnh đính kèm. Vui lòng thử lại.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Scaffold(
      backgroundColor: k.canvas,
      appBar: AppBar(
        title: Text(
          widget.className != null
              ? 'Duyệt đơn nghỉ / đi trễ • ${widget.className}'
              : 'Duyệt đơn xin phép',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: k.ink),
        ),
        backgroundColor: k.surface,
        iconTheme: IconThemeData(color: k.ink),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: k.brand,
          unselectedLabelColor: k.inkSoft,
          indicatorColor: k.brand,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chờ duyệt'),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: k.bad,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Đã xử lý'),
                  if (_reviewedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: k.lineStrong,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_reviewedCount',
                        style: TextStyle(
                          color: k.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(k),
    );
  }

  Widget _buildBody(KPalette k) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: k.brand));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: k.bad),
              const SizedBox(height: KSpace.x3),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: k.inkSoft),
              ),
              const SizedBox(height: KSpace.x4),
              ElevatedButton.icon(
                onPressed: () => _loadRequests(
                  tab: _tabController.index == 0 ? 'pending' : 'reviewed',
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: k.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _tabController.index == 0 ? Icons.task_alt : Icons.history,
              size: 56,
              color: k.inkFaint,
            ),
            const SizedBox(height: KSpace.x3),
            Text(
              _tabController.index == 0
                  ? 'Không có đơn nào đang chờ duyệt'
                  : 'Chưa có lịch sử đơn đã xử lý',
              style: TextStyle(fontSize: 15, color: k.inkSoft),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: k.brand,
      onRefresh: () => _loadRequests(
        tab: _tabController.index == 0 ? 'pending' : 'reviewed',
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(KSpace.x4),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: KSpace.x3),
        itemBuilder: (context, index) {
          final item = _items[index];
          return LeaveRequestCard(
            item: item,
            onApprove: () => _handleApprove(item),
            onReject: () => _handleReject(item),
            onAttachment: () => _openAttachment(item),
            processing: _processing.contains(item.requestId),
          );
        },
      ),
    );
  }
}
