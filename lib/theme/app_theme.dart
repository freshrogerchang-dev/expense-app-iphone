import 'package:flutter/material.dart';

/// 對應原本 React 版本裡的 `c` 顏色物件
class AppColors {
  static const paper = Color(0xFFF7F5EF);
  static const paperDeep = Color(0xFFEFEAdb);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFFCFBF6);
  static const ink = Color(0xFF1F2420);
  static const inkSoft = Color(0xFF4A4F48);
  static const inkFaint = Color(0xFF7A7E74);
  static const moss = Color(0xFF4A6741);
  static const mossDeep = Color(0xFF38512F);
  static const mossLight = Color(0xFFE7EDE3);
  static const mossMist = Color(0xFFF1F5EE);
  static const mossDark = Color(0xFF2E4226);
  static const clay = Color(0xFFC1622E);
  static const clayDeep = Color(0xFFA24E22);
  static const clayLight = Color(0xFFF5E4D8);
  static const line = Color(0xFFDAD5C8);
  static const lineSoft = Color(0xFFE9E4D6);
  static const gold = Color(0xFFB8935A);
}

/// 對應原本 React 版本裡的 shadow 物件
class AppShadows {
  static List<BoxShadow> sm = [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> md = [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
  ];
  static List<BoxShadow> lg = [
    BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 28, offset: const Offset(0, 10)),
  ];
  static List<BoxShadow> xl = [
    BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 44, offset: const Offset(0, 20)),
  ];
}

/// 金額使用的等寬字型（若想跟原本一樣用 Noto Serif TC 當標題字，
/// 可以加入 google_fonts 套件後在這裡替換）
const String monoFontFamily = 'monospace';
