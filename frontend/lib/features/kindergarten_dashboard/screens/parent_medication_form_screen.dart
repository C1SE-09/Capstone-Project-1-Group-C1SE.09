import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_submitted_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

class ParentMedicationFormScreen extends StatefulWidget {
  const ParentMedicationFormScreen(
      {super.key,
      required this.child,
      required this.className,
      this.repository,
      this.imagePicker});
  final Child child;
  final String className;
  final HttpMedicationRepository? repository;
  final ImagePicker? imagePicker;
  @override
  State<ParentMedicationFormScreen> createState() =>
      _ParentMedicationFormScreenState();
}

class _ParentMedicationFormScreenState
    extends State<ParentMedicationFormScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _dosage = TextEditingController(),
      _notes = TextEditingController();
  final _slots = <String>{};
  late final Child _child = widget.child;
  late final HttpMedicationRepository _repo =
      widget.repository ?? HttpMedicationRepository();
  DateTime _from = medicationDateInVietnam(DateTime.now());
  late DateTime _to = _from;
  String _category = 'prescription';
  Uint8List? _bytes;
  String? _fileName, _imagePath, _error;
  bool _busy = false,
      _picking = false,
      _dirty = false,
      _dialog = false,
      _stale = false;
  int get _days =>
      DateTime.utc(_to.year, _to.month, _to.day)
          .difference(DateTime.utc(_from.year, _from.month, _from.day))
          .inDays +
      1;

  @override
  void didUpdateWidget(covariant ParentMedicationFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_child.childId != widget.child.childId ||
        _child.classId != widget.child.classId ||
        oldWidget.repository != widget.repository) {
      _stale = true;
      _error =
          'Hồ sơ bé đang soạn đã thay đổi. Hãy quay lại và tạo lại đơn; bản nháp hiện chưa gửi.';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    if (_busy || _picking || _dialog) return;
    _dialog = true;
    final agreed = !_dirty ||
        await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                        title: const Text('Bỏ thay đổi?'),
                        content: const Text(
                            'Nội dung đơn thuốc chưa gửi sẽ không được lưu.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Tiếp tục soạn')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Bỏ thay đổi'))
                        ])) ==
            true;
    _dialog = false;
    if (mounted && agreed) Navigator.pop(context);
  }

  Future<void> _pickDate(bool end) async {
    // Đồng hồ máy chỉ gợi ý ngày; server quyết định ngày nào còn được gửi.
    final first = end ? _from : DateTime(1);
    var last = end
        ? DateTime(_from.year, _from.month, _from.day + 6)
        : DateTime(9999, 12, 31);
    if (last.isBefore(first)) last = first;
    var initial = end ? _to : _from;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final value = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        helpText: end ? 'Đến ngày' : 'Từ ngày',
        cancelText: 'Hủy',
        confirmText: 'Xong');
    if (!mounted || value == null) return;
    setState(() {
      if (end) {
        _to = value;
      } else {
        _from = value;
        if (_to.isBefore(value) || _days > 7) _to = value;
      }
      _dirty = true;
    });
  }

  void _toggle(String value) => setState(() {
        if (_slots.contains(value)) {
          _slots.remove(value);
        } else if (_slots.length < 24) {
          _slots.add(value);
        } else {
          _error = 'Mỗi ngày tối đa 24 cữ. Vui lòng kiểm tra lại khung giờ.';
        }
        _dirty = true;
      });
  Future<void> _pickTime() async {
    final result = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 30),
        cancelText: 'Hủy',
        confirmText: 'Thêm',
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (mounted && result != null) {
      final value =
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
      if (!_slots.contains(value)) _toggle(value);
    }
  }

  Future<void> _pickImage() async {
    if (_busy || _picking || _stale) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await (widget.imagePicker ?? ImagePicker())
          .pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const MedicationRequestException(
            'Ảnh tối đa 5 MiB. Vui lòng chọn ảnh nhỏ hơn.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted || _stale) return;
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _imagePath = null;
        _dirty = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is MedicationRequestException
            ? error.message
            : 'Không thể chọn ảnh. Vui lòng kiểm tra quyền thư viện.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _picking || _stale) return;
    FocusScope.of(context).unfocus();
    if (!_key.currentState!.validate()) return;
    String? invalid;
    if (_slots.isEmpty) invalid = 'Chọn ít nhất một khung giờ uống.';
    if (_bytes == null) invalid = 'Ảnh đơn thuốc là bắt buộc.';
    if (_days < 1 || _days > 7) {
      invalid =
          'Chọn đợt tối đa 7 ngày tính cả hai đầu. Máy chủ kiểm tra ngày hợp lệ khi gửi.';
    }
    if (_child.classId?.isNotEmpty != true) {
      invalid = 'Bé chưa có lớp. Vui lòng liên hệ nhà trường.';
    }
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final slots = _slots.toList()..sort();
    try {
      _imagePath ??= await _repo.uploadPrescription(
          childId: _child.childId, bytes: _bytes!);
      if (!mounted || _stale) return;
      final result = await _repo.createMedicationRequests(
          childId: _child.childId,
          expectedClassId: _child.classId,
          fromDate: _from,
          toDate: _to,
          timeSlots: slots,
          medicineCategory: _category,
          medicineName: _name.text,
          dosage: _dosage.text,
          notes: _notes.text,
          prescriptionImageUrl: _imagePath!);
      if (!mounted || _stale) return;
      _dirty = false;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => ParentMedicationSubmittedScreen(result: result)));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = medicationError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)));
  Widget _field(String label, TextEditingController controller, int limit,
          {bool required = false, int lines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        Semantics(
          label: label,
          child: TextFormField(
              controller: controller,
              enabled: !_busy && !_stale,
              maxLines: lines,
              onChanged: (_) => setState(() => _dirty = true),
              validator: (value) => required && (value ?? '').trim().isEmpty
                  ? 'Vui lòng nhập $label.'
                  : (value ?? '').trim().runes.length > limit
                      ? '$label tối đa $limit ký tự.'
                      : null,
              decoration: InputDecoration(
                  filled: true,
                  fillColor: context.k.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.k.line)))),
        ),
        const SizedBox(height: 13)
      ]);
  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: _busy || _stale ? null : (_) => onTap(),
      selectedColor: context.k.brand,
      backgroundColor: context.k.surface,
      labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : context.k.inkSoft),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact);
  @override
  Widget build(BuildContext context) {
    final times = {'08:30', '11:30', '14:30', ..._slots}.toList()..sort();
    return PopScope(
        canPop: !_dirty && !_busy && !_picking,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _discard();
        },
        child: ParentRequestLayout(
            title: 'Tạo đơn dặn thuốc',
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Form(
                    key: _key,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Bé ${_child.fullName} · ${widget.className}',
                              style: TextStyle(
                                  fontSize: 11, color: context.k.brand)),
                          const SizedBox(height: 13),
                          _label('Loại thuốc'),
                          Wrap(spacing: 7, children: [
                            for (final entry in {
                              'prescription': 'Theo đơn bác sĩ',
                              'non_prescription': 'Không kê đơn',
                              'supplement': 'Vitamin / TPCN'
                            }.entries)
                              _chip(
                                  entry.value,
                                  _category == entry.key,
                                  () => setState(() {
                                        _category = entry.key;
                                        _dirty = true;
                                      })),
                          ]),
                          const SizedBox(height: 13),
                          _field('Tên thuốc', _name, 255),
                          _field('Liều lượng', _dosage, 255, required: true),
                          _label('Khung giờ uống (chọn nhiều)'),
                          Wrap(spacing: 7, children: [
                            for (final value in times)
                              _chip(value, _slots.contains(value),
                                  () => _toggle(value)),
                            TextButton(
                                onPressed: _busy || _stale ? null : _pickTime,
                                child: const Text('+ Thêm giờ')),
                          ]),
                          Text(
                              'Đã chọn ${_slots.length} khung giờ × $_days ngày → ${_slots.length * _days} cữ riêng.',
                              style: TextStyle(
                                  fontSize: 11, color: context.k.brand)),
                          const SizedBox(height: 13),
                          _label('Thời gian uống'),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton(
                                onPressed: _busy || _stale
                                    ? null
                                    : () => _pickDate(false),
                                child: Tooltip(
                                    message: 'Từ ngày',
                                    child: Text('Từ ${requestDate(_from)}'))),
                            OutlinedButton(
                                onPressed: _busy || _stale
                                    ? null
                                    : () => _pickDate(true),
                                child: Tooltip(
                                    message: 'Đến ngày',
                                    child: Text('Đến ${requestDate(_to)}'))),
                          ]),
                          const SizedBox(height: 8),
                          Text('Tối đa 7 ngày cho một đợt dặn thuốc.',
                              style: TextStyle(
                                  fontSize: 11, color: context.k.inkSoft)),
                          const SizedBox(height: 13),
                          _label('Ảnh đơn thuốc / giấy chỉ định *'),
                          OutlinedButton(
                              onPressed: _busy || _picking || _stale
                                  ? null
                                  : _pickImage,
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              child: Column(children: [
                                Text(_picking
                                    ? 'Đang mở thư viện...'
                                    : _fileName ?? '+ Thêm ảnh đơn thuốc'),
                                if (_fileName != null)
                                  const Text('Đã đính kèm · Chạm để thay ảnh',
                                      style: TextStyle(fontSize: 11))
                              ])),
                          const SizedBox(height: 8),
                          Text(
                              'Ảnh bắt buộc, JPEG/PNG/WebP tối đa 5 MiB. Hệ thống không kiểm duyệt nội dung ảnh hoặc tư vấn liều dùng.',
                              style: TextStyle(
                                  fontSize: 11, color: context.k.bad)),
                          const SizedBox(height: 13),
                          _field('Ghi chú thêm cho cô', _notes, 1000, lines: 3),
                          if (_error != null) ...[
                            Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: TextStyle(color: context.k.bad))),
                            const SizedBox(height: 13)
                          ],
                          MedicationAction(
                              label: 'Gửi đơn dặn thuốc',
                              busy: _busy,
                              onPressed: _picking || _stale ? null : _submit),
                        ])))));
  }
}
