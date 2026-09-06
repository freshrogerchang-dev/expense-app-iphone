import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ==========================================
// 1. 色彩系統 (大地色系)
// ==========================================
class AppColors {
  static const paper = Color(0xFFF7F5EF);
  static const paperDeep = Color(0xFFEFEADB);
  static const card = Color(0xFFFFFFFF);
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
}

// ==========================================
// 2. 資料模型
// ==========================================
class TransactionModel {
  final String id;
  final String date;
  final String category;
  final String merchant;
  final double amount;
  final String type; // 'expense' or 'income'

  TransactionModel({
    required this.id,
    required this.date,
    required this.category,
    required this.merchant,
    required this.amount,
    required this.type,
  });
}

// ==========================================
// 3. 主程式進入點
// ==========================================
void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '記帳 App',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.paper,
        textTheme: GoogleFonts.notoSerifTcTextTheme(),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 模擬資料清單
  List<TransactionModel> transactions = [
    TransactionModel(id: '1', date: '2026-09-05', category: '餐飲', merchant: '麥當勞', amount: 150, type: 'expense'),
    TransactionModel(id: '2', date: '2026-09-05', category: '交通', merchant: '捷運', amount: 30, type: 'expense'),
    TransactionModel(id: '3', date: '2026-09-04', category: '日用品', merchant: '全聯福利中心', amount: 450, type: 'expense'),
    TransactionModel(id: '4', date: '2026-09-01', category: '薪資', merchant: '九月薪水', amount: 50000, type: 'income'),
  ];

  void _addNewTransaction(TransactionModel tx) {
    setState(() {
      transactions.insert(0, tx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      BookkeepingScreen(
        transactions: transactions,
        onAddTap: () => _showAddSheet(context),
      ),
      _buildPlaceholder('統計分析畫面'),
      _buildPlaceholder('資產管理畫面'),
      _buildPlaceholder('設定與 Supabase 連線'),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line, width: 1))),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.mossDark,
          unselectedItemColor: AppColors.inkFaint,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '記帳'),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: '統計'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: '資產'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '設定'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 16)),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddSheet(
        onSaved: (tx) {
          _addNewTransaction(tx);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ==========================================
// 4. 記帳主畫面
// ==========================================
class BookkeepingScreen extends StatelessWidget {
  final List<TransactionModel> transactions;
  final VoidCallback onAddTap;

  const BookkeepingScreen({super.key, required this.transactions, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    double expenseTotal = transactions.where((t) => t.type == 'expense').fold(0, (sum, t) => sum + t.amount);
    double incomeTotal = transactions.where((t) => t.type == 'income').fold(0, (sum, t) => sum + t.amount);
    double balance = incomeTotal - expenseTotal;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 130),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.chevron_left, color: AppColors.inkSoft),
                  Text('2026 年 9 月', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  Icon(Icons.chevron_right, color: AppColors.inkSoft),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.mossDark, AppColors.moss, AppColors.mossDeep]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Text('本月總支出', style: TextStyle(color: AppColors.mossLight, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('\$${NumberFormat('#,###').format(expenseTotal)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('收入 \$${NumberFormat('#,###').format(incomeTotal)}', style: const TextStyle(color: AppColors.mossLight, fontSize: 12)),
                      const SizedBox(width: 16),
                      Text('結餘 \$${NumberFormat('#,###').format(balance)}', style: const TextStyle(color: AppColors.mossLight, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: transactions.map((tx) => _buildTransactionRow(tx)).toList(),
              ),
            )
          ],
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('記一筆', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(TransactionModel tx) {
    bool isIncome = tx.type == 'income';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: AppColors.mossLight, shape: BoxShape.circle),
            child: const Icon(Icons.category, color: AppColors.mossDark, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.merchant, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text('${tx.date} • ${tx.category}', style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isIncome ? AppColors.mossLight : AppColors.clayLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isIncome ? AppColors.moss : AppColors.clay),
            ),
            child: Text(
              '${isIncome ? '+' : '-'}\$${NumberFormat('#,###').format(tx.amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isIncome ? AppColors.moss : AppColors.clayDeep),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 5. 計算機與記一筆彈窗
// ==========================================
class AddSheet extends StatefulWidget {
  final Function(TransactionModel) onSaved;
  const AddSheet({super.key, required this.onSaved});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  String display = "0";
  String note = "";
  String selectedCategory = "餐飲";
  bool isExpense = true;

  final List<String> expenseCats = ["餐飲", "交通", "日用品", "娛樂", "服飾", "繳費"];
  final List<String> incomeCats = ["薪資", "獎金", "投資", "兼職", "退款", "其他"];

  void _pressDigit(String d) {
    setState(() {
      if (display == "0" && d != ".") display = d;
      else display += d;
    });
  }

  void _pressBackspace() {
    setState(() {
      if (display.length <= 1) display = "0";
      else display = display.substring(0, display.length - 1);
    });
  }

  void _pressAC() {
    setState(() { display = "0"; });
  }

  void _handleSave() {
    double amount = double.tryParse(display) ?? 0;
    if (amount <= 0) return;

    widget.onSaved(TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      category: selectedCategory,
      merchant: note.isEmpty ? selectedCategory : note,
      amount: amount,
      type: isExpense ? 'expense' : 'income',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.mossDark, AppColors.moss, AppColors.mossDeep]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    children: [
                      _buildTabBtn('支出', isExpense, () => setState(() { isExpense = true; selectedCategory = expenseCats[0]; })),
                      _buildTabBtn('收入', !isExpense, () => setState(() { isExpense = false; selectedCategory = incomeCats[0]; })),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 10,
              children: (isExpense ? expenseCats : incomeCats).map((cat) {
                bool isSelected = selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = cat),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isSelected ? AppColors.moss : AppColors.card,
                        child: Icon(Icons.category, size: 20, color: isSelected ? Colors.white : AppColors.mossDark),
                      ),
                      const SizedBox(height: 4),
                      Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? AppColors.mossDark : AppColors.inkSoft, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.line))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.paperDeep, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => note = val,
                          decoration: const InputDecoration(border: InputBorder.none, hintText: '填寫備註', isDense: true),
                          style: const TextStyle(fontSize: 16, color: AppColors.ink),
                        ),
                      ),
                      Text('$display\$', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isExpense ? AppColors.clayDeep : AppColors.moss)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Row(children: [ _calcBtn('7'), _calcBtn('8'), _calcBtn('9') ]),
                          Row(children: [ _calcBtn('4'), _calcBtn('5'), _calcBtn('6') ]),
                          Row(children: [ _calcBtn('1'), _calcBtn('2'), _calcBtn('3') ]),
                          Row(children: [ _calcBtn('AC', color: AppColors.clayLight, textColor: AppColors.clayDeep), _calcBtn('0'), _calcBtn('.') ]),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _calcBtn('⌫', color: AppColors.clayLight, textColor: AppColors.clayDeep),
                          _calcBtn('+', color: AppColors.mossMist, textColor: AppColors.mossDark),
                          _calcBtn('-', color: AppColors.mossMist, textColor: AppColors.mossDark),
                          GestureDetector(
                            onTap: _handleSave,
                            child: Container(
                              height: 54, margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.moss, AppColors.mossDeep]),
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: const Center(child: Text('完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? AppColors.mossDark : AppColors.mossLight)),
      ),
    );
  }

  Widget _calcBtn(String label, {Color color = AppColors.card, Color textColor = AppColors.ink}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (label == 'AC') _pressAC();
          else if (label == '⌫') _pressBackspace();
          else if (label != '+' && label != '-') _pressDigit(label);
        },
        child: Container(
          height: 54, margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.lineSoft), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))),
        ),
      ),
    );
  }
}
