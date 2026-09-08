import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

const List<String> _commonBanks = [
  '中信', '國泰世華', '玉山', '富邦', '台新',
  '中華郵政', '聯邦', '第一銀行', '華南', '兆豐', '永豐', 'LINE Bank',
];

const List<String> _commonStocks = [
  '0050 元大台灣50', '0056 元大高股息', '00878 國泰永續高股息', '006208 富邦台50',
  '2330 台積電', '2317 鴻海', '2454 聯發科', '2308 台達電', '2881 富邦金', '2882 國泰金',
];

class _NumberToken {
  final String raw;
  final double value;
  _NumberToken(this.raw, this.value);
}

List<_NumberToken> _extractNumberTokens(String text) {
  final matches = RegExp(r'[\d][\d,]*(\.\d+)?').allMatches(text);
  final seen = <String>{};
  final tokens = <_NumberToken>[];
  for (final m in matches) {
    final raw = m.group(0)!;
    final cleaned = raw.replaceAll(',', '');
    final num = double.tryParse(cleaned);
    if (num != null && num > 0 && !seen.contains(cleaned)) {
      seen.add(cleaned);
      tokens.add(_NumberToken(raw, num));
    }
  }
  tokens.sort((a, b) => b.value.compareTo(a.value));
  return tokens.take(12).toList();
}

class AssetAddSheet extends StatefulWidget {
  final String userId;
  const AssetAddSheet({super.key, required this.userId});

  @override
  State<AssetAddSheet> createState() => _AssetAddSheetState();
}

class _AssetAddSheetState extends State<AssetAddSheet> {
  String _assetType = 'bank'; // 'bank' | 'stock'
  String _entryMode = 'manual'; // 'manual' | 'ocr'
  final _nameController = TextEditingController();

  String _activeField = 'amount'; // 'amount' | 'quantity' | 'unitPrice'
  String _amount = '0';
  String _quantity = '0';
  String _unitPrice = '0';
  bool _freshEntry = true;

  File? _imageFile;
  bool _ocrRunning = false;
  List<_NumberToken> _numberTokens = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _computedAmount => _assetType == 'stock'
      ? (double.tryParse(_quantity) ?? 0) * (double.tryParse(_unitPrice) ?? 0)
      : double.tryParse(_amount) ?? 0;

  void _switchAssetType(String type) {
    setState(() {
      _assetType = type;
      _activeField = type == 'bank' ? 'amount' : 'quantity';
      _freshEntry = true;
    });
  }

  void _pressDigit(String d) {
    setState(() {
      final current = _fieldValue(_activeField);
      String next;
      if (_freshEntry) {
        _freshEntry = false;
        next = d == '.' ? '0.' : d;
      } else if (d == '.' && current.contains('.')) {
        next = current;
      } else if (current == '0' && d != '.') {
        next = d;
      } else if (current.length >= 10) {
        next = current;
      } else {
        next = current + d;
      }
      _setFieldValue(_activeField, next);
    });
  }

  void _pressAC() => setState(() {
        _setFieldValue(_activeField, '0');
        _freshEntry = true;
      });

  void _pressBackspace() => setState(() {
        final current = _fieldValue(_activeField);
        _setFieldValue(_activeField, current.length <= 1 ? '0' : current.substring(0, current.length - 1));
      });

  String _fieldValue(String field) {
    switch (field) {
      case 'quantity':
        return _quantity;
      case 'unitPrice':
        return _unitPrice;
      default:
        return _amount;
    }
  }

  void _setFieldValue(String field, String value) {
    switch (field) {
      case 'quantity':
        _quantity = value;
        break;
      case 'unitPrice':
        _unitPrice = value;
        break;
      default:
        _amount = value;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _imageFile = file;
      _ocrRunning = true;
      _numberTokens = [];
    });
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final result = await recognizer.processImage(InputImage.fromFile(file));
      await recognizer.close();
      if (!mounted) return;
      setState(() {
        _numberTokens = _extractNumberTokens(result.text);
        _ocrRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocrRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('圖片文字辨識失敗，請直接手動輸入數字')));
    }
  }

  void _applyToken(_NumberToken token) {
    setState(() {
      if (_assetType == 'bank') {
        _amount = token.value.toStringAsFixed(token.value == token.value.roundToDouble() ? 0 : 2);
      } else if (_activeField == 'quantity') {
        _quantity = token.value.toStringAsFixed(token.value == token.value.roundToDouble() ? 0 : 2);
      } else {
        _unitPrice = token.value.toStringAsFixed(token.value == token.value.roundToDouble() ? 0 : 2);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入資產名稱（例如：中信活存 / 台積電）')));
      return;
    }
    if (_computedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請確認金額或股數/市價')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.insertAsset(
        userId: widget.userId,
        assetType: _assetType,
        name: name,
        quantity: _assetType == 'stock' ? double.tryParse(_quantity) : null,
        unitPrice: _assetType == 'stock' ? double.tryParse(_unitPrice) : null,
        amount: _computedAmount,
        source: _entryMode == 'ocr' ? 'ocr_import' : 'manual',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存失敗，請檢查主控台')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mossDark, AppColors.moss, AppColors.mossDeep],
              ),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close, color: Colors.white)),
                const Text('新增資產帳戶', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 48),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _segButton('銀行帳戶', _assetType == 'bank', () => _switchAssetType('bank')),
                  _segButton('證券／股票', _assetType == 'stock', () => _switchAssetType('stock')),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: _modeButton('計算機手動輸入', _entryMode == 'manual', () => setState(() => _entryMode = 'manual')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeButton('截圖辨識填入', _entryMode == 'ocr', () => setState(() => _entryMode = 'ocr'),
                        icon: Icons.document_scanner_outlined),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(_assetType == 'bank' ? '常用金融機構快捷：' : '熱門標的快捷：',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkFaint, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (_assetType == 'bank' ? _commonBanks : _commonStocks).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final item = (_assetType == 'bank' ? _commonBanks : _commonStocks)[i];
                      final isSelected = _nameController.text == item;
                      return GestureDetector(
                        onTap: () => setState(() => _nameController.text = item),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.mossLight : AppColors.card,
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(item,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? AppColors.mossDark : AppColors.inkSoft,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(_assetType == 'bank' ? '帳戶名稱' : '股票標的名稱',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: _assetType == 'bank' ? '例如：中信活存 / 國泰數位' : '例如：0050 元大台灣50',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                if (_entryMode == 'ocr') _buildOcrSection(),
                if (_assetType == 'bank')
                  _fieldCard('amount', '帳戶餘額 (NT\$)', 'NT\$ ${double.tryParse(_amount)?.toStringAsFixed(0) ?? 0}')
                else
                  Row(children: [
                    Expanded(child: _fieldCard('quantity', '股數', _quantity)),
                    const SizedBox(width: 8),
                    Expanded(child: _fieldCard('unitPrice', '均價 / 市價', _unitPrice)),
                  ]),
                if (_assetType == 'stock')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('預估市值：NT\$ ${_computedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
                    ),
                  ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          if (_entryMode == 'manual')
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.line))),
              child: _buildCalcGrid(),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.line))),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text(_saving ? '儲存中...' : '確認新增資產', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moss,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildOcrSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _imageFile == null
          ? GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                    color: AppColors.card, border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.camera_alt, color: AppColors.moss, size: 24),
                  const SizedBox(height: 6),
                  const Text('點擊上傳銀行或證券 App 截圖', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  const Text('自動辨識數字填入下方欄位', style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                ]),
              ),
            )
          : Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!, height: 160, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              if (_ocrRunning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('正在分析圖片數字...', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._numberTokens.map((tok) => GestureDetector(
                          onTap: () => _applyToken(tok),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(6)),
                            child: Text(tok.raw, style: const TextStyle(fontFamily: monoFontFamily, fontSize: 12)),
                          ),
                        )),
                    TextButton(onPressed: _pickImage, child: const Text('重新上傳截圖')),
                  ],
                ),
            ]),
    );
  }

  Widget _fieldCard(String field, String label, String valueDisplay) {
    final isActive = _activeField == field;
    return GestureDetector(
      onTap: () => setState(() {
        _activeField = field;
        _freshEntry = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          border: Border.all(color: isActive ? AppColors.moss : AppColors.line, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(valueDisplay, style: const TextStyle(fontFamily: monoFontFamily, fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mossDark)),
        ]),
      ),
    );
  }

  Widget _segButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? AppColors.mossDark : AppColors.mossLight)),
      ),
    );
  }

  Widget _modeButton(String label, bool active, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.moss : AppColors.card,
          border: Border.all(color: active ? AppColors.moss : AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: active ? Colors.white : AppColors.inkSoft), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.inkSoft)),
        ]),
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
        minimumSize: const Size(0, 50),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18, fontFamily: monoFontFamily)),
    );
  }

  Widget _buildCalcGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.6,
      children: [
        _key('7', () => _pressDigit('7')),
        _key('8', () => _pressDigit('8')),
        _key('9', () => _pressDigit('9')),
        _key('⌫', _pressBackspace, bg: AppColors.clayLight, fg: AppColors.clayDeep),
        _key('4', () => _pressDigit('4')),
        _key('5', () => _pressDigit('5')),
        _key('6', () => _pressDigit('6')),
        _key('AC', _pressAC, bg: AppColors.clayLight, fg: AppColors.clayDeep),
        _key('1', () => _pressDigit('1')),
        _key('2', () => _pressDigit('2')),
        _key('3', () => _pressDigit('3')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(_saving ? '...' : '確認', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        _key('0', () => _pressDigit('0')),
        _key('00', () {
          _pressDigit('0');
          _pressDigit('0');
        }),
        _key('.', () => _pressDigit('.')),
        if (_assetType == 'stock')
          _key('換欄', () => setState(() {
                _activeField = _activeField == 'quantity' ? 'unitPrice' : 'quantity';
                _freshEntry = true;
              }), bg: AppColors.mossMist, fg: AppColors.mossDark)
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
