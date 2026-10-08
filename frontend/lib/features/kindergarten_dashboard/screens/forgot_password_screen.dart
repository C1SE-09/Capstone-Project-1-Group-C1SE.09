import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.authRepository,
    this.onBackToLogin,
  });

  final AuthRepository? authRepository;
  final VoidCallback? onBackToLogin;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final AuthRepository _authRepository = widget.authRepository ?? AuthRepository();

  int _currentStep = 0; // 0: Nhập email, 1: Nhập OTP, 2: Đặt mật khẩu mới

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  void _goBackToLogin() {
    if (widget.onBackToLogin != null) {
      widget.onBackToLogin!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/login');
    }
  }

  // --- Step 1: Gửi mã xác thực ---
  Future<void> _handleSendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Vui lòng nhập địa chỉ email hợp lệ.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final msg = await _authRepository.requestPasswordReset(email);
      if (!mounted) return;
      _startResendTimer();
      setState(() {
        _currentStep = 1;
        _infoMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AuthException ? e.message : 'Lỗi gửi yêu cầu: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 2: Xác nhận OTP ---
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ 6 chữ số mã xác thực.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await _authRepository.verifyResetCode(
        email: _emailController.text.trim(),
        resetCode: otp,
      );
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
        _infoMessage = 'Mã xác thực chính xác! Vui lòng tạo mật khẩu mới.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AuthException ? e.message : 'Xác thực thất bại: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Gửi lại mã OTP
  Future<void> _handleResendOtp() async {
    if (!_canResend || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final msg = await _authRepository.requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      _startResendTimer();
      setState(() {
        _infoMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AuthException ? e.message : 'Không thể gửi lại mã: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 3: Đặt lại mật khẩu mới ---
  Future<void> _handleResetPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      setState(() {
        _errorMessage = 'Mật khẩu mới phải có ít nhất 6 ký tự.';
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = 'Xác nhận mật khẩu không trùng khớp.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await _authRepository.resetPassword(
        email: _emailController.text.trim(),
        resetCode: _otpController.text.trim(),
        newPassword: newPass,
      );
      if (!mounted) return;

      // Hiển thị thông báo thành công
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.k.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: context.k.ok, size: 28),
              const SizedBox(width: 10),
              Text('Thành công', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: context.k.ink)),
            ],
          ),
          content: Text(
            'Mật khẩu của bạn đã được thay đổi thành công. Vui lòng đăng nhập với mật khẩu mới.',
            style: TextStyle(fontSize: 14, height: 1.4, color: context.k.inkSoft),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _goBackToLogin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.k.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('ĐĂNG NHẬP NGAY'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AuthException ? e.message : 'Đặt lại mật khẩu thất bại: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.k.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar: Quay lại
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _isLoading ? null : _goBackToLogin,
                      icon: Icon(Icons.arrow_back_rounded, color: context.k.inkSoft),
                      tooltip: 'Quay lại đăng nhập',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // App Brand Logo & Name
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.k.brand, context.k.brand.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: context.k.brand.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'KinderLog',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: context.k.ink,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stepper Progress Indicator
                  _buildStepperHeader(),
                  const SizedBox(height: 20),

                  // Main Card
                  KCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thông báo lỗi nếu có
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.k.badTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.k.bad.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, size: 18, color: context.k.bad),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.k.bad,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Thông báo thông tin nếu có
                        if (_infoMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.k.infoTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.k.info.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 18, color: context.k.info),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _infoMessage!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.k.info,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Nội dung từng bước
                        if (_currentStep == 0) _buildStepEmail(),
                        if (_currentStep == 1) _buildStepOtp(),
                        if (_currentStep == 2) _buildStepNewPassword(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nút Quay lại đăng nhập
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _goBackToLogin,
                      icon: Icon(Icons.arrow_back_rounded, size: 16, color: context.k.inkSoft),
                      label: Text(
                        'Quay lại màn hình đăng nhập',
                        style: TextStyle(
                          color: context.k.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Header 3 bước
  Widget _buildStepperHeader() {
    return Row(
      children: [
        _buildStepBadge(0, '1', 'Email'),
        _buildStepDivider(0),
        _buildStepBadge(1, '2', 'Xác thực'),
        _buildStepDivider(1),
        _buildStepBadge(2, '3', 'Mật khẩu'),
      ],
    );
  }

  Widget _buildStepBadge(int stepIndex, String number, String label) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? context.k.ok
                : (isActive ? context.k.brand : context.k.surfaceSunken),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone
                  ? context.k.ok
                  : (isActive ? context.k.brand : context.k.line),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : context.k.inkSoft,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? context.k.brand : context.k.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        color: isDone ? context.k.ok : context.k.line,
      ),
    );
  }

  // --- Step 0: Nhập email ---
  Widget _buildStepEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.k.brandTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.mail_outline_rounded, color: context.k.brand, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quên mật khẩu?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.k.ink,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Nhận mã xác thực qua email đã đăng ký',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.k.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Địa chỉ Email',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.k.ink,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: context.k.ink),
          onSubmitted: (_) => _handleSendEmail(),
          decoration: InputDecoration(
            hintText: 'vidu@gmail.com',
            hintStyle: TextStyle(color: context.k.inkFaint),
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20, color: context.k.inkSoft),
            filled: true,
            fillColor: context.k.surfaceSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.brand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('GỬI MÃ XÁC THỰC'),
          ),
        ),
      ],
    );
  }

  // --- Step 1: Nhập OTP ---
  Widget _buildStepOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.k.warnTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.pin_rounded, color: context.k.warn, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xác thực mã OTP',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.k.ink,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kiểm tra email ${_emailController.text}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.k.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Mã xác thực gồm 6 chữ số (Hiệu lực trong 5 phút)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.k.ink,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
            color: context.k.ink,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleVerifyOtp(),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(letterSpacing: 10, color: context.k.inkFaint),
            filled: true,
            fillColor: context.k.surfaceSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.brand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        // Countdown & Gửi lại mã
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                  _errorMessage = null;
                  _infoMessage = null;
                });
              },
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Đổi email khác',
                style: TextStyle(fontSize: 12, color: context.k.inkSoft),
              ),
            ),
            if (_canResend)
              TextButton(
                onPressed: _isLoading ? null : _handleResendOtp,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  'Gửi lại mã',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.k.brand,
                  ),
                ),
              )
            else
              Text(
                'Gửi lại sau ${_resendCountdown}s',
                style: TextStyle(fontSize: 12, color: context.k.inkSoft),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('XÁC NHẬN MÃ OTP'),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Mật khẩu mới ---
  Widget _buildStepNewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.k.okTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock_reset_rounded, color: context.k.ok, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đặt mật khẩu mới',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.k.ink,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mật khẩu mới tối thiểu 6 ký tự',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.k.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Mật khẩu mới',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.k.ink,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          style: TextStyle(color: context.k.ink),
          decoration: InputDecoration(
            hintText: 'Nhập mật khẩu mới',
            hintStyle: TextStyle(color: context.k.inkFaint),
            prefixIcon: Icon(Icons.lock_outline, size: 20, color: context.k.inkSoft),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: context.k.inkSoft,
              ),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            filled: true,
            fillColor: context.k.surfaceSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.brand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        Text(
          'Xác nhận mật khẩu mới',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.k.ink,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: context.k.ink),
          decoration: InputDecoration(
            hintText: 'Nhập lại mật khẩu mới',
            hintStyle: TextStyle(color: context.k.inkFaint),
            prefixIcon: Icon(Icons.lock_outline, size: 20, color: context.k.inkSoft),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: context.k.inkSoft,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            filled: true,
            fillColor: context.k.surfaceSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.k.brand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleResetPassword(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('CẬP NHẬT MẬT KHẨU'),
          ),
        ),
      ],
    );
  }
}
