// M6–M7: cữ/giờ/actor thật từ máy chủ, không tự suy ra đã uống từ thao tác bấm.
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    as ui;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/teacher_emergency_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show Avatar, KButton;

class TeacherMedicationScreen extends StatefulWidget {
  const TeacherMedicationScreen({
    super.key,
    this.repository,
    this.initialDate,
    this.dashboardRepository,
    this.onNavigationSelected,
  });
  final HttpMedicationRepository? repository;
  final String? initialDate;
  final HttpDashboardRepository? dashboardRepository;
  final ValueChanged<GardenVoiceTeacherDestination>? onNavigationSelected;
  @override
  State<TeacherMedicationScreen> createState() =>
      _TeacherMedicationScreenState();
}

class _TeacherMedicationScreenState extends State<TeacherMedicationScreen> {
  late HttpMedicationRepository _repo;
  late Future<MedicationsTodayData> _future;
  final _processing = <String>{};
  int _version = 0;
  String _filter = 'all';
  bool _openingEmergency = false;
  MedicationItem? _confirmedDose;
  static const _labels = {
    'all': 'Tất cả',
    'morning': 'Buổi Sáng',
    'noon': 'Buổi Trưa',
    'afternoon': 'Buổi Chiều'
  };
  static const _sections = {
    'morning': 'Buổi sáng',
    'noon': 'Buổi trưa',
    'afternoon': 'Buổi chiều'
  };
  static const _sessionNames = {
    'morning': 'Sáng',
    'noon': 'Trưa',
    'afternoon': 'Chiều'
  };
  static const _weekdays = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật'
  ];
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _version++;
    _processing.clear();
    _openingEmergency = false;
    _confirmedDose = null;
    _repo = widget.repository ?? HttpMedicationRepository();
    _future = _repo.getTodayMedications(date: widget.initialDate);
  }

  @override
  void didUpdateWidget(covariant TeacherMedicationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate ||
        oldWidget.repository != widget.repository) {
      _reset();
    }
  }

  Future<MedicationsTodayData> _reload() {
    final next = _repo.getTodayMedications(date: widget.initialDate);
    setState(() {
      _future = next;
    });
    return next;
  }

  Future<void> _refresh() async {
    try {
      await _reload();
    } on Exception catch (_) {/* FutureBuilder hiện lỗi/tải lại. */}
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _emergency(String classId) async {
    if (_openingEmergency) return;
    final version = _version;
    setState(() => _openingEmergency = true);
    try {
      final roster =
          await (widget.dashboardRepository ?? HttpDashboardRepository())
              .getClassChildren(classId);
      if (!mounted || version != _version) return;
      await TeacherEmergencySheet.show(context,
          repository: _repo,
          children: roster
              .map((child) => uiChildFromDomain(
                  child: child,
                  reportStatus: ui.ReportStatus.none,
                  severity: ui.Severity.none))
              .toList());
    } on Exception catch (_) {
      if (mounted && version == _version) {
        _message(
            'Không tải được danh sách lớp. Vui lòng thử lại hoặc mở báo cáo sự cố từ trang lớp.');
      }
    } finally {
      if (mounted && version == _version) {
        setState(() => _openingEmergency = false);
      }
    }
  }

  String _key(MedicationItem item, String date) =>
      '${item.requestId}|$date|${item.session}';
  Future<void> _confirm(MedicationItem item, String date) async {
    final key = _key(item, date), version = _version;
    if (item.isGiven || _processing.contains(key)) return;
    final reqDate = item.requestDate;
    if (DateTime.tryParse(date) == null ||
        (reqDate != null && DateFormat('yyyy-MM-dd').format(reqDate) != date)) {
      _message(
          'Ngày của cữ thuốc chưa khớp. Vui lòng tải lại trước khi xác nhận.');
      return;
    }
    setState(() {
      _processing.add(key);
    });
    try {
      await _repo.confirmMedication(
          requestId: item.requestId, session: item.session, date: date);
      if (!mounted || version != _version) return;
      final data = await _reload();
      if (!mounted || version != _version) return;
      final confirmed = data.allItems.where((d) =>
          d.requestId == item.requestId &&
          d.session == item.session &&
          d.isGiven);
      if (confirmed.isNotEmpty) {
        setState(() => _confirmedDose = confirmed.first);
      } else {
        _message(
            'Đã gửi thao tác nhưng chưa xác minh trạng thái mới. Vui lòng tải lại lịch thuốc.');
      }
    } on MedicationAlreadyConfirmedException catch (error) {
      if (mounted && version == _version) {
        _message(error.message);
        await _refresh();
      }
    } on Exception catch (error) {
      if (mounted && version == _version) _message(medicationError(error));
    } finally {
      if (mounted && version == _version) {
        setState(() {
          _processing.remove(key);
        });
      }
    }
  }

  String _friendlyErrorMessage(Object? error) {
    if (error == null) {
      return 'Không thể tải lịch uống thuốc. Vui lòng thử lại sau.';
    }
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('500') || errStr.contains('internal server error')) {
      return 'Máy chủ đang gặp sự cố khi xử lý dữ liệu dặn thuốc. Vui lòng thử lại sau hoặc liên hệ quản trị viên.';
    }
    if (errStr.contains('socketexception') ||
        errStr.contains('connection') ||
        errStr.contains('timeout') ||
        errStr.contains('network')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
    }
    if (errStr.contains('403') || errStr.contains('không có quyền')) {
      return 'Bạn không có quyền truy cập dữ liệu dặn thuốc của lớp này.';
    }
    if (errStr.contains('401') || errStr.contains('unauthorized')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    return error is MedicationRequestException
        ? error.message
        : 'Không thể tải lịch uống thuốc của lớp. Vui lòng nhấn "Thử lại".';
  }

  @override
  Widget build(BuildContext context) {
    final confirmedDose = _confirmedDose;
    if (confirmedDose != null) {
      return ParentRequestLayout(
        title: 'Đã cho uống thuốc',
        subtitle: 'Xác nhận đã khóa để tránh trùng liều',
        gardenVoice: true,
        onBack: () => setState(() => _confirmedDose = null),
        child: _confirmationResult(confirmedDose),
      );
    }
    return FutureBuilder<MedicationsTodayData>(
      future: _future,
      builder: (context, snapshot) => ParentRequestLayout(
        title: 'Uống thuốc hôm nay',
        subtitle:
            snapshot.data == null ? null : _headerSubtitle(snapshot.data!),
        gardenVoice: true,
        bottomNavigationBar: GardenVoiceTeacherNavigation(
          selected: GardenVoiceTeacherDestination.home,
          onSelected: widget.onNavigationSelected ?? (_) {},
        ),
        child: _todayContent(context, snapshot),
      ),
    );
  }

  String _headerSubtitle(MedicationsTodayData data) {
    final date = DateTime.tryParse(data.date);
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(vn.year, vn.month, vn.day);
    final dateLabel = date == null
        ? data.date
        : '${_weekdays[date.weekday - 1]}, ${DateFormat(DateUtils.isSameDay(date, today) ? 'dd/MM' : 'dd/MM/yyyy').format(date)}';
    final className = data.className?.trim();
    if (className == null || className.isEmpty) return dateLabel;
    final classLabel =
        className.startsWith('Lớp ') ? className : 'Lớp $className';
    return '$dateLabel · $classLabel';
  }

  Widget _todayContent(
      BuildContext context, AsyncSnapshot<MedicationsTodayData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
          child:
              CircularProgressIndicator(semanticsLabel: 'Đang tải lịch thuốc'));
    }
    if (snapshot.hasError || snapshot.data == null) {
      return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ParentRequestError(_friendlyErrorMessage(snapshot.error),
              onRetry: _refresh));
    }
    final data = snapshot.data!;
    return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                  'Xác nhận 1 chạm khi đã cho bé uống. Kiểm tra đúng bé, đúng thuốc, đúng liều trước khi xác nhận.',
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: context.k.inkSoft)),
              const SizedBox(height: 12),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final entry in _labels.entries)
                  ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      selectedColor: context.k.brand,
                      backgroundColor: context.k.surface,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      pressElevation: 0,
                      labelPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      padding: EdgeInsets.zero,
                      showCheckmark: false,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _filter == entry.key
                              ? Theme.of(context).colorScheme.onPrimary
                              : context.k.inkSoft),
                      onSelected: (_) => setState(() => _filter = entry.key))
              ]),
              const SizedBox(height: 13),
              if (data.allItems.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Không có cữ thuốc trong ngày đang xem.')),
              if (_filter != 'all' &&
                  !data.allItems.any((item) => item.session == _filter))
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Không có cữ thuốc trong buổi đang chọn.')),
              for (final entry in _sections.entries)
                if (_filter == 'all' || _filter == entry.key) ...[
                  Text(entry.value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 9),
                  for (final item in data.allItems
                      .where((item) => item.session == entry.key)) ...[
                    _card(item, data.date),
                    const SizedBox(height: 13),
                  ],
                  if (data.allItems
                      .any((item) => item.session == entry.key && item.isGiven))
                    _lockNote(
                        entry.key,
                        data.allItems.firstWhere((item) =>
                            item.session == entry.key && item.isGiven)),
                ],
              const SizedBox(height: 13),
              FilledButton(
                  onPressed:
                      _openingEmergency ? null : () => _emergency(data.classId),
                  style: FilledButton.styleFrom(
                      backgroundColor: context.k.bad,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                      textStyle: TextStyle(
                          fontFamily: context.k.isGardenVoice
                              ? 'Nunito'
                              : 'BeVietnamPro',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.warning_amber_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(_openingEmergency
                        ? 'Đang tải danh sách lớp...'
                        : 'Báo cáo sự cố khẩn cấp')
                  ])),
            ]));
  }

  Widget _confirmationResult(MedicationItem item) {
    final stamp = item.givenAt == null
        ? null
        : DateFormat('HH:mm')
            .format(item.givenAt!.toUtc().add(const Duration(hours: 7)));
    final audit = stamp == null
        ? '${item.givenByName == null ? 'Đã xác nhận.' : '${item.givenByName} đã xác nhận.'} Chưa có thời điểm xác nhận.'
        : 'Đã uống lúc $stamp${item.givenByName == null ? '' : ' · ${item.givenByName} xác nhận'}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MedicationCard(
            color: context.k.okTint,
            radius: 24,
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/garden_voice/medication_confirmed.svg',
                  width: 40,
                  height: 40,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đã xác nhận bé uống thuốc',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Trạng thái đã được xác nhận từ máy chủ.',
                          style: TextStyle(
                              fontSize: 12, color: context.k.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          MedicationCard(
            radius: 24,
            borderColor: context.k.line,
            child: Row(
              children: [
                Avatar(name: item.childName, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.childName,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text('${item.medicationName} · ${item.dosage}',
                          style: TextStyle(
                              fontSize: 12, color: context.k.inkSoft)),
                      Text(audit,
                          style: TextStyle(
                              fontSize: 11.5, color: context.k.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const MedicationBadge('Đã uống',
                    status: 'given', showDot: true),
              ],
            ),
          ),
          const SizedBox(height: 13),
          MedicationCard(
            radius: 12,
            color: context.k.surfaceSunken,
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/garden_voice/medication_lock.svg',
                  width: 16,
                  height: 16,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                      'Liều này đã khóa — không thể xác nhận lại, tránh cho bé uống trùng liều.',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text('Chưa có xác nhận giao thông báo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
          const SizedBox(height: 13),
          KButton(
            label: 'Quay lại danh sách thuốc',
            secondary: true,
            onPressed: () => setState(() => _confirmedDose = null),
          ),
        ],
      ),
    );
  }

  Widget _lockNote(String session, MedicationItem given) {
    final stamp = given.givenAt == null
        ? null
        : DateFormat('HH:mm')
            .format(given.givenAt!.toUtc().add(const Duration(hours: 7)));
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: context.k.warnTint, borderRadius: BorderRadius.circular(14)),
        child: Text(
            'Lớp có 2 cô: cô còn lại mở cùng màn hình sẽ thấy trạng thái này và nút xác nhận bị khóa. Nếu cố xác nhận lại, backend trả lỗi 409: "Cảnh báo trùng liều: Bé đã được ${given.givenByName ?? 'một cô'} cho uống thuốc buổi ${_sessionNames[session]}${stamp == null ? '' : ' lúc $stamp'} rồi!" — chống uống trùng liều.',
            style: TextStyle(fontSize: 11.5, color: context.k.ink)));
  }

  Widget _card(MedicationItem item, String date) {
    final givenAt = item.givenAt;
    final stamp = givenAt == null
        ? null
        : DateFormat('HH:mm')
            .format(givenAt.toUtc().add(const Duration(hours: 7)));
    return MedicationCard(
        radius: 24,
        borderColor: context.k.line,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Avatar(name: item.childName, size: 40),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.childName,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (item.childNickname?.isNotEmpty == true)
                    Text(item.childNickname!,
                        style:
                            TextStyle(fontSize: 11, color: context.k.inkSoft)),
                  Text(
                      '${item.medicationName} · ${item.dosage}'
                      '${item.timeSlot == null ? '' : ' · ${item.timeSlot}'}'
                      '${item.instructions?.isNotEmpty == true ? ' · ${item.instructions}' : ''}',
                      style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
                ])),
            const SizedBox(width: 8),
            MedicationBadge(item.isGiven ? 'Đã uống' : 'Chờ uống',
                status: item.isGiven ? 'given' : 'pending', showDot: true),
          ]),
          if (item.notes?.isNotEmpty == true &&
              item.notes != item.instructions) ...[
            const SizedBox(height: 9),
            Text('Ghi chú: ${item.notes}',
                style: TextStyle(fontSize: 11, color: context.k.inkSoft))
          ],
          const SizedBox(height: 9),
          if (item.isGiven)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: context.k.okTint,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                    '✓ ${item.givenByName ?? 'Chưa rõ người xác nhận'} đã cho uống'
                    '${stamp == null ? '. Chưa có thời điểm xác nhận.' : ' lúc $stamp'}',
                    style: TextStyle(
                        color: context.k.ok,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)))
          else
            MedicationAction(
                label: 'Đã cho uống thuốc',
                busy: _processing.contains(_key(item, date)),
                onPressed: () => _confirm(item, date)),
          if (item.prescriptionImageUrl?.isNotEmpty == true)
            MedicationPrivateImage(
                path: item.prescriptionImageUrl!, repository: _repo),
        ]));
  }
}
