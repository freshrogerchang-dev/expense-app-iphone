import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../utils/category_data.dart';
import '../services/supabase_service.dart';

class _InvoiceRecord {
  String date;
  String merchant;
  List<String> items = [];
  double total = 0;
  _InvoiceRecord({required this.date, required this.merchant});
}

/// 對應原本的 splitCsvLine()：處理欄位中含逗號的情況（用雙引號包起來）
List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final buf = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ',' && !inQuotes) {
      result.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  result.add(buf.toString().trim());
  return result;
}

class InvoiceFlow extends StatefulWidget {
  final String userId;
  const InvoiceFlow({super.key, required this.userId});

  @override
  State<InvoiceFlow> createState() => _InvoiceFlowState();
}

class _InvoiceFlowState extends State<InvoiceFlow> {
  bool _loading = false;
  String _syncStatus = '等待上傳檔案...';
  bool _success = false;

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _loading = true;
      _success = false;
      _syncStatus = '解析發票檔案中...';
    });

    try {
      final file = File(result.files.single.path!);
      var bytes = await file.readAsBytes();
      // 去掉 UTF-8 BOM
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        bytes = bytes.sublist(3);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final lines = text.split(RegExp(r'\r\n|\n')).where((l) => l.trim().isNotEmpty).toList();

      if (lines.length < 2) {
        setState(() {
          _syncStatus = '解析失敗：檔案內沒有交易資料';
          _loading = false;
        });
        return;
      }

      final dataLines = lines[0].contains('消費時間') ? lines.sublist(1) : lines;
      final invoiceMap = <String, _InvoiceRecord>{};

      for (final line in dataLines) {
        final cols = _splitCsvLine(line);
        if (cols.length < 9) continue;

        final rawDateTime = cols[0];
        final invoiceNum = cols[1];
        final merchant = cols[2];
        final itemName = cols[4];
        final rawTotal = cols[8];

        if (invoiceNum.isEmpty) continue;

        final dateOnly = rawDateTime.split(' ').first.replaceAll('/', '-');

        final record = invoiceMap.putIfAbsent(
          invoiceNum,
          () => _InvoiceRecord(date: dateOnly, merchant: merchant.isEmpty ? '特約商店' : merchant),
        );
        if (itemName.isNotEmpty) record.items.add(itemName);

        final totalNum = double.tryParse(rawTotal.replaceAll(RegExp(r'[NT$,\s]'), ''));
        if (totalNum != null && totalNum != 0) record.total = totalNum;
      }

      final formatted = invoiceMap.entries.where((e) => e.value.total > 0).map((e) {
        final invoiceNum = e.key;
        final inv = e.value;
        final detailName = inv.items.isNotEmpty ? '${inv.merchant}（${inv.items.join('、')}）' : inv.merchant;
        final categorySourceText = '${inv.merchant} ${inv.items.join(' ')}';
        final cat = autoDetectCategory(categorySourceText);
        final possibleSubs = subcategoryMap[cat] ?? [];
        final matchedSub = possibleSubs.cast<String?>().firstWhere((s) => categorySourceText.contains(s!), orElse: () => null);

        return {
          'user_id': widget.userId,
          'transaction_date': inv.date,
          'invoice_num': invoiceNum,
          'merchant': detailName,
          'amount': inv.total,
          'category': cat,
          'subcategory': matchedSub,
          'source': 'invoice_import',
          'type': 'expense',
        };
      }).toList();

      if (formatted.isEmpty) {
        setState(() {
          _syncStatus = '解析失敗：未能抓取到有效的發票交易資料';
          _loading = false;
        });
        return;
      }

      final invoiceNums = formatted.map((d) => d['invoice_num'] as String).toList();
      final existing = await SupabaseService.instance.fetchExistingInvoiceNums(widget.userId, invoiceNums);
      final existingSet = existing.toSet();
      final newData = formatted.where((d) => !existingSet.contains(d['invoice_num'])).toList();

      if (newData.isEmpty) {
        setState(() {
          _syncStatus = '這份檔案的 ${formatted.length} 張發票都已經匯入過了，沒有新增';
          _loading = false;
        });
        return;
      }

      setState(() => _syncStatus = '寫入資料庫中（共 ${newData.length} 張新發票）...');
      await SupabaseService.instance.insertTransactionsBulk(newData);

      setState(() {
        _syncStatus = '匯入成功！新增 ${newData.length} 張發票 ✓';
        _loading = false;
        _success = true;
      });
    } catch (e) {
      setState(() {
        _syncStatus = '檔案格式錯誤，請確認是財政部發票存摺 CSV';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('從發票存摺匯入 CSV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 8),
        const Text('上傳發票存摺 CSV，系統會自動辨識主分類與對應細項。', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _pickAndImport,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkFaint))
                : const Icon(Icons.refresh, color: Colors.white),
            label: Text(_loading ? _syncStatus : '選擇發票存摺 CSV 並匯入',
                style: TextStyle(color: _loading ? AppColors.inkFaint : Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _loading ? AppColors.paper : AppColors.moss,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (!_loading && _success) Padding(padding: const EdgeInsets.only(top: 14), child: Center(child: Text(_syncStatus, style: const TextStyle(color: AppColors.moss, fontWeight: FontWeight.bold)))),
        if (!_loading && !_success && _syncStatus != '等待上傳檔案...')
          Padding(padding: const EdgeInsets.only(top: 14), child: Center(child: Text(_syncStatus, style: const TextStyle(color: AppColors.clay)))),
      ]),
    );
  }
}
