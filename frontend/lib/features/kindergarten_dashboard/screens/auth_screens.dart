import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
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
      if (rawRole == 'admin') {
        await _authRepository.logout();
        await SessionManagementService.instance.clearSession();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Tài khoản Quản trị viên chỉ hỗ trợ trên phiên bản Web máy tính. Vui lòng truy cập cổng quản trị trên trình duyệt web.';
        });
        return;
      }
      final UserRole role = rawRole == 'parent' ? UserRole.parent : UserRole.teacher;
      PushNotificationService.instance.registerCurrentDevice();
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
    final baseTheme = Theme.of(context);
    final palette = KPalette.loginWarmSage;
    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: palette.brand,
          surface: palette.surface,
        ),
        scaffoldBackgroundColor: palette.surface,
        textTheme: baseTheme.textTheme.apply(
          fontFamily: 'Nunito',
          bodyColor: palette.ink,
          displayColor: palette.ink,
        ),
        extensions: [
          ...baseTheme.extensions.values.where((extension) => extension is! KPalette),
          palette,
        ],
      ),
      child: Builder(
        builder: (context) {
          final k = context.k;
          return Scaffold(
            backgroundColor: k.surface,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 342),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: k.brand,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'K',
                                style: TextStyle(
                                  color: k.canvas,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'KinderLog',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: k.ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        AspectRatio(
                          aspectRatio: 342 / 220,
                          child: Image.asset(
                            'assets/garden_voice/login_classroom.png',
                            key: const ValueKey('loginIllustration'),
                            width: double.infinity,
                            fit: BoxFit.contain,
                            semanticLabel:
                                'Cô và các bé cùng đọc sách trong lớp',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Chào mừng trở lại!',
                          style: TextStyle(
                            color: k.ink,
                            fontSize: 24,
                            height: 32 / 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cùng gia đình lưu giữ từng khoảnh khắc khôn lớn của bé.',
                          style: TextStyle(
                            color: k.inkSoft,
                            fontSize: 15,
                            height: 21 / 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          constraints: const BoxConstraints(minHeight: 58),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: k.surfaceSunken,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: k.inputBorder),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TÊN ĐĂNG NHẬP',
                                style: TextStyle(
                                  color: k.inkSoft,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextField(
                                  controller: _usernameController,
                                  enabled: !_busy,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  style: TextStyle(
                                    color: k.ink,
                                    fontSize: 14.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Nhập tên đăng nhập hoặc Gmail',
                                    hintStyle: TextStyle(
                                      color: k.inkFaint,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    isDense: true,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(minHeight: 58),
                          padding: const EdgeInsets.only(left: 16, right: 4),
                          decoration: BoxDecoration(
                            color: k.surfaceSunken,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: k.inputBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MẬT KHẨU',
                                        style: TextStyle(
                                          color: k.inkSoft,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextField(
                                        controller: _passwordController,
                                        enabled: !_busy,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) => _handleLogin(),
                                        style: TextStyle(
                                          color: k.ink,
                                          fontSize: 14.5,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Nhập mật khẩu',
                                          hintStyle: TextStyle(
                                            color: k.inkFaint,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          isDense: true,
                                          filled: false,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: _obscurePassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: k.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final remember = CheckboxListTile(
                              value: _rememberAccount,
                              onChanged: _busy ? null : _setRememberAccount,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Lưu mật khẩu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: k.inkSoft,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                            final forgot = TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (widget.onForgotPassword != null) {
                                        widget.onForgotPassword!();
                                      } else {
                                        context.push('/forgot-password');
                                      }
                                    },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: k.brand,
                              ),
                              child: Text(
                                'Quên mật khẩu?',
                                style: TextStyle(
                                  color: k.brand,
                                  fontFamily: 'Nunito',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                            if (MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
                                MediaQuery.sizeOf(context).width < 360) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  remember,
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: forgot,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: remember),
                                forgot,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_rememberError != null)
                          Semantics(
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _rememberError!,
                                style: TextStyle(
                                  color: k.bad,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        if (_errorMessage != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: k.badTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: k.bad, fontSize: 13),
                            ),
                          ),
                        ],
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: k.brand,
                              foregroundColor: k.canvas,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                                side: BorderSide(color: k.brandStrong),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: k.canvas,
                                    ),
                                  )
                                : Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      color: k.canvas,
                                      fontFamily: 'Nunito',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: k.reviewSurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Khám phá KinderLog',
                                style: TextStyle(
                                  color: k.inkSoft,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _LoginRolePill(label: 'Giáo viên'),
                                  SizedBox(width: 12),
                                  _LoginRolePill(label: 'Phụ huynh'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Kết nối lớp học · An tâm mỗi ngày',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: k.inkFaint,
                            fontSize: 11,
                            height: 18 / 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginRolePill extends StatelessWidget {
  const _LoginRolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: 116,
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: k.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
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
