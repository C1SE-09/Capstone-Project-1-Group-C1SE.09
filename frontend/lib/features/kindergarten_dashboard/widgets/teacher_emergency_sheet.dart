// M8–M9: biên bản từ server không chứng minh phụ huynh đã nhận FCM.
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../screens/parent_medication_widgets.dart';
import '../screens/parent_requests_widgets.dart';
import '../theme.dart';

class TeacherEmergencySheet extends StatefulWidget {
  const TeacherEmergencySheet(
      {super.key,
      required this.children,
      this.initialChildId,
      this.repository});
  final List<Child> children;
  final String? initialChildId;
  final HttpMedicationRepository? repository;
  static Future<void> show(BuildContext context,
          {required List<Child> children,
          String? initialChildId,
          HttpMedicationRepository? repository}) =>
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 480),
          builder: (_) => TeacherEmergencySheet(
              children: children,
              initialChildId: initialChildId,
              repository: repository));
  @override
  State<TeacherEmergencySheet> createState() => _TeacherEmergencySheetState();
}

class _TeacherEmergencySheetState extends State<TeacherEmergencySheet> {
  late HttpMedicationRepository _repo =
      widget.repository ?? HttpMedicationRepository();
  final _temperature = TextEditingController(),
      _notes = TextEditingController();
  String? _childId, _error, _contactsError;
  String _type = 'high_fever';
  bool _busy = false, _loadingContacts = false;
  int _version = 0;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _contacts = [];
  static const _types = {
    'high_fever': 'Sốt cao',
    'severe_injury': 'Tai nạn / Té ngã',
    'acute_allergy': 'Dị ứng cấp tính',
    'other': 'Khác'
  };
  @override
  void initState() {
    super.initState();
    if (widget.children.any((c) => c.id == widget.initialChildId)) {
      _childId = widget.initialChildId;
    }
  }

  @override
  void didUpdateWidget(covariant TeacherEmergencySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        !widget.children.any((c) => c.id == _childId)) {
      _version++;
      _repo = widget.repository ?? HttpMedicationRepository();
      _busy = false;
      _result = null;
      _childId = null;
      _contacts = [];
    }
  }

  @override
  void dispose() {
    _temperature.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _result != null) return;
    final id = _childId, version = _version;
    if (id == null || !widget.children.any((c) => c.id == id)) {
      setState(() => _error = 'Vui lòng chọn học sinh gặp sự cố.');
      return;
    }
    final raw = _temperature.text.trim().replaceAll(',', '.');
    final temperature = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty &&
        (temperature == null ||
            !temperature.isFinite ||
            temperature < 34 ||
            temperature > 44)) {
      setState(() => _error = 'Nhiệt độ phải là số từ 34°C đến 44°C.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final result = await _repo.createHealthIncident(
          childId: id,
          incidentType: _type,
          description: _notes.text.trim(),
          temperature: temperature);
      if (!mounted || version != _version) return;
      setState(() {
        _result = result;
        final contacts = result['emergency_contacts'];
        if (contacts is List &&
            contacts.every((row) =>
                row is Map<String, dynamic> && row['phone'] is String)) {
          _contacts = contacts.cast<Map<String, dynamic>>();
        } else {
          _contactsError =
              'Đã lưu sự cố nhưng danh bạ chưa hợp lệ. Hãy tải lại danh bạ, không gửi lại biên bản.';
        }
      });
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = medicationError(error));
      }
    } finally {
      if (mounted && version == _version) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reloadContacts() async {
    if (_loadingContacts || _result == null) return;
    final id = _result!['child_id'] as String, version = _version;
    setState(() {
      _loadingContacts = true;
    });
    try {
      final contacts = await _repo.getEmergencyContacts(id);
      if (!mounted || version != _version) return;
      setState(() {
        _contacts = contacts;
        _contactsError = null;
      });
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _contactsError = medicationError(error));
      }
    } finally {
      if (mounted && version == _version) {
        setState(() => _loadingContacts = false);
      }
    }
  }

  Future<void> _call(String phone) async {
    final uri = phoneCallUri(phone);
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {/* Danh bạ vẫn hiển thị để liên hệ qua cách khác. */}
    if (mounted) {
      setState(() => _contactsError =
          'Không mở được ứng dụng gọi điện. Vui lòng dùng số trong danh bạ để liên hệ trực tiếp.');
    }
  }

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 480, minHeight: MediaQuery.sizeOf(context).height),
          child: Material(
              color: context.k.canvas,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 20, 20,
                          MediaQuery.viewInsetsOf(context).bottom + 20),
                      child: _result == null ? _form() : _success())))));

  Widget _form() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                  child: Text('Báo cáo sự cố khẩn cấp',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.k.bad))),
              IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close))
            ]),
            const SizedBox(height: 13),
            MedicationCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const Text('Chọn bé gặp sự cố',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                      value: _childId,
                      isExpanded: true,
                      hint: const Text('Chọn học sinh...'),
                      items: widget.children
                          .map((child) => DropdownMenuItem(
                              value: child.id, child: Text(child.name)))
                          .toList(),
                      onChanged:
                          _busy ? null : (id) => setState(() => _childId = id)),
                  const SizedBox(height: 9),
                  const Text('Loại sự cố',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Wrap(spacing: 7, runSpacing: 6, children: [
                    for (final type in _types.entries)
                      ChoiceChip(
                          label: Text(type.value,
                              style: const TextStyle(fontSize: 11)),
                          selected: _type == type.key,
                          showCheckmark: false,
                          selectedColor: context.k.bad,
                          backgroundColor: context.k.surfaceSunken,
                          labelStyle: TextStyle(
                              color: _type == type.key
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : context.k.ink),
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _type = type.key))
                  ]),
                ])),
            const SizedBox(height: 13),
            TextField(
                controller: _temperature,
                enabled: !_busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Nhiệt độ (không bắt buộc)',
                    suffixText: '°C',
                    border: OutlineInputBorder())),
            const SizedBox(height: 13),
            TextField(
                controller: _notes,
                enabled: !_busy,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Mô tả / biện pháp đã thực hiện (tùy chọn)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 13),
            Text(
                'Lưu biên bản và yêu cầu hệ thống gửi cảnh báo. Không cần nhập mô tả để gửi; hãy gọi trực tiếp gia đình khi cần.',
                style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
            if (_error != null) ...[
              const SizedBox(height: 13),
              Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: TextStyle(color: context.k.bad)))
            ],
            const SizedBox(height: 13),
            MedicationAction(
                label: 'Phát cảnh báo khẩn cấp',
                danger: true,
                busy: _busy,
                onPressed: _submit),
          ]);
  Widget _success() {
    final result = _result!;
    final stamp = DateTime.tryParse(result['reported_at']?.toString() ?? '');
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: context.k.badTint,
                  borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Text('Đã ghi nhận sự cố khẩn cấp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.k.bad)),
                const SizedBox(height: 5),
                Text(
                    '${result['child_name']} · ${result['incident_type_label'] ?? _types[result['incident_type']] ?? 'Sự cố sức khỏe'}'
                    '${result['temperature'] == null ? '' : ' ${result['temperature']}°C'}${stamp == null ? '' : ' · ${requestTimestamp(stamp)}'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 5),
                Text(
                    'Chưa có xác nhận giao thông báo. Vui lòng liên hệ trực tiếp.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
              ])),
          const SizedBox(height: 13),
          const Text('Liên hệ trực tiếp với gia đình',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          if (_contacts.isEmpty && _contactsError == null) ...[
            const SizedBox(height: 13),
            const Text('Chưa cập nhật số điện thoại phụ huynh của bé này.')
          ],
          if (_contactsError != null) ...[
            const SizedBox(height: 13),
            Semantics(
                liveRegion: true,
                child: Text(_contactsError!,
                    style: TextStyle(color: context.k.bad)))
          ],
          for (final contact in _contacts) ...[
            const SizedBox(height: 13),
            MedicationCard(
                child: LayoutBuilder(builder: (context, constraints) {
              final phone = contact['phone'] as String? ?? '';
              final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${contact['relationship'] ?? 'Phụ huynh'} · ${contact['name'] ?? 'Chưa rõ tên'}',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(
                        phoneCallUri(phone) == null
                            ? 'Chưa có số điện thoại hợp lệ'
                            : phone,
                        style:
                            TextStyle(fontSize: 12, color: context.k.inkSoft)),
                  ]);
              final button = FilledButton(
                  onPressed:
                      phoneCallUri(phone) == null ? null : () => _call(phone),
                  style: FilledButton.styleFrom(
                      backgroundColor: context.k.brand,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder()),
                  child: const Text('Gọi ngay'));
              return constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [info, const SizedBox(height: 9), button])
                  : Row(children: [
                      Expanded(child: info),
                      const SizedBox(width: 10),
                      button
                    ]);
            }))
          ],
          TextButton(
              onPressed: _loadingContacts ? null : _reloadContacts,
              child: Text(_loadingContacts
                  ? 'Đang tải danh bạ...'
                  : 'Tải lại danh bạ')),
          const SizedBox(height: 13),
          MedicationCard(
              child: Text(
                  '${result['reported_by_name'] ?? 'Chưa rõ người báo cáo'}'
                  '${stamp == null ? '' : ' · ${requestTimestamp(stamp)}'}\n${result['description'] ?? ''}',
                  style: const TextStyle(fontSize: 12.5))),
          const SizedBox(height: 13),
          MedicationAction(
              label: 'Hoàn tất', onPressed: () => Navigator.maybePop(context)),
        ]);
  }
}
