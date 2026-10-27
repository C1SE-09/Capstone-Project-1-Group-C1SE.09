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

bool isValidParentPhone(String value) => RegExp(r'^0\d{9}$').hasMatch(value.trim());

bool isValidParentEmail(String value) {
  final v = value.trim();
  if (v.isEmpty) return true;
  return RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z0-9]{2,}$').hasMatch(v);
}

Future<void> showParentProfileSheet(
  BuildContext context, {
  required Parent parent,
  required void Function(String phone, String? email, String? relationship) onSaved,
  HttpDashboardRepository? repository,
}) {
  return showKSheet(
    context,
    ParentProfileForm(parent: parent, repository: repository, onSaved: onSaved),
  );
}

class ParentProfileForm extends StatefulWidget {
  const ParentProfileForm({super.key, required this.parent, required this.onSaved, this.repository});

  final Parent parent;
  final void Function(String phone, String? email, String? relationship) onSaved;
  final HttpDashboardRepository? repository;

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
    if (_relationship != null && !kRelationshipOptions.contains(_relationship)) {
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

  @override
  Widget build(BuildContext context) {
    final validPhone = isValidParentPhone(_phoneController.text);
    final validEmail = isValidParentEmail(_emailController.text);
    final canSave = validPhone && validEmail && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Chỉnh sửa thông tin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autofocus: true,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Số điện thoại *',
            helperText: '10 chữ số, bắt đầu bằng 0',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Email',
            helperText: 'vd: phuhuynh@gmail.com',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _relationship,
          decoration: const InputDecoration(
            labelText: 'Quan hệ với bé',
          ),
          items: kRelationshipOptions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (val) => setState(() => _relationship = val),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 13, color: context.k.bad)),
        ],
        const SizedBox(height: 20),
        KButton(
          label: _saving ? 'Đang lưu…' : 'Lưu thay đổi',
          onPressed: canSave ? _save : null,
        ),
      ],
    );
  }
}
