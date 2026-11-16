import 'package:flutter/material.dart';

import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

/// Mở trang sửa bé; chỉ thông báo thay đổi khi API đã trả hồ sơ mới.
Future<void> showParentChildEditScreen(
  BuildContext context, {
  required Child child,
  required String parentId,
  required ValueChanged<Child> onSaved,
  HttpDashboardRepository? repository,
}) async {
  final updated = await Navigator.of(context).push<Child>(MaterialPageRoute(
    builder: (_) => GardenVoiceScope(
      child: ParentChildEditScreen(
        child: child,
        parentId: parentId,
        repository: repository,
      ),
    ),
  ));
  if (updated == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  onSaved(updated);
  if (messenger?.mounted ?? false) {
    messenger!.showSnackBar(
      const SnackBar(content: Text('Đã cập nhật thông tin của bé thành công')),
    );
  }
}

/// Form Garden Voice mở từ bút chì trong sheet thông tin bé.
class ParentChildEditScreen extends StatefulWidget {
  const ParentChildEditScreen({
    super.key,
    required this.child,
    required this.parentId,
    this.repository,
  });

  final Child child;
  final String parentId;
  final HttpDashboardRepository? repository;

  @override
  State<ParentChildEditScreen> createState() => _ParentChildEditScreenState();
}

class _ParentChildEditScreenState extends State<ParentChildEditScreen> {
  late final _repository = widget.repository ?? HttpDashboardRepository();
  late final _name = TextEditingController(text: widget.child.fullName);
  late final _nickname =
      TextEditingController(text: widget.child.nickname ?? '');
  late final _allergies =
      TextEditingController(text: widget.child.medicalAllergies ?? '');
  late DateTime? _dateOfBirth = widget.child.dateOfBirth;
  late String? _gender = _initialGender(widget.child.gender);
  bool _saving = false;
  String? _error;

  String? _initialGender(String? value) {
    final gender = value?.trim();
    return switch (gender?.toLowerCase()) {
      null || '' => null,
      'male' || 'nam' => 'male',
      'female' || 'nữ' || 'nu' => 'female',
      'other' || 'khác' => 'other',
      _ => gender,
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _allergies.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!_saving) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateTime(1900);
    final initialDate =
        _dateOfBirth ?? DateTime(today.year - 3, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : initialDate.isAfter(today)
              ? today
              : initialDate,
      firstDate: firstDate,
      lastDate: today,
      helpText: 'Chọn ngày sinh của bé',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Họ và tên của bé không được để trống.');
      return;
    }
    if (_dateOfBirth != null &&
        DateUtils.dateOnly(_dateOfBirth!)
            .isAfter(DateUtils.dateOnly(DateTime.now()))) {
      setState(
          () => _error = 'Ngày sinh của bé không thể là ngày trong tương lai.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _repository.updateChildInfo(
        parentId: widget.parentId,
        childId: widget.child.childId,
        fullName: name,
        // Chuỗi rỗng yêu cầu API xóa giá trị; null có nghĩa là không cập nhật.
        nickname: _nickname.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        medicalAllergies: _allergies.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getFriendlyErrorMessage(
          error,
          fallback: 'Không thể lưu thông tin của bé. Vui lòng thử lại sau.',
        );
      });
    }
  }

  TextStyle get _bodyStyle => Theme.of(context).textTheme.bodyLarge!.copyWith(
        fontSize: 14,
        height: 1.4,
        color: context.k.ink,
      );

  Widget _label(String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.k.ink,
            ),
      );

  InputDecoration _decoration({String? hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        counterText: '',
        filled: true,
        fillColor: context.k.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.k.line),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.k.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.k.brand),
        ),
      );

  Widget _field({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          _label(label),
          Semantics(
            label: label,
            child: TextField(
              key: ValueKey(keyName),
              controller: controller,
              enabled: !_saving,
              maxLength: maxLength,
              maxLines: maxLines,
              textCapitalization: capitalization,
              style: _bodyStyle,
              decoration: _decoration(hint: hint),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: KAppBar(title: 'Chỉnh sửa thông tin bé', onBack: _cancel),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('child-edit-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(KSpace.x5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 14,
                      children: [
                        Text(
                          'Cập nhật thông tin để nhà trường chăm sóc bé tốt hơn.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: context.k.inkSoft,
                                  ),
                        ),
                        _field(
                          keyName: 'child-edit-name',
                          label: 'Họ và tên của bé *',
                          controller: _name,
                          hint: 'Ví dụ: Nguyễn Minh An',
                          maxLength: 150,
                          capitalization: TextCapitalization.words,
                        ),
                        _field(
                          keyName: 'child-edit-nickname',
                          label: 'Tên gọi ở nhà (Biệt danh)',
                          controller: _nickname,
                          hint: 'Ví dụ: Bơ, Sóc, Bon…',
                          maxLength: 50,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 6,
                          children: [
                            _label('Ngày sinh của bé'),
                            Semantics(
                              button: true,
                              enabled: !_saving,
                              label: 'Chọn ngày sinh của bé',
                              child: InkWell(
                                key: const ValueKey('child-edit-dob'),
                                onTap: _saving ? null : _pickDate,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: _decoration(
                                    suffix: const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 20),
                                  ),
                                  child: Text(
                                    _dateOfBirth == null
                                        ? 'Chọn ngày sinh'
                                        : kDateLabel(_dateOfBirth!),
                                    style: _bodyStyle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 6,
                          children: [
                            _label('Giới tính'),
                            Wrap(
                              spacing: KSpace.x2,
                              runSpacing: KSpace.x2,
                              children: [
                                for (final option in const [
                                  ('male', 'Bé trai (Nam)'),
                                  ('female', 'Bé gái (Nữ)'),
                                  ('other', 'Khác'),
                                ])
                                  Semantics(
                                    enabled: !_saving,
                                    selected: _gender == option.$1,
                                    child: IgnorePointer(
                                      ignoring: _saving,
                                      child: FilterChipButton(
                                        label: option.$2,
                                        selected: _gender == option.$1,
                                        onTap: () =>
                                            setState(() => _gender = option.$1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_gender == null)
                              Text('Chưa cập nhật',
                                  style: _bodyStyle.copyWith(
                                      color: context.k.inkSoft)),
                          ],
                        ),
                        _field(
                          keyName: 'child-edit-allergies',
                          label: 'Dị ứng & Lưu ý sức khỏe',
                          controller: _allergies,
                          hint: 'Thông tin dị ứng cần nhà trường lưu ý',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KSpace.x5, KSpace.x2, KSpace.x5, KSpace.x5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: [
                      if (_error != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              style: _bodyStyle.copyWith(color: context.k.bad)),
                        ),
                      KButton(
                        label: _saving ? 'Đang lưu thông tin…' : 'Lưu thay đổi',
                        onPressed: _saving ? null : _save,
                      ),
                      KButton(
                          label: 'Hủy',
                          secondary: true,
                          onPressed: _saving ? null : _cancel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
