import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class EditObservationSheet extends StatelessWidget {
  const EditObservationSheet({
    super.key,
    required this.title,
    required this.isClasswide,
    this.isUnmatched = false,
    required this.eatingCtrl,
    required this.sleepCtrl,
    required this.activitiesCtrl,
    required this.moodCtrl,
    required this.healthCtrl,
    required this.noteCtrl,
    required this.snippetCtrl,
  });

  final String title;
  final bool isClasswide;
  final bool isUnmatched;
  final TextEditingController eatingCtrl;
  final TextEditingController sleepCtrl;
  final TextEditingController activitiesCtrl;
  final TextEditingController moodCtrl;
  final TextEditingController healthCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController snippetCtrl;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.k.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnmatched ? context.k.warnTint : context.k.brandTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: isUnmatched ? context.k.warn : context.k.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉnh sửa · $title',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.k.ink,
                      ),
                    ),
                    Text(
                      isClasswide
                          ? 'Áp dụng cho toàn thể các bé trong lớp'
                          : isUnmatched
                              ? 'Chỉnh sửa nội dung đoạn chưa phân loại'
                              : 'Chỉnh sửa chi tiết thông tin cho bé',
                      style: TextStyle(fontSize: 12, color: context.k.inkSoft),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                tooltip: 'Đóng',
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (isUnmatched) ...[
                    _buildField(
                      context,
                      icon: Icons.chat_bubble_outline,
                      label: 'Nội dung đoạn nói',
                      controller: snippetCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildField(
                    context,
                    icon: Icons.restaurant_outlined,
                    label: 'Bữa ăn',
                    controller: eatingCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: Icons.bedtime_outlined,
                    label: 'Giấc ngủ',
                    controller: sleepCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    suffixText: 'phút',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: Icons.palette_outlined,
                    label: 'Hoạt động',
                    controller: activitiesCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: Icons.sentiment_satisfied_outlined,
                    label: 'Tâm trạng',
                    controller: moodCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: Icons.health_and_safety_outlined,
                    label: 'Sức khỏe',
                    controller: healthCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: Icons.edit_note,
                    label: 'Ghi chú cho phụ huynh',
                    controller: noteCtrl,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadii.control)),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Lưu thay đổi'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadii.control)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: context.k.brand),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.k.ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          maxLength: maxLength,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          buildCounter: maxLength != null
              ? (context,
                  {required currentLength, required isFocused, maxLength}) {
                  return Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$currentLength/$maxLength ký tự',
                      style:
                          TextStyle(fontSize: 11, color: context.k.inkSoft),
                    ),
                  );
                }
              : null,
          style: TextStyle(fontSize: 13, color: context.k.ink),
          decoration: InputDecoration(
            suffixText: suffixText,
            suffixStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.k.inkSoft),
            isDense: true,
            filled: true,
            fillColor: context.k.canvas,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          ),
        ),
      ],
    );
  }
}
