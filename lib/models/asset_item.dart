class AssetItem {
  final String id;
  final String assetType; // 'bank' | 'stock'
  final String name;
  final double? quantity;
  final double? unitPrice;
  final double amount;
  final String source; // manual, ocr_import

  AssetItem({
    required this.id,
    required this.assetType,
    required this.name,
    this.quantity,
    this.unitPrice,
    required this.amount,
    required this.source,
  });

  factory AssetItem.fromMap(Map<String, dynamic> map) {
    return AssetItem(
      id: map['id'].toString(),
      assetType: map['asset_type'] as String,
      name: map['name'] as String,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      amount: (map['amount'] as num).toDouble(),
      source: (map['source'] as String?) ?? 'manual',
    );
  }
}
