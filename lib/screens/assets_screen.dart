import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/asset_item.dart';
import '../services/supabase_service.dart';
import 'asset_add_sheet.dart';

class AssetsScreen extends StatefulWidget {
  final String userId;
  const AssetsScreen({super.key, required this.userId});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  bool _loading = true;
  double _netFlow = 0;
  List<AssetItem> _assets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txs = await SupabaseService.instance.fetchTransactions(widget.userId);
    final assets = await SupabaseService.instance.fetchAssets(widget.userId);
    final income = txs.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final expense = txs.where((t) => t.type != 'income').fold<double>(0, (s, t) => s + t.amount);
    if (!mounted) return;
    setState(() {
      _netFlow = income - expense;
      _assets = assets;
      _loading = false;
    });
  }

  Future<void> _deleteAsset(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('確定要刪除這筆資產嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除', style: TextStyle(color: AppColors.clayDeep))),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.instance.deleteAsset(id);
    setState(() => _assets.removeWhere((a) => a.id == id));
  }

  Future<void> _openAddSheet() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => AssetAddSheet(userId: widget.userId)),
    );
    if (saved == true) _load();
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

    final bankAssets = _assets.where((a) => a.assetType == 'bank').toList();
    final stockAssets = _assets.where((a) => a.assetType == 'stock').toList();
    final assetsTotal = _assets.fold<double>(0, (s, a) => s + a.amount);
    final netTotal = _netFlow + assetsTotal;

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
          children: [
            const Text('資產', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.ink)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.mossDark, AppColors.moss, AppColors.mossDeep],
                ),
                boxShadow: AppShadows.lg,
              ),
              child: Column(children: [
                const Text('總淨資產', style: TextStyle(fontSize: 13.5, color: AppColors.mossLight, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('NT\$ ${_fmt(netTotal)}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: monoFontFamily)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: AppColors.mossLight), children: [
                    const TextSpan(text: '現金流 '),
                    TextSpan(text: _fmt(_netFlow), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: monoFontFamily)),
                  ])),
                  const SizedBox(width: 16),
                  Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: AppColors.mossLight), children: [
                    const TextSpan(text: '資產 '),
                    TextSpan(text: _fmt(assetsTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: monoFontFamily)),
                  ])),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: const [
              Icon(Icons.account_balance, size: 16, color: AppColors.moss),
              SizedBox(width: 6),
              Text('銀行資產', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
            ]),
            const SizedBox(height: 10),
            _assetListCard(bankAssets, emptyText: '尚未新增銀行資產', valueColor: AppColors.mossDark),
            const SizedBox(height: 18),
            Row(children: const [
              Icon(Icons.show_chart, size: 16, color: AppColors.clay),
              SizedBox(width: 6),
              Text('證券／股票（不計入現金流）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
            ]),
            const SizedBox(height: 10),
            _assetListCard(stockAssets, emptyText: '尚未新增股票資產', valueColor: AppColors.clayDeep, showQuantity: true),
          ],
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 16,
        child: Center(
          child: ElevatedButton.icon(
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('新增資產', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moss,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 8,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _assetListCard(List<AssetItem> items, {required String emptyText, required Color valueColor, bool showQuantity = false}) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.sm),
        child: Center(child: Text(emptyText, style: const TextStyle(color: AppColors.inkFaint, fontSize: 13))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.md),
      child: Column(
        children: items.map((a) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lineSoft))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  if (showQuantity && a.quantity != null)
                    Text('${_fmt(a.quantity!)} 股 × ${_fmt(a.unitPrice ?? 0)}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
                ]),
              ),
              Text('NT\$ ${_fmt(a.amount)}', style: TextStyle(fontFamily: monoFontFamily, fontSize: 14.5, fontWeight: FontWeight.bold, color: valueColor)),
              IconButton(onPressed: () => _deleteAsset(a.id), icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.clay)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
