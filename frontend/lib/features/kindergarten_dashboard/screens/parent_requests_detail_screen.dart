import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'parent_requests_attachment.dart';
import 'parent_requests_widgets.dart';

class ParentRequestDetailScreen extends StatefulWidget {
  const ParentRequestDetailScreen(
      {super.key,
      required this.requestId,
      required this.child,
      required this.className,
      this.repository});
  final String requestId;
  final Child child;
  final String className;
  final HttpLeaveRequestRepository? repository;

  @override
  State<ParentRequestDetailScreen> createState() =>
      _ParentRequestDetailScreenState();
}

class _ParentRequestDetailScreenState extends State<ParentRequestDetailScreen> {
  late HttpLeaveRequestRepository _repository;
  late Future<LeaveRequestEntity> _request;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpLeaveRequestRepository();
    _request = _fetch();
  }

  @override
  void didUpdateWidget(covariant ParentRequestDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId ||
        oldWidget.child.childId != widget.child.childId ||
        oldWidget.repository != widget.repository) {
      _repository = widget.repository ?? HttpLeaveRequestRepository();
      _request = _fetch();
    }
  }

  Future<LeaveRequestEntity> _fetch() async {
    final request = await _repository.getRequest(widget.requestId);
    if (request.childId != widget.child.childId) {
      throw const LeaveRequestException(
          'Không thể xác minh đơn của bé. Vui lòng tải lại.');
    }
    return request;
  }

  Future<void> _reload() async {
    setState(() {
      _request = _fetch();
    });
    try {
      await _request;
    } catch (_) {/* FutureBuilder hiển thị lỗi và nút thử lại. */}
  }

  @override
  Widget build(BuildContext context) => ParentRequestLayout(
      title: 'Chi tiết đơn',
      child: FutureBuilder<LeaveRequestEntity>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Đang tải chi tiết đơn'));
            }
            if (snapshot.hasError || snapshot.data == null) {
              final error = snapshot.error;
              return ListView(padding: const EdgeInsets.all(18), children: [
                ParentRequestError(
                    error is LeaveRequestException
                        ? error.message
                        : 'Không thể tải chi tiết đơn. Vui lòng thử lại.',
                    onRetry: _reload)
              ]);
            }
            final request = snapshot.data!;
            return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    children: [
                      _ReviewStatus(request),
                      const SizedBox(height: 12),
                      ParentRequestCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            ParentRequestInfo('Loại đơn',
                                _value(requestTypeLabel(request.requestType))),
                            ParentRequestInfo(
                                'Bé',
                                _value(
                                    '${widget.child.fullName}${widget.className.isEmpty ? '' : ' — ${widget.className}'}')),
                            ParentRequestInfo(
                                'Thời gian', _value(requestRange(request))),
                            if (request.expectedArrivalTime != null)
                              ParentRequestInfo(
                                  'Giờ đến dự kiến',
                                  _value(request.expectedArrivalTime!
                                      .substring(0, 5))),
                            ParentRequestInfo(
                                'Đính kèm',
                                _value(request.attachmentUrl == null
                                    ? 'Không có'
                                    : 'Ảnh y tế')),
                            Text('Lý do',
                                style: TextStyle(
                                    fontSize: 12, color: context.k.inkSoft)),
                            const SizedBox(height: 6),
                            Text(request.reason),
                          ])),
                      if (request.status == LeaveStatus.rejected &&
                          request.rejectReason?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        ParentRequestCard(
                            color: context.k.badTint,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Lý do từ chối',
                                      style: TextStyle(
                                          color: context.k.bad,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text(request.rejectReason!,
                                      style: TextStyle(color: context.k.bad)),
                                ])),
                      ],
                      if (request.attachmentUrl != null) ...[
                        const SizedBox(height: 12),
                        ParentRequestAttachment(
                            path: request.attachmentUrl!,
                            repository: _repository),
                      ],
                      const SizedBox(height: 12),
                      _Timeline(request),
                      const SizedBox(height: 12),
                      ParentRequestCard(
                          color: context.k.brandTint,
                          child: Text(
                              request.requestType ==
                                      LeaveRequestType.lateArrival
                                  ? 'Giờ đến là dự kiến; kết quả duyệt đơn không thay thế điểm danh thực tế.'
                                  : 'Kết quả duyệt đơn không xác nhận bé đã có mặt hay thay thế điểm danh thực tế.',
                              style: TextStyle(
                                  fontSize: 12, color: context.k.brand))),
                    ]));
          }));

  Widget _value(String text) => Text(text,
      textAlign: TextAlign.end,
      style: const TextStyle(fontWeight: FontWeight.w600));
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus(this.request);
  final LeaveRequestEntity request;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (ink, tint) = switch (request.status) {
      LeaveStatus.pending => (k.warnDeep, k.warnTint),
      LeaveStatus.approved => (k.brand, k.brandTint),
      LeaveStatus.rejected => (k.bad, k.badTint),
    };
    return ParentRequestCard(
        color: tint,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(requestStatusLabel(request.status),
              style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              request.status == LeaveStatus.pending
                  ? 'Đơn đã gửi, đang chờ giáo viên duyệt.'
                  : '${request.reviewerName ?? 'Giáo viên'}${request.reviewedAt == null ? '' : ' · ${requestTimestamp(request.reviewedAt!)}'}',
              style: TextStyle(fontSize: 11, color: ink)),
        ]));
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.request);
  final LeaveRequestEntity request;

  @override
  Widget build(BuildContext context) => ParentRequestCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tiến trình xử lý',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _step(context, 'Đã gửi đơn',
            '${requestTimestamp(request.createdAt)}${request.parentName == null ? '' : ' · ${request.parentName}'}'),
        const SizedBox(height: 8),
        _step(
            context,
            switch (request.status) {
              LeaveStatus.pending => 'Đang chờ giáo viên duyệt',
              LeaveStatus.approved => 'Giáo viên đã duyệt',
              LeaveStatus.rejected => 'Giáo viên đã từ chối',
            },
            [
              if (request.reviewedAt != null)
                requestTimestamp(request.reviewedAt!),
              if (request.reviewerName != null) request.reviewerName!
            ].join(' · ')),
      ]));

  Widget _step(BuildContext context, String title, String detail) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 10, color: context.k.brand)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (detail.isNotEmpty)
            Text(detail,
                style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
        ])),
      ]);
}
