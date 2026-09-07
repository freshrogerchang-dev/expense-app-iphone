import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/category_data.dart';

class CategorySlice {
  final String name;
  final double amount;
  final double percentage;
  final Color color;
  final double startAngle; // radians
  final double sweepAngle; // radians
  CategorySlice({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
  });
}

/// 對應原本的 PieChartBreakdown：左邊圓餅圖、右邊圖例，點擊任一邊會彈出詳情視窗
class CategoryPieBreakdown extends StatefulWidget {
  final String title;
  final List<MapEntry<String, double>> categoryStats; // 已排序，由大到小
  final double totalAmount;
  const CategoryPieBreakdown({
    super.key,
    required this.title,
    required this.categoryStats,
    required this.totalAmount,
  });

  @override
  State<CategoryPieBreakdown> createState() => _CategoryPieBreakdownState();
}

class _CategoryPieBreakdownState extends State<CategoryPieBreakdown> {
  String? _activeSlice;

  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryStats.isEmpty || widget.totalAmount == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('尚無分類支出', style: TextStyle(color: AppColors.inkFaint, fontSize: 13))),
      );
    }

    double cumulative = 0;
    final slices = widget.categoryStats.map((e) {
      final pct = e.value / widget.totalAmount;
      final sweep = pct * 2 * 3.1415926535;
      final slice = CategorySlice(
        name: e.key,
        amount: e.value,
        percentage: pct * 100,
        color: getCategoryColor(e.key),
        startAngle: cumulative,
        sweepAngle: sweep,
      );
      cumulative += sweep;
      return slice;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 140,
            height: 140,
            child: GestureDetector(
              onTapUp: (details) => _handleTap(details, slices, const Size(140, 140)),
              child: CustomPaint(
                size: const Size(140, 140),
                painter: _PiePainter(slices: slices, activeSlice: _activeSlice),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: slices.map((s) {
                final isActive = _activeSlice == s.name;
                final isFaded = _activeSlice != null && !isActive;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _showDetail(s),
                    child: Opacity(
                      opacity: isFaded ? 0.3 : 1,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: s.name,
                                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
                              TextSpan(
                                  text: '  (${s.percentage.toStringAsFixed(s.percentage % 1 == 0 ? 0 : 1)}%)',
                                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                            ])),
                            const SizedBox(height: 2),
                            Text('NT\$ ${_fmt(s.amount)}',
                                style: const TextStyle(
                                    fontFamily: monoFontFamily, fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ]),
    );
  }

  void _handleTap(TapUpDetails details, List<CategorySlice> slices, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = details.localPosition - center;
    final radius = size.width / 2;
    if (pos.distance < radius * 0.35 || pos.distance > radius) return; // 中間挖空區域或超出範圍不算
    var angle = pos.direction + 3.1415926535 / 2; // 從 12 點方向開始算
    if (angle < 0) angle += 2 * 3.1415926535;
    for (final s in slices) {
      if (angle >= s.startAngle && angle < s.startAngle + s.sweepAngle) {
        _showDetail(s);
        return;
      }
    }
  }

  void _showDetail(CategorySlice slice) {
    setState(() => _activeSlice = _activeSlice == slice.name ? null : slice.name);
    if (_activeSlice == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: slice.color, borderRadius: BorderRadius.circular(6))),
          const SizedBox(width: 8),
          Expanded(child: Text('${slice.name} 支出詳情', style: const TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title.contains('半年') ? '近半年總計' : '本月總計', style: const TextStyle(fontSize: 13, color: AppColors.inkFaint)),
          const SizedBox(height: 4),
          Text('NT\$ ${_fmt(slice.amount)}',
              style: const TextStyle(fontFamily: monoFontFamily, fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 12),
          const Text('分類佔比', style: TextStyle(fontSize: 13, color: AppColors.inkFaint)),
          const SizedBox(height: 4),
          Text('${slice.percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontFamily: monoFontFamily, fontSize: 18, fontWeight: FontWeight.bold, color: slice.color)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      ),
    ).then((_) => setState(() => _activeSlice = null));
  }
}

class _PiePainter extends CustomPainter {
  final List<CategorySlice> slices;
  final String? activeSlice;
  _PiePainter({required this.slices, required this.activeSlice});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (final s in slices) {
      final isActive = activeSlice == s.name;
      final isFaded = activeSlice != null && !isActive;
      final paint = Paint()
        ..color = s.color.withOpacity(isFaded ? 0.3 : 1)
        ..style = PaintingStyle.fill;
      // 從 12 點方向開始畫（-90 度）
      final start = s.startAngle - 3.1415926535 / 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: isActive ? radius * 1.03 : radius), start, s.sweepAngle, true, paint);
    }

    // 中間挖空，做成甜甜圈圖
    final holePaint = Paint()..color = AppColors.card;
    canvas.drawCircle(center, radius * 0.5, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.activeSlice != activeSlice;
}
