import 'package:flutter/material.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  const CategoryItem(this.name, this.icon);
}

const List<CategoryItem> expenseCategories = [
  CategoryItem('餐飲', Icons.restaurant),
  CategoryItem('交通', Icons.directions_bus),
  CategoryItem('日用品', Icons.shopping_basket),
  CategoryItem('生活繳費', Icons.bolt),
  CategoryItem('零食', Icons.icecream),
  CategoryItem('居住', Icons.home),
  CategoryItem('娛樂', Icons.movie),
  CategoryItem('社交', Icons.celebration),
  CategoryItem('服飾', Icons.checkroom),
  CategoryItem('醫療', Icons.medical_services),
  CategoryItem('教育', Icons.school),
  CategoryItem('美容', Icons.auto_awesome),
  CategoryItem('美妝', Icons.brush),
  CategoryItem('旅遊', Icons.luggage),
  CategoryItem('寵物', Icons.pets),
  CategoryItem('汽車', Icons.directions_car),
  CategoryItem('親子', Icons.child_care),
  CategoryItem('健身', Icons.fitness_center),
  CategoryItem('居家用品', Icons.kitchen),
  CategoryItem('菸酒', Icons.sports_bar),
  CategoryItem('數位', Icons.camera_alt),
  CategoryItem('遊戲', Icons.sports_esports),
  CategoryItem('訂閱', Icons.repeat),
  CategoryItem('鞋包', Icons.shopping_bag),
  CategoryItem('玩具', Icons.toys),
  CategoryItem('其他', Icons.more_horiz),
];

const List<CategoryItem> incomeCategories = [
  CategoryItem('薪資', Icons.account_balance_wallet),
  CategoryItem('獎金', Icons.card_giftcard),
  CategoryItem('兼職', Icons.attach_money),
  CategoryItem('投資', Icons.trending_up),
  CategoryItem('退款', Icons.replay),
  CategoryItem('禮金', Icons.redeem),
  CategoryItem('其他收入', Icons.more_horiz),
];

final Map<String, IconData> categoryIconMap = {
  for (final c in [...expenseCategories, ...incomeCategories]) c.name: c.icon,
};

List<String> get defaultCategoryList => expenseCategories.map((e) => e.name).toList();

/// 對應原本的 subcategoryMap
const Map<String, List<String>> subcategoryMap = {
  '餐飲': ['早餐', '中餐', '晚餐', '消夜', '點心', '飲料', '烘焙', '咖啡'],
  '交通': ['計程車', '公車', '火車', '高鐵', '捷運', '停車費'],
  '娛樂': ['電影', '遊戲', '展覽', '訂閱服務', 'KTV'],
  '日用品': ['清潔用品', '衛生紙', '洗劑', '生活雜貨'],
  '服飾': ['上衣', '褲子', '外套', '配件'],
  '其他': ['醫療', '教育', '房租', '保險', '捐款', '電信費', '網路費', '水電費'],
};

const List<String> _categoryColorPalette = [
  '#4A6741', '#C1622E', '#7D9D70', '#A68A64', '#8C6D62',
  '#5E7A8C', '#B8935A', '#6B7F5E', '#A6795A', '#7A8C6B',
];

/// 對應原本用字串 hash 決定分類顏色的 getCategoryColor()
Color getCategoryColor(String? name) {
  if (name == null || name.isEmpty) return const Color(0xFFA6A99C);
  int hash = 0;
  for (final codeUnit in name.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
  }
  final hex = _categoryColorPalette[hash % _categoryColorPalette.length];
  return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
}

/// 對應原本的 autoDetectCategory()，依關鍵字自動判斷分類
String autoDetectCategory(String? text) {
  if (text == null || text.isEmpty) return '其他';
  final t = text.toLowerCase();
  bool has(List<String> keys) => keys.any((k) => t.contains(k));

  if (has(['飯', '麵', '咖啡', '茶', '可頌', '米漿', '牛', '豬', '雞', '鍋', '餐', '食品', '超商', '全家',
      '統一超商', '麥當勞', 'ubereats', 'foodpanda', '壽司', '燒肉', '蘋果', '便當', '火鍋', '飲料',
      '漢堡', '餐廳', '美食', '烘焙', '麵包', '蛋糕', '飲食'])) {
    return '餐飲';
  }
  if (has(['油', '加油', '停車', '停管', '高鐵', '台鐵', '捷運', '公車', '客運', '計程車', 'uber',
      't-cross', '車位', '車票', '交通', 'e-tag', 'etag'])) {
    return '交通';
  }
  if (has(['服飾', '衣服', '上衣', '褲', '外套'])) {
    return '服飾';
  }
  if (has(['商店', '百貨', 'momo', 'pchome', '蝦皮', '3c', '日用品', '寶雅', '全聯', '家樂福', '大潤發',
      '屈臣氏', '康是美', '購物', '買'])) {
    return '日用品';
  }
  if (has(['電影', '遊戲', 'spotify', 'netflix', '展覽', 'ktv', '票', '娛樂', '門票', '游藝'])) {
    return '娛樂';
  }
  if (has(['電信', '中華電信', '台灣大哥大', '遠傳', '台灣之星', '亞太電信', '手機費', '網路費', '5g',
      '4g', '費率', '水電', '房租'])) {
    return '生活繳費';
  }
  return '其他';
}
