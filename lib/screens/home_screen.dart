import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'create_log_screen.dart';
import 'date_view_screen.dart';
import 'equipment_view_screen.dart';
import 'memo_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      CreateLogScreen(
        onRequestTabSwitch: (int index) {
          setState(() => _currentIndex = index);
        },
      ),
      const DateViewScreen(),
      const EquipmentViewScreen(),
      const MemoScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 날짜별 조회 탭(인덱스 1)이면 앱 종료
        if (_currentIndex == 1) {
          return true;
        }
        // 다른 탭이면 날짜별 조회 탭으로 이동
        setState(() => _currentIndex = 1);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Log.it'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: '일지 작성',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '날짜별 조회',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설비별 조회',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: '메모',
          ),
        ],
      ),
      ),
    );
  }
}
