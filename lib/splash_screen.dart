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
            builder: (context) => MainNavigationScreen(token: token),
          ),
        );
      } else {
        print('❌ No token found, navigating to LoginScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('❌ Error in _checkLoginStatus: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
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
