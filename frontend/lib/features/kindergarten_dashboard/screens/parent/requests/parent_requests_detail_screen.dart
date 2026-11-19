import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_attachment.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_cards.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_cancelled_screen.dart';

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
  bool _cancelling = false, _dialog = false, _cancelAttemptFailed = false;
  int _version = 0;
  String? _cancelError;

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
      _version++;
      _cancelling = false;
      _cancelError = null;
      _cancelAttemptFailed = false;
      _repository = widget.repository ?? HttpLeaveRequestRepository();
      _request = _fetch();
    }
  }

  Future<LeaveRequestEntity> _fetch() async {
    final childId = widget.child.childId, requestId = widget.requestId;
    final request = await _repository.getRequest(requestId);
    if (request.childId != childId || request.requestId != requestId) {
      throw const LeaveRequestException(
          'Không thể xác minh đơn của bé. Vui lòng tải lại.');
    }
    return request;
  }

  Future<void> _cancel(LeaveRequestEntity request) async {
    if (_cancelling || _dialog || !request.canCancel) return;
    final version = _version,
        child = widget.child,
        className = widget.className;
    final repository = _repository;
    _dialog = true;
    final range = request.totalDays == 1
        ? 'ngày ${requestDate(request.fromDate)}'
        : 'từ ${requestDate(request.fromDate)} đến ${requestDate(request.toDate)}';
    final agreed = await showParentRequestDialog(context,
        title: context.l10n?.leaveRequestCancelConfirmTitle ?? 'Hủy đơn xin nghỉ?',
        message:
            'Đơn ${requestTypeLabel(request.requestType).toLowerCase()} $range của bé ${child.fullNameWithNickname} sẽ bị hủy. Điểm danh thực tế được giữ nguyên.',
        cancelLabel: context.l10n?.requestKeepAction ?? 'Giữ đơn',
        confirmLabel: context.l10n?.requestCancelAction ?? 'Hủy đơn',
        danger: true);
    _dialog = false;
    if (!mounted || version != _version || !agreed) return;
    setState(() {
      _cancelling = true;
      _cancelError = null;
      _cancelAttemptFailed = false;
    });
    try {
      final result = await repository.cancelRequest(request.requestId);
      if (!mounted || version != _version) return;
      await Navigator.of(context).pushReplacement<void, void>(MaterialPageRoute(
          builder: (_) => ParentRequestsCancelledScreen(
              result: result,
              request: request,
              child: child,
              className: className)));
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _cancelAttemptFailed = true;
        _cancelError = error is LeaveRequestException
            ? error.message
            : (context.l10n?.cancelConfirmPendingPrompt ??
                'Chưa xác nhận hủy. Hãy tải lại trạng thái trước khi thử lại.');
      });
      if (error is LeaveRequestException &&
          {400, 409}.contains(error.statusCode)) {
        await _reload();
      }
    } finally {
      if (mounted && version == _version) setState(() => _cancelling = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _request = _fetch();
    });
    try {
      await _request;
    } catch (_) {/* FutureBuilder hiển thị lỗi và nút thử lại. */}
  }

  Future<void> _refresh() {
    setState(() {
      _cancelError = null;
      _cancelAttemptFailed = false;
    });
    return _reload();
  }

  @override
  Widget build(BuildContext context) => ParentRequestLayout(
      gardenVoice: true,
      title: context.l10n?.requestDetailTitle ?? 'Chi tiết đơn',
      child: FutureBuilder<LeaveRequestEntity>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: context.l10n?.requestDetailLoading ?? 'Đang tải chi tiết đơn'));
            }
            if (snapshot.hasError || snapshot.data == null) {
              final error = snapshot.error;
              return ListView(padding: const EdgeInsets.all(18), children: [
                ParentRequestError(
                    error is LeaveRequestException
                        ? error.message
                        : (context.l10n?.requestDetailLoadError ??
                            'Không thể tải chi tiết đơn. Vui lòng thử lại.'),
                    onRetry: _reload)
              ]);
            }
            final request = snapshot.data!;
            return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    children: [
                      _ReviewStatus(request),
                      const SizedBox(height: 12),
                      ParentRequestCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            ParentRequestInfo(
                                context.l10n?.requestTypeTitle ?? 'Loại đơn',
                                _value(requestTypeLabel(request.requestType)),
                                gardenVoice: true),
                            ParentRequestInfo(
                                context.l10n?.commonChild ?? 'Bé',
                                _value(
                                    '${widget.child.fullNameWithNickname}${widget.className.isEmpty ? '' : ' — ${widget.className}'}'),
                                gardenVoice: true),
                            ParentRequestInfo(
                                context.l10n?.requestTimeLabel ?? 'Thời gian',
                                _value(gardenVoiceRequestRange(request)),
                                gardenVoice: true),
                            if (request.expectedArrivalTime != null)
                              ParentRequestInfo(
                                  context.l10n?.requestExpectedArrival ??
                                      'Giờ đến dự kiến',
                                  _value(request.expectedArrivalTime!
                                      .substring(0, 5)),
                                  gardenVoice: true),
                            ParentRequestInfo(
                                context.l10n?.requestAttachmentLabel ??
                                    'Đính kèm',
                                _value(request.attachmentUrl == null
                                    ? (context.l10n?.commonNone ?? 'Không có')
                                    : (context.l10n?.requestMedicalImageLabel ??
                                        'Ảnh y tế')),
                                gardenVoice: true),
                            Text(
                                context.l10n?.parentRequestsReasonLabel ??
                                    'Lý do',
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
                                  Text(
                                      context.l10n?.requestRejectReason ??
                                          'Lý do từ chối',
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
                      if (_cancelError != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                            liveRegion: true,
                            child: Text(_cancelError!,
                                style: TextStyle(color: context.k.bad)))
                      ],
                      if (request.canCancel ||
                          request.status == LeaveStatus.pending ||
                          _cancelAttemptFailed ||
                          _cancelError != null ||
                          request.cancelBlockReason?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        MedicationAction(
                            label: context.l10n?.requestCancelThisAction ??
                                'Hủy đơn này',
                            danger: true,
                            busy: _cancelling,
                            onPressed: !request.canCancel ||
                                    _cancelling ||
                                    _cancelAttemptFailed ||
                                    _cancelError != null
                                ? null
                                : () => _cancel(request)),
                        const SizedBox(height: 8),
                        Text(
                            request.canCancel
                                ? 'Có thể hủy trước ${request.cancelBefore == null ? 'thời hạn máy chủ' : requestTimestamp(request.cancelBefore!)}. Máy chủ kiểm tra lại khi hủy.'
                                : request.cancelBlockReason ??
                                    _cancelError ??
                                    (context.l10n?.cannotCancelContactTeacher ??
                                        'Đơn hiện không thể hủy. Vui lòng liên hệ giáo viên.'),
                            style: TextStyle(
                                fontSize: 11, color: context.k.inkSoft)),
                      ] else if (request.cancelBlockReason?.isNotEmpty == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(request.cancelBlockReason!,
                                style: TextStyle(
                                    fontSize: 11, color: context.k.inkSoft))),
                      const SizedBox(height: 12),
                      ParentRequestCard(
                          color: context.k.brandTint,
                          child: Text(
                              request.requestType ==
                                      LeaveRequestType.lateArrival
                                  ? (context.l10n?.lateArrivalDisclaimer ??
                                      'Giờ đến là dự kiến; kết quả duyệt đơn không thay thế điểm danh thực tế.')
                                  : (context.l10n?.leaveRequestDisclaimer ??
                                      'Kết quả duyệt đơn không xác nhận bé đã có mặt hay thay thế điểm danh thực tế.'),
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
    final isEn = LocaleController.instance.isEnglish;
    if (request.status == LeaveStatus.approved) {
      return ParentRequestCard(
          color: k.okTint,
          child: Column(children: [
            Text('✓ ĐƠN ĐÃ ĐƯỢC DUYỆT',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: k.ok)),
            const SizedBox(height: 3),
            Text(
                isEn
                    ? '${request.reviewerName ?? 'Teacher'}${request.reviewedAt == null ? '' : ' approved at ${requestTimestamp(request.reviewedAt!)}'}'
                    : '${request.reviewerName ?? 'Giáo viên'}${request.reviewedAt == null ? '' : ' duyệt lúc ${requestTimestamp(request.reviewedAt!)}'}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: k.inkSoft)),
          ]));
    }
    final (ink, tint) = switch (request.status) {
      LeaveStatus.pending => (k.warnDeep, k.warnTint),
      LeaveStatus.approved => (k.ok, k.okTint),
      LeaveStatus.rejected => (k.bad, k.badTint),
      LeaveStatus.cancelled => (k.inkSoft, k.surfaceSunken),
    };
    return ParentRequestCard(
        color: tint,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (request.status == LeaveStatus.pending) ...[
            Icon(Icons.schedule, size: 18, color: ink),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(requestStatusLabel(request.status),
                    style: TextStyle(
                        color: ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                    request.status == LeaveStatus.pending
                        ? (isEn
                            ? 'Sent at ${requestTimestamp(request.createdAt)}'
                            : 'Đã gửi lúc ${requestTimestamp(request.createdAt)}')
                        : request.status == LeaveStatus.cancelled
                            ? (isEn ? 'Cancelled by parent' : 'Phụ huynh đã hủy đơn')
                            : (isEn
                                ? '${request.reviewerName ?? 'Teacher'}${request.reviewedAt == null ? '' : ' · ${requestTimestamp(request.reviewedAt!)}'}'
                                : '${request.reviewerName ?? 'Giáo viên'}${request.reviewedAt == null ? '' : ' · ${requestTimestamp(request.reviewedAt!)}'}'),
                    style: TextStyle(fontSize: 11.5, color: ink)),
              ])),
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
        Text(
          context.l10n?.requestProcessStatus ?? 'Tiến trình xử lý',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (request.status == LeaveStatus.approved) ...[
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: context.k.brandTint,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  context.l10n?.syncAttendanceNotConfirmed ??
                      'Chưa có xác nhận đồng bộ điểm danh từ hệ thống.',
                  style: TextStyle(fontSize: 12, color: context.k.brand))),
          const SizedBox(height: 8),
        ],
        _step(
            context,
            context.l10n?.requestSubmittedTitle ?? 'Đã gửi đơn',
            '${requestTimestamp(request.createdAt)}${request.parentName == null ? '' : ' · ${request.parentName}'}'),
        const SizedBox(height: 8),
        _step(
            context,
            switch (request.status) {
              LeaveStatus.pending =>
                context.l10n?.requestWaitingTeacher ?? 'Đang chờ giáo viên duyệt',
              LeaveStatus.approved =>
                context.l10n?.requestTeacherApproved ?? 'Giáo viên đã duyệt',
              LeaveStatus.rejected =>
                context.l10n?.requestTeacherRejected ?? 'Giáo viên đã từ chối',
              LeaveStatus.cancelled =>
                context.l10n?.requestParentCancelled ?? 'Phụ huynh đã hủy đơn',
            },
            [
              if (request.status != LeaveStatus.cancelled &&
                  request.reviewedAt != null)
                requestTimestamp(request.reviewedAt!),
              if (request.status != LeaveStatus.cancelled &&
                  request.reviewerName != null)
                request.reviewerName!
            ].join(' · ')),
        if (request.status == LeaveStatus.pending) ...[
          const SizedBox(height: 8),
          _step(
              context,
              context.l10n?.requestReviewResult ?? 'Kết quả duyệt',
              context.l10n?.requestNoResultYet ?? 'Chưa có'),
        ],
      ]));

  Widget _step(BuildContext context, String title, String detail) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Image.asset(
                'assets/request_timeline/${title == 'Đã gửi đơn' ? 'complete' : request.status == LeaveStatus.pending ? 'waiting' : 'complete'}.png',
                width: 11,
                height: 11,
                excludeFromSemantics: true)),
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
