import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import 'parent_requests_submitted_screen.dart';
import 'parent_requests_widgets.dart';

part 'parent_requests_form_fields.dart';

class ParentRequestFormScreen extends StatefulWidget {
  const ParentRequestFormScreen(
      {super.key,
      required this.child,
      required this.className,
      required this.teacherName,
      this.repository,
      this.imagePicker});

  final Child child;
  final String className;
  final String teacherName;
  final HttpLeaveRequestRepository? repository;
  final ImagePicker? imagePicker;

  @override
  State<ParentRequestFormScreen> createState() =>
      _ParentRequestFormScreenState();
}

class _ParentRequestFormScreenState extends State<ParentRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final HttpLeaveRequestRepository _repository;
  LeaveRequestType _type = LeaveRequestType.absence;
  DateTime _from = DateUtils.dateOnly(DateTime.now());
  late DateTime _to = _from;
  TimeOfDay _eta = const TimeOfDay(hour: 8, minute: 30);
  Uint8List? _imageBytes;
  String? _imageName;
  String? _attachmentUrl;
  String? _error;
  bool _overlap = false;
  bool _busy = false;
  bool _pickingImage = false;
  bool _dirty = false;
  bool _discardOpen = false;

  bool get _late => _type == LeaveRequestType.lateArrival;
  int get _days =>
      DateTime.utc(_to.year, _to.month, _to.day)
          .difference(DateTime.utc(_from.year, _from.month, _from.day))
          .inDays +
      1;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpLeaveRequestRepository();
    _reason.addListener(_reasonChanged);
  }

  void _reasonChanged() => setState(() => _dirty = true);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _changeType(LeaveRequestType value) => setState(() {
        _type = value;
        _to = _from;
        _dirty = true;
        _error = null;
      });

  void _changeEta(TimeOfDay value) => setState(() {
        _eta = value;
        _dirty = true;
      });

  Future<void> _pickDate({bool end = false}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = end && _from.isAfter(today) ? _from : today;
    final last =
        end ? _from.add(const Duration(days: 365)) : DateTime(9999, 12, 31);
    final initial = end ? _to : _from;
    final date = await showDatePicker(
        context: context,
        firstDate: first,
        lastDate: last.isBefore(first) ? first : last,
        initialDate: initial.isBefore(first) ? first : initial,
        cancelText: 'Hủy',
        confirmText: 'OK',
        helpText: end ? 'Đến ngày' : (_late ? 'Ngày đi trễ' : 'Từ ngày'));
    if (date == null || !mounted) return;
    setState(() {
      if (end) {
        _to = date;
      } else {
        _from = date;
        if (_late || _to.isBefore(date) || _to.difference(date).inDays > 365) {
          _to = date;
        }
      }
      _dirty = true;
    });
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
        context: context,
        initialTime: _eta,
        cancelText: 'Hủy',
        confirmText: 'Xong',
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (mounted && value != null) _changeEta(value);
  }

  Future<void> _pickImage() async {
    if (_busy || _pickingImage) return;
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    try {
      final file = await (widget.imagePicker ?? ImagePicker())
          .pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const LeaveRequestException(
            'Ảnh tối đa 5 MiB. Vui lòng chọn ảnh nhỏ hơn.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _attachmentUrl = null;
        _dirty = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is LeaveRequestException
            ? e.message
            : 'Không thể mở ảnh. Vui lòng kiểm tra quyền truy cập thư viện và thử lại.');
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _removeImage() => setState(() {
        _imageBytes = null;
        _imageName = null;
        _attachmentUrl = null;
        _dirty = true;
      });

  Future<void> _discard([ParentRequestDestination? destination]) async {
    if (_busy || _pickingImage || _discardOpen) return;
    _discardOpen = true;
    final discard = !_dirty ||
        await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                        title: const Text('Bỏ thay đổi?'),
                        content: const Text(
                            'Nội dung đơn chưa gửi sẽ không được lưu.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Tiếp tục soạn')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Bỏ thay đổi')),
                        ])) ==
            true;
    _discardOpen = false;
    if (mounted && discard) Navigator.of(context).pop(destination);
  }

  Future<void> _submit() async {
    if (_busy || _pickingImage) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final classId = widget.child.classId;
    if (classId == null || classId.isEmpty) {
      setState(() =>
          _error = 'Bé chưa có thông tin lớp. Vui lòng liên hệ nhà trường.');
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final arrival =
        DateTime(_from.year, _from.month, _from.day, _eta.hour, _eta.minute);
    if (_from.isBefore(today) ||
        _to.isBefore(_from) ||
        _days > 366 ||
        (_late && !arrival.isAfter(DateTime.now()))) {
      setState(() => _error =
          'Chọn ngày và giờ trong tương lai; mỗi đơn tối đa 366 ngày.');
      return;
    }
    final from = _from, to = _late ? _from : _to, type = _type;
    final reason = _reason.text.trim();
    final eta = _late
        ? '${_eta.hour.toString().padLeft(2, '0')}:${_eta.minute.toString().padLeft(2, '0')}:00'
        : null;
    setState(() {
      _busy = true;
      _error = null;
      _overlap = false;
    });
    try {
      final attachment = _imageBytes == null
          ? null
          : _attachmentUrl ??
              await _repository.uploadAttachment(
                  childId: widget.child.childId,
                  bytes: _imageBytes!,
                  fileName: _imageName!);
      _attachmentUrl = attachment;
      var acknowledged = false;
      while (true) {
        try {
          final request = await _repository.createRequest(
              childId: widget.child.childId,
              classId: classId,
              fromDate: from,
              toDate: to,
              requestType: type,
              expectedArrivalTime: eta,
              reason: reason,
              attachmentUrl: attachment,
              mealWarningAcknowledged: acknowledged);
          if (!mounted) return;
          _dirty = false;
          final destination = await Navigator.of(context)
              .push<ParentRequestDestination>(MaterialPageRoute(
                  builder: (_) =>
                      ParentRequestSubmittedScreen(request: request)));
          if (mounted) {
            Navigator.of(context)
                .pop(destination ?? ParentRequestDestination.history);
          }
          return;
        } on LeaveRequestException catch (e) {
          if (e.code != 'meal_warning_required' || acknowledged) rethrow;
          if (!mounted) return;
          final agreed = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                      title: const Text('Xác nhận tiền ăn'),
                      content: Text(e.message),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Đồng ý')),
                      ]));
          if (!mounted || agreed != true) return;
          acknowledged = true;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is LeaveRequestException
              ? e.message
              : 'Không thể gửi đơn. Nội dung được giữ lại để bạn thử lại.';
          _overlap =
              e is LeaveRequestException && e.code == 'overlapping_request';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<ParentRequestDestination>(
        canPop: !_dirty && !_busy && !_pickingImage,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _discard(result);
        },
        child: ParentRequestLayout(
            title: _late ? 'Báo đi trễ' : 'Tạo đơn xin nghỉ',
            child: _ParentRequestFormFields(this)),
      );
}
