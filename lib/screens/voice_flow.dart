import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../utils/category_data.dart';
import '../services/supabase_service.dart';

/// 對應原本的 parseVoiceDate()：解析「昨天」「前天」「3月5號」等中文日期用語
DateTime _parseVoiceDate(String text) {
  var now = DateTime.now();
  if (text.contains('前天')) {
    return now.subtract(const Duration(days: 2));
  }
  if (text.contains('昨天')) {
    return now.subtract(const Duration(days: 1));
  }
  final m1 = RegExp(r'(\d{1,2})月(\d{1,2})[號日]?').firstMatch(text);
  final m2 = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(text);
  final m = m1 ?? m2;
  if (m != null) {
    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    return DateTime(now.year, month, day);
  }
  return now;
}

class VoiceFlow extends StatefulWidget {
  final String userId;
  const VoiceFlow({super.key, required this.userId});

  @override
  State<VoiceFlow> createState() => _VoiceFlowState();
}

class _VoiceFlowState extends State<VoiceFlow> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _transcript = '';

  String _merchant = '';
  String _amount = '';
  String _category = '餐飲';
  String? _subcategory;
  DateTime _date = DateTime.now();
  Map<String, List<String>> _extraSubcats = {};
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadCustomSubcats();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (err) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadCustomSubcats() async {
    final data = await SupabaseService.instance.fetchCustomSubcategories(widget.userId);
    if (mounted) setState(() => _extraSubcats = data);
  }

  List<String> get _subOptions => [
        ...(subcategoryMap[_category] ?? []),
        ...(_extraSubcats[_category] ?? []),
      ];

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('您的裝置不支援語音辨識，請手動輸入。')));
      return;
    }
    setState(() {
      _isListening = true;
      _transcript = '正在聆聽中...（請說出：昨天中華電信費 500塊）';
    });
    await _speech.listen(
      localeId: 'zh_TW',
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _transcript = result.recognizedWords;
            _isListening = false;
          });
          _processVoiceText(result.recognizedWords);
        }
      },
    );
  }

  void _processVoiceText(String text) {
    final date = _parseVoiceDate(text);

    final numberMatch = RegExp(r'\d+').firstMatch(text);
    final amount = numberMatch?.group(0) ?? '';

    var merchant = text
        .replaceAll(RegExp(r'昨天|前天|\d{1,2}月\d{1,2}[號日]?|\d{1,2}/\d{1,2}'), '')
        .replaceFirst(RegExp(r'\d+'), '')
        .replaceAll(RegExp(r'塊|元|錢|新台幣'), '')
        .trim();

    final category = autoDetectCategory('$merchant $text');
    final possibleSubs = [...(subcategoryMap[category] ?? []), ...(_extraSubcats[category] ?? [])];
    final matchedSub = possibleSubs.cast<String?>().firstWhere((s) => (('$merchant $text').contains(s!)), orElse: () => null);

    setState(() {
      _date = date;
      _amount = amount;
      _merchant = merchant.isEmpty ? text : merchant;
      _category = category;
      _subcategory = matchedSub;
    });
  }

  Future<void> _save() async {
    final amountVal = double.tryParse(_amount);
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未能偵測到有效金額，請確認金額或手動調整！')));
      return;
    }
    setState(() => _status = 'saving');
    try {
      await SupabaseService.instance.insertTransaction(
        userId: widget.userId,
        amount: amountVal,
        category: _category,
        subcategory: _subcategory,
        merchant: _merchant.isEmpty ? '語音記帳' : _merchant,
        type: 'expense',
        source: 'manual',
        transactionDate: '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'error');
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(children: [
        const Text('語音智慧記帳', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 8),
        const Text('點擊麥克風說出消費內容（例如：「昨天中華電信費 500塊」），系統會自動辨識日期、分類與細項。',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _isListening ? null : _startListening,
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isListening ? [AppColors.clay, AppColors.clayDeep] : [AppColors.moss, AppColors.mossDeep],
              ),
              boxShadow: AppShadows.lg,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(_isListening ? '請說話...' : '點擊圖示開始語音輸入', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.inkSoft)),
        if (_transcript.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('語音識別原始結果：', style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
              const SizedBox(height: 4),
              Text('「$_transcript」', style: const TextStyle(fontSize: 14, color: AppColors.ink)),
            ]),
          ),
        ],
        if (_merchant.isNotEmpty || _amount.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.mossLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moss)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('解析預覽與調整（可直接修改）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mossDark)),
              const SizedBox(height: 12),
              _label('消費日期'),
              _dateField(),
              const SizedBox(height: 10),
              _label('店家 / 項目'),
              _textField(initial: _merchant, onChanged: (v) => _merchant = v),
              const SizedBox(height: 10),
              _label('金額 (NT\$)'),
              _textField(initial: _amount, onChanged: (v) => _amount = v, numeric: true, bold: true),
              const SizedBox(height: 12),
              _label('主分類'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: defaultCategoryList.map((catName) {
                final isSelected = _category == catName;
                return GestureDetector(
                  onTap: () => setState(() {
                    _category = catName;
                    _subcategory = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.moss : AppColors.card,
                      border: Border.all(color: isSelected ? AppColors.moss : AppColors.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(catName, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),
              _label('$_category 細項'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: _subOptions.map((sub) {
                final isSelected = _subcategory == sub;
                return GestureDetector(
                  onTap: () => setState(() => _subcategory = isSelected ? null : sub),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.moss : AppColors.card,
                      border: Border.all(color: isSelected ? AppColors.moss : AppColors.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(sub, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.inkSoft)),
                  ),
                );
              }).toList()),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _status == 'saving' ? null : _save,
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(_status == 'saving' ? '儲存中...' : '確認並記錄這筆語音支出', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          if (_status == 'error')
            const Padding(padding: EdgeInsets.only(top: 10), child: Text('儲存失敗，請檢查主控台', style: TextStyle(color: AppColors.clay))),
        ],
      ]),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.bold));

  Widget _textField({required String initial, required ValueChanged<String> onChanged, bool numeric = false, bool bold = false}) {
    return TextFormField(
      initialValue: initial,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: TextStyle(fontFamily: bold ? monoFontFamily : null, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _dateField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
        child: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
      ),
    );
  }
}
