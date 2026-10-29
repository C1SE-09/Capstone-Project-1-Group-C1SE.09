import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_detail_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

class ParentRequestsScreen extends StatefulWidget {
  const ParentRequestsScreen(
      {super.key,
      required this.child,
      required this.className,
      required this.teacherName,
      this.repository});

  final Child child;
  final String className;
  final String teacherName;
  final HttpLeaveRequestRepository? repository;

  @override
  State<ParentRequestsScreen> createState() => _ParentRequestsScreenState();
}

class _ParentRequestsScreenState extends State<ParentRequestsScreen> {
  late HttpLeaveRequestRepository _repository;
  LeaveStatus? _status;
  List<LeaveRequestEntity> _items = [];
  int _total = 0;
  int _loadVersion = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpLeaveRequestRepository();
    _load();
  }

  @override
  void didUpdateWidget(covariant ParentRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.childId != widget.child.childId ||
        oldWidget.repository != widget.repository) {
      _repository = widget.repository ?? HttpLeaveRequestRepository();
      _status = null;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items = [];
        _total = 0;
      }
    });
    try {
      final page = await _repository.getMyRequests(
          childId: widget.child.childId,
          status: _status,
          offset: more ? _items.length : 0);
      if (!mounted || version != _loadVersion) return;
      if (page.items.any((item) => item.childId != widget.child.childId)) {
        throw const LeaveRequestException(
            'Không thể xác minh đơn của bé. Vui lòng tải lại.');
      }
      setState(() {
        _items = [..._items, ...page.items];
        _total = page.total;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() => _error = e is LeaveRequestException
          ? e.message
          : 'Không thể tải danh sách đơn. Vui lòng thử lại.');
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final destination = await Navigator.of(context)
        .push<ParentRequestDestination>(MaterialPageRoute(
            builder: (_) => ParentRequestFormScreen(
                child: widget.child,
                className: widget.className,
                teacherName: widget.teacherName,
                repository: _repository)));
    if (!mounted) return;
    if (destination == ParentRequestDestination.home) {
      Navigator.of(context).pop();
    } else if (destination == ParentRequestDestination.history) {
      setState(() => _status = null);
      _load();
    }
  }

  Future<void> _detail(LeaveRequestEntity item) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ParentRequestDetailScreen(
            requestId: item.requestId,
            child: widget.child,
            className: widget.className,
            repository: _repository)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => ParentRequestLayout(
        title: 'Xin phép nghỉ / báo trễ',
        actions: [
          IconButton(
              tooltip: 'Tạo đơn mới',
              onPressed: _create,
              icon: CircleAvatar(
                  radius: 15,
                  backgroundColor: context.k.brand,
                  child: Icon(Icons.add,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary)))
        ],
        child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: context.k.brandTint,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            'Bé ${widget.child.fullName}${widget.className.isEmpty ? '' : ' · ${widget.className}'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.k.brand)))),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final status in [null, ...LeaveStatus.values]) ...[
                        ParentRequestPill(
                            label: status == null
                                ? 'Tất cả'
                                : requestStatusLabel(status),
                            selected: _status == status,
                            onPressed: () {
                              if (_status == status) return;
                              setState(() => _status = status);
                              _load();
                            }),
                        const SizedBox(width: 6),
                      ],
                    ])),
                for (final item in _items) ...[
                  _HistoryCard(item: item, onTap: () => _detail(item)),
                  const SizedBox(height: 12),
                ],
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: CircularProgressIndicator(
                              semanticsLabel: 'Đang tải danh sách đơn'))),
                if (_error != null)
                  ParentRequestError(_error!,
                      onRetry: () => _load(more: _items.isNotEmpty)),
                if (!_loading && _error == null && _items.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child:
                          Text('Chưa có đơn nào', textAlign: TextAlign.center)),
                if (!_loading && _error == null && _items.length < _total)
                  TextButton(
                      onPressed: () => _load(more: true),
                      child: const Text('Tải thêm')),
                ParentRequestButton(label: 'TẠO ĐƠN MỚI', onPressed: _create),
              ],
            )),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onTap});
  final LeaveRequestEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Xem chi tiết đơn ${requestTypeLabel(item.requestType)}',
        child: Material(
            color: context.k.surface,
            borderRadius: BorderRadius.circular(14),
            textStyle: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                height: 1.3,
                color: context.k.ink),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ParentRequestCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    SizedBox(
                        width: double.infinity,
                        child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 4,
                            spacing: 12,
                            children: [
                              Text(requestTypeLabel(item.requestType),
                                  style: TextStyle(
                                      color: context.k.brand,
                                      fontWeight: FontWeight.w600)),
                              ParentRequestStatus(item.status),
                            ])),
                    const SizedBox(height: 6),
                    Text(requestRange(item),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (item.expectedArrivalTime != null)
                      Text(
                          'Giờ đến dự kiến: ${item.expectedArrivalTime!.substring(0, 5)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(item.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.k.inkSoft)),
                    if (item.status == LeaveStatus.rejected &&
                        item.rejectReason?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      ParentRequestCard(
                          color: context.k.badTint,
                          child: Text('Lý do từ chối: ${item.rejectReason}',
                              style: TextStyle(
                                  fontSize: 12, color: context.k.bad))),
                    ],
                    const SizedBox(height: 6),
                    Text(
                        item.status == LeaveStatus.pending
                            ? 'Gửi ${requestTimestamp(item.createdAt)}${item.attachmentUrl == null ? '' : ' · Có ảnh y tế đính kèm'}'
                            : '${item.status == LeaveStatus.cancelled ? 'Phụ huynh đã hủy đơn' : '${item.reviewerName ?? 'Giáo viên'} ${item.status == LeaveStatus.approved ? 'đã duyệt' : 'đã từ chối'}'}${item.reviewedAt == null ? '' : ' · ${requestTimestamp(item.reviewedAt!)}'}',
                        style:
                            TextStyle(fontSize: 11, color: context.k.inkSoft)),
                  ])),
            )),
      );
}
