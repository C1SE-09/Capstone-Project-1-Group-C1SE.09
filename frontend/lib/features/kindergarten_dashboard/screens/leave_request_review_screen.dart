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
import 'parent_requests_widgets.dart';

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
  late HttpLeaveRequestRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  int _pendingCount = 0;
  int _reviewedCount = 0;
  List<LeaveRequestEntity> _items = [];
  final Set<String> _processing = {};
  final Map<String, String> _rejectionDrafts = {};
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _moreError;
  int _nextOffset = 0;
  int _loadVersion = 0;
  int _scopeVersion = 0;

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

  @override
  void didUpdateWidget(covariant LeaveRequestReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId ||
        oldWidget.repository != widget.repository) {
      _scopeVersion++;
      _pendingCount = 0;
      _reviewedCount = 0;
      _repository = widget.repository ?? HttpLeaveRequestRepository();
      _processing.clear();
      _rejectionDrafts.clear();
      _loadRequests(tab: _tabController.index == 0 ? 'pending' : 'reviewed');
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final tabName = _tabController.index == 0 ? 'pending' : 'reviewed';
    _loadRequests(tab: tabName);
  }

  Future<void> _loadRequests({required String tab, bool more = false}) async {
    if (more && (_isLoading || _loadingMore)) return;
    final version = ++_loadVersion;
    setState(() {
      _loadingMore = more;
      _isLoading = !more;
      _errorMessage = null;
      _moreError = null;
      if (!more) {
        _nextOffset = 0;
        _hasMore = false;
        _items = [];
      }
    });

    try {
      final result = await _repository.getLeaveRequests(
        classId: widget.classId,
        tab: tab,
        offset: _nextOffset,
      );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _pendingCount = result.pendingCount;
        _reviewedCount = result.reviewedCount;
        _nextOffset += result.items.length;
        _hasMore = result.items.isNotEmpty &&
            _nextOffset < (tab == 'pending' ? _pendingCount : _reviewedCount);
        final unique = {
          for (final item in [..._items, ...result.items]) item.requestId: item
        };
        _items = unique.values.toList();
        _isLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        if (more) {
          _moreError = 'Không tải thêm được đơn. Vui lòng thử lại.';
        } else {
          _errorMessage =
              'Không thể tải danh sách đơn. Vui lòng kiểm tra kết nối mạng.';
        }
        _isLoading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _handleApprove(LeaveRequestEntity item) async {
    if (_processing.contains(item.requestId)) return;
    setState(() => _processing.add(item.requestId));
    final scope = _scopeVersion;
    try {
      await _repository.approveLeaveRequest(item.requestId);
      if (!mounted || scope != _scopeVersion) return;
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
      if (!mounted || scope != _scopeVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phê duyệt đơn thất bại. Vui lòng thử lại sau.'),
          backgroundColor: KColors.bad,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && scope == _scopeVersion) {
        setState(() => _processing.remove(item.requestId));
      }
    }
  }

  Future<void> _handleReject(LeaveRequestEntity item) async {
    if (_processing.contains(item.requestId)) return;
    setState(() => _processing.add(item.requestId));
    final scope = _scopeVersion;
    try {
      final confirmedReason = await RejectReasonDialog.show(
        context,
        childName: item.childName ?? 'Học sinh',
        initialReason: _rejectionDrafts[item.requestId] ?? '',
        request: item,
      );
      if (!mounted ||
          scope != _scopeVersion ||
          confirmedReason == null ||
          confirmedReason.isEmpty) {
        return;
      }
      _rejectionDrafts[item.requestId] = confirmedReason;
      await _repository.rejectLeaveRequest(
        requestId: item.requestId,
        rejectReason: confirmedReason,
      );
      if (!mounted || scope != _scopeVersion) return;
      _rejectionDrafts.remove(item.requestId);
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
      if (!mounted || scope != _scopeVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Từ chối đơn thất bại. Vui lòng kiểm tra lại.'),
          backgroundColor: KColors.bad,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && scope == _scopeVersion) {
        setState(() => _processing.remove(item.requestId));
      }
    }
  }

  Future<void> _openAttachment(LeaveRequestEntity item) async {
    final path = item.attachmentUrl;
    if (path == null) return;
    final version = _loadVersion;
    try {
      final bytes = await _repository.getAttachmentBytes(path);
      if (!mounted || version != _loadVersion) return;
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
      if (!mounted || version != _loadVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không tải được ảnh đính kèm. Vui lòng thử lại.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return ParentRequestLayout(
      title: 'Duyệt đơn xin nghỉ',
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                  child: Text(widget.className ?? 'Lớp phụ trách',
                      style: TextStyle(fontSize: 11, color: k.inkSoft))),
              Flexible(
                  child: Text(
                      '$_pendingCount chờ duyệt · $_reviewedCount đã xử lý',
                      style: TextStyle(fontSize: 11, color: k.warnDeep))),
            ])),
        TabBar(
            controller: _tabController,
            labelColor: k.brand,
            unselectedLabelColor: k.inkSoft,
            tabs: const [Tab(text: 'Chờ duyệt'), Tab(text: 'Đã xử lý')]),
        Expanded(child: _buildBody(k)),
      ]),
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
        itemCount: _items.length +
            (_hasMore || _loadingMore || _moreError != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: KSpace.x3),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_loadingMore) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(KSpace.x4),
                      child: CircularProgressIndicator()));
            }
            return Column(children: [
              if (_moreError != null)
                Text(_moreError!, style: TextStyle(color: k.bad)),
              TextButton(
                  onPressed: () => _loadRequests(
                      tab: _tabController.index == 0 ? 'pending' : 'reviewed',
                      more: true),
                  child: Text(
                      _moreError == null ? 'Tải thêm' : 'Thử lại tải thêm')),
            ]);
          }
          final item = _items[index];
          return LeaveRequestCard(
            key: ValueKey(item.requestId),
            item: item,
            initiallyExpanded: index == 0,
            className: widget.className,
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
