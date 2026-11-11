// frontend/lib/features/kindergarten_dashboard/widgets/parent_profile_sheet.dart
// ==============================================================================
// Sheet chỉnh sửa thông tin liên hệ của phụ huynh (SĐT, Email, Mối quan hệ).

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

const kRelationshipOptions = ['Bố', 'Mẹ', 'Ông', 'Bà', 'Người giám hộ'];

bool isValidParentPhone(String value) =>
    RegExp(r'^0\d{9}$').hasMatch(value.trim());

bool isValidParentEmail(String value) {
  final v = value.trim();
  if (v.isEmpty) return true;
  return RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z0-9]{2,}$').hasMatch(v);
}

Future<void> showParentProfileSheet(
  BuildContext context, {
  required Parent parent,
  required void Function(String phone, String? email, String? relationship)
      onSaved,
  HttpDashboardRepository? repository,
}) {
  return showKSheet(
    context,
    ParentProfileForm(parent: parent, repository: repository, onSaved: onSaved),
  );
}

Future<void> showParentProfileEditScreen(
  BuildContext context, {
  required Parent parent,
  required String childName,
  required void Function(String phone, String? email, String? relationship)
      onSaved,
  HttpDashboardRepository? repository,
}) {
  return Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => GardenVoiceScope(
      child: ParentProfileForm(
        parent: parent,
        childName: childName,
        fullScreen: true,
        repository: repository,
        onSaved: onSaved,
      ),
    ),
  ));
}

class ParentProfileForm extends StatefulWidget {
  const ParentProfileForm({
    super.key,
    required this.parent,
    required this.onSaved,
    this.repository,
    this.childName = '',
    this.fullScreen = false,
  });

  final Parent parent;
  final void Function(String phone, String? email, String? relationship)
      onSaved;
  final HttpDashboardRepository? repository;
  final String childName;
  final bool fullScreen;

  @override
  State<ParentProfileForm> createState() => _ParentProfileFormState();
}

class _ParentProfileFormState extends State<ParentProfileForm> {
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.parent.phone ?? '');
  late final TextEditingController _emailController =
      TextEditingController(text: widget.parent.email ?? '');
  late String? _relationship = widget.parent.relationship?.trim();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_relationship != null &&
        !kRelationshipOptions.contains(_relationship)) {
      _relationship = null;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (!isValidParentPhone(phone)) return;
    if (!isValidParentEmail(email)) {
      setState(() => _error = 'Email không hợp lệ. Vui lòng kiểm tra lại.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository?.updateParentProfile(
        widget.parent.parentId,
        phone: phone,
        email: email.isEmpty ? null : email,
        relationship: _relationship,
      );
      if (!mounted) return;
      widget.onSaved(phone, email.isEmpty ? null : email, _relationship);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin phụ huynh')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getFriendlyErrorMessage(
          error,
          fallback: 'Không lưu được thông tin, vui lòng thử lại.',
        );
      });
    }
  }

  Future<void> _selectRelationship() async {
    final relationship =
        await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => GardenVoiceScope(
        child: _ParentRelationshipScreen(
          childName: widget.childName,
          selected: _relationship,
        ),
      ),
    ));
    if (relationship != null && mounted) {
      setState(() => _relationship = relationship);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validPhone = isValidParentPhone(_phoneController.text);
    final validEmail = isValidParentEmail(_emailController.text);
    final canSave = validPhone && validEmail && !_saving;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.fullScreen) ...[
          Text('Chỉnh sửa thông tin',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _phoneController,
          key: const ValueKey('parent-profile-phone'),
          keyboardType: TextInputType.phone,
          autofocus: !widget.fullScreen,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Số điện thoại *',
            helperText: '10 chữ số, bắt đầu bằng 0',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          key: const ValueKey('parent-profile-email'),
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Email',
            helperText: 'vd: phuhuynh@gmail.com',
          ),
        ),
        const SizedBox(height: 12),
        if (widget.fullScreen)
          Semantics(
            button: true,
            child: InkWell(
              key: const ValueKey('parent-profile-relationship'),
              onTap: _selectRelationship,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Quan hệ với bé'),
                child: Row(
                  children: [
                    Expanded(child: Text(_relationship ?? 'Chọn quan hệ')),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _relationship,
            decoration: const InputDecoration(labelText: 'Quan hệ với bé'),
            items: kRelationshipOptions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) => setState(() => _relationship = val),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 13, color: context.k.bad)),
        ],
      ],
    );

    if (!widget.fullScreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          form,
          const SizedBox(height: 20),
          KButton(
              label: _saving ? 'Đang lưu…' : 'Lưu thay đổi',
              onPressed: canSave ? _save : null),
        ],
      );
    }

    return Scaffold(
      backgroundColor: context.k.canvas,
      appBar: KAppBar(
        title: 'Sửa thông tin liên hệ',
        onBack: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Text('Cập nhật thông tin để nhà trường liên lạc khi cần.',
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: context.k.inkSoft)),
            const SizedBox(height: 18),
            form,
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KButton(
                  label: _saving ? 'Đang lưu…' : 'Lưu thay đổi',
                  onPressed: canSave ? _save : null),
              const SizedBox(height: 12),
              KButton(
                  label: 'Hủy',
                  secondary: true,
                  onPressed: () => Navigator.maybePop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParentRelationshipScreen extends StatelessWidget {
  const _ParentRelationshipScreen({required this.childName, this.selected});

  final String childName;
  final String? selected;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.k.canvas,
        appBar: KAppBar(
            title: 'Quan hệ với bé', onBack: () => Navigator.maybePop(context)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text('Chọn mối quan hệ của bạn với $childName.',
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: context.k.inkSoft)),
            const SizedBox(height: 14),
            for (final relationship in kRelationshipOptions) ...[
              KCard(
                onTap: () => Navigator.pop(context, relationship),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(relationship)),
                    if (relationship == selected)
                      Icon(Icons.check_circle, color: context.k.brand)
                    else
                      Icon(Icons.circle_outlined, color: context.k.lineStrong),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
}
