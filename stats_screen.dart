import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/transaction_item.dart';
import '../services/supabase_service.dart';
import '../widgets/trend_bar_chart.dart';
import '../widgets/category_pie_breakdown.dart';

const Map<String, String> _sourceLabelMap = {
  'invoice_import': '發票存摺',
  'photo': '發票二維條碼',
  'manual': '手動輸入',
};

const Map<String, Color> _sourceColorMap = {
  'invoice_import': AppColors.moss,
  'photo': AppColors.clay,
  'manual': AppColors.inkFaint,
};

class StatsScreen extends StatefulWidget {
  final String userId;
  const StatsScreen({super.key, required this.userId});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _loading = true;
  List<TransactionItem> _allExpense = [];
  late String _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txs = await SupabaseService.instance.fetchTransactions(widget.userId);
    if (!mounted) return;
    setState(() {
      _allExpense = txs.where((t) => t.type != 'income').toList();
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    final parts = _currentMonth.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1] + delta, 1);
    setState(() => _currentMonth = '${d.year}-${d.month.toString().padLeft(2, '0')}');
  }

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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.moss));
    }

    final parts = _currentMonth.split('-');
    final displayYear = int.parse(parts[0]);
    final displayMon = int.parse(parts[1]);

    final monthTxs = _allExpense.where((t) => t.transactionDate.startsWith(_currentMonth)).toList();
    final monthTotal = monthTxs.fold<double>(0, (s, t) => s + t.amount);

    final prevDate = DateTime(displayYear, displayMon - 1, 1);
    final prevKey = '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';
    final prevTotal =
        _allExpense.where((t) => t.transactionDate.startsWith(prevKey)).fold<double>(0, (s, t) => s + t.amount);
    final double? diffRate = prevTotal > 0 ? ((monthTotal - prevTotal) / prevTotal) * 100 : null;

    // 近六個月趨勢與分類統計
    final trendPoints = <TrendPoint>[];
    double sixMonthTotal = 0;
    final sixMonthCatMap = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(displayYear, displayMon - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final label = '${d.month}月';
      final mTxs = _allExpense.where((t) => t.transactionDate.startsWith(key)).toList();
      final mTotal = mTxs.fold<double>(0, (s, t) => s + t.amount);
      sixMonthTotal += mTotal;
      trendPoints.add(TrendPoint(label, mTotal));
      for (final t in mTxs) {
        final cat = t.category ?? '其他';
        sixMonthCatMap[cat] = (sixMonthCatMap[cat] ?? 0) + t.amount;
      }
    }

    final monthCatMap = <String, double>{};
    for (final t in monthTxs) {
      final cat = t.category ?? '其他';
      monthCatMap[cat] = (monthCatMap[cat] ?? 0) + t.amount;
    }
    final monthCatStats = monthCatMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sixMonthCatStats = sixMonthCatMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // 記帳來源分布
    final sourceCount = <String, int>{'invoice_import': 0, 'photo': 0, 'manual': 0};
    for (final t in monthTxs) {
      final s = t.source;
      if (sourceCount.containsKey(s)) sourceCount[s] = sourceCount[s]! + 1;
    }
    final totalSourceCount = monthTxs.isEmpty ? 1 : monthTxs.length;
    final sourceStats = sourceCount.entries.where((e) => e.value > 0).map((e) {
      return _SourceStat(
        id: e.key,
        label: _sourceLabelMap[e.key] ?? '手動輸入',
        pct: (e.value / totalSourceCount * 100).round(),
        color: _sourceColorMap[e.key] ?? AppColors.inkFaint,
      );
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const Text('統計', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.md),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left, color: AppColors.inkSoft)),
              Text('$displayYear 年 $displayMon 月',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: monoFontFamily, color: AppColors.ink)),
              IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right, color: AppColors.inkSoft)),
            ]),
          ),
          const SizedBox(height: 16),
          Column(children: [
            const Text('月支出總額', style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('NT\$ ${_fmt(monthTotal)}',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: AppColors.ink, fontFamily: monoFontFamily)),
            if (diffRate != null) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(diffRate >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 15, color: diffRate >= 0 ? AppColors.clay : AppColors.moss),
                const SizedBox(width: 6),
                Text('較上月 ${diffRate >= 0 ? '+' : ''}${diffRate.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: diffRate >= 0 ? AppColors.clay : AppColors.moss)),
              ]),
            ],
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
                color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('近半年支出總計', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              const SizedBox(height: 4),
              Text('NT\$ ${_fmt(sixMonthTotal)}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.ink)),
              const SizedBox(height: 8),
              TrendBarChart(data: trendPoints),
            ]),
          ),
          const SizedBox(height: 18),
          CategoryPieBreakdown(title: '本月分類佔比', categoryStats: monthCatStats, totalAmount: monthTotal),
          const SizedBox(height: 18),
          CategoryPieBreakdown(title: '近半年分類佔比', categoryStats: sixMonthCatStats, totalAmount: sixMonthTotal),
          const SizedBox(height: 18),
          if (sourceStats.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('記帳來源分布', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 12,
                    child: Row(children: sourceStats.map((s) => Expanded(flex: s.pct, child: Container(color: s.color))).toList()),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: sourceStats.map((s) {
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(s.label, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Text('${s.pct}%', style: const TextStyle(fontFamily: monoFontFamily, fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    ]);
                  }).toList(),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _SourceStat {
  final String id;
  final String label;
  final int pct;
  final Color color;
  _SourceStat({required this.id, required this.label, required this.pct, required this.color});
}
