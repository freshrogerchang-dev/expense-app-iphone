class TransactionItem {
  final String id;
  final double amount;
  final String? category;
  final String? subcategory;
  final String? merchant;
  final String type; // 'expense' | 'income'
  final String source; // manual, photo, invoice_import
  final String transactionDate; // yyyy-MM-dd
  final String? invoiceNum;
  final String? receiptUrl;

  TransactionItem({
    required this.id,
    required this.amount,
    this.category,
    this.subcategory,
    this.merchant,
    required this.type,
    required this.source,
    required this.transactionDate,
    this.invoiceNum,
    this.receiptUrl,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'].toString(),
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String?,
      subcategory: map['subcategory'] as String?,
      merchant: map['merchant'] as String?,
      type: (map['type'] as String?) ?? 'expense',
      source: (map['source'] as String?) ?? 'manual',
      transactionDate: map['transaction_date'] as String,
      invoiceNum: map['invoice_num'] as String?,
      receiptUrl: map['receipt_url'] as String?,
    );
  }

  /// 對應原本畫面上顯示的 item.name 邏輯：merchant || subcategory || category
  String get displayName =>
      merchant ?? subcategory ?? category ?? (type == 'income' ? '收入' : '支出');
}
