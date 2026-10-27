import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/ui_types.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/class_info_adapter.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/screens/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    this.authRepository,
    this.onForgotPassword,
  });

  final ValueChanged<UserRole> onLogin;
  final AuthRepository? authRepository;
  final VoidCallback? onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _authRepository = widget.authRepository ?? AuthRepository();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _loadingCredentials = true;
  bool _rememberAccount = true;
  String? _errorMessage;
  String? _rememberError;

  bool get _busy => _isLoading || _loadingCredentials;

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  Future<void> _loadRememberedLogin() async {
    try {
      final saved = await _authRepository.readRememberedLogin();
      if (!mounted) return;
      if (saved != null) {
        _usernameController.text = saved.username;
        _passwordController.text = saved.password;
        _rememberAccount = true;
      }
    } catch (_) {
      if (mounted) {
        _rememberError = 'Không thể đọc thông tin đã nhớ. Bạn vẫn có thể đăng nhập.';
      }
    } finally {
      if (mounted) setState(() => _loadingCredentials = false);
    }
  }

  Future<void> _setRememberAccount(bool? value) async {
    if (_busy) return;
    final enabled = value ?? false;
    setState(() {
      _rememberAccount = enabled;
      _rememberError = null;
      _loadingCredentials = !enabled;
    });
    if (enabled) return;
    try {
      await _authRepository.clearRememberedLogin();
    } catch (_) {
      if (mounted) {
        setState(() {
          _rememberAccount = true;
          _rememberError = 'Chưa xóa được thông tin đã nhớ. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingCredentials = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_busy) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ tên đăng nhập/Gmail và mật khẩu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authRepository.login(
        username: username,
        password: password,
      );
      if (!mounted) return;
      try {
        if (_rememberAccount) {
          await _authRepository.saveRememberedLogin(
            username: username,
            password: password,
          );
        } else {
          await _authRepository.clearRememberedLogin();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Đã đăng nhập nhưng chưa lưu được lựa chọn ghi nhớ. '
                'Hãy thử lại trên thiết bị này; bản web cần HTTPS hoặc localhost.'),
          ));
        }
      }
      if (!mounted) return;
      final rawRole = user.role.toLowerCase();
      final UserRole role;
      if (rawRole == 'admin') {
        role = UserRole.admin;
      } else if (rawRole == 'parent') {
        role = UserRole.parent;
      } else {
        role = UserRole.teacher;
      }
      if (role == UserRole.parent || role == UserRole.teacher) {
        // Giáo viên cũng nhận push nhắc hoàn thành điểm danh.
        PushNotificationService.instance.registerCurrentDevice();
      }
      widget.onLogin(role);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AuthException ? e.message : 'Đăng nhập không thành công. Quý phụ huynh và thầy cô vui lòng kiểm tra lại kết nối mạng hoặc thử lại sau.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo & Title
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.k.brand, context.k.brand.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: context.k.brand.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'KinderLog',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Hệ thống sổ liên lạc & báo cáo mầm non',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.k.inkSoft,
                          ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Login Form Card
                  KCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Đăng nhập',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập thông tin tài khoản của bạn để tiếp tục',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.k.inkSoft,
                              ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner if any
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.k.badTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.k.bad.withValues(alpha: .35)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 20, color: context.k.bad),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.k.ink,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Username / Gmail Field
                        Text(
                          'Tên đăng nhập hoặc Gmail',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _usernameController,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            hintText: 'Nhập tên đăng nhập hoặc Gmail',
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            filled: true,
                            fillColor: context.k.surfaceSunken,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.k.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.k.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.k.brand, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 18),

                        // Password Field
                        Text(
                          'Mật khẩu',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          enabled: !_busy,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Nhập mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: context.k.surfaceSunken,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.k.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.k.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.k.brand, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 8),

                        CheckboxListTile(
                          value: _rememberAccount,
                          onChanged: _busy ? null : _setRememberAccount,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Lưu mật khẩu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text(
                            'Tự động điền tài khoản & mật khẩu cho lần sau',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_rememberError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(_rememberError!,
                                style: TextStyle(fontSize: 12, color: context.k.bad)),
                          ),

                        // Forgot password button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : () {
                              if (widget.onForgotPassword != null) {
                                widget.onForgotPassword!();
                              } else {
                                context.push('/forgot-password');
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                color: KColors.brand,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login Action Button (ĐĂNG NHẬP)
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.k.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('ĐĂNG NHẬP'),
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
      ),
    );
  }
}

class ClassSelectScreen extends StatefulWidget {
  const ClassSelectScreen({super.key, required this.onPick, this.repository});
  final ValueChanged<String> onPick;
  final HttpDashboardRepository? repository;
  @override
  State<ClassSelectScreen> createState() => _ClassSelectScreenState();
}

class _ClassSelectScreenState extends State<ClassSelectScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late Future<List<ClassReportOverview>> classesFuture;
  @override
  void initState() {
    super.initState();
    classesFuture = repository.getTeacherClasses();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chọn lớp', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Chọn lớp bạn muốn ghi nhận hôm nay.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.k.inkSoft),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<ClassReportOverview>>(
                future: classesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Không tải được danh sách lớp.'),
                          TextButton(
                            onPressed: () => setState(() => classesFuture = repository.getTeacherClasses()),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    );
                  }
                  final classes = (snapshot.data ?? []).map((item) => uiClassInfoFromOverview(item)).toList();
                  if (classes.isEmpty) return const Center(child: Text('Chưa có lớp được phân công.'));
                  return ListView(
                    children: classes
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: KCard(
                              onTap: () => widget.onPick(item.id),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: context.k.brandTint,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.groups_outlined, color: context.k.brand),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Lớp ${item.name}',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                                        Text(item.school,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.k.inkSoft)),
                                        Text('${item.count} trẻ · ${item.role}',
                                            style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: context.k.inkFaint),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      );
}
