import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/transaction_item.dart';
import '../services/supabase_service.dart';
import '../utils/category_data.dart';
import 'add_sheet.dart';

class BookkeepingScreen extends StatefulWidget {
  final String userId;
  const BookkeepingScreen({super.key, required this.userId});

  @override
  State<BookkeepingScreen> createState() => _BookkeepingScreenState();
}

class _BookkeepingScreenState extends State<BookkeepingScreen> {
  List<TransactionItem> _txs = [];
  bool _loading = true;
  String _viewType = 'expense'; // 'expense' | 'income'
  String? _categoryFilter;
  final Set<String> _selectedIds = {};
  late String _currentMonth; // 'YYYY-MM'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txs = await SupabaseService.instance.fetchTransactions(widget.userId);
      if (!mounted) return;
      setState(() {
        _txs = txs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入失敗：$e')));
    }
  }

  List<TransactionItem> get _monthTxs =>
      _txs.where((t) => t.transactionDate.startsWith(_currentMonth)).toList();

  List<TransactionItem> get _monthExpense => _monthTxs.where((t) => t.type != 'income').toList();

  List<TransactionItem> get _monthIncome => _monthTxs.where((t) => t.type == 'income').toList();

  List<TransactionItem> get _viewTxs => _viewType == 'income' ? _monthIncome : _monthExpense;

  List<TransactionItem> get _filteredTxs => _categoryFilter == null
      ? _viewTxs
      : _viewTxs.where((t) => (t.category ?? '未分類') == _categoryFilter).toList();

  void _changeMonth(int delta) {
    final parts = _currentMonth.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1] + delta, 1);
    setState(() {
      _currentMonth = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      _selectedIds.clear();
      _categoryFilter = null;
    });
  }

  Future<void> _deleteOne(String id) async {
    final confirmed = await _confirm('確定要刪除這筆紀錄嗎？');
    if (!confirmed) return;
    await SupabaseService.instance.deleteTransaction(id);
    setState(() {
      _txs.removeWhere((t) => t.id == id);
      _selectedIds.remove(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await _confirm('確定要刪除選取的 ${_selectedIds.length} 筆紀錄嗎？');
    if (!confirmed) return;
    await SupabaseService.instance.deleteTransactions(_selectedIds.toList());
    setState(() {
      _txs.removeWhere((t) => _selectedIds.contains(t.id));
      _selectedIds.clear();
    });
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: AppColors.clayDeep)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openAddSheet() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddSheet(userId: widget.userId, defaultType: _viewType),
      ),
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

    final expenseTotal = _monthExpense.fold<double>(0, (s, t) => s + t.amount);
    final incomeTotal = _monthIncome.fold<double>(0, (s, t) => s + t.amount);
    final balance = incomeTotal - expenseTotal;
    final heroTotal = _viewType == 'income' ? incomeTotal : expenseTotal;

    final byCategory = <String, double>{};
    for (final t in _viewTxs) {
      final key = t.category ?? '未分類';
      byCategory[key] = (byCategory[key] ?? 0) + t.amount;
    }
    final categoryTotals = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final groups = <String, List<TransactionItem>>{};
    for (final t in _filteredTxs) {
      groups.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    final groupEntries = groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    final parts = _currentMonth.split('-');
    final isAllSelected = _filteredTxs.isNotEmpty && _selectedIds.length == _filteredTxs.length;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
            children: [
              // 月份切換
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, color: AppColors.inkSoft, size: 26),
                    ),
                    Text(
                      '${parts[0]} 年 ${int.parse(parts[1])} 月',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, fontFamily: monoFontFamily, color: AppColors.ink),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 26),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Hero 卡片
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.mossDark, AppColors.moss, AppColors.mossDeep],
                  ),
                  boxShadow: AppShadows.lg,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration:
                          BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _segButton('支出', _viewType == 'expense', () => setState(() {
                              _viewType = 'expense';
                              _categoryFilter = null;
                              _selectedIds.clear();
                            })),
                        _segButton('收入', _viewType == 'income', () => setState(() {
                              _viewType = 'income';
                              _categoryFilter = null;
                              _selectedIds.clear();
                            })),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Text(_viewType == 'income' ? '本月總收入' : '本月總支出',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.mossLight, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('NT\$ ${_fmt(heroTotal)}',
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: monoFontFamily)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: AppColors.mossLight), children: [
                        const TextSpan(text: '收入 '),
                        TextSpan(
                            text: _fmt(incomeTotal),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontFamily: monoFontFamily)),
                      ])),
                      const SizedBox(width: 18),
                      Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: AppColors.mossLight), children: [
                        const TextSpan(text: '結餘 '),
                        TextSpan(
                            text: _fmt(balance),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontFamily: monoFontFamily)),
                      ])),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 分類 chips
              if (categoryTotals.isNotEmpty)
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryTotals.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) {
                      final entry = categoryTotals[i];
                      final isSelected = _categoryFilter == entry.key;
                      final accent = getCategoryColor(entry.key);
                      final icon = categoryIconMap[entry.key] ?? Icons.more_horiz;
                      return GestureDetector(
                        onTap: () => setState(() => _categoryFilter = isSelected ? null : entry.key),
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.mossMist : AppColors.card,
                            border: Border.all(color: isSelected ? accent : AppColors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isSelected ? AppShadows.md : AppShadows.sm,
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration:
                                  BoxDecoration(color: isSelected ? accent : AppColors.mossMist, shape: BoxShape.circle),
                              child: Icon(icon, size: 15, color: isSelected ? Colors.white : accent),
                            ),
                            const SizedBox(height: 8),
                            Text(entry.key,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? AppColors.mossDark : AppColors.inkSoft)),
                            Text(_fmt(entry.value),
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: monoFontFamily,
                                    color: AppColors.ink)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (_categoryFilter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('目前篩選分類：$_categoryFilter',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.mossDark, fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () => setState(() => _categoryFilter = null),
                      child: const Text('顯示全部', style: TextStyle(color: AppColors.clay)),
                    ),
                  ]),
                ),
              if (_filteredTxs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        if (isAllSelected) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds
                            ..clear()
                            ..addAll(_filteredTxs.map((t) => t.id));
                        }
                      }),
                      child: Row(children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isAllSelected ? AppColors.moss : AppColors.paper,
                            border: Border.all(color: isAllSelected ? AppColors.moss : AppColors.line, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isAllSelected ? const Icon(Icons.check, size: 14, color: AppColors.paper) : null,
                        ),
                        const SizedBox(width: 8),
                        Text('全選篩選結果 (${_filteredTxs.length})',
                            style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    if (_selectedIds.isNotEmpty)
                      TextButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete, size: 16, color: AppColors.clayDeep),
                        label: Text('刪除選取 (${_selectedIds.length})',
                            style: const TextStyle(color: AppColors.clayDeep, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(backgroundColor: AppColors.clayLight),
                      ),
                  ]),
                ),
              const SizedBox(height: 8),
              // 交易列表
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppShadows.lg,
                ),
                child: groupEntries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            _categoryFilter != null
                                ? '此分類在 ${int.parse(parts[1])} 月尚無紀錄'
                                : '${int.parse(parts[1])} 月還沒有${_viewType == 'income' ? '收入' : '支出'}紀錄',
                            style: const TextStyle(color: AppColors.inkFaint, fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                    : Column(
                        children: groupEntries.map((entry) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(entry.key,
                                  style: const TextStyle(fontSize: 13, color: AppColors.inkFaint, letterSpacing: 1.5)),
                            ),
                            ...entry.value.map((tx) => _TxRow(
                                  tx: tx,
                                  selected: _selectedIds.contains(tx.id),
                                  onToggle: () => setState(() {
                                    if (_selectedIds.contains(tx.id)) {
                                      _selectedIds.remove(tx.id);
                                    } else {
                                      _selectedIds.add(tx.id);
                                    }
                                  }),
                                  onDelete: () => _deleteOne(tx.id),
                                )),
                          ]);
                        }).toList(),
                      ),
              ),
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
              icon: const Icon(Icons.mic, color: Colors.white),
              label: const Text('記一筆', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moss,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? AppColors.mossDark : AppColors.mossLight)),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionItem tx;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _TxRow({required this.tx, required this.selected, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final icon = categoryIconMap[tx.category] ?? Icons.more_horiz;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lineSoft))),
      child: Row(children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.moss : AppColors.paper,
              border: Border.all(color: selected ? AppColors.moss : AppColors.line, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: selected ? const Icon(Icons.check, size: 14, color: AppColors.paper) : null,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.mossLight, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: AppColors.mossDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.displayName,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Text(tx.category ?? '未分類', style: const TextStyle(fontSize: 13, color: AppColors.inkFaint)),
              if (tx.subcategory != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.mossMist, borderRadius: BorderRadius.circular(4)),
                  child: Text(tx.subcategory!,
                      style: const TextStyle(fontSize: 12, color: AppColors.mossDark, fontWeight: FontWeight.bold)),
                ),
              ]
            ]),
          ]),
        ),
        Text('${isIncome ? '+' : '-'}${tx.amount.round()}',
            style: TextStyle(
                fontFamily: monoFontFamily,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isIncome ? AppColors.moss : AppColors.clayDeep)),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.clay)),
      ]),
    );
  }
}
