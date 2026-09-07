import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTab {
  final String id;
  final IconData icon;
  final String label;
  const AppTab(this.id, this.icon, this.label);
}

const List<AppTab> appTabs = [
  AppTab('book', Icons.edit_note, '記帳'),
  AppTab('stats', Icons.pie_chart, '統計'),
  AppTab('assets', Icons.account_balance_wallet, '資產'),
  AppTab('settings', Icons.settings, '設定'),
];

class BottomNavBar extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChange;
  const BottomNavBar({super.key, required this.activeTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      child: Row(
        children: appTabs.map((t) {
          final active = activeTab == t.id;
          return Expanded(
            child: InkWell(
              onTap: () => onTabChange(t.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.mossMist : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      t.icon,
                      size: 20,
                      color: active ? AppColors.mossDark : AppColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: active ? AppColors.mossDark : AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
