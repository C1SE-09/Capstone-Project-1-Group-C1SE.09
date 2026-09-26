import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/presentation/recording/widgets/extraction_edit_view.dart';
import 'package:adark_frontend/presentation/recording/widgets/report_review_view.dart';
import 'package:adark_frontend/presentation/recording/widgets/report_sent_success_view.dart';
import 'package:adark_frontend/presentation/recording/widgets/send_report_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

enum ScreenStep { edit, review, success }

class ExtractionResultsScreen extends StatefulWidget {
  const ExtractionResultsScreen({
    super.key,
    required this.voiceId,
    required this.teacherId,
    this.childId,
    this.childName,
    this.childInitials,
    this.classTeacherInfo,
    this.initialStep = ScreenStep.edit,
    this.initialMeals,
    this.initialSleeping,
    this.initialHealth,
    this.initialActivities,
    this.initialMood,
    this.initialNotes,
    this.initialTranscript,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  final String voiceId;
  final String teacherId;
  final String? childId;
  final String? childName;
  final String? childInitials;
  final String? classTeacherInfo;
  final ScreenStep initialStep;
  final String? initialMeals;
  final String? initialSleeping;
  final String? initialHealth;
  final String? initialActivities;
  final String? initialMood;
  final String? initialNotes;
  final String? initialTranscript;
  final TeacherRepositoryBase? _repository;
  @override
  State<ExtractionResultsScreen> createState() => _ExtractionResultsScreenState();
}

class _ExtractionResultsScreenState extends State<ExtractionResultsScreen> {
  late final TeacherRepositoryBase _repo;
  ScreenStep _currentStep = ScreenStep.edit;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isReanalyzing = false;
  bool _hasAnalysis = false;
  String _analyzedTranscript = '';
  late final TextEditingController _transcriptController;
  late final TextEditingController _mealsController;
  late final TextEditingController _sleepingController;
  late final TextEditingController _healthController;
  late final TextEditingController _activitiesController;
  late final TextEditingController _moodController;
  late final TextEditingController _notesController;

  /// Transcript gốc do PhoWhisper trả về, dùng để phát hiện giáo viên có sửa.
  String _originalTranscript = '';

  String get _childName => (widget.childName != null && widget.childName!.isNotEmpty)
      ? widget.childName!
      : 'N/A';

  String get _childInitials {
    if (widget.childInitials != null && widget.childInitials!.isNotEmpty) {
      return widget.childInitials!;
    }
    if (widget.childName != null && widget.childName!.isNotEmpty) {
      final parts = widget.childName!.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.isEmpty) return '?';
      if (parts.length == 1) return parts.first[0].toUpperCase();
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    return '?';
  }

  String get _classTeacherInfo => (widget.classTeacherInfo != null && widget.classTeacherInfo!.isNotEmpty)
      ? widget.classTeacherInfo!
      : 'Lớp Mầm 1 · Cô Mai';
  String get _currentFormattedDate {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return '$day/$month/$year';
  }

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? TeacherRepository();
    _transcriptController = TextEditingController();
    _mealsController = TextEditingController();
    _sleepingController = TextEditingController();
    _healthController = TextEditingController();
    _activitiesController = TextEditingController();
    _moodController = TextEditingController();
    _notesController = TextEditingController();
    _fetchTranscript();
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _mealsController.dispose();
    _sleepingController.dispose();
    _healthController.dispose();
    _activitiesController.dispose();
    _moodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchTranscript() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    if (widget.initialMeals != null ||
        widget.initialSleeping != null ||
        widget.initialHealth != null ||
        widget.initialActivities != null ||
        widget.initialMood != null ||
        widget.initialNotes != null ||
        widget.voiceId == 'manual-report') {
      if (!mounted) return;
      setState(() {
        final seededTranscript = (widget.initialTranscript ?? '').trim();
        _transcriptController.text = seededTranscript;
        _originalTranscript = seededTranscript;
        _analyzedTranscript = seededTranscript;
        _mealsController.text = widget.initialMeals ?? '';
        _sleepingController.text = widget.initialSleeping ?? '';
        _healthController.text = widget.initialHealth ?? '';
        _activitiesController.text = widget.initialActivities ?? '';
        _moodController.text = widget.initialMood ?? '';
        _notesController.text = widget.initialNotes ?? '';
        _currentStep = widget.voiceId == 'manual-report'
            ? ScreenStep.review
            : widget.initialStep;
        _hasAnalysis = true;
        _isLoading = false;
      });
      return;
    }

    if (widget.voiceId == 'manual-report' ||
        widget.voiceId == 'voice-001' ||
        widget.voiceId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final record = await _repo.getVoiceRecord(
        voiceId: widget.voiceId,
        teacherId: widget.teacherId,
      );
      if (!mounted) return;
      setState(() {
        if (_transcriptController.text.trim().isEmpty) {
          _transcriptController.text = record.effectiveTranscript;
          _originalTranscript = record.effectiveTranscript;
        }
        _originalTranscript = record.effectiveTranscript;
        _analyzedTranscript = _transcriptController.text.trim();
        _mealsController.clear();
        _sleepingController.clear();
        _healthController.clear();
        _activitiesController.clear();
        _moodController.clear();
        _notesController.clear();
        _hasAnalysis = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cannotLoadTranscript(e.toString())),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      Future.delayed(const Duration(seconds: 2)).then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }



  /// Chỉ chạy model sau khi giáo viên đã kiểm tra/chỉnh transcript.
  Future<void> _analyzeTranscript() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isReanalyzing || _isSubmitting) return;
    final edited = _transcriptController.text.trim();
    if (edited.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.transcriptEmpty),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isReanalyzing = true);
    try {
      final effectiveTeacherId = widget.teacherId.isNotEmpty
          ? widget.teacherId
          : 'bbbbbbbb-0000-0000-0000-000000000001';

      final extraction = await _repo.analyzeTranscript(
        voiceId: widget.voiceId,
        teacherId: effectiveTeacherId,
        editedTranscript: edited,
      );

      if (!mounted) return;
      if (_transcriptController.text.trim() != edited) {
        setState(() => _isReanalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.transcriptChanged),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() {
        _originalTranscript = edited;
        _analyzedTranscript = edited;
        _mealsController.text = extraction.meals ?? '';
        _sleepingController.text = extraction.sleeping ?? '';
        _healthController.text = extraction.health ?? '';
        _activitiesController.text = extraction.activities ?? '';
        _moodController.text = extraction.mood ?? '';
        _hasAnalysis = true;
        _isReanalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.analyzeSuccess),
          backgroundColor: const Color(0xFF0D5C4D),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReanalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reanalyzeFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _goToReviewStep() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) return;
    if (_originalTranscript.isNotEmpty &&
        _transcriptController.text.trim() != _originalTranscript) {
      _originalTranscript = _transcriptController.text.trim();
    }
    _analyzedTranscript = _transcriptController.text.trim();
    setState(() => _isSubmitting = true);
    try {
      _hasAnalysis = true;
      final effectiveTeacherId =
          (widget.teacherId.isNotEmpty && widget.teacherId != 'null')
              ? widget.teacherId
              : 'bbbbbbbb-0000-0000-0000-000000000001';
      final effectiveChildId =
          (widget.childId != null && widget.childId!.isNotEmpty && widget.childId != 'null')
              ? widget.childId!
              : 'dddddddd-0000-0000-0000-000000000001';

      bool saved = false;

      if (widget.voiceId.isNotEmpty &&
          widget.voiceId != 'voice-001' &&
          widget.voiceId != 'manual-report') {
        try {
          await _repo.createDraftReport(
            voiceId: widget.voiceId,
            teacherId: effectiveTeacherId,
            childId: effectiveChildId,
            editedExtraction: ExtractionData(
              transcript: _transcriptController.text.trim(),
              meals: _mealsController.text.trim(),
              sleeping: _sleepingController.text.trim(),
              health: _healthController.text.trim(),
              activities: _activitiesController.text.trim(),
              mood: _moodController.text.trim(),
            ),
          ).timeout(const Duration(seconds: 4));
          saved = true;
        } catch (e) {
          debugPrint('createDraftReport error: $e');
        }
      }

      if (!saved) {
        try {
          await _repo.createManualReport(
            teacherId: effectiveTeacherId,
            childId: effectiveChildId,
            eating: _mealsController.text.trim().isNotEmpty ? _mealsController.text.trim() : null,
            sleeping: _sleepingController.text.trim().isNotEmpty ? _sleepingController.text.trim() : null,
            health: _healthController.text.trim().isNotEmpty ? _healthController.text.trim() : null,
            activities: _activitiesController.text.trim().isNotEmpty ? _activitiesController.text.trim() : null,
            mood: _moodController.text.trim().isNotEmpty ? _moodController.text.trim() : null,
            teacherNote: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          ).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('createManualReport error: $e');
        }
      }

      if (!mounted) return;
      setState(() { _isSubmitting = false; _currentStep = ScreenStep.review; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotCreateDraft(e.toString())), backgroundColor: Colors.red));
    }
  }

  void _openConfirmBottomSheet() {
    showSendReportConfirmSheet(context: context, childName: _childName, childInitials: _childInitials, formattedDate: _currentFormattedDate, onConfirmSend: _submitFinalReport);
  }

  Future<void> _submitFinalReport() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final effectiveTeacherId =
          (widget.teacherId.isNotEmpty && widget.teacherId != 'null')
              ? widget.teacherId
              : 'bbbbbbbb-0000-0000-0000-000000000001';
      final effectiveChildId =
          (widget.childId != null && widget.childId!.isNotEmpty && widget.childId != 'null')
              ? widget.childId!
              : 'dddddddd-0000-0000-0000-000000000001';

      bool saved = false;

      if (widget.voiceId.isNotEmpty &&
          widget.voiceId != 'voice-001' &&
          widget.voiceId != 'manual-report') {
        try {
          await _repo.createDraftReport(
            voiceId: widget.voiceId,
            teacherId: effectiveTeacherId,
            childId: effectiveChildId,
            editedExtraction: ExtractionData(
              transcript: _transcriptController.text.trim(),
              meals: _mealsController.text.trim(),
              sleeping: _sleepingController.text.trim(),
              health: _healthController.text.trim(),
              activities: _activitiesController.text.trim(),
              mood: _moodController.text.trim(),
            ),
          ).timeout(const Duration(seconds: 4));
          saved = true;
        } catch (e) {
          debugPrint('submitFinalReport createDraftReport error: $e');
        }
      }

      if (!saved) {
        try {
          await _repo.createManualReport(
            teacherId: effectiveTeacherId,
            childId: effectiveChildId,
            eating: _mealsController.text.trim().isNotEmpty
                ? _mealsController.text.trim()
                : null,
            sleeping: _sleepingController.text.trim().isNotEmpty
                ? _sleepingController.text.trim()
                : null,
            health: _healthController.text.trim().isNotEmpty
                ? _healthController.text.trim()
                : null,
            activities: _activitiesController.text.trim().isNotEmpty
                ? _activitiesController.text.trim()
                : null,
            mood: _moodController.text.trim().isNotEmpty
                ? _moodController.text.trim()
                : null,
            teacherNote: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          ).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('submitFinalReport createManualReport error: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _currentStep = ScreenStep.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSubmit(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFFF9F8F3), body: SafeArea(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D5C4D))) : _buildCurrentStepView(context)));
  }

  Widget _buildCurrentStepView(BuildContext context) {
    switch (_currentStep) {
      case ScreenStep.edit:
        return ExtractionEditView(
          transcriptController: _transcriptController,
          mealsController: _mealsController,
          sleepingController: _sleepingController,
          healthController: _healthController,
          activitiesController: _activitiesController,
          moodController: _moodController,
          notesController: _notesController,
          onGoToReview: _goToReviewStep,
          onReanalyze: _analyzeTranscript,
          hasAnalysis: _hasAnalysis,
          onTranscriptChanged: () {
            if (_hasAnalysis) {
              setState(() {
                _hasAnalysis = false;
                _mealsController.clear();
                _sleepingController.clear();
                _healthController.clear();
                _activitiesController.clear();
                _moodController.clear();
              });
            }
          },
          isSubmitting: _isSubmitting,
          isReanalyzing: _isReanalyzing,
        );
      case ScreenStep.review:
        return ReportReviewView(childName: _childName, childInitials: _childInitials, classTeacherInfo: _classTeacherInfo, formattedDate: _currentFormattedDate, transcript: _analyzedTranscript, meals: _mealsController.text, sleeping: _sleepingController.text, health: _healthController.text, activities: _activitiesController.text, mood: _moodController.text, notes: _notesController.text, onGoBackToEdit: () => setState(() => _currentStep = ScreenStep.edit), onOpenConfirmSheet: _openConfirmBottomSheet);
      case ScreenStep.success:
        return ReportSentSuccessView(childName: _childName, formattedDate: _currentFormattedDate, onBackToHome: () => context.go('/teacher'));
    }
  }
}
