// M8–M9: biên bản từ server không chứng minh phụ huynh đã nhận FCM.
import 'dart:async';

import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/data/repositories/http_health_incident_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_cards.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show Avatar, KButton;

class TeacherEmergencySheet extends StatefulWidget {
  const TeacherEmergencySheet(
      {super.key,
      required this.children,
      this.initialChildId,
      this.repository});
  final List<Child> children;
  final String? initialChildId;
  final HttpHealthIncidentRepository? repository;
  static Future<void> show(BuildContext context,
          {required List<Child> children,
          String? initialChildId,
          HttpHealthIncidentRepository? repository}) =>
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 480),
          builder: (_) => GardenVoiceScope(
              child: TeacherEmergencySheet(
                  children: children,
                  initialChildId: initialChildId,
                  repository: repository)));
  @override
  State<TeacherEmergencySheet> createState() => _TeacherEmergencySheetState();
}

class _TeacherEmergencySheetState extends State<TeacherEmergencySheet> {
  late HttpHealthIncidentRepository _repo =
      widget.repository ?? HttpHealthIncidentRepository();
  final _temperature = TextEditingController(),
      _notes = TextEditingController();
  String? _childId, _error, _contactsError;
  String _type = 'high_fever';
  bool _busy = false, _loadingContacts = false;
  int _version = 0, _contactsVersion = 0;
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
      unawaited(_loadContacts(_childId!));
    }
  }

  @override
  void didUpdateWidget(covariant TeacherEmergencySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        !widget.children.any((c) => c.id == _childId)) {
      _version++;
      _contactsVersion++;
      _repo = widget.repository ?? HttpHealthIncidentRepository();
      _busy = false;
      _result = null;
      _childId = null;
      _contacts = [];
      _contactsError = null;
      _loadingContacts = false;
      if (widget.children.any((c) => c.id == widget.initialChildId)) {
        _childId = widget.initialChildId;
        unawaited(_loadContacts(_childId!));
      }
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
          _contactsError = null;
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
    final id = _result?['child_id']?.toString() ?? _childId;
    if (_loadingContacts || id == null) return;
    await _loadContacts(id);
  }

  Future<void> _loadContacts(String id) async {
    final version = ++_contactsVersion;
    setState(() {
      _loadingContacts = true;
      _contacts = [];
      _contactsError = null;
    });
    try {
      final contacts = await _repo.getEmergencyContacts(id);
      if (!mounted ||
          version != _contactsVersion ||
          (_childId != id && _result?['child_id'] != id)) {
        return;
      }
      setState(() {
        _contacts = contacts;
      });
    } catch (error) {
      if (mounted && version == _contactsVersion) {
        setState(() => _contactsError = medicationError(error));
      }
    } finally {
      if (mounted && version == _contactsVersion) {
        setState(() => _loadingContacts = false);
      }
    }
  }

  void _selectChild(String? id) {
    if (id == null || id == _childId) return;
    setState(() {
      _childId = id;
      _error = null;
    });
    unawaited(_loadContacts(id));
  }

  Future<void> _openChildPicker() async {
    final selectedId = await showDialog<String>(
      context: context,
      builder: (_) => GardenVoiceScope(
        child: _ChildPickerDialog(
          children: widget.children,
          selectedId: _childId,
        ),
      ),
    );
    if (selectedId != null && selectedId != _childId) {
      _selectChild(selectedId);
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

  Future<void> _callParent() async {
    final contacts = _contacts
        .where((contact) =>
            phoneCallUri(contact['phone'] as String? ?? '') != null)
        .toList();
    if (contacts.isEmpty) {
      setState(() => _contactsError =
          'Chưa có số điện thoại hợp lệ trong danh bạ khẩn cấp.');
      return;
    }
    if (contacts.length == 1) {
      await _call(contacts.single['phone'] as String);
      return;
    }
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chọn phụ huynh để gọi'),
        children: [
          for (final contact in contacts)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, contact['phone'] as String),
              child: Text(
                  '${contact['name'] ?? 'Phụ huynh'} · ${contact['relationship'] ?? 'Người thân'}'),
            ),
        ],
      ),
    );
    if (phone != null) await _call(phone);
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

  InputDecoration _input(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: context.k.inkFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.k.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.k.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.k.brand)));

  Widget _form() {
    final selectedChild = _childId == null
        ? null
        : widget.children.where((c) => c.id == _childId).firstOrNull;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              IconButton(
                  tooltip: 'Đóng',
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.maybePop(context),
                  icon: SvgPicture.asset(
                      'assets/garden_voice/emergency_back.svg',
                      width: 24,
                      height: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Báo sự cố',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: context.k.ink)),
                    Text('Thông báo cho phụ huynh và nhà trường',
                        style:
                            TextStyle(fontSize: 12, color: context.k.inkSoft)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: context.k.badTint,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                SvgPicture.asset(
                    'assets/garden_voice/emergency_triangle_alert.svg',
                    width: 28,
                    height: 28),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text(
                        'Kiểm tra đúng bé, nội dung và người nhận trước khi gửi cảnh báo khẩn.',
                        style: TextStyle(fontSize: 12, height: 1.35))),
              ]),
            ),
            const SizedBox(height: 13),
            MedicationCard(
              radius: 24,
              child: InkWell(
                onTap: _busy ? null : _openChildPicker,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: selectedChild != null
                      ? Row(
                          children: [
                            Avatar(name: selectedChild.name, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedChild.fullNameWithNickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.k.ink,
                                    ),
                                  ),
                                  if (selectedChild.allergy?.trim().isNotEmpty ?? false) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dị ứng: ${selectedChild.allergy!.trim()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: context.k.warn,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.k.surfaceSunken,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Đổi bé',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.k.brand,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.unfold_more,
                                      size: 16, color: context.k.brand),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: context.k.surfaceSunken,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_search_rounded,
                                  color: context.k.inkSoft, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chọn học sinh...',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.k.inkSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Chạm để tìm kiếm và chọn bé',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.k.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SvgPicture.asset(
                              'assets/garden_voice/chevron_right.svg',
                              width: 18,
                              height: 18,
                              colorFilter: ColorFilter.mode(
                                  context.k.inkSoft, BlendMode.srcIn),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Loại sự cố',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final type in _types.entries)
                ChoiceChip(
                  label: Text(type.value),
                  selected: _type == type.key,
                  showCheckmark: false,
                  selectedColor: context.k.bad,
                  backgroundColor: context.k.accentTint,
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return context.k.bad;
                    }
                    return context.k.accentTint;
                  }),
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  pressElevation: 0,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  padding: EdgeInsets.zero,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _type == type.key
                          ? Colors.white
                          : context.k.accentDeep),
                  onSelected:
                      _busy ? null : (_) => setState(() => _type = type.key),
                ),
            ]),
            const SizedBox(height: 13),
            const Text('Nhiệt độ (không bắt buộc)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
                controller: _temperature,
                enabled: !_busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: _input('Ví dụ: 38.5').copyWith(
                    suffixText: '°C',
                    suffixStyle:
                        TextStyle(fontSize: 13, color: context.k.inkSoft))),
            const SizedBox(height: 13),
            const Text('Mô tả sự cố',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
                controller: _notes,
                enabled: !_busy,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration:
                    _input('Tình trạng và biện pháp sơ cứu (không bắt buộc)')),
            const SizedBox(height: 16),
            const Text('Người nhận cảnh báo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loadingContacts)
              Text('Đang tải danh bạ...',
                  style: TextStyle(fontSize: 12, color: context.k.inkSoft))
            else if (_contacts.isEmpty && _contactsError == null)
              Text('Chưa cập nhật số điện thoại phụ huynh của bé này.',
                  style: TextStyle(fontSize: 12, color: context.k.inkSoft))
            else
              for (var index = 0; index < _contacts.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _recipient(_contacts[index]),
              ],
            if (_contactsError != null) ...[
              const SizedBox(height: 8),
              Semantics(
                  liveRegion: true,
                  child: Text(_contactsError!,
                      style: TextStyle(fontSize: 11.5, color: context.k.bad))),
              TextButton(
                  onPressed: _loadingContacts ? null : _reloadContacts,
                  child: Text(_loadingContacts
                      ? 'Đang tải danh bạ...'
                      : 'Tải lại danh bạ')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 9),
              Semantics(
                  liveRegion: true,
                  child: Text(_error!,
                      style: TextStyle(fontSize: 11.5, color: context.k.bad))),
            ],
            const SizedBox(height: 16),
            MedicationAction(
                label: 'Gửi cảnh báo khẩn',
                danger: true,
                busy: _busy,
                onPressed: _submit),
            const SizedBox(height: 8),
            KButton(
              label: 'Gọi phụ huynh',
              secondary: true,
              onPressed: _loadingContacts ? null : _callParent,
            ),
            const SizedBox(height: 10),
            Text(
                'Một chạm tạo biên bản sự cố. Thông báo đẩy có thể được xử lý nền; hãy gọi gia đình nếu cần xác nhận ngay.',
                style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
          ]);
  }

  Widget _recipient(Map<String, dynamic> contact) {
    final phone = contact['phone'] as String? ?? '';
    return MedicationCard(
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: context.k.infoTint,
                borderRadius: BorderRadius.circular(18)),
            child: SvgPicture.asset('assets/garden_voice/emergency_user.svg',
                width: 20, height: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${contact['name'] ?? 'Phụ huynh'} · ${contact['relationship'] ?? 'Người thân'}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(maskedPhone(phone),
                    style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    final result = _result!;
    final stamp = DateTime.tryParse(result['reported_at']?.toString() ?? '');
    final clock = stamp == null
        ? null
        : DateFormat('HH:mm')
            .format(stamp.toUtc().add(const Duration(hours: 7)));
    final description = (result['description'] ?? '').toString().trim();
    final hasValidContact = _contacts.any(
        (contact) => phoneCallUri(contact['phone'] as String? ?? '') != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          IconButton(
              tooltip: 'Đóng',
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.maybePop(context),
              icon: SvgPicture.asset('assets/garden_voice/emergency_back.svg',
                  width: 24, height: 24)),
          const SizedBox(width: 10),
          const Text('Sự cố',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Center(
          child: SvgPicture.asset('assets/garden_voice/emergency_sent.svg',
              width: 76, height: 76, excludeFromSemantics: true),
        ),
        const SizedBox(height: 9),
        const Text('Đã lưu biên bản sự cố',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            'Sự cố của ${result['child_name']} đã được ghi nhận${clock == null ? '' : ' lúc $clock'}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.k.inkSoft)),
        const SizedBox(height: 13),
        MedicationCard(
          radius: 24,
          borderColor: context.k.line,
          child: Column(
            children: [
              for (var index = 0; index < _contacts.length; index++) ...[
                if (index > 0) ...[
                  Divider(height: 1, color: context.k.line),
                ],
                Row(children: [
                  Expanded(
                      child: Text(
                          '${_contacts[index]['relationship'] ?? 'Phụ huynh'}',
                          style: TextStyle(
                              fontSize: 12, color: context.k.inkSoft))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${_contacts[index]['name'] ?? 'Chưa rõ tên'}',
                            style: const TextStyle(fontSize: 12.5)),
                        Text(
                            maskedPhone(
                                _contacts[index]['phone'] as String? ?? ''),
                            style: TextStyle(
                                fontSize: 11.5, color: context.k.inkSoft)),
                      ])),
                ]),
              ],
              if (_contacts.isEmpty) ...[
                Text('Liên hệ',
                    style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
                const SizedBox(height: 4),
                const Text('Chưa cập nhật số điện thoại phụ huynh của bé.'),
              ],
              Divider(height: 1, color: context.k.line),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    flex: 2,
                    child: Text('Nội dung',
                        style:
                            TextStyle(fontSize: 12, color: context.k.inkSoft))),
                Expanded(
                    flex: 3,
                    child: Text(
                        description.isEmpty
                            ? 'Chưa có mô tả từ giáo viên.'
                            : description,
                        style: const TextStyle(fontSize: 12.5))),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Chưa có xác nhận giao thông báo đẩy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
        if (_contactsError != null) ...[
          const SizedBox(height: 8),
          Semantics(
              liveRegion: true,
              child: Text(_contactsError!,
                  style: TextStyle(fontSize: 11.5, color: context.k.bad))),
        ],
        if (_contactsError != null || _contacts.isEmpty)
          TextButton(
              style: TextButton.styleFrom(foregroundColor: context.k.inkSoft),
              onPressed: _loadingContacts ? null : _reloadContacts,
              child: Text(_loadingContacts
                  ? 'Đang tải danh bạ...'
                  : 'Tải lại danh bạ')),
        const SizedBox(height: 9),
        MedicationAction(
            label: 'Gọi phụ huynh ngay',
            onPressed: hasValidContact ? _callParent : null),
        const SizedBox(height: 8),
        KButton(
          label: 'Hoàn tất',
          secondary: true,
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    );
  }
}

class _ChildPickerDialog extends StatefulWidget {
  const _ChildPickerDialog({
    required this.children,
    required this.selectedId,
  });

  final List<Child> children;
  final String? selectedId;

  @override
  State<_ChildPickerDialog> createState() => _ChildPickerDialogState();
}

class _ChildPickerDialogState extends State<_ChildPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final q = _query.trim().toLowerCase();
    final filtered = widget.children.where((c) {
      if (q.isEmpty) return true;
      final nameWithNick = c.fullNameWithNickname.toLowerCase();
      final nick = (c.nickname ?? '').toLowerCase();
      return nameWithNick.contains(q) || nick.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: k.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn học sinh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: k.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: k.inkSoft, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: k.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: k.line),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val),
                  style: TextStyle(fontSize: 14, color: k.ink),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc biệt danh bé...',
                    hintStyle: TextStyle(fontSize: 13, color: k.inkFaint),
                    prefixIcon: Icon(Icons.search, size: 20, color: k.inkSoft),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: k.inkSoft),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Không tìm thấy học sinh phù hợp.',
                          style: TextStyle(fontSize: 13, color: k.inkFaint),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: k.line),
                      itemBuilder: (context, index) {
                        final child = filtered[index];
                        final isSelected = child.id == widget.selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, child.id),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? k.brandTint.withValues(alpha: .25) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Avatar(name: child.name, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child.fullNameWithNickname,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                          color: isSelected ? k.brand : k.ink,
                                        ),
                                      ),
                                      if (child.allergy?.trim().isNotEmpty ?? false) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Dị ứng: ${child.allergy!.trim()}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: k.warn,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: k.brand, size: 22)
                                else
                                  Icon(Icons.radio_button_unchecked, color: k.lineStrong, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
