import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../utils/category_data.dart';
import '../services/supabase_service.dart';

class _ParsedInvoice {
  final String invoiceNum;
  final int amount;
  _ParsedInvoice(this.invoiceNum, this.amount);
}

/// 對應原本的 parseInvoiceCode()：財政部電子發票二維條碼（左側 QR Code）規格解析
/// 欄位（相對於「發票字軌+號碼」起始位置）：
/// [0-9]   發票字軌+號碼 (2碼英文 + 8碼數字)
/// [10-16] 開立日期 (7碼)
/// [17-20] 隨機碼 (4碼)
/// [21-28] 銷售額，未稅，16進位 (8碼)
/// [29-36] 總計金額，含稅，16進位 (8碼)  <- 我們要的金額欄位
_ParsedInvoice? _parseInvoiceCode(String? rawText) {
  if (rawText == null || rawText.isEmpty) return null;
  if (rawText.startsWith('**')) return null; // 右側商品明細，不是我們要的

  final match = RegExp(r'[A-Z]{2}\d{8}').firstMatch(rawText);
  if (match == null) return null;

  final invNum = match.group(0)!;
  final baseIndex = match.start;
  final totalStart = baseIndex + 29;
  final totalEnd = baseIndex + 37;

  if (rawText.length < totalEnd) return null;

  final hexTotal = rawText.substring(totalStart, totalEnd).trim();
  final totalAmount = int.tryParse(hexTotal, radix: 16);

  if (totalAmount != null && totalAmount > 0 && totalAmount < 10000000) {
    return _ParsedInvoice(invNum, totalAmount);
  }
  return null;
}

class PhotoFlow extends StatefulWidget {
  final String userId;
  const PhotoFlow({super.key, required this.userId});

  @override
  State<PhotoFlow> createState() => _PhotoFlowState();
}

class _PhotoFlowState extends State<PhotoFlow> {
  MobileScannerController? _controller;
  bool _scanning = false;
  String _merchant = '';
  String _amount = '';
  String _category = '餐飲';
  String? _subcategory;
  Map<String, List<String>> _extraSubcats = {};
  String? _scanMessage;
  bool _torchOn = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadCustomSubcats();
  }

  Future<void> _loadCustomSubcats() async {
    final data = await SupabaseService.instance.fetchCustomSubcategories(widget.userId);
    if (mounted) setState(() => _extraSubcats = data);
  }

  List<String> get _subOptions => [
        ...(subcategoryMap[_category] ?? []),
        ...(_extraSubcats[_category] ?? []),
      ];

  void _startScanning() {
    setState(() {
      _scanning = true;
      _scanMessage = '請保持約 15 公分距離，將發票左側 QR Code 置於鏡頭前';
      _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
    });
  }

  Future<void> _stopScanning() async {
    await _controller?.stop();
    _controller?.dispose();
    setState(() {
      _controller = null;
      _scanning = false;
      _torchOn = false;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final parsed = _parseInvoiceCode(barcode.rawValue);
      if (parsed != null) {
        setState(() {
          _amount = parsed.amount.toString();
          _merchant = '發票 ${parsed.invoiceNum}';
          _category = autoDetectCategory(_merchant);
          _scanMessage = '成功辨識發票！ ✓';
        });
        _stopScanning();
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null) return;
    await _controller!.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _save() async {
    final amountVal = double.tryParse(_amount);
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請填寫正確的消費金額！')));
      return;
    }
    setState(() => _status = 'saving');
    try {
      await SupabaseService.instance.insertTransaction(
        userId: widget.userId,
        amount: amountVal,
        category: _category,
        subcategory: _subcategory,
        merchant: _merchant.isEmpty ? '發票二維條碼' : _merchant,
        type: 'expense',
        source: 'photo',
        transactionDate: DateTime.now().toIso8601String().slice10(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'error');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_scanning)
          Column(children: [
            GestureDetector(
              onTap: _startScanning,
              child: Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(color: AppColors.paper, border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.qr_code_scanner, color: AppColors.moss, size: 28),
                  SizedBox(height: 6),
                  Text('開啟即時掃描鏡頭', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  SizedBox(height: 2),
                  Text('請掃描「左側」含金額之 QR Code', style: TextStyle(fontSize: 12, color: AppColors.clay, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ])
        else
          Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(children: [
                SizedBox(
                  height: 260,
                  child: MobileScanner(controller: _controller, onDetect: _onDetect),
                ),
                if (_scanMessage != null)
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(6)),
                      child: Text(_scanMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _toggleTorch,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _torchOn ? AppColors.clay : Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                      child: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _stopScanning,
              style: TextButton.styleFrom(backgroundColor: AppColors.clayLight, foregroundColor: AppColors.clay),
              child: const Text('關閉相機'),
            ),
            const SizedBox(height: 10),
          ]),
        const Text('發票號碼 / 店家名稱', style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _merchant,
          onChanged: (v) => setState(() {
            _merchant = v;
            _category = autoDetectCategory(v);
          }),
          decoration: InputDecoration(
            hintText: '例如：發票 AB12345678',
            filled: true,
            fillColor: AppColors.paper,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        const Text('消費金額 (NT\$)', style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _amount,
          keyboardType: TextInputType.number,
          onChanged: (v) => _amount = v,
          style: const TextStyle(fontFamily: monoFontFamily, fontWeight: FontWeight.bold, fontSize: 18),
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: AppColors.paper,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        const Text('主分類', style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: defaultCategoryList.map((catName) {
          final isSelected = _category == catName;
          return GestureDetector(
            onTap: () => setState(() {
              _category = catName;
              _subcategory = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.moss : AppColors.paper,
                border: Border.all(color: isSelected ? AppColors.moss : AppColors.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(catName, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.bold)),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),
        Text('$_category 細項', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _subOptions.map((sub) {
          final isSelected = _subcategory == sub;
          return GestureDetector(
            onTap: () => setState(() => _subcategory = isSelected ? null : sub),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.moss : AppColors.paper,
                border: Border.all(color: isSelected ? AppColors.moss : AppColors.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(sub, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : AppColors.inkSoft)),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_amount.isEmpty || _status == 'saving') ? null : _save,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(_status == 'saving' ? '儲存中...' : '確認並記錄這筆支出', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        if (_status == 'error')
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('儲存失敗，請檢查主控台', style: TextStyle(color: AppColors.clay))),
      ]),
    );
  }
}

extension _DateSlice on String {
  String slice10() => substring(0, 10);
}
