import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:image_picker/image_picker.dart';

import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/http_report_response_repository.dart';
import 'package:adark_frontend/domain/entities/report/report_response.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/voice_message_bubble.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/voice_record_bar.dart';

typedef ImagePickerCallback = Future<Uint8List?> Function(ImageSource source);

class ReportDiscussionSection extends StatefulWidget {
  const ReportDiscussionSection({
    super.key,
    required this.reportId,
    required this.childName,
    required this.teacherName,
    this.repository,
    this.onPickImage,
    this.initialResponses,
    this.isTeacher = false,
    this.onDiscussionUpdated,
    this.header,
    this.padding,
    this.bottomBarPadding,
    this.bottomBarBackgroundColor,
    this.isOverlay = false,
  });

  final String reportId;
  final String childName;
  final String teacherName;
  final HttpReportResponseRepository? repository;
  final ImagePickerCallback? onPickImage;
  final List<ReportResponse>? initialResponses;
  final bool isTeacher;
  final VoidCallback? onDiscussionUpdated;
  final Widget? header;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? bottomBarPadding;
  final Color? bottomBarBackgroundColor;
  final bool isOverlay;

  @override
  State<ReportDiscussionSection> createState() => _ReportDiscussionSectionState();
}

class _ReportDiscussionSectionState extends State<ReportDiscussionSection> {
  late final HttpReportResponseRepository _repo =
      widget.repository ?? HttpReportResponseRepository();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<ReportResponse> _responses = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _pollTimer;

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isVoiceRecording = false;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        _scrollToBottom();
      }
    });
    if (widget.initialResponses != null) {
      _responses = List.from(widget.initialResponses!);
      _isLoading = false;
    } else {
      _fetchResponses();
    }
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _syncResponsesSilently();
    });
  }

  Future<void> _syncResponsesSilently() async {
    if (!mounted || _isSending) return;
    try {
      final list = await _repo.getResponses(widget.reportId);
      if (!mounted) return;
      if (list.length != _responses.length ||
          !_areListsEqual(list, _responses)) {
        final wasNearBottom = _isNearBottom();
        setState(() {
          _responses = list;
        });
        widget.onDiscussionUpdated?.call();
        if (wasNearBottom) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    return (max - current) < 120;
  }

  bool _areListsEqual(List<ReportResponse> a, List<ReportResponse> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].responseId != b[i].responseId ||
          a[i].isResolved != b[i].isResolved ||
          a[i].isRead != b[i].isRead) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchResponses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getResponses(widget.reportId);
      if (!mounted) return;
      setState(() {
        _responses = list;
        _isLoading = false;
      });
      widget.onDiscussionUpdated?.call();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ReportResponseException
            ? e.message
            : (context.l10n?.cannotLoadDiscussion ??
                'Không thể tải trao đổi. Quý phụ huynh vui lòng thử lại sau.');
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop(); // Close bottom sheet modal
    try {
      Uint8List? bytes;
      String? name;

      if (widget.onPickImage != null) {
        bytes = await widget.onPickImage!(source);
        name = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        final picker = ImagePicker();
        final xFile = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (xFile != null) {
          bytes = await xFile.readAsBytes();
          name = xFile.name;
        }
      }

      if (bytes != null && mounted) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = name ?? 'attachment.jpg';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n?.cannotPickImageGeneric ?? 'Không thể chọn ảnh. Vui lòng thử lại.',
            ),
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.k.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.k.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n?.attachImageTitle ?? 'Đính kèm hình ảnh',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.k.ink,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.k.brandTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.camera_alt_rounded, color: context.k.brand),
                ),
                title: Text(
                  context.l10n?.takePhotoCamera ?? 'Chụp ảnh từ máy ảnh',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.k.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.photo_library_rounded, color: context.k.inkSoft),
                ),
                title: Text(
                  context.l10n?.choosePhotoGallery ?? 'Chọn ảnh từ thư viện',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final fallbackContent =
          context.l10n?.sentAttachedImage ?? 'Đã gửi một hình ảnh đính kèm';
      final newResponse = await _repo.sendResponse(
        reportId: widget.reportId,
        content: text.isNotEmpty ? text : fallbackContent,
        imageBytes: _selectedImageBytes,
        fileName: _selectedImageName,
        isTeacher: widget.isTeacher,
      );

      if (!mounted) return;
      setState(() {
        _responses.add(newResponse);
        _textController.clear();
        _selectedImageBytes = null;
        _selectedImageName = null;
        _isSending = false;
      });
      widget.onDiscussionUpdated?.call();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ReportResponseException
                ? e.message
                : (context.l10n?.cannotSendMessage ??
                    'Không thể gửi tin nhắn. Quý phụ huynh vui lòng thử lại.'),
          ),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  Future<void> _handleSendVoice({
    required Uint8List bytes,
    required int durationSeconds,
    required String fileName,
  }) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final newResponse = await _repo.sendVoiceResponse(
        reportId: widget.reportId,
        audioBytes: bytes,
        durationSeconds: durationSeconds,
        fileName: fileName,
        isTeacher: widget.isTeacher,
      );

      if (!mounted) return;
      setState(() {
        _responses.add(newResponse);
        _isSending = false;
      });
      widget.onDiscussionUpdated?.call();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ReportResponseException
                ? e.message
                : (context.l10n?.cannotSendVoiceMessage ??
                    'Không thể gửi tin nhắn thoại. Vui lòng thử lại sau.'),
          ),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.header != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: widget.padding ?? EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.header!,
                  const SizedBox(height: KSpace.x4),
                  const Divider(height: 24),
                  _buildSectionHeader(),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else if (_responses.isEmpty)
                    _buildEmptyState()
                  else
                    _buildMessagesList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: widget.bottomBarBackgroundColor ?? context.k.surface,
              border: Border(
                top: BorderSide(
                  color: context.k.line.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
            ),
            padding: widget.bottomBarPadding ??
                const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedImageBytes != null) _buildSelectedImagePreview(),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (widget.isOverlay) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else if (_responses.isEmpty)
                    _buildEmptyState()
                  else
                    _buildMessagesList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: widget.bottomBarBackgroundColor ?? context.k.surface,
              border: Border(
                top: BorderSide(
                  color: context.k.line.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
            ),
            padding: widget.bottomBarPadding ??
                const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedImageBytes != null) _buildSelectedImagePreview(),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_errorMessage != null)
          _buildErrorState()
        else if (_responses.isEmpty)
          _buildEmptyState()
        else
          _buildMessagesList(),
        if (_selectedImageBytes != null) _buildSelectedImagePreview(),
        const SizedBox(height: 12),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSectionHeader() {
    final count = _responses.length;
    final hasResponses = count > 0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          widget.isTeacher
              ? (context.l10n?.discussionWithParent ?? 'Trao đổi với phụ huynh')
              : (context.l10n?.discussionWithTeacher ?? 'Trao đổi với giáo viên'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.k.ink,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.k.surfaceSunken,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            context.l10n?.discussionResponseCount(count) ?? '$count phản hồi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.k.inkSoft,
            ),
          ),
        ),
        if (hasResponses)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.k.brandTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.k.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  context.l10n?.discussionResponded ?? 'Đã phản hồi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.k.brand,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.k.line),
      ),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 32, color: context.k.inkFaint),
          const SizedBox(height: 8),
          Text(
            widget.isTeacher
                ? (context.l10n?.discussionNoDiscussionYet ?? 'Chưa có trao đổi nào')
                : (context.l10n?.discussionNoResponsesYet ?? 'Chưa có phản hồi nào'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.k.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isTeacher
                ? (context.l10n?.discussionTeacherEmptyHint ??
                    'Khi phụ huynh gửi phản hồi về báo cáo này, tin nhắn sẽ hiển thị tại đây để cô theo dõi và trả lời.')
                : (context.l10n?.discussionParentEmptyHint ??
                    'Quý phụ huynh có thể gửi tin nhắn trao đổi hoặc lời dặn dò cho cô giáo về báo cáo này.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.k.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.k.badTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: context.k.bad,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchResponses,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              context.l10n?.bugReportCommonRetry ?? 'Thử lại',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: context.k.bad),
          ),
        ],
      ),
    );
  }

  bool _isMe(ReportResponse msg) {
    final myUserId = AuthRepository.currentUser?.userId;
    if (myUserId != null &&
        myUserId.isNotEmpty &&
        msg.authorUserId != null &&
        msg.authorUserId!.isNotEmpty) {
      return msg.authorUserId == myUserId;
    }
    // Fallback khi không có userId để so sánh (e.g. trong widget test):
    if (widget.isTeacher) {
      return msg.isFromTeacher;
    } else {
      return msg.isFromParent;
    }
  }

  Widget _buildMessagesList() {
    return Column(
      children: [
        for (final msg in _responses) ...[
          if (_isMe(msg))
            _buildSentMessageItem(msg)
          else
            _buildReceivedMessageItem(msg),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSentMessageItem(ReportResponse msg) {
    final avatarLetter = msg.authorName.trim().isNotEmpty
        ? msg.authorName.trim().characters.first.toUpperCase()
        : 'M';
    final readText = widget.isTeacher
        ? (msg.isRead
            ? (context.l10n?.discussionSentReadByParent ?? 'Đã gửi · Phụ huynh đã đọc')
            : (context.l10n?.commonSent ?? 'Đã gửi'))
        : (msg.isRead
            ? (context.l10n?.discussionSentReadByTeacher ?? 'Đã gửi · Cô đã đọc')
            : (context.l10n?.commonSent ?? 'Đã gửi'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              msg.authorName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.k.ink,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatTime(msg.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: context.k.inkFaint,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: context.k.brandTint,
              child: Text(
                avatarLetter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.k.brand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 310),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.k.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
              topRight: Radius.circular(16),
            ),
            border: Border.all(color: context.k.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.k.ink,
                ),
              ),
              if (msg.hasImage && msg.imageUrl != null) ...[
                const SizedBox(height: 8),
                AttachmentThumbnailWidget(
                  url: msg.imageUrl!,
                  repository: _repo,
                ),
              ],
              if (msg.hasAudio && msg.audioUrl != null) ...[
                const SizedBox(height: 8),
                VoiceMessageBubbleWidget(
                  audioUrl: msg.audioUrl!,
                  durationSeconds: msg.audioDuration,
                  repository: _repo,
                  isMe: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
              size: 13,
              color: msg.isRead ? context.k.brand : context.k.inkSoft,
            ),
            const SizedBox(width: 4),
            Text(
              readText,
              style: TextStyle(
                fontSize: 11,
                color: context.k.inkSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceivedMessageItem(ReportResponse msg) {
    final avatarLetter = msg.authorName.trim().isNotEmpty
        ? msg.authorName.trim().characters.first.toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: context.k.surfaceSunken,
              child: msg.isFromTeacher
                  ? Icon(Icons.school_rounded, size: 14, color: context.k.brand)
                  : Text(
                      avatarLetter,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.k.brand,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              msg.authorName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.k.ink,
              ),
            ),
            if (msg.isFromTeacher) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: context.k.brandTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'GVCN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.k.brand,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              _formatTime(msg.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: context.k.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: msg.isFromTeacher ? context.k.brandTint : context.k.surfaceSunken,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.k.ink,
                ),
              ),
              if (msg.hasImage && msg.imageUrl != null) ...[
                const SizedBox(height: 8),
                AttachmentThumbnailWidget(
                  url: msg.imageUrl!,
                  repository: _repo,
                ),
              ],
              if (msg.hasAudio && msg.audioUrl != null) ...[
                const SizedBox(height: 8),
                VoiceMessageBubbleWidget(
                  audioUrl: msg.audioUrl!,
                  durationSeconds: msg.audioDuration,
                  repository: _repo,
                  isMe: false,
                ),
              ],
              if (msg.isResolved) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n?.discussionAcknowledged ?? '✓ Đã ghi nhận & xử lý',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.isTeacher && !msg.isResolved) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              try {
                final updated =
                    await _repo.resolveResponse(msg.responseId, resolved: true);
                if (mounted) {
                  setState(() {
                    final idx = _responses
                        .indexWhere((r) => r.responseId == msg.responseId);
                    if (idx != -1) _responses[idx] = updated;
                  });
                  widget.onDiscussionUpdated?.call();
                }
              } catch (_) {}
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: context.k.brand),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n?.discussionMarkHandled ?? 'Đánh dấu đã xử lý',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.k.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.k.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              _selectedImageBytes!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedImageName ?? (context.l10n?.discussionAttachedImage ?? 'Ảnh đính kèm'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.k.ink,
                  ),
                ),
                Text(
                  context.l10n?.discussionReadyToSendWithMsg ?? 'Đã sẵn sàng gửi kèm tin nhắn',
                  style: TextStyle(fontSize: 11, color: context.k.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n?.discussionCancelImage ?? 'Hủy chọn ảnh',
            onPressed: () {
              setState(() {
                _selectedImageBytes = null;
                _selectedImageName = null;
              });
            },
            icon: Icon(Icons.close_rounded, size: 20, color: context.k.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return ListenableBuilder(
      listenable: _inputFocusNode,
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _inputFocusNode.requestFocus(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: context.k.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _inputFocusNode.hasFocus
                  ? context.k.brand
                  : context.k.line,
              width: _inputFocusNode.hasFocus ? 1.5 : 1.0,
            ),
          ),
          child: _isVoiceRecording
              ? VoiceRecordBar(
                  isSending: _isSending,
                  onRecordingStateChanged: (rec) {
                    if (mounted) setState(() => _isVoiceRecording = rec);
                  },
                  onVoiceRecorded: _handleSendVoice,
                )
              : Row(
                  children: [
                    IconButton(
                      tooltip: context.l10n?.discussionAttachImageTooltip ?? 'Đính kèm ảnh',
                      onPressed: _isSending ? null : _showImageSourcePicker,
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.k.surfaceSunken,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 19,
                          color: context.k.inkSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _inputFocusNode,
                        enabled: !_isSending,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(fontSize: 13, color: context.k.ink),
                        decoration: InputDecoration(
                          hintText: widget.isTeacher
                              ? (context.l10n?.discussionTeacherInputHint ??
                                  'Nhắn phản hồi cho phụ huynh về báo cáo này...')
                              : (context.l10n?.discussionParentInputHint ??
                                  'Nhắn cho cô giáo về báo cáo này...'),
                          hintStyle:
                              TextStyle(fontSize: 12.5, color: context.k.inkFaint),
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    VoiceRecordBar(
                      isSending: _isSending,
                      onRecordingStateChanged: (rec) {
                        if (mounted) setState(() => _isVoiceRecording = rec);
                      },
                      onVoiceRecorded: _handleSendVoice,
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _handleSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.k.brand,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AttachmentThumbnailWidget extends StatefulWidget {
  const AttachmentThumbnailWidget({
    super.key,
    required this.url,
    required this.repository,
  });

  final String url;
  final HttpReportResponseRepository repository;

  @override
  State<AttachmentThumbnailWidget> createState() =>
      _AttachmentThumbnailWidgetState();
}

class _AttachmentThumbnailWidgetState extends State<AttachmentThumbnailWidget> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant AttachmentThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loading = true;
      _hasError = false;
      _bytes = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final bytes = await widget.repository.getAttachmentBytes(widget.url);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  void _openLightbox() {
    if (_bytes == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        pageBuilder: (context, _, __) =>
            _ImageLightboxDialog(imageBytes: _bytes!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 100,
        width: 120,
        decoration: BoxDecoration(
          color: context.k.surfaceSunken,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.k.brand,
          ),
        ),
      );
    }

    if (_hasError || _bytes == null) {
      return InkWell(
        onTap: () {
          setState(() {
            _loading = true;
            _hasError = false;
          });
          _fetch();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 80,
          width: 110,
          decoration: BoxDecoration(
            color: context.k.surfaceSunken,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.k.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded,
                  size: 22, color: context.k.inkSoft),
              const SizedBox(height: 4),
              Text(
                context.l10n?.bugReportCommonRetry ?? 'Thử lại',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.k.brand,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: _openLightbox,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.memory(
              _bytes!,
              height: 120,
              width: 160,
              fit: BoxFit.cover,
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.zoom_in_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageLightboxDialog extends StatelessWidget {
  const _ImageLightboxDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                clipBehavior: Clip.none,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 14,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: IconButton(
                  tooltip: context.l10n?.commonClose ?? 'Đóng',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút bong bóng chat nổi (Floating Chat Bubble) và khung chat Messenger
/// overlay cho trao đổi giữa phụ huynh và giáo viên dưới báo cáo.
class ReportDiscussionBubble extends StatefulWidget {
  const ReportDiscussionBubble({
    super.key,
    required this.reportId,
    required this.childName,
    required this.teacherName,
    this.isTeacher = false,
    this.repository,
    this.onPickImage,
    this.initialResponses,
    this.onDiscussionUpdated,
    this.unreadCount = 0,
    required this.child,
  });

  final String reportId;
  final String childName;
  final String teacherName;
  final bool isTeacher;
  final HttpReportResponseRepository? repository;
  final ImagePickerCallback? onPickImage;
  final List<ReportResponse>? initialResponses;
  final VoidCallback? onDiscussionUpdated;
  final int unreadCount;
  final Widget child;

  @override
  State<ReportDiscussionBubble> createState() => _ReportDiscussionBubbleState();
}

class _ReportDiscussionBubbleState extends State<ReportDiscussionBubble> {
  bool _isOpen = false;
  late int _unreadCount = widget.unreadCount;
  late final HttpReportResponseRepository _repo =
      widget.repository ?? HttpReportResponseRepository();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _unreadCount = widget.unreadCount;
    _syncUnreadCount();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _syncUnreadCount();
    });
  }

  @override
  void didUpdateWidget(ReportDiscussionBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount != oldWidget.unreadCount) {
      _unreadCount = widget.unreadCount;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncUnreadCount() async {
    if (!mounted || _isOpen) return;
    try {
      final list = await _repo.getResponses(widget.reportId, markRead: false);
      if (!mounted) return;
      final unread = list.where((r) {
        if (r.isRead) return false;
        return widget.isTeacher ? r.isFromParent : r.isFromTeacher;
      }).length;
      if (unread != _unreadCount) {
        setState(() => _unreadCount = unread);
      }
    } catch (_) {}
  }

  void _openChat() {
    setState(() {
      _isOpen = true;
      _unreadCount = 0;
    });
    widget.onDiscussionUpdated?.call();
  }

  void _closeChat() {
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isOpen) {
          _closeChat();
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (!_isOpen)
            Positioned(
              right: 18,
              bottom: 18,
              child: _buildFloatingButton(context),
            ),
          if (_isOpen)
            Positioned.fill(
              child: _buildChatOverlay(context),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton(BuildContext context) {
    return Tooltip(
      message: widget.isTeacher
          ? (context.l10n?.chatWithParent ?? 'Nhắn tin với phụ huynh')
          : (context.l10n?.chatWithTeacher ?? 'Nhắn tin với cô giáo'),
      child: GestureDetector(
        key: const ValueKey('report-discussion-bubble-btn'),
        onTap: _openChat,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.k.brand,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.k.brand.withValues(alpha: 0.38),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 26,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    key: const ValueKey('report-discussion-unread-badge'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: context.k.bad,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOverlay(BuildContext context) {
    return Container(
      key: const ValueKey('report-discussion-overlay'),
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildOverlayHeader(context),
            Expanded(
              child: ReportDiscussionSection(
                reportId: widget.reportId,
                childName: widget.childName,
                teacherName: widget.teacherName,
                isTeacher: widget.isTeacher,
                repository: widget.repository,
                onPickImage: widget.onPickImage,
                initialResponses: widget.initialResponses,
                onDiscussionUpdated: widget.onDiscussionUpdated,
                isOverlay: true,
                bottomBarPadding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.k.surface,
        border: Border(
          bottom: BorderSide(
            color: context.k.line.withValues(alpha: 0.7),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: context.k.brandTint,
            child: Icon(
              widget.isTeacher ? Icons.person_rounded : Icons.school_rounded,
              size: 19,
              color: context.k.brand,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isTeacher
                      ? (context.l10n?.discussionWithParent ?? 'Trao đổi với phụ huynh')
                      : (context.l10n?.discussionWithTeacher ?? 'Trao đổi với giáo viên'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.k.ink,
                  ),
                ),
                Text(
                  widget.isTeacher
                      ? (context.l10n?.childLabelPrefix(widget.childName) ?? 'Bé ${widget.childName}')
                      : widget.teacherName,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.k.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('report-discussion-close-overlay-btn'),
            tooltip: context.l10n?.minimizeChatTooltip ?? 'Thu nhỏ khung chat',
            onPressed: _closeChat,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            style: IconButton.styleFrom(
              backgroundColor: context.k.surfaceSunken,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: context.k.ink,
            ),
          ),
        ],
      ),
    );
  }
}


