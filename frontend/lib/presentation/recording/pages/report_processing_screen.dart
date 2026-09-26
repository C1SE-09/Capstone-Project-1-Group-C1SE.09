// ============================================================================
// ReportProcessingScreen – "Đang xử lý báo cáo"
//
// 2 Giai đoạn (ProcessingPhase):
//   1. Phase 1 (transcribe): Sau khi nhấn "Lưu bản ghi" từ Màn hình ghi âm:
//      - Step 0: ✓ Đã nhận bản ghi âm
//      - Step 1: ⟳ Đang chuyển giọng nói thành văn bản (Status Polling API)
//      -> Khi xong → tự động chuyển sang TranscriptReviewScreen (Màn hình 3).
//
//   2. Phase 2 (extract): Sau khi nhấn "Tiếp tục" từ TranscriptReviewScreen:
//      - Step 0: ✓ Đã nhận bản ghi âm
//      - Step 1: ✓ Đang chuyển giọng nói thành văn bản
//      - Step 2: ⟳ Đang phân tích nội dung (AI Extraction API)
//      - Step 3: ⟳ Đang tạo báo cáo (Draft Report API)
//      -> Khi xong → tự động chuyển sang ExtractionResultsScreen (Màn hình 4 kết quả).
// ============================================================================

import 'dart:async';

import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/extraction_results_screen.dart';
import 'package:adark_frontend/presentation/recording/pages/transcript_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum ProcessingPhase { transcribe, extract }

class ReportProcessingScreen extends StatefulWidget {
  const ReportProcessingScreen({
    super.key,
    required this.child,
    this.phase = ProcessingPhase.transcribe,
    this.transcript = '',
    this.audioFilePath,
    this.audioDuration = 18,
    this.voiceId,
    this.teacherId,
    this.classId,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  final Child child;
  final ProcessingPhase phase;
  final String transcript;
  final String? audioFilePath;
  final int audioDuration;
  final String? voiceId;
  final String? teacherId;
  final String? classId;
  final TeacherRepositoryBase? _repository;

  @override
  State<ReportProcessingScreen> createState() => _ReportProcessingScreenState();
}

class _ReportProcessingScreenState extends State<ReportProcessingScreen>
    with TickerProviderStateMixin {
  late final TeacherRepositoryBase _repo;

  // ─── Processing state ────────────────────────────────────────────────────
  late int _completedSteps;
  bool _hasError = false;
  String? _errorMessage;

  late AnimationController _spinnerController;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 200; // Max 200 attempts * 3s = 600s timeout

  // ─── Constants ───────────────────────────────────────────────────────────
  static const _kPrimary = Color(0xFF0D5C4D);
  static const _kBackground = Color(0xFFF9F8F3);
  static const _kSurface = Colors.white;
  static const _kTextPrimary = Color(0xFF1E2522);
  static const _kTextSecondary = Color(0xFF757B77);
  static const _kTextGreen = Color(0xFF1B6E60);
  static const _kBorder = Color(0xFFDCE1DE);

  List<String> _steps = [];

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? TeacherRepository();

    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _startPipeline();
  }

  void _initSteps(AppLocalizations l10n) {
    _steps = [
      l10n.stepReceived,
      l10n.stepTranscribing,
      l10n.stepAnalyzing,
      l10n.stepCreating,
    ];
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ─── Main Pipeline ───────────────────────────────────────────────────────

  Future<void> _startPipeline() async {
    _pollingTimer?.cancel();
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _pollAttempts = 0;
      if (widget.phase == ProcessingPhase.transcribe) {
        _completedSteps = 1; // Step 0 (Đã nhận bản ghi âm) done; Step 1 active
      } else {
        _completedSteps = 2; // Step 0,1 done; Step 2 active (Đang phân tích)
      }
    });

    if (widget.phase == ProcessingPhase.transcribe) {
      await _runTranscribePhase();
    } else {
      await _runExtractPhase();
    }
  }

  // ─── Phase 1: Transcribe Phase (Ảnh 1 -> Ảnh 2 -> Ảnh 3) ─────────────────

  Future<void> _runTranscribePhase() async {
    final voiceId = widget.voiceId;
    final teacherId = widget.teacherId ?? 'bbbbbbbb-0000-0000-0000-000000000001';

    // Simulation / Fast fallback if mock voiceId or no voiceId
    if (voiceId == null || voiceId.isEmpty || voiceId == 'voice-001') {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      setState(() {
        _completedSteps = 2;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _navigateToReview(
        transcript: widget.transcript.isNotEmpty
            ? widget.transcript
            : 'Hôm nay bé ${widget.child.displayName} ăn hết suất, ngủ khoảng 2 tiếng, sức khỏe bình thường và chơi ngoan với các bạn trong giờ hoạt động nhóm.',
        voiceId: 'voice-001',
      );
      return;
    }

    // Real Status Polling (Task #92 & Task #93 requirement: poll every 3 seconds)
    final record = await _pollVoiceStatus(voiceId: voiceId, teacherId: teacherId);
    if (record == null || !mounted) return;

    // Step 1 Completed -> Mark Step 1 Done ✓
    setState(() {
      _completedSteps = 2;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    _navigateToReview(
      transcript: record.effectiveTranscript,
      voiceId: record.id,
    );
  }

  Future<VoiceRecord?> _pollVoiceStatus({required String voiceId, required String teacherId}) async {
    final l10n = AppLocalizations.of(context)!;
    final completer = Completer<VoiceRecord?>();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      _pollAttempts++;

      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = l10n.processingTimeout;
          });
        }
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      try {
        final record = await _repo.getVoiceRecord(voiceId: voiceId, teacherId: teacherId);
        if (!mounted) return;

        if (record.status == 'completed') {
          timer.cancel();
          if (!completer.isCompleted) completer.complete(record);
        } else if (record.status == 'failed') {
          timer.cancel();
          setState(() {
            _hasError = true;
            _errorMessage = record.errorMessage ?? l10n.transcriptionFailed;
          });
          if (!completer.isCompleted) completer.complete(null);
        }
      } catch (e) {
        if (_pollAttempts >= _maxPollAttempts) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = l10n.connectionError(e.toString());
            });
          }
          if (!completer.isCompleted) completer.complete(null);
        }
      }
    });

    return completer.future;
  }

  void _navigateToReview({required String transcript, required String voiceId}) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => TranscriptReviewScreen(
          child: widget.child,
          transcript: transcript,
          audioDuration: widget.audioDuration,
          audioFilePath: widget.audioFilePath,
          voiceId: voiceId,
          teacherId: widget.teacherId,
          classId: widget.classId,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ─── Phase 2: Extract & Draft Phase (Ảnh 3 -> Ảnh 4 -> Results) ──────────

  Future<void> _runExtractPhase() async {
    final voiceId = widget.voiceId ?? 'voice-001';
    final teacherId = widget.teacherId ?? 'bbbbbbbb-0000-0000-0000-000000000001';

    // 1. Step 2 (Đang phân tích nội dung với mô hình NLP AI)
    ExtractionData? extraction;
    if (voiceId != 'voice-001' && voiceId != 'manual-report') {
      try {
        if (widget.transcript.isNotEmpty) {
          extraction = await _repo.analyzeTranscript(
            voiceId: voiceId,
            teacherId: teacherId,
            editedTranscript: widget.transcript,
          );
        } else {
          extraction = await _repo.extractVoice(
            voiceId: voiceId,
            teacherId: teacherId,
          );
        }
      } catch (e) {
        debugPrint('NLP Extraction failed: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Step 2 Done → Move to Step 3 (Đang tạo báo cáo)
    setState(() {
      _completedSteps = 3;
    });

    // 2. Step 3 (Đang tạo báo cáo)
    if (voiceId != 'voice-001' && voiceId != 'manual-report') {
      try {
        await _repo.createDraftReport(
          voiceId: voiceId,
          teacherId: teacherId,
          editedExtraction: extraction,
        );
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() {
      _completedSteps = 4;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    _navigateToExtractionResults(extraction: extraction);
  }

  void _navigateToExtractionResults({ExtractionData? extraction}) {
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
          initialMeals: extraction?.meals,
          initialSleeping: extraction?.sleeping,
          initialHealth: extraction?.health,
          initialActivities: extraction?.activities,
          initialMood: extraction?.mood,
          initialNotes: null,
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
    final l10n = AppLocalizations.of(context)!;
    _initSteps(l10n);

    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _buildChildCard(formattedDate, l10n),
                    const SizedBox(height: 24),
                    _buildStepsList(l10n),
                    if (_hasError) ...[
                      const SizedBox(height: 20),
                      _buildErrorCard(l10n),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomNotice(l10n),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
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
          Text(
            l10n.processing,
            style: const TextStyle(
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

  Widget _buildChildCard(String formattedDate, AppLocalizations l10n) {
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
                '${l10n.className} Mầm 1 · $formattedDate',
                style: const TextStyle(fontSize: 13, color: _kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Steps List ──────────────────────────────────────────────────────────

  Widget _buildStepsList(AppLocalizations l10n) {
    return Column(
      children: List.generate(_steps.length, (i) {
        final isDone = i < _completedSteps;
        final isActive = !_hasError && i == _completedSteps;
        final isPending = i > _completedSteps;

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

  // ─── Error Card ──────────────────────────────────────────────────────────

  Widget _buildErrorCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage ?? l10n.errorGeneric,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _startPipeline,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Notice ───────────────────────────────────────────────────────

  Widget _buildBottomNotice(AppLocalizations l10n) {
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
          Expanded(
            child: Text(
              l10n.canLeaveScreen,
              style: const TextStyle(
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
