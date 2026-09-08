import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

const Map<String, String> _sourceLabelMap = {
  'invoice_import': '發票存摺',
  'photo': '發票二維條碼',
  'manual': '手動輸入',
};

String _csvEscape(dynamic value) {
  final str = value?.toString() ?? '';
  if (str.contains(RegExp(r'[",\n]'))) {
    return '"${str.replaceAll('"', '""')}"';
  }
  return str;
}

class SettingsScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.userId, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _backupStatus;
  String? _csvStatus;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _handleBackupJson() async {
    setState(() => _backupStatus = 'working');
    try {
      final txs = await _client.from('transactions').select().eq('user_id', widget.userId);
      final subs = await _client.from('custom_subcategories').select().eq('user_id', widget.userId);

      final payload = {
        'exported_at': DateTime.now().toIso8601String(),
        'user_id': widget.userId,
        'transactions': txs,
        'custom_subcategories': subs,
      };

      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/記帳備份_$dateStr.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      await Share.shareXFiles([XFile(file.path)], text: '記帳 App 資料備份');
      setState(() => _backupStatus = 'done');
    } catch (e) {
      setState(() => _backupStatus = 'error');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _backupStatus = null);
      });
    }
  }

  Future<void> _handleExportCsv() async {
    setState(() => _csvStatus = 'working');
    try {
      final data = await _client
          .from('transactions')
          .select()
          .eq('user_id', widget.userId)
          .order('transaction_date', ascending: false);

      final header = ['日期', '類型', '分類', '細項', '店家/備註', '金額', '來源', '發票號碼'];
      final rows = (data as List).map((t) {
        return [
          t['transaction_date'],
          t['type'] == 'income' ? '收入' : '支出',
          t['category'] ?? '',
          t['subcategory'] ?? '',
          t['merchant'] ?? '',
          t['amount'],
          _sourceLabelMap[t['source']] ?? '手動輸入',
          t['invoice_num'] ?? '',
        ];
      }).toList();

      final csvBody = [header, ...rows].map((row) => row.map(_csvEscape).join(',')).join('\r\n');
      final csvContent = '\uFEFF$csvBody'; // 加上 BOM，Excel 開啟中文才不會亂碼

      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/記帳匯出_$dateStr.csv');
      await file.writeAsString(csvContent, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)], text: '記帳 App CSV 匯出');
      setState(() => _csvStatus = 'done');
    } catch (e) {
      setState(() => _csvStatus = 'error');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _csvStatus = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('設定', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('目前登入帳號', style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_client.auth.currentUser?.email ?? widget.userId, style: const TextStyle(fontFamily: monoFontFamily, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('資料備份與匯出', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('匯出的檔案會透過系統分享選單，你可以存到雲端硬碟、傳到自己信箱，或直接存到裝置。',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint, height: 1.5)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _backupStatus == 'working' ? null : _handleBackupJson,
                icon: const Icon(Icons.file_download, color: AppColors.mossDark),
                label: Text(
                  _backupStatus == 'working' ? '備份中...' : _backupStatus == 'done' ? '已產生備份檔 ✓' : '手動備份（完整 JSON，可還原）',
                  style: const TextStyle(color: AppColors.mossDark, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mossMist, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _csvStatus == 'working' ? null : _handleExportCsv,
                icon: const Icon(Icons.upload_file, color: AppColors.inkSoft),
                label: Text(
                  _csvStatus == 'working' ? '匯出中...' : _csvStatus == 'done' ? '已產生 CSV ✓' : '匯出 CSV（Excel 可開）',
                  style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.line), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (_backupStatus == 'error' || _csvStatus == 'error')
              const Padding(padding: EdgeInsets.only(top: 10), child: Text('匯出失敗，請檢查主控台錯誤訊息', textAlign: TextAlign.center, style: TextStyle(color: AppColors.clay, fontSize: 12.5))),
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Icon(Icons.cloud_outlined, size: 16, color: AppColors.inkFaint),
              SizedBox(width: 8),
              Text('自動備份（Google Drive）', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.ink)),
            ]),
            const SizedBox(height: 10),
            const Text(
              '這個功能需要額外設定 Google Cloud OAuth 用戶端（google_sign_in 套件 + Drive API 權限），屬於原生 App 特有的設定流程，先保留這個入口，之後可以直接跟我說要接這塊。',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint, height: 1.6),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: AppColors.clayDeep),
            label: const Text('登出', style: TextStyle(color: AppColors.clayDeep, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.clay), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
