// frontend/lib/presentation/screens/extraction_results_screen.dart
// ============================================================================
// ExtractionResultsScreen (Task #90 - Extraction Review Flow Coordinator)
// ============================================================================

import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/presentation/widgets/report/extraction_edit_view.dart';
import 'package:adark_frontend/presentation/widgets/report/report_review_view.dart';
import 'package:adark_frontend/presentation/widgets/report/report_sent_success_view.dart';
import 'package:adark_frontend/presentation/widgets/report/send_report_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _ScreenStep { edit, review, success }

class ExtractionResultsScreen extends StatefulWidget {
  const ExtractionResultsScreen({
    super.key,
    required this.voiceId,
    required this.teacherId,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  final String voiceId;
  final String teacherId;
  final TeacherRepositoryBase? _repository;

  @override
  State<ExtractionResultsScreen> createState() =>
      _ExtractionResultsScreenState();
}

class _ExtractionResultsScreenState extends State<ExtractionResultsScreen> {
  late final TeacherRepositoryBase _repo;

  _ScreenStep _currentStep = _ScreenStep.edit;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Controllers for the 6 fields
  late final TextEditingController _mealsController;
  late final TextEditingController _sleepingController;
  late final TextEditingController _healthController;
  late final TextEditingController _activitiesController;
  late final TextEditingController _moodController;
  late final TextEditingController _notesController;

  // Child Info (Defaults matching mockup)
  final String _childName = 'Nguyễn Thị Nhím';
  final String _childInitials = 'TN';
  final String _classTeacherInfo = 'Lớp Mầm 1 · Cô Hà';

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

    _mealsController = TextEditingController();
    _sleepingController = TextEditingController();
    _healthController = TextEditingController();
    _activitiesController = TextEditingController();
    _moodController = TextEditingController();
    _notesController = TextEditingController();

    _fetchExtraction();
  }

  @override
  void dispose() {
    _mealsController.dispose();
    _sleepingController.dispose();
    _healthController.dispose();
    _activitiesController.dispose();
    _moodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchExtraction() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.voiceId.isNotEmpty && widget.voiceId != 'voice-001') {
        final extraction = await _repo.extractVoice(
          voiceId: widget.voiceId,
          teacherId: widget.teacherId,
        );

        if (!mounted) return;
        setState(() {
          _mealsController.text = extraction.meals ?? 'Ăn hết suất, ăn tốt';
          _sleepingController.text = extraction.sleeping ?? '2 tiếng, ngủ ngon';
          _healthController.text = extraction.health ?? 'Bình thường';
          _activitiesController.text =
              extraction.activities ?? 'Chơi ngoan với các bạn trong giờ hoạt động nhóm';
          _moodController.text = extraction.mood ?? 'Vui vẻ';
          _notesController.text =
              'Bé chơi ngoan, hòa nhập tốt với các bạn trong giờ hoạt động nhóm.';
          _isLoading = false;
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() {
          _mealsController.text = 'Ăn hết suất, ăn tốt';
          _sleepingController.text = '2 tiếng, ngủ ngon';
          _healthController.text = 'Bình thường';
          _activitiesController.text =
              'Chơi ngoan với các bạn trong giờ hoạt động nhóm';
          _moodController.text = 'Vui vẻ';
          _notesController.text =
              'Bé chơi ngoan, hòa nhập tốt với các bạn trong giờ hoạt động nhóm.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mealsController.text = 'Ăn hết suất, ăn tốt';
        _sleepingController.text = '2 tiếng, ngủ ngon';
        _healthController.text = 'Bình thường';
        _activitiesController.text =
            'Chơi ngoan với các bạn trong giờ hoạt động nhóm';
        _moodController.text = 'Vui vẻ';
        _notesController.text =
            'Bé chơi ngoan, hòa nhập tốt với các bạn trong giờ hoạt động nhóm.';
        _isLoading = false;
      });
    }
  }

  // Action: Press "Tạo báo cáo" -> Go to Review Step (Image 1)
  void _goToReviewStep() {
    setState(() {
      _currentStep = _ScreenStep.review;
    });
  }

  // Action: Press "Gửi phụ huynh" -> Show Confirmation Bottom Sheet (Image 2)
  void _openConfirmBottomSheet() {
    showSendReportConfirmSheet(
      context: context,
      childName: _childName,
      childInitials: _childInitials,
      formattedDate: _currentFormattedDate,
      onConfirmSend: _submitFinalReport,
    );
  }

  // Action: Press "Gửi báo cáo" in Modal -> Submit & Go to Success Screen (Image 3)
  Future<void> _submitFinalReport() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.voiceId.isNotEmpty && widget.voiceId != 'voice-001') {
        final editedExtraction = ExtractionData(
          meals: _mealsController.text.trim(),
          sleeping: _sleepingController.text.trim(),
          health: _healthController.text.trim(),
          activities: _activitiesController.text.trim(),
          mood: _moodController.text.trim(),
        );

        await _repo.createDraftReport(
          voiceId: widget.voiceId,
          teacherId: widget.teacherId,
          editedExtraction: editedExtraction,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _currentStep = _ScreenStep.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF9F8F3);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D5C4D)),
              )
            : _buildCurrentStepView(context),
      ),
    );
  }

  Widget _buildCurrentStepView(BuildContext context) {
    switch (_currentStep) {
      case _ScreenStep.edit:
        return ExtractionEditView(
          mealsController: _mealsController,
          sleepingController: _sleepingController,
          healthController: _healthController,
          activitiesController: _activitiesController,
          moodController: _moodController,
          notesController: _notesController,
          onGoToReview: _goToReviewStep,
        );

      case _ScreenStep.review:
        return ReportReviewView(
          childName: _childName,
          childInitials: _childInitials,
          classTeacherInfo: _classTeacherInfo,
          formattedDate: _currentFormattedDate,
          meals: _mealsController.text,
          sleeping: _sleepingController.text,
          health: _healthController.text,
          activities: _activitiesController.text,
          mood: _moodController.text,
          notes: _notesController.text,
          onGoBackToEdit: () {
            setState(() {
              _currentStep = _ScreenStep.edit;
            });
          },
          onOpenConfirmSheet: _openConfirmBottomSheet,
        );

      case _ScreenStep.success:
        return ReportSentSuccessView(
          childName: _childName,
          formattedDate: _currentFormattedDate,
          onBackToHome: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/teacher');
            }
          },
        );
    }
  }
}
