import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_item.dart';
import '../models/asset_item.dart';

/// 對應原本 React 版本裡所有 `supabase.from(...)` 的呼叫，
/// 統一集中在這裡管理，畫面只呼叫這個 service，不要直接碰 SupabaseClient。
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------- transactions ----------------

  Future<List<TransactionItem>> fetchTransactions(String userId) async {
    final data = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => TransactionItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> insertTransaction({
    required String userId,
    required double amount,
    String? category,
    String? subcategory,
    String? merchant,
    required String type,
    required String source,
    required String transactionDate,
    String? invoiceNum,
  }) async {
    await _client.from('transactions').insert({
      'user_id': userId,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'merchant': merchant,
      'type': type,
      'source': source,
      'transaction_date': transactionDate,
      if (invoiceNum != null) 'invoice_num': invoiceNum,
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<void> deleteTransactions(List<String> ids) async {
    await _client.from('transactions').delete().inFilter('id', ids);
  }

  /// 批次新增交易，用於發票存摺 CSV 匯入
  Future<void> insertTransactionsBulk(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('transactions').insert(rows);
  }

  Future<List<String>> fetchExistingInvoiceNums(String userId, List<String> invoiceNums) async {
    final data = await _client
        .from('transactions')
        .select('invoice_num')
        .eq('user_id', userId)
        .inFilter('invoice_num', invoiceNums);
    return (data as List).map((e) => e['invoice_num'] as String).toList();
  }

  // ---------------- custom_subcategories ----------------

  Future<Map<String, List<String>>> fetchCustomSubcategories(String userId) async {
    final data = await _client
        .from('custom_subcategories')
        .select('category, name')
        .eq('user_id', userId);
    final grouped = <String, List<String>>{};
    for (final row in (data as List)) {
      final cat = row['category'] as String;
      grouped.putIfAbsent(cat, () => []).add(row['name'] as String);
    }
    return grouped;
  }

  Future<void> addCustomSubcategory(String userId, String category, String name) async {
    await _client.from('custom_subcategories').insert({
      'user_id': userId,
      'category': category,
      'name': name,
    });
  }

  // ---------------- assets ----------------

  Future<List<AssetItem>> fetchAssets(String userId) async {
    final data = await _client
        .from('assets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => AssetItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> insertAsset({
    required String userId,
    required String assetType,
    required String name,
    double? quantity,
    double? unitPrice,
    required double amount,
    required String source,
  }) async {
    await _client.from('assets').insert({
      'user_id': userId,
      'asset_type': assetType,
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
      'source': source,
    });
  }

  Future<void> deleteAsset(String id) async {
    await _client.from('assets').delete().eq('id', id);
  }
}
