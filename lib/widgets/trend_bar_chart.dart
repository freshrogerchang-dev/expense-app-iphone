import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrendPoint {
  final String label;
  final double amount;
  TrendPoint(this.label, this.amount);
}

/// 對應原本 DynamicTrendChart 裡手刻的 SVG 長條圖
class TrendBarChart extends StatelessWidget {
  final List<TrendPoint> data;
  const TrendBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: CustomPaint(
        size: const Size(double.infinity, 130),
        painter: _TrendPainter(data),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> data;
  _TrendPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.map((e) => e.amount).fold<double>(1, (a, b) => a > b ? a : b);
    const barW = 32.0;
    const gap = 14.0;
    final totalW = data.length * barW + (data.length - 1) * gap;
    final startX = (size.width - totalW) / 2;
    const baselineY = 102.0;
    const chartH = 80.0;

    final axisPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(startX - 4, baselineY), Offset(startX + totalW + 4, baselineY), axisPaint);

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final h = (point.amount / maxVal) * chartH;
      final x = startX + i * (barW + gap);
      final isLast = i == data.length - 1;

      final barPaint = Paint()
        ..color = isLast ? AppColors.moss : (point.amount > 0 ? AppColors.mossLight : AppColors.paper);
      final barHeight = h < 2 ? 2.0 : h;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, baselineY - barHeight, barW, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      final amountText = point.amount > 0
          ? (point.amount >= 1000 ? '${(point.amount / 1000).toStringAsFixed(1)}k' : point.amount.round().toString())
          : '0';
      _drawText(canvas, amountText, Offset(x + barW / 2, baselineY - barHeight - 16),
          const TextStyle(fontSize: 10, fontFamily: monoFontFamily, color: AppColors.inkSoft, fontWeight: FontWeight.bold));

      _drawText(canvas, point.label, Offset(x + barW / 2, baselineY + 4),
          const TextStyle(fontSize: 11, color: AppColors.inkSoft, fontWeight: FontWeight.bold));
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.data != data;
}
