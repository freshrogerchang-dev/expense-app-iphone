import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'screens/bookkeeping_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/assets_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: 換成你原本 Vercel 專案 .env 裡的 Supabase URL / anon key
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_REF.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記帳 App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.paper,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.moss),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// 依 Supabase Auth 的登入狀態，自動顯示登入頁或主畫面。
/// 未登入 → LoginScreen；已登入 → HomeShell。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() => _session = data.session);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const LoginScreen();
    }
    return const HomeShell();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _tab = 'book';

  // 走到 HomeShell 代表 AuthGate 已經確認有登入 session，
  // 這裡的 'demo-user' 只是型別安全用的保底值，正常不會用到。
  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? 'demo-user';

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_tab) {
      case 'stats':
        body = StatsScreen(userId: _userId);
        break;
      case 'assets':
        body = AssetsScreen(userId: _userId);
        break;
      case 'settings':
        body = SettingsScreen(userId: _userId, onLogout: _logout);
        break;
      case 'book':
      default:
        body = BookkeepingScreen(userId: _userId);
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: BottomNavBar(
        activeTab: _tab,
        onTabChange: (t) => setState(() => _tab = t),
      ),
    );
  }
}
