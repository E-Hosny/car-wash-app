import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // استيراد صفحة تسجيل الدخول
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Splash delay
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print('🔍 Checking login status...');
      print('Token exists: ${token != null}');
      print('Token length: ${token?.length ?? 0}');

      if (token != null && token.isNotEmpty) {
        print('✅ User is logged in, navigating to MainNavigationScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MainNavigationScreen(token: token, isGuest: false),
          ),
        );
      } else {
        print('❌ No token found, showing guest options');
        if (!mounted) return;
        _showGuestDialog();
      }
    } catch (e) {
      print('❌ Error in _checkLoginStatus: $e');
      if (!mounted) return;
      _showGuestDialog();
    }
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Welcome to Car Wash App',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You can browse our services as a guest or login to access full features including placing orders.',
          ),
          actions: [
            TextButton(
              child: const Text('Browse as Guest'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainNavigationScreen(
                      isGuest: true,
                      initialIndex: 0, // Start with services tab
                    ),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(
          image: AssetImage('assets/logo.png'),
          width: 300,
          height: 300,
        ),
      ),
    );
  }
}
