import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
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
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.canvas,
      appBar: KAppBar(
        title: 'Đổi mật khẩu',
        subtitle: 'Bảo vệ tài khoản KinderLog',
        onBack: widget.onBack ?? (Navigator.canPop(context) ? () => Navigator.pop(context) : null),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: KColors.brandTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: KColors.brand,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cập nhật mật khẩu',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: KColors.ink,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Vui lòng nhập mật khẩu hiện tại và mật khẩu mới.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: KColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: KColors.badTint,
                      borderRadius: BorderRadius.circular(KRadii.control),
                      border: Border.all(color: KColors.bad.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: KColors.bad, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: KColors.bad,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. Mật khẩu hiện tại
                const Text(
                  'Mật khẩu hiện tại',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KColors.ink,
                  ),
                ),
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
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu đang sử dụng',
                    prefixIcon: const Icon(Icons.lock_outline,
                        size: 20, color: KColors.inkFaint),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: KColors.inkFaint,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Mật khẩu mới
                const Text(
                  'Mật khẩu mới',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KColors.ink,
                  ),
                ),
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
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu mới (tối thiểu 6 ký tự)',
                    prefixIcon: const Icon(Icons.key_outlined,
                        size: 20, color: KColors.inkFaint),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: KColors.inkFaint,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Xác nhận mật khẩu mới
                const Text(
                  'Xác nhận mật khẩu mới',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu mới.';
                    }
                    if (val != _newPasswordController.text) {
                      return 'Mật khẩu xác nhận không khớp.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Nhập lại mật khẩu mới',
                    prefixIcon: const Icon(Icons.check_circle_outline,
                        size: 20, color: KColors.inkFaint),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: KColors.inkFaint,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Nút Đổi mật khẩu
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : KButton(
                        label: 'Đổi mật khẩu',
                        icon: Icons.save_outlined,
                        large: true,
                        onPressed: _submit,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công!'),
          backgroundColor: KColors.ok,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Có lỗi xảy ra: $e');
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
                  fontSize: 12.5,
                  color: KColors.bad,
                  fontWeight: FontWeight.w500,
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
              if (val != _newPasswordController.text) return 'Mật khẩu xác nhận không khớp.';
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
          const SizedBox(height: 20),

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
