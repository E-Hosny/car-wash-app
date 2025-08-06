import 'package:flutter/material.dart';
import 'order_request_screen.dart';
import 'my_orders_screen.dart';
import 'all_packages_screen.dart';
import 'guest_services_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String? token; // Made nullable to support guest mode
  final int initialIndex;
  final bool isGuest;

  const MainNavigationScreen({
    super.key,
    this.token,
    this.initialIndex = 0,
    this.isGuest = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
              'You need to login to access this feature. Would you like to login now?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = widget.isGuest
        ? [
            // Guest can browse services
            const GuestServicesScreen(),
            AllPackagesScreen(token: widget.token, isGuest: true),
            const _LoginPromptScreen(), // Show login prompt for orders
          ]
        : [
            OrderRequestScreen(token: widget.token!),
            AllPackagesScreen(token: widget.token, isGuest: false),
            MyOrdersScreen(token: widget.token!),
          ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: widget.isGuest
            ? const Text(
                'Browse Services',
                style: TextStyle(color: Colors.black, fontSize: 18),
              )
            : null,
        actions: [
          if (widget.isGuest)
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text(
                'Login',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('auth_token');
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
        ],
      ),
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: currentIndex,
        onTap: (index) {
          if (widget.isGuest && index == 2) {
            // Show login prompt for Orders tab in guest mode
            _showLoginPrompt();
            return;
          }
          setState(() {
            currentIndex = index;
          });
        },
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              widget.isGuest
                  ? Icons.design_services_outlined
                  : Icons.local_car_wash_outlined,
            ),
            activeIcon: Icon(
              widget.isGuest ? Icons.design_services : Icons.local_car_wash,
            ),
            label: widget.isGuest ? 'Services' : 'New Order',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            activeIcon: Icon(Icons.card_giftcard),
            label: 'Packages',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              widget.isGuest
                  ? Icons.receipt_long_outlined
                  : Icons.receipt_long_outlined,
              color: widget.isGuest ? Colors.grey[400] : null,
            ),
            activeIcon: Icon(
              Icons.receipt_long,
              color: widget.isGuest ? Colors.grey[400] : null,
            ),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}

class _LoginPromptScreen extends StatelessWidget {
  const _LoginPromptScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Login Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You need to login to access this feature',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Login Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
