import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'my_orders_screen.dart';
import 'all_packages_screen.dart';
import 'guest_services_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'services/config_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final String? token; // Made nullable to support guest mode
  final int initialIndex;
  final bool isGuest;
  final bool forceOrdersTab; // New parameter to force orders tab
  final bool showPaymentSuccess; // New parameter to show payment success message

  const MainNavigationScreen({
    super.key,
    this.token,
    this.initialIndex = 0,
    this.isGuest = false,
    this.forceOrdersTab = false,
    this.showPaymentSuccess = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int currentIndex;
  bool packagesEnabled = true;
  bool loadingConfig = true;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    // Clear any existing snackbars when entering main navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final enabled = await ConfigService.fetchPackagesEnabled();
    if (!mounted) return;
    
    setState(() {
      packagesEnabled = enabled;
      loadingConfig = false;

      // If forceOrdersTab is true, ensure we stay on orders tab
      if (widget.forceOrdersTab) {
        currentIndex = packagesEnabled ? 2 : 1; // Orders tab index
      } else {
        // Adjust currentIndex based on packages availability
        if (!packagesEnabled) {
          // If packages are disabled, adjust index for orders tab
          if (currentIndex == 2) {
            currentIndex = 1; // Orders tab when packages disabled
          } else if (currentIndex == 1) {
            currentIndex = 0; // Home tab
          }
        }
      }
    });
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
    if (loadingConfig) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = widget.isGuest
        ? (packagesEnabled
            ? [
                const GuestServicesScreen(),
                AllPackagesScreen(token: widget.token, isGuest: true),
                const _LoginPromptScreen(),
              ]
            : [
                const GuestServicesScreen(),
                const _LoginPromptScreen(),
              ])
        : (packagesEnabled
            ? [
                HomeScreen(token: widget.token!),
                AllPackagesScreen(token: widget.token, isGuest: false),
                MyOrdersScreen(token: widget.token!, showSuccessMessage: widget.showPaymentSuccess),
              ]
            : [
                HomeScreen(token: widget.token!),
                MyOrdersScreen(token: widget.token!, showSuccessMessage: widget.showPaymentSuccess),
              ]);

    final items = widget.isGuest
        ? (packagesEnabled
            ? [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.design_services_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.design_services,
                  ),
                  label: 'Services',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard_outlined),
                  activeIcon: Icon(Icons.card_giftcard),
                  label: 'Packages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.grey[400],
                  ),
                  activeIcon: Icon(
                    Icons.receipt_long,
                    color: Colors.grey[400],
                  ),
                  label: 'Orders',
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.design_services_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.design_services,
                  ),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.grey[400],
                  ),
                  activeIcon: Icon(
                    Icons.receipt_long,
                    color: Colors.grey[400],
                  ),
                  label: 'Orders',
                ),
              ])
        : (packagesEnabled
            ? [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.home,
                  ),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard_outlined),
                  activeIcon: Icon(Icons.card_giftcard),
                  label: 'Packages',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home_outlined,
                  ),
                  activeIcon: Icon(
                    Icons.home,
                  ),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
              ]);

    // Ensure currentIndex is within range
    if (currentIndex >= screens.length) {
      currentIndex = 0;
    }

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
          // Allow normal navigation - remove forceOrdersTab restrictions
          if (widget.isGuest && !packagesEnabled && index == 1) {
            _showLoginPrompt();
            return;
          }
          if (widget.isGuest && packagesEnabled && index == 2) {
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
        items: items,
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
