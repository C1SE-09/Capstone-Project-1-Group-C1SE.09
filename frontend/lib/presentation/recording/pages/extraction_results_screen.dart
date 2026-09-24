import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/presentation/recording/widgets/extraction_edit_view.dart';
import 'package:adark_frontend/presentation/recording/widgets/report_review_view.dart';
import 'package:adark_frontend/presentation/recording/widgets/report_sent_success_view.dart';
import 'package:adark_frontend/presentation/recording/widgets/send_report_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ScreenStep { edit, review, success }

class ExtractionResultsScreen extends StatefulWidget {
  const ExtractionResultsScreen({super.key, required this.voiceId, required this.teacherId, this.childId, this.childName, this.childInitials, this.classTeacherInfo, this.initialStep = ScreenStep.edit, TeacherRepositoryBase? repository}) : _repository = repository;
  final String voiceId;
  final String teacherId;
  final String? childId;
  final String? childName;
  final String? childInitials;
  final String? classTeacherInfo;
  final ScreenStep initialStep;
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
  late final TextEditingController _transcriptController;
  late final TextEditingController _mealsController;
  late final TextEditingController _sleepingController;
  late final TextEditingController _healthController;
  late final TextEditingController _activitiesController;
  late final TextEditingController _moodController;
  late final TextEditingController _notesController;

  /// Transcript gốc do PhoWhisper trả về, dùng để phát hiện giáo viên có sửa.
  String _originalTranscript = '';

  String get _childName => widget.childName ?? 'N/A';
  String get _childInitials => widget.childInitials ?? '?';
  String get _classTeacherInfo => widget.classTeacherInfo ?? 'N/A';
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
    setState(() => _isLoading = true);
    try {
      final record = await _repo.getVoiceRecord(
        voiceId: widget.voiceId,
        teacherId: widget.teacherId,
      );
      if (!mounted) return;
      setState(() {
        _originalTranscript = record.effectiveTranscript;
        _transcriptController.text = record.effectiveTranscript;
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
          content: Text('Không thể tải transcript PhoWhisper: $e'),
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
    if (_isReanalyzing || _isSubmitting) return;
    final edited = _transcriptController.text.trim();
    if (edited.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript đang trống, không thể gửi phân tích.'),
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
          const SnackBar(
            content: Text('Transcript đã thay đổi trong lúc phân tích. Hãy gửi lại nội dung mới.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() {
        _originalTranscript = edited;
        _mealsController.text = extraction.meals ?? '';
        _sleepingController.text = extraction.sleeping ?? '';
        _healthController.text = extraction.health ?? '';
        _activitiesController.text = extraction.activities ?? '';
        _moodController.text = extraction.mood ?? '';
        _hasAnalysis = true;
        _isReanalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã phân tích transcript đã chỉnh sửa.'),
          backgroundColor: Color(0xFF0D5C4D),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReanalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể phân tích lại: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _goToReviewStep() async {
    if (_isSubmitting) return;
    if (_originalTranscript.isNotEmpty &&
        _transcriptController.text.trim() != _originalTranscript) {
      _originalTranscript = _transcriptController.text.trim();
    }
    setState(() => _isSubmitting = true);
    try {
      if (!_hasAnalysis) {
        throw const TeacherRepositoryException(
          'Vui lòng gửi transcript cho model phân tích trước.',
        );
      }
      final effectiveTeacherId = widget.teacherId.isNotEmpty ? widget.teacherId : 'bbbbbbbb-0000-0000-0000-000000000001';
      await _repo.createDraftReport(
        voiceId: widget.voiceId,
        teacherId: effectiveTeacherId,
        childId: widget.childId,
        editedExtraction: ExtractionData(
          transcript: _transcriptController.text.trim(),
          meals: _mealsController.text.trim(),
          sleeping: _sleepingController.text.trim(),
          health: _healthController.text.trim(),
          activities: _activitiesController.text.trim(),
          mood: _moodController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() { _isSubmitting = false; _currentStep = ScreenStep.review; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể tạo bản nháp: $e'), backgroundColor: Colors.red));
    }
  }

  void _openConfirmBottomSheet() {
    showSendReportConfirmSheet(context: context, childName: _childName, childInitials: _childInitials, formattedDate: _currentFormattedDate, onConfirmSend: _submitFinalReport);
  }

  Future<void> _submitFinalReport() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final effectiveTeacherId = widget.teacherId.isNotEmpty
          ? widget.teacherId
          : 'bbbbbbbb-0000-0000-0000-000000000001';
      await _repo.createDraftReport(
        voiceId: widget.voiceId,
        teacherId: effectiveTeacherId,
        childId: widget.childId,
        editedExtraction: ExtractionData(
          transcript: _transcriptController.text.trim(),
          meals: _mealsController.text.trim(),
          sleeping: _sleepingController.text.trim(),
          health: _healthController.text.trim(),
          activities: _activitiesController.text.trim(),
          mood: _moodController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() { _isSubmitting = false; _currentStep = ScreenStep.success; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
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
        return ReportReviewView(childName: _childName, childInitials: _childInitials, classTeacherInfo: _classTeacherInfo, formattedDate: _currentFormattedDate, transcript: _transcriptController.text, meals: _mealsController.text, sleeping: _sleepingController.text, health: _healthController.text, activities: _activitiesController.text, mood: _moodController.text, notes: _notesController.text, onGoBackToEdit: () => setState(() => _currentStep = ScreenStep.edit), onOpenConfirmSheet: _openConfirmBottomSheet);
      case ScreenStep.success:
        return ReportSentSuccessView(childName: _childName, formattedDate: _currentFormattedDate, onBackToHome: () => context.go('/teacher'));
    }
  }
}
