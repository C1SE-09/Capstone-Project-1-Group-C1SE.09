// frontend/lib/features/kindergarten_dashboard/widgets/admin_trend_painter.dart
// ==============================================================================
// CustomPainter vẽ biểu đồ xu hướng 7 ngày (Admin Report Trend Chart).

import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class AdminTrendPainter extends CustomPainter {
  AdminTrendPainter({required this.dark, required this.trends});

  final bool dark;
  final List<AdminReportTrendDto> trends;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPadding = 30.0;
    const topPadding = 24.0;
    const horizontalPadding = 24.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width - horizontalPadding * 2;

    final grid = Paint()
      ..color = dark ? Colors.white12 : const Color(0xFFE3E9E6)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight * i / 4;
      canvas.drawLine(Offset(horizontalPadding, y), Offset(size.width - horizontalPadding, y), grid);
    }

    final int count = trends.isNotEmpty ? trends.length : 7;
    final sentData = trends.isNotEmpty
        ? trends.map((t) => t.sentReports.toDouble()).toList()
        : <double>[12.0, 18.0, 15.0, 22.0, 20.0, 25.0, 28.0];

    final draftData = trends.isNotEmpty
        ? trends.map((t) => t.draftReports.toDouble()).toList()
        : <double>[3.0, 2.0, 4.0, 1.0, 3.0, 2.0, 2.0];

    final maxVal = [
      ...sentData,
      ...draftData,
      5.0,
    ].reduce((a, b) => a > b ? a : b);

    // Vẽ đường đã gửi (xanh brand) và bản nháp (vàng warn)
    _drawTrendLine(
      canvas: canvas,
      data: sentData,
      color: KColors.brand,
      min: 0,
      max: maxVal * 1.25,
      chartHeight: chartHeight,
      chartWidth: chartWidth,
      topPadding: topPadding,
      horizontalPadding: horizontalPadding,
      isSent: true,
    );

    _drawTrendLine(
      canvas: canvas,
      data: draftData,
      color: KColors.warn,
      min: 0,
      max: maxVal * 1.25,
      chartHeight: chartHeight,
      chartWidth: chartWidth,
      topPadding: topPadding,
      horizontalPadding: horizontalPadding,
      isSent: false,
    );

    // Vẽ nhãn ngày ở trục X
    final textStyle = TextStyle(
      color: dark ? Colors.white70 : const Color(0xFF6B7280),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    for (var i = 0; i < count; i++) {
      final x = count > 1
          ? horizontalPadding + i * chartWidth / (count - 1)
          : horizontalPadding + chartWidth / 2;

      String dateLabel;
      if (trends.isNotEmpty && i < trends.length) {
        final raw = trends[i].reportDate;
        final parts = raw.split('-');
        if (parts.length >= 3) {
          dateLabel = '${parts[2]}/${parts[1]}';
        } else {
          dateLabel = raw;
        }
      } else {
        final d = DateTime.now().subtract(Duration(days: count - 1 - i));
        dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      }

      final textSpan = TextSpan(text: dateLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - bottomPadding + 8),
      );
    }
  }

  void _drawTrendLine({
    required Canvas canvas,
    required List<double> data,
    required Color color,
    required double min,
    required double max,
    required double chartHeight,
    required double chartWidth,
    required double topPadding,
    required double horizontalPadding,
    required bool isSent,
  }) {
    if (data.isEmpty) return;
    final path = Path();
    final dot = Paint()..color = color;
    final range = max - min == 0 ? 1.0 : (max - min);

    for (var i = 0; i < data.length; i++) {
      final x = data.length > 1
          ? horizontalPadding + i * chartWidth / (data.length - 1)
          : horizontalPadding + chartWidth / 2;
      final y = topPadding + chartHeight - ((data[i] - min) / range) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Vẽ điểm tròn 2 lớp
      canvas.drawCircle(Offset(x, y), 4.5, dot);
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = Colors.white,
      );

      // Vẽ nhãn số lượng đã báo cáo ở từng điểm
      final valInt = data[i].toInt();
      final labelSpan = TextSpan(
        text: '$valInt',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelY = isSent ? y - 16 : y + 6;
      labelPainter.paint(canvas, Offset(x - labelPainter.width / 2, labelY));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant AdminTrendPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.trends != trends;
}
