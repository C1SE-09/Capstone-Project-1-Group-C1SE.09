// frontend/lib/presentation/recording/pages/report_processing_screen.dart
// ============================================================================
// ReportProcessingScreen – "Đang xử lý báo cáo"
//
// Hiển thị 4 bước xử lý theo thứ tự:
//   1. Đã nhận bản ghi âm       ← completed (check xanh)
//   2. Đang chuyển giọng nói thành văn bản ← in-progress (spinner xanh)
//   3. Đang phân tích nội dung  ← pending (circle xám)
//   4. Đang tạo báo cáo         ← pending (circle xám)
//
// Sau khi xong → tự động chuyển sang ExtractionResultsScreen
// ============================================================================

import 'dart:async';

import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/extraction_results_screen.dart';
import 'package:flutter/material.dart';

class ReportProcessingScreen extends StatefulWidget {
  const ReportProcessingScreen({
    super.key,
    required this.child,
    required this.transcript,
    this.voiceId,
    this.teacherId,
    this.classId,
  });

  final Child child;
  final String transcript;
  final String? voiceId;
  final String? teacherId;
  final String? classId;

  @override
  State<ReportProcessingScreen> createState() => _ReportProcessingScreenState();
}

class _ReportProcessingScreenState extends State<ReportProcessingScreen>
    with TickerProviderStateMixin {
  // ─── Processing state ────────────────────────────────────────────────────
  int _completedSteps = 1; // Step 0 (received) là done ngay
  int _currentStep = 1; // Step 1 đang processing

  late AnimationController _spinnerController;
  Timer? _simulationTimer;

  // ─── Constants ───────────────────────────────────────────────────────────
  static const _kPrimary = Color(0xFF0D5C4D);
  static const _kBackground = Color(0xFFF9F8F3);
  static const _kSurface = Colors.white;
  static const _kTextPrimary = Color(0xFF1E2522);
  static const _kTextSecondary = Color(0xFF757B77);
  static const _kTextGreen = Color(0xFF1B6E60);
  static const _kBorder = Color(0xFFDCE1DE);

  static const _steps = <String>[
    'Đang phân tích nội dung',
    'Đang tạo báo cáo',
  ];

  // Thời gian (ms) cho mỗi bước giả lập
  static const _stepDurations = <int>[0, 2500, 2000, 1500];

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Bắt đầu giả lập tiến trình
    _runSimulation();
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // ─── Simulation logic ────────────────────────────────────────────────────

  Future<void> _runSimulation() async {
    // Bước 1 → 2 → 3
    for (int step = 1; step <= 3; step++) {
      await Future.delayed(Duration(milliseconds: _stepDurations[step]));
      if (!mounted) return;
      setState(() {
        _completedSteps = step + 1;
        _currentStep = step + 1;
      });
    }

    // Tất cả bước xong → chuyển màn hình
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _navigateToExtraction();
  }

  void _navigateToExtraction() {
    final effectiveTeacherId =
        (widget.teacherId != null && widget.teacherId!.isNotEmpty)
            ? widget.teacherId!
            : 'bbbbbbbb-0000-0000-0000-000000000001';

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ExtractionResultsScreen(
          voiceId: widget.voiceId ?? 'voice-001',
          teacherId: effectiveTeacherId,
          childId: widget.child.childId,
          childName: widget.child.fullName,
          childInitials: _initials(widget.child.fullName),
          initialMeals: 'Ăn hết suất, ăn tốt',
          initialSleeping: '2 tiếng, ngủ ngon',
          initialHealth: 'Bình thường',
          initialActivities: 'Chơi ngoan với các bạn trong giờ hoạt động nhóm',
          initialMood: 'Vui vẻ',
          initialNotes: 'Bé chơi ngoan, hòa nhập tốt với các bạn.',
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _buildChildCard(formattedDate),
                    const SizedBox(height: 24),
                    _buildStepsList(),
                  ],
                ),
              ),
            ),
            _buildBottomNotice(),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                size: 28, color: _kTextPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          const Text(
            'Đang xử lý báo cáo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _kTextPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Child Info Card ─────────────────────────────────────────────────────

  Widget _buildChildCard(String formattedDate) {
    final initials = _initials(widget.child.fullName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE2EFE9),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _kTextGreen,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.child.fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Lớp Mầm 1 · $formattedDate',
                style: const TextStyle(fontSize: 13, color: _kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Steps List ──────────────────────────────────────────────────────────

  Widget _buildStepsList() {
    return Column(
      children: List.generate(_steps.length, (i) {
        final isDone = i < _completedSteps - 1;
        final isActive = i == _currentStep - 1 && !isDone;
        final isPending = i > _currentStep - 1;

        return _buildStepRow(
          label: _steps[i],
          isDone: isDone,
          isActive: isActive,
          isPending: isPending,
          isLast: i == _steps.length - 1,
        );
      }),
    );
  }

  Widget _buildStepRow({
    required String label,
    required bool isDone,
    required bool isActive,
    required bool isPending,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon + vertical line column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                _buildStepIcon(isDone: isDone, isActive: isActive),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone
                          ? _kPrimary.withAlpha((0.4 * 255).round())
                          : const Color(0xFFDCE1DE),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Label
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isPending
                      ? const Color(0xFFB0B6B3)
                      : isDone
                          ? _kTextSecondary
                          : _kTextPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon({required bool isDone, required bool isActive}) {
    if (isDone) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: _kPrimary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 17),
      );
    }

    if (isActive) {
      return SizedBox(
        width: 28,
        height: 28,
        child: RotationTransition(
          turns: _spinnerController,
          child: CustomPaint(
            painter: _SpinnerArcPainter(color: _kPrimary),
          ),
        ),
      );
    }

    // Pending
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB0B6B3), width: 2),
      ),
    );
  }

  // ─── Bottom Notice ───────────────────────────────────────────────────────

  Widget _buildBottomNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_tethering_rounded,
              color: _kTextGreen, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Bạn có thể rời màn hình này. Chúng tôi sẽ thông báo khi báo cáo sẵn sàng.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF47544C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Utils ───────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ─── Custom Spinner Painter ───────────────────────────────────────────────────

class _SpinnerArcPainter extends CustomPainter {
  const _SpinnerArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((0.2 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - paint.strokeWidth) / 2;

    // Background circle
    canvas.drawCircle(center, radius, paint);

    // Active arc
    paint.color = color;
    const sweepAngle = 3.14159 * 1.2; // ~216°
    const startAngle = -3.14159 / 2; // top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerArcPainter oldDelegate) =>
      oldDelegate.color != color;
}
