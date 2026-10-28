// frontend/lib/features/kindergarten_dashboard/widgets/teacher_emergency_sheet.dart
// =================================================================================
// Bottom sheet / Dialog cho Giáo viên phát cảnh báo khẩn cấp 1 chạm tại lớp (Task #285 / Story #74).
// - Zero typing: chọn bé và loại sự cố là phát cảnh báo ngay.
// - Trả về danh bạ Bố/Mẹ để cô giáo bấm gọi trực tiếp qua SIM.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';

class TeacherEmergencySheet extends StatefulWidget {
  const TeacherEmergencySheet({
    super.key,
    required this.children,
    this.initialChildId,
    this.repository,
  });

  final List<Child> children;
  final String? initialChildId;
  final HttpMedicationRepository? repository;

  static Future<void> show(
    BuildContext context, {
    required List<Child> children,
    String? initialChildId,
    HttpMedicationRepository? repository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherEmergencySheet(
        children: children,
        initialChildId: initialChildId,
        repository: repository,
      ),
    );
  }

  @override
  State<TeacherEmergencySheet> createState() => _TeacherEmergencySheetState();
}

class _TeacherEmergencySheetState extends State<TeacherEmergencySheet> {
  late final HttpMedicationRepository _repository =
      widget.repository ?? HttpMedicationRepository();

  String? _selectedChildId;
  String _selectedIncidentType = 'high_fever';
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isSubmitting = false;
  List<Map<String, dynamic>>? _emergencyContacts;
  String? _successChildName;

  final Map<String, String> _incidentLabels = {
    'high_fever': 'Sốt cao co giật',
    'severe_injury': 'Tai nạn / Té ngã',
    'acute_allergy': 'Dị ứng cấp tính',
    'other': 'Sự cố sức khỏe khác',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialChildId != null &&
        widget.children.any((c) => c.id == widget.initialChildId)) {
      _selectedChildId = widget.initialChildId;
    } else if (widget.children.isNotEmpty) {
      _selectedChildId = widget.children.first.id;
    }
  }

  @override
  void dispose() {
    _tempController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitEmergency() async {
    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn học sinh gặp sự cố.')),
      );
      return;
    }

    final tempRaw = _tempController.text.trim().replaceAll(',', '.');
    final tempVal = tempRaw.isNotEmpty ? double.tryParse(tempRaw) : null;
    if (tempVal != null && (tempVal < 34.0 || tempVal > 44.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhiệt độ cơ thể không hợp lệ (từ 34°C đến 44°C).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await _repository.createHealthIncident(
        childId: _selectedChildId!,
        incidentType: _selectedIncidentType,
        description: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        temperature: tempVal,
      );

      final child = widget.children.cast<Child?>().firstWhere(
        (c) => c?.id == _selectedChildId,
        orElse: () => null,
      );

      final contactsRaw = res['emergency_contacts'];
      final contacts = contactsRaw is List
          ? contactsRaw.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      setState(() {
        _isSubmitting = false;
        _emergencyContacts = contacts;
        _successChildName = child?.name ?? 'Bé';
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        String errorMsg = 'Gửi cảnh báo thất bại';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['detail'] != null) {
            final detail = data['detail'];
            if (detail is String) {
              errorMsg = detail;
            } else if (detail is List && detail.isNotEmpty) {
              final firstErr = detail.first;
              errorMsg = firstErr is Map && firstErr['msg'] != null
                  ? firstErr['msg'].toString()
                  : detail.toString();
            }
          } else {
            errorMsg = e.message ?? 'Lỗi kết nối máy chủ';
          }
        } else {
          errorMsg = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tự động gọi tới $cleanPhone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _emergencyContacts != null ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD32F2F),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Báo Động Sự Cố Khẩn Cấp',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    Text(
                      'Phát tín hiệu chuông còi hú ngay tới máy phụ huynh',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Chọn bé gặp sự cố
          const Text(
            'Học sinh gặp sự cố:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedChildId,
                isExpanded: true,
                hint: const Text('Chọn học sinh...'),
                items: widget.children.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedChildId = val),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Chọn loại sự cố (1-chạm)
          const Text(
            'Loại sự cố khẩn cấp (1-chạm):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _incidentLabels.entries.map((entry) {
              final isSelected = _selectedIncidentType == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                selectedColor: const Color(0xFFFF4D4F),
                backgroundColor: const Color(0xFFF5F5F5),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) =>
                    setState(() => _selectedIncidentType = entry.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 3. Nhiệt độ (nếu có, không bắt buộc)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tempController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Nhiệt độ (nếu sốt)',
                    hintText: 'Vd: 39.5',
                    suffixText: '°C',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Ghi chú nhanh (tùy chọn)
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Ghi chú / Biện pháp sơ cứu (tùy chọn)',
              hintText: 'Vd: Đã chườm ấm trán, bé đang nằm nghỉ...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Nút bấm phát cảnh báo
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.notifications_active, size: 22),
            label: Text(
              _isSubmitting
                  ? 'ĐANG GỬI CẢNH BÁO...'
                  : '🚨 PHÁT CẢNH BÁO KHẨN CẤP',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final contacts = _emergencyContacts ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 54),
        const SizedBox(height: 8),
        Text(
          'Đã Phát Cảnh Báo Khẩn Cấp!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Còi báo động đã được gửi tới thiết bị phụ huynh của ${_successChildName ?? "bé"}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 20),

        const Text(
          'Danh bạ khẩn cấp gọi trực tiếp bố/mẹ:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (contacts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Chưa cập nhật số điện thoại phụ huynh của bé này.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          for (final contact in contacts)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FFED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7EB8F)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: const Icon(Icons.person, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${contact["relationship"] ?? "Phụ huynh"}: ${contact["name"] ?? "Bố/Mẹ"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          contact["phone"] ?? "",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _callPhone(contact["phone"] ?? ""),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Gọi ngay'),
                  ),
                ],
              ),
            ),

        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
