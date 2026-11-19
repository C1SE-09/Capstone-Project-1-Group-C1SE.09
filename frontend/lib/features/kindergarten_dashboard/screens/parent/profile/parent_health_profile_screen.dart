// parent_health_profile_screen.dart
// =========================================================
// Màn "Thông tin sức khỏe" của phụ huynh (design v4 — Figma Make):
// dị ứng dài hạn + lưu ý chăm sóc, lưu qua PATCH có kiểm tra version.

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';

import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

/// Đếm code point để khớp `len()` của Python, không dùng UTF-16 length.
int healthCharCount(String value) => value.runes.length;

/// Mở màn hồ sơ sức khỏe; [onSaved] nhận hồ sơ mới sau khi lưu thành công.
Future<void> showParentHealthProfile(
  BuildContext context, {
  required Child child,
  required String className,
  required HttpDashboardRepository repository,
  ValueChanged<Child>? onSaved,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GardenVoiceScope(
        child: ParentHealthProfileScreen(
          child: child,
          className: className,
          repository: repository,
          onSaved: onSaved,
        ),
      ),
    ),
  );
}

class ParentHealthProfileScreen extends StatefulWidget {
  const ParentHealthProfileScreen({
    super.key,
    required this.child,
    required this.className,
    required this.repository,
    this.onSaved,
  });

  final Child child;
  final String className;
  final HttpDashboardRepository repository;
  final ValueChanged<Child>? onSaved;

  @override
  State<ParentHealthProfileScreen> createState() =>
      _ParentHealthProfileScreenState();
}

class _ParentHealthProfileScreenState extends State<ParentHealthProfileScreen> {
  static const _maxChars = 1000;

  final _allergyController = TextEditingController();
  final _notesController = TextEditingController();
  final _allergyFocus = FocusNode();

  late Child _child = widget.child;
  String _status = 'unknown';
  String _initialStatus = 'unknown';
  String _initialAllergy = '';
  String _initialNotes = '';

  bool _loading = true;
  bool _loadError = false;
  bool _saving = false;
  bool _conflict = false;
  String? _fieldError;
  String? _bannerTitle;
  String? _bannerBody;

  @override
  void initState() {
    super.initState();
    _applyChild(widget.child);
    _load();
  }

  @override
  void dispose() {
    _allergyController.dispose();
    _notesController.dispose();
    _allergyFocus.dispose();
    super.dispose();
  }

  void _applyChild(Child child) {
    _child = child;
    _status = child.allergyStatus;
    _initialStatus = _status;
    _initialAllergy =
        _status == 'present' ? (child.medicalAllergies ?? '').trim() : '';
    _initialNotes = (child.careNotes ?? '').trim();
    _allergyController.text = _initialAllergy;
    _notesController.text = _initialNotes;
    _fieldError = null;
    _bannerTitle = null;
    _bannerBody = null;
    _conflict = false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final child = await widget.repository.getChildHealthProfile(
        widget.child.childId,
      );
      if (!mounted) return;
      setState(() {
        _applyChild(child);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  String get _allergyValue =>
      _status == 'present' ? _allergyController.text.trim() : '';

  String get _notesValue => _notesController.text.trim();

  bool get _dirty =>
      _status != _initialStatus ||
      _allergyValue != _initialAllergy ||
      _notesValue != _initialNotes;

  Future<void> _selectStatus(String value) async {
    if (value == _status) return;
    if (_initialStatus != 'unknown') {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n?.parentHealthChangeConfirmTitle ?? 'Thay đổi thông tin dị ứng?'),
          content: Text(
            l10n?.parentHealthChangeConfirmMessage ?? 'Thông tin dị ứng hiện có sẽ được thay thế sau khi lưu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n?.parentHealthContinueEditing ?? 'Tiếp tục chỉnh sửa'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n?.commonConfirm ?? 'Xác nhận thay đổi'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _status = value;
      _fieldError = null;
      _bannerTitle = null;
      _bannerBody = null;
    });
  }

  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.parentHealthDiscardTitle ?? 'Bỏ thay đổi?'),
        content: Text(l10n?.parentHealthDiscardMessage ?? 'Những thay đổi bạn vừa nhập sẽ không được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n?.parentHealthContinueEditing ?? 'Tiếp tục chỉnh sửa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n?.parentHealthDiscardAction ?? 'Bỏ thay đổi'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _save() async {
    if (_saving || _conflict || !_dirty) return;
    final l10n = LocaleController.instance.currentL10n;
    if (_status == 'present' && _allergyValue.isEmpty) {
      setState(() => _fieldError = l10n.parentHealthAllergyRequired);
      _allergyFocus.requestFocus();
      return;
    }
    if (healthCharCount(_allergyValue) > _maxChars ||
        healthCharCount(_notesValue) > _maxChars) {
      setState(() {
        _bannerTitle = l10n.parentHealthTooLongTitle;
        _bannerBody = l10n.parentHealthTooLongBody;
      });
      return;
    }

    setState(() {
      _saving = true;
      _fieldError = null;
      _bannerTitle = null;
      _bannerBody = null;
    });
    try {
      final saved = await widget.repository.updateChildHealthProfile(
        childId: _child.childId,
        allergyStatus: _status,
        medicalAllergies: _status == 'present' ? _allergyValue : null,
        careNotes: _notesValue.isEmpty ? null : _notesValue,
        expectedVersion: _child.healthVersion,
      );
      if (!mounted) return;
      widget.onSaved?.call(saved);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n?.parentHealthUpdateSuccess ?? 'Đã cập nhật thông tin sức khỏe')),
      );
    } on ClassDataException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (error.statusCode == 409) {
          _conflict = true;
          _bannerTitle = l10n.parentHealthConflictTitle;
          _bannerBody = l10n.parentHealthConflictBody;
        } else if (error.statusCode == 422) {
          _bannerTitle = l10n.parentHealthInvalidTitle;
          _bannerBody = l10n.parentHealthInvalidBody;
        } else {
          _bannerTitle = l10n.healthProfileSaveFailed;
          _bannerBody = l10n.healthProfileSaveFailedDesc;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _bannerTitle = l10n.healthProfileSaveFailed;
        _bannerBody = l10n.healthProfileSaveFailedDesc;
      });
    }
  }

  String? get _metaLabel {
    final source = _child.healthUpdateSource;
    final hasData = _child.allergyStatus != 'unknown' ||
        (_child.medicalAllergies ?? '').trim().isNotEmpty ||
        (_child.careNotes ?? '').trim().isNotEmpty;
    if (!hasData) return null;
    final l10n = LocaleController.instance.currentL10n;
    if (source == 'legacy' || source == null) {
      return l10n.parentHealthLegacyInfo;
    }
    final updatedAt = _child.healthUpdatedAt;
    if (updatedAt == null) return null;
    final who = source == 'admin' ? l10n.roleAdmin : l10n.entityParent;
    return l10n.parentHealthLastUpdated(who, _formatDateTime(updatedAt));
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}, '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (!discard) return;
        if (!context.mounted) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: context.k.canvas,
        appBar: KAppBar(
          title: l10n?.parentHealthTitle ?? 'Thông tin sức khỏe',
          onBack: () => Navigator.maybePop(context),
        ),
        body: SafeArea(child: _buildBody(context)),
        bottomNavigationBar: _loading || _loadError
            ? null
            : BottomActionBar(
                child: KButton(
                  label: _saving
                      ? (l10n?.bugReportAdminSaving ?? 'Đang lưu...')
                      : (l10n?.commonSaveChanges ?? 'Lưu thay đổi'),
                  onPressed: _dirty && !_saving && !_conflict ? _save : null,
                ),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n?.parentHealthLoadError ?? 'Không tải được hồ sơ sức khỏe.',
                style: TextStyle(fontSize: 14, color: context.k.ink),
              ),
              const SizedBox(height: 16),
              KButton(label: l10n?.commonRetry ?? 'Thử lại', onPressed: _load),
              const SizedBox(height: 8),
              KButton(
                label: l10n?.commonBack ?? 'Quay lại',
                secondary: true,
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                _status == 'present' ? context.k.accentTint : context.k.okTint,
            border: Border.all(color: context.k.lineStrong),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _status == 'present'
                        ? Icons.warning_amber_rounded
                        : Icons.health_and_safety_outlined,
                    size: 18,
                    color: _status == 'present'
                        ? context.k.accentDeep
                        : context.k.brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _status == 'present'
                        ? (l10n?.parentAllergyTitle ?? 'Dị ứng')
                        : _status == 'none'
                            ? (l10n?.healthAllergyNone ?? 'Không ghi nhận dị ứng')
                            : (l10n?.healthAllergyUndeclared ?? 'Chưa khai báo dị ứng'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: _status == 'present'
                          ? context.k.accentDeep
                          : context.k.brand,
                    ),
                  ),
                ],
              ),
              if (_status == 'present' && _allergyValue.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _allergyValue,
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: context.k.ink),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n?.parentHealthAllergyStatus ?? 'Trạng thái dị ứng',
            style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.k.ink)),
        const SizedBox(height: 8),
        _HealthOption(
          title: l10n?.parentAllergyNotDeclared ?? 'Chưa khai báo',
          subtitle: l10n?.parentHealthUndeclaredSubtitle ?? 'Gia đình chưa cung cấp thông tin dị ứng.',
          selected: _status == 'unknown',
          onTap: () => _selectStatus('unknown'),
        ),
        _HealthOption(
          title: l10n?.parentHealthNoKnownAllergy ?? 'Không có dị ứng được biết',
          subtitle: l10n?.parentHealthNoKnownAllergySubtitle ?? 'Gia đình chưa ghi nhận bé dị ứng với thứ gì.',
          selected: _status == 'none',
          onTap: () => _selectStatus('none'),
        ),
        _HealthOption(
          title: l10n?.parentHasAllergy ?? 'Có dị ứng',
          subtitle: l10n?.parentHealthHasAllergySubtitle ?? 'Ghi rõ những gì bé bị dị ứng.',
          selected: _status == 'present',
          onTap: () => _selectStatus('present'),
        ),
        if (_status == 'present') ...[
          const SizedBox(height: 4),
          TextField(
            controller: _allergyController,
            focusNode: _allergyFocus,
            maxLines: 3,
            onChanged: (_) => setState(() => _fieldError = null),
            decoration: InputDecoration(
              labelText: l10n?.parentHealthAllergyLabel ?? 'Mô tả dị ứng',
              hintText: l10n?.parentHealthAllergyHint ?? 'Ví dụ: Đậu phộng',
              errorText: _fieldError,
            ),
          ),
          _CharCounter(
            count: healthCharCount(_allergyController.text),
            max: _maxChars,
          ),
        ],
        const SizedBox(height: 12),
        Text(l10n?.parentHealthCareNotes ?? 'Lưu ý chăm sóc',
            style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.k.brand)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            helperText:
                l10n?.parentHealthCareNotesHelper ?? 'Không dùng để gửi lời dặn trong ngày hoặc yêu cầu dùng thuốc.',
            helperMaxLines: 2,
            filled: true,
            fillColor: context.k.okTint,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(16),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(16),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: context.k.brand, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        _CharCounter(
            count: healthCharCount(_notesController.text), max: _maxChars),
        if (_metaLabel != null) ...[
          const SizedBox(height: 12),
          Text(
            _metaLabel!,
            style: TextStyle(fontSize: 12, color: context.k.inkFaint),
          ),
        ],
        if (_bannerTitle != null) ...[
          const SizedBox(height: 16),
          _Banner(
            title: _bannerTitle!,
            body: _bannerBody,
            onReload: _conflict ? _load : null,
          ),
        ],
      ],
    );
  }
}

/// Một lựa chọn trạng thái dị ứng (radio tự vẽ để không phụ thuộc RadioGroup).
class _HealthOption extends StatelessWidget {
  const _HealthOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.k.brand : context.k.lineStrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? context.k.brandTint : context.k.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: selected ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.k.brand,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.k.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharCounter extends StatelessWidget {
  const _CharCounter({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$count/$max',
        style: TextStyle(
          fontSize: 11,
          color: count > max ? context.k.bad : context.k.inkFaint,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, this.body, this.onReload});

  final String title;
  final String? body;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.k.badTint,
        borderRadius: BorderRadius.circular(KRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: context.k.bad),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.k.bad,
                  ),
                ),
              ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(body!, style: const TextStyle(fontSize: 12)),
          ],
          if (onReload != null) ...[
            const SizedBox(height: 8),
            KButton(
              label: context.l10n?.commonReload ?? 'Tải lại',
              secondary: true,
              onPressed: onReload,
            ),
          ],
        ],
      ),
    );
  }
}
