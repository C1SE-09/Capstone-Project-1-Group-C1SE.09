import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class AttendanceApprovalResultScreen extends StatelessWidget {
  const AttendanceApprovalResultScreen({
    super.key,
    required this.request,
    this.onReturnToAttendance,
  });

  final LeaveRequestEntity request;
  final ValueChanged<DateTime>? onReturnToAttendance;

  bool get _isLate => request.requestType == LeaveRequestType.lateArrival;

  String get _childName {
    final name = request.childName?.trim() ?? '';
    return name;
  }

  String get _title => _isLate ? 'Đã duyệt báo trễ' : 'Đã duyệt đơn';

  String get _bannerTitle =>
      _childName.isEmpty ? _title : '$_title của $_childName';

  String get _subtitle {
    if (_isLate) {
      return 'Giờ đến thực tế do giáo viên xác nhận; ETA chỉ là thời gian dự kiến.';
    }
    return 'Có thể kiểm tra trạng thái điểm danh tại màn hình Điểm danh sau khi duyệt đơn.';
  }

  String get _dateLabel => DateFormat('dd/MM').format(request.fromDate);

  String? _formatTime(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final time = raw.contains('T') ? raw.split('T').last : raw;
    final parts = time.split(':');
    if (parts.length < 2) return time;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  String get _detailLine => _isLate
      ? (_formatTime(request.expectedArrivalTime) == null
          ? 'Báo đi trễ đã được duyệt'
          : 'Dự kiến đến lúc ${_formatTime(request.expectedArrivalTime)}')
      : 'Đơn nghỉ đã được duyệt';

  void _return(BuildContext context) {
    Navigator.of(context).pop();
    onReturnToAttendance?.call(request.fromDate);
  }

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            return Scaffold(
              backgroundColor: k.canvas,
              appBar: KAppBar(
                title: _title,
                subtitle: 'Đơn đã được cập nhật',
                onBack: () => Navigator.maybePop(context),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: k.okTint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: k.okDot,
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              'assets/garden_voice/approval_success.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _bannerTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700,
                                    color: k.ink,
                                  ),
                                ),
                                Text(
                                  'Trạng thái yêu cầu đã được cập nhật.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: k.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Điểm danh ngày $_dateLabel sau khi duyệt',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: k.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  KCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 70),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: k.brand,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _childName.isEmpty ? '' : _initials(_childName),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: k.surface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _childName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: k.ink,
                                  ),
                                ),
                                Text(
                                  _detailLine,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: k.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            ui.ReportStatus.submitted,
                            labelOverride:
                                _isLate ? 'Báo trễ đã duyệt' : 'Đã duyệt',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: k.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: k.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  KButton(
                    label: 'Về Điểm danh',
                    onPressed: () => _return(context),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return parts.first.characters.first.toUpperCase();
  return '${parts[parts.length - 2].characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
