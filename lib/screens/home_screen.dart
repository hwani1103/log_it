import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'create_log_screen.dart';
import 'date_view_screen.dart';
import 'equipment_view_screen.dart';
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
      const CreateLogScreen(),
      const DateViewScreen(),
      const EquipmentViewScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        ],
      ),
    );
  }
}
