import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

/// Màn hình Đổi mật khẩu dành cho người dùng đã đăng nhập (Giáo viên / Phụ huynh).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.onSuccess,
    this.onBack,
    this.authRepository,
  });

  final VoidCallback? onSuccess;
  final VoidCallback? onBack;
  final AuthRepository? authRepository;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  final bool _logoutOtherDevices = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không trùng khớp.');
      return;
    }

    if (currentPass == newPass) {
      setState(() =>
          _errorMessage = 'Mật khẩu mới không được trùng với mật khẩu hiện tại.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepository.changePassword(
        currentPassword: currentPass,
        newPassword: newPass,
        logoutOtherDevices: _logoutOtherDevices,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công!'),
          backgroundColor: KColors.ok,
        ),
      );

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else if (widget.onBack != null) {
        widget.onBack!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = getFriendlyErrorMessage(
        e,
        fallback: 'Không thể đổi mật khẩu vào lúc này. Quý phụ huynh và thầy cô vui lòng thử lại sau ít phút.',
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          final normalBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: k.line),
          );
          return Scaffold(
            backgroundColor: k.canvas,
            appBar: KAppBar(
              title: 'Đổi mật khẩu',
              subtitle: 'Bảo vệ tài khoản KinderLog',
              onBack: widget.onBack ??
                  (Navigator.canPop(context) ? () => Navigator.pop(context) : null),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: k.badTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: k.badText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      _passwordLabel('Mật khẩu hiện tại', k),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại.';
                          }
                          return null;
                        },
                        style: TextStyle(color: k.ink, fontSize: 14),
                        decoration: _passwordDecoration(
                          k: k,
                          border: normalBorder,
                          obscure: _obscureCurrent,
                          onToggle: () => setState(
                              () => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _passwordLabel('Mật khẩu mới', k),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu mới.';
                          }
                          if (val.length < 6) {
                            return 'Mật khẩu mới phải có tối thiểu 6 ký tự.';
                          }
                          return null;
                        },
                        style: TextStyle(color: k.ink, fontSize: 14),
                        decoration: _passwordDecoration(
                          k: k,
                          border: normalBorder,
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _passwordLabel('Xác nhận mật khẩu mới', k),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng xác nhận mật khẩu mới.';
                          }
                          if (val != _newPasswordController.text) {
                            return 'Mật khẩu xác nhận không trùng khớp.';
                          }
                          return null;
                        },
                        style: TextStyle(color: k.ink, fontSize: 14),
                        decoration: _passwordDecoration(
                          k: k,
                          border: normalBorder,
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Yêu cầu mật khẩu mới',
                        style: TextStyle(
                          color: k.inkSoft,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        '· Tối thiểu 6 ký tự',
                        style: TextStyle(
                          color: k.inkSoft,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : KButton(
                                label: 'Đổi mật khẩu',
                                onPressed: _submit,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _passwordLabel(String label, KPalette palette) => Text(
        label,
        style: TextStyle(
          color: palette.ink,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      );

  InputDecoration _passwordDecoration({
    required KPalette k,
    required InputBorder border,
    required bool obscure,
    required VoidCallback onToggle,
  }) =>
      InputDecoration(
        filled: true,
        fillColor: k.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: k.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: k.bad),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: k.bad, width: 1.5),
        ),
        errorStyle: TextStyle(color: k.badText, fontSize: 12, height: 1.4),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: k.inkSoft,
          ),
        ),
      );
}

/// Helper function hiển thị Modal Bottom Sheet Đổi mật khẩu
Future<void> showChangePasswordBottomSheet(
  BuildContext context, {
  AuthRepository? authRepository,
}) {
  return showKSheet(
    context,
    _ChangePasswordFormSheet(authRepository: authRepository),
  );
}

class _ChangePasswordFormSheet extends StatefulWidget {
  const _ChangePasswordFormSheet({this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<_ChangePasswordFormSheet> createState() =>
      __ChangePasswordFormSheetState();
}

class __ChangePasswordFormSheetState
    extends State<_ChangePasswordFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _logoutOtherDevices = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không trùng khớp.');
      return;
    }

    if (currentPass == newPass) {
      setState(() =>
          _errorMessage = 'Mật khẩu mới không được trùng với mật khẩu hiện tại.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepository.changePassword(
        currentPassword: currentPass,
        newPassword: newPass,
        logoutOtherDevices: _logoutOtherDevices,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công!'),
          backgroundColor: KColors.ok,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = getFriendlyErrorMessage(
        e,
        fallback: 'Không thể đổi mật khẩu vào lúc này. Quý phụ huynh và thầy cô vui lòng thử lại sau ít phút.',
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: KColors.brand, size: 24),
              const SizedBox(width: 10),
              Text(
                'Đổi mật khẩu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: KColors.badTint,
                borderRadius: BorderRadius.circular(KRadii.control),
                border: Border.all(color: KColors.bad.withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: KColors.bad,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            validator: (val) =>
                (val == null || val.trim().isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại.' : null,
            decoration: InputDecoration(
              labelText: 'Mật khẩu hiện tại',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Vui lòng nhập mật khẩu mới.';
              if (val.length < 6) return 'Mật khẩu mới phải từ 6 ký tự.';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              prefixIcon: const Icon(Icons.key_outlined, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Vui lòng xác nhận mật khẩu mới.';
              if (val != _newPasswordController.text) return 'Mật khẩu xác nhận không trùng khớp.';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Xác nhận mật khẩu mới',
              prefixIcon: const Icon(Icons.check_circle_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),

          CheckboxListTile(
            value: _logoutOtherDevices,
            onChanged: (value) =>
                setState(() => _logoutOtherDevices = value ?? true),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Đăng xuất các thiết bị khác',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Các máy khác sẽ phải đăng nhập lại.',
              style: TextStyle(fontSize: 11, color: KColors.inkFaint),
            ),
          ),
          const SizedBox(height: 8),

          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(
                      child: KButton(
                        label: 'Hủy',
                        secondary: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KButton(
                        label: 'Lưu thay đổi',
                        icon: Icons.check,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
