import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/category_data.dart';
import '../services/supabase_service.dart';
import 'voice_flow.dart';
import 'photo_flow.dart';
import 'invoice_flow.dart';

/// 對應原本 AddSheet 的「手動輸入」模式。
/// 語音／發票 QR／CSV 匯入模式先留在這裡當作之後擴充的入口（見下方 TODO）。
class AddSheet extends StatefulWidget {
  final String userId;
  final String defaultType; // 'expense' | 'income'
  const AddSheet({super.key, required this.userId, required this.defaultType});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  String _mode = 'manual'; // 'manual' | 'voice' | 'photo' | 'invoice'
  late String _type;
  late String _category;
  String? _subcategory;
  Map<String, List<String>> _extraSubcats = {};
  final _noteController = TextEditingController();
  final _customSubController = TextEditingController();
  bool _showCustomInput = false;
  DateTime _entryDate = DateTime.now();
  bool _saving = false;
  bool _continuous = false;

  String _display = '0';
  double? _stored;
  String? _pendingOp;
  bool _freshEntry = true;

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    _category = _type == 'income' ? incomeCategories.first.name : expenseCategories.first.name;
    _loadCustomSubcats();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _customSubController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomSubcats() async {
    final data = await SupabaseService.instance.fetchCustomSubcategories(widget.userId);
    if (mounted) setState(() => _extraSubcats = data);
  }

  List<String> get _subOptions => [
        ...(subcategoryMap[_category] ?? []),
        ...(_extraSubcats[_category] ?? []),
      ];

  List<CategoryItem> get _categoryList => _type == 'income' ? incomeCategories : expenseCategories;

  // ---------------- 計算機邏輯 ----------------

  void _pressDigit(String d) {
    setState(() {
      if (_freshEntry) {
        _freshEntry = false;
        _display = d == '.' ? '0.' : d;
        return;
      }
      if (d == '.' && _display.contains('.')) return;
      if (_display == '0' && d != '.') {
        _display = d;
        return;
      }
      if (_display.length >= 10) return;
      _display += d;
    });
  }

  void _pressOperator(String op) {
    setState(() {
      if (_pendingOp != null && _freshEntry) {
        _pendingOp = op;
        return;
      }
      final current = double.tryParse(_display) ?? 0;
      if (_pendingOp != null && !_freshEntry) {
        _stored = _compute(_stored ?? 0, current, _pendingOp!);
      } else {
        _stored = current;
      }
      _pendingOp = op;
      _freshEntry = true;
      _display = _fmtNum(_stored ?? 0);
    });
  }

  double _compute(double a, double b, String op) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      default:
        return b;
    }
  }

  void _pressAC() {
    setState(() {
      _display = '0';
      _stored = null;
      _pendingOp = null;
      _freshEntry = true;
    });
  }

  void _pressBackspace() {
    setState(() {
      _display = _display.length <= 1 ? '0' : _display.substring(0, _display.length - 1);
    });
  }

  double _finalAmount() {
    final current = double.tryParse(_display) ?? 0;
    if (_pendingOp != null && _stored != null) {
      if (_freshEntry) return _stored!;
      return _compute(_stored!, current, _pendingOp!);
    }
    return current;
  }

  String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  // ---------------- 儲存 ----------------

  Future<void> _addCustomSubcategory() async {
    final value = _customSubController.text.trim();
    if (value.isEmpty) return;
    if (_subOptions.contains(value)) {
      setState(() {
        _subcategory = value;
        _customSubController.clear();
        _showCustomInput = false;
      });
      return;
    }
    await SupabaseService.instance.addCustomSubcategory(widget.userId, _category, value);
    setState(() {
      _extraSubcats[_category] = [...(_extraSubcats[_category] ?? []), value];
      _subcategory = value;
      _customSubController.clear();
      _showCustomInput = false;
    });
  }

  Future<void> _save() async {
    final amount = _finalAmount();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入金額')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.insertTransaction(
        userId: widget.userId,
        amount: amount,
        category: _category,
        subcategory: _subcategory,
        merchant: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        type: _type,
        source: 'manual',
        transactionDate:
            '${_entryDate.year}-${_entryDate.month.toString().padLeft(2, '0')}-${_entryDate.day.toString().padLeft(2, '0')}',
      );
      if (_continuous) {
        _pressAC();
        _noteController.clear();
        if (mounted) {
          setState(() {
            _subcategory = null;
            _entryDate = DateTime.now();
            _saving = false;
          });
        }
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存失敗，請檢查主控台')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_entryDate.year}-${_entryDate.month.toString().padLeft(2, '0')}-${_entryDate.day.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(children: [
          // 頂部
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mossDark, AppColors.moss, AppColors.mossDeep],
              ),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Row(children: [
                  _modeIconButton('manual', Icons.edit),
                  const SizedBox(width: 6),
                  _modeIconButton('voice', Icons.mic),
                  const SizedBox(width: 6),
                  _modeIconButton('photo', Icons.qr_code),
                  const SizedBox(width: 6),
                  _modeIconButton('invoice', Icons.receipt_long),
                ]),
              ]),
              if (_mode == 'manual') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _segButton('支出', _type == 'expense', () => setState(() {
                          _type = 'expense';
                          _category = expenseCategories.first.name;
                          _subcategory = null;
                        })),
                    _segButton('收入', _type == 'income', () => setState(() {
                          _type = 'income';
                          _category = incomeCategories.first.name;
                          _subcategory = null;
                        })),
                  ]),
                ),
              ],
            ]),
          ),
          // 內容區：手動模式顯示分類/細項，其他模式顯示對應的流程元件
          Expanded(
            child: _mode != 'manual'
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildAlternateModeContent(),
                  )
                : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8,
                  children: _categoryList.map((cat) {
                    final isSelected = _category == cat.name;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _category = cat.name;
                        _subcategory = null;
                      }),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.moss : AppColors.card,
                            border: Border.all(color: isSelected ? AppColors.moss : AppColors.lineSoft, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(cat.icon, size: 20, color: isSelected ? Colors.white : AppColors.mossDark),
                        ),
                        const SizedBox(height: 6),
                        Text(cat.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: isSelected ? AppColors.mossDark : AppColors.inkSoft,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (_subOptions.isNotEmpty || true)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ..._subOptions.map((sub) {
                      final isSelected = _subcategory == sub;
                      return GestureDetector(
                        onTap: () => setState(() => _subcategory = isSelected ? null : sub),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.moss : AppColors.card,
                            border: Border.all(color: isSelected ? AppColors.moss : AppColors.line),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(sub,
                              style: TextStyle(fontSize: 12.5, color: isSelected ? AppColors.paper : AppColors.inkSoft)),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: () => setState(() => _showCustomInput = !_showCustomInput),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.clay, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('+ 自訂', style: TextStyle(fontSize: 12.5, color: AppColors.clay)),
                      ),
                    ),
                  ]),
                if (_showCustomInput)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _customSubController,
                          decoration: InputDecoration(
                            hintText: '輸入 $_category 的自訂細項',
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (_) => _addCustomSubcategory(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustomSubcategory,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss, foregroundColor: Colors.white),
                        child: const Text('新增'),
                      ),
                    ]),
                  ),
                const SizedBox(height: 14),
              ]),
            ),
          ),
          // 底部：日期、備註、計算機（只在手動模式顯示）
          if (_mode == 'manual')
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.line))),
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.mossMist, borderRadius: BorderRadius.circular(999)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.mossDark),
                        const SizedBox(width: 6),
                        Text(dateStr,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mossDark)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.paperDeep, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(hintText: '填寫備註', border: InputBorder.none),
                      ),
                    ),
                    Text('${_type == 'income' ? '+' : '-'}$_display',
                        style: TextStyle(
                            fontFamily: monoFontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _type == 'income' ? AppColors.moss : AppColors.clayDeep)),
                  ]),
                ),
                const SizedBox(height: 12),
                _buildCalcGrid(),
                const SizedBox(height: 6),
                Text(_continuous ? '連續記帳中，儲存後不會關閉視窗' : '長按「完成」啟用連續記帳',
                    style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _modeIconButton(String mode, IconData icon) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: active ? AppColors.mossDark : Colors.white),
      ),
    );
  }

  Widget _buildAlternateModeContent() {
    switch (_mode) {
      case 'voice':
        return VoiceFlow(userId: widget.userId);
      case 'photo':
        return PhotoFlow(userId: widget.userId);
      case 'invoice':
        return InvoiceFlow(userId: widget.userId);
      default:
        return const SizedBox.shrink();
    }
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

  Widget _key(String label, VoidCallback onTap, {Color? bg, Color? fg}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg ?? AppColors.card,
        foregroundColor: fg ?? AppColors.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 54),
      ),
      child: Text(label, style: const TextStyle(fontSize: 20, fontFamily: monoFontFamily)),
    );
  }

  /// 簡化版計算機：僅支援 + - 兩個運算子（原版有 × ÷，可依同樣模式在 _compute 補上）
  Widget _buildCalcGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: [
        _key('7', () => _pressDigit('7')),
        _key('8', () => _pressDigit('8')),
        _key('9', () => _pressDigit('9')),
        _key('⌫', _pressBackspace, bg: AppColors.clayLight, fg: AppColors.clayDeep),
        _key('4', () => _pressDigit('4')),
        _key('5', () => _pressDigit('5')),
        _key('6', () => _pressDigit('6')),
        _key('-', () => _pressOperator('-'), bg: AppColors.mossMist, fg: AppColors.mossDark),
        _key('1', () => _pressDigit('1')),
        _key('2', () => _pressDigit('2')),
        _key('3', () => _pressDigit('3')),
        _key('+', () => _pressOperator('+'), bg: AppColors.mossMist, fg: AppColors.mossDark),
        _key('AC', _pressAC, bg: AppColors.clayLight, fg: AppColors.clayDeep),
        _key('0', () => _pressDigit('0')),
        _key('.', () => _pressDigit('.')),
        GestureDetector(
          onLongPress: () => setState(() => _continuous = true),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(_saving ? '...' : '完成', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
