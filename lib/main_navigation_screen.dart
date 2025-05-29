import 'package:flutter/material.dart';
import 'order_request_screen.dart';
import 'my_orders_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String token;
  const MainNavigationScreen({super.key, required this.token});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // الصفحات اللي هنبدل بينهم
    final screens = [
      OrderRequestScreen(token: widget.token),
      MyOrdersScreen(token: widget.token),
    ];

    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Orders',
          ),
        ],
      ),
    );
  }
}
