import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class ParentContactScreen extends StatefulWidget {
  const ParentContactScreen({
    super.key,
    required this.parent,
    required this.childName,
    required this.onEdit,
  });

  final Parent parent;
  final String childName;
  final void Function(
    void Function(String phone, String? email, String? relationship) onSaved,
  ) onEdit;

  @override
  State<ParentContactScreen> createState() => _ParentContactScreenState();
}

class _ParentContactScreenState extends State<ParentContactScreen> {
  late String? _phone = widget.parent.phone;
  late String? _email = widget.parent.email;
  late String? _relationship = widget.parent.relationship;

  void _edit() => widget.onEdit((phone, email, relationship) {
        setState(() {
          _phone = phone;
          _email = email;
          _relationship = relationship;
        });
      });

  String _maskedEmail(String? value) {
    final email = value?.trim() ?? '';
    final at = email.indexOf('@');
    return at < 0
        ? (email.isEmpty ? 'Chưa cập nhật' : email)
        : '${email.substring(0, at)}@…';
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone?.trim() ?? '';
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.k.canvas,
      appBar: KAppBar(
          title: l10n?.parentContactInfo ?? 'Thông tin liên hệ',
          onBack: () => Navigator.maybePop(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              l10n?.parentAccountChildPrefix(widget.childName) ?? 'Tài khoản phụ huynh của bé ${widget.childName}',
              style: TextStyle(
                  fontSize: 14, height: 1.4, color: context.k.inkSoft),
            ),
            const SizedBox(height: 14),
            _contactCard(context, l10n?.parentFullNameLabel ?? 'Họ và tên', widget.parent.fullName),
            const SizedBox(height: 14),
            Semantics(
              button: phoneCallUri(phone) != null,
              label: l10n?.parentCopyPhoneTooltip ?? 'Sao chép số điện thoại',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: phoneCallUri(phone) == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(l10n?.parentCopiedPhoneSnackbar ?? 'Đã sao chép số điện thoại')),
                        );
                      },
                child: _contactCard(
                  context,
                  l10n?.accountPhoneNumber ?? 'Số điện thoại',
                  phone.isEmpty ? (l10n?.commonNotUpdated ?? 'Chưa cập nhật') : maskedPhone(phone),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _contactCard(context, l10n?.accountEmail ?? 'Email', _maskedEmail(_email)),
            const SizedBox(height: 14),
            _contactCard(
              context,
              l10n?.parentRelationshipLabel ?? 'Quan hệ với bé',
              _relationship?.trim().isNotEmpty == true
                  ? _relationship!.trim()
                  : (l10n?.commonNotUpdated ?? 'Chưa cập nhật'),
            ),
            const SizedBox(height: 14),
            KButton(label: l10n?.parentEditInfo ?? 'Chỉnh sửa thông tin', onPressed: _edit),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, String label, String value) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: context.k.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: context.k.brand)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 16, height: 1.4, color: context.k.ink)),
          ],
        ),
      );
}

