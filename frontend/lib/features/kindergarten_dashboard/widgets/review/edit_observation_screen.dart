import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class EditObservationScreen extends StatelessWidget {
  const EditObservationScreen({
    super.key,
    required this.title,
    this.isUnmatched = false,
    required this.eatingCtrl,
    required this.sleepCtrl,
    required this.sleepDescriptionCtrl,
    required this.activitiesCtrl,
    required this.moodCtrl,
    required this.healthCtrl,
    required this.noteCtrl,
    required this.snippetCtrl,
  });

  final String title;
  final bool isUnmatched;
  final TextEditingController eatingCtrl;
  final TextEditingController sleepCtrl;
  final TextEditingController sleepDescriptionCtrl;
  final TextEditingController activitiesCtrl;
  final TextEditingController moodCtrl;
  final TextEditingController healthCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController snippetCtrl;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Scaffold(
      backgroundColor: k.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context, false),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: SvgPicture.asset('assets/garden_voice/edit_back.svg'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chỉnh sửa báo cáo',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('$title · Hôm nay',
                            style: TextStyle(fontSize: 12, color: k.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  if (isUnmatched) ...[
                    _buildField(
                      context,
                      icon: Icon(Icons.chat_bubble_outline,
                          size: 18, color: context.k.brand),
                      label: 'Nội dung đoạn nói',
                      controller: snippetCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildField(
                    context,
                    icon: _foodIcon(),
                    label: 'Ăn uống',
                    controller: eatingCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon:
                        SvgPicture.asset('assets/garden_voice/review_moon.svg'),
                    label: 'Giấc ngủ',
                    controller: sleepDescriptionCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Thời lượng (phút)',
                          style: TextStyle(fontSize: 12, color: k.inkSoft)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          key: const ValueKey('sleep-duration-minutes'),
                          controller: sleepCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _fieldDecoration(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    context,
                    icon:
                        SvgPicture.asset('assets/garden_voice/edit_health.svg'),
                    label: 'Sức khỏe',
                    controller: healthCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: const SizedBox(width: 22, height: 22),
                    label: 'Tâm trạng',
                    controller: moodCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: SvgPicture.asset(
                        'assets/garden_voice/review_artist_palette.svg'),
                    label: 'Hoạt động',
                    controller: activitiesCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    context,
                    icon: const SizedBox(width: 22, height: 22),
                    label: 'Ghi chú của cô',
                    controller: noteCtrl,
                    maxLines: 3,
                    maxLength: 500,
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: k.brand,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Lưu thay đổi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodIcon() => SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 2,
              child: SvgPicture.asset('assets/garden_voice/review_spoon.svg'),
            ),
            Positioned(
              left: 2,
              top: 10,
              child: SvgPicture.asset('assets/garden_voice/review_bowl.svg'),
            ),
          ],
        ),
      );

  InputDecoration _fieldDecoration(BuildContext context) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.k.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.k.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.k.brand, width: 1.5),
        ),
      );

  Widget _buildField(
    BuildContext context, {
    required Widget icon,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 22, height: 22, child: Center(child: icon)),
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
          buildCounter: maxLength != null
              ? (context,
                  {required currentLength, required isFocused, maxLength}) {
                  return Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$currentLength/$maxLength ký tự',
                      style: TextStyle(fontSize: 11, color: context.k.inkSoft),
                    ),
                  );
                }
              : null,
          style: TextStyle(fontSize: 13, color: context.k.ink),
          decoration: _fieldDecoration(context),
        ),
      ],
    );
  }
}
