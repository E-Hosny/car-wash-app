import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:upgrader/upgrader.dart';
import 'services/force_update_messages.dart';
import 'services/language_service.dart';
import 'login_screen.dart'; // استيراد صفحة تسجيل الدخول
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation_screen.dart';
import 'translations.dart';
import 'widgets/language_selection_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _currentLanguage = 'en';
  bool _isRTL = false;
  bool _languageSelected = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _checkLoginStatus();
  }

  Future<void> _loadLanguage() async {
    final lang = await LanguageService.getCurrentLanguage();
    final isRTL = await LanguageService.isRTL();
    if (mounted) {
      setState(() {
        _currentLanguage = lang;
        _isRTL = isRTL;
      });
    }
  }

  String _t(String key) {
    return AppTranslations.getTextWithFallback(key, _currentLanguage);
  }

  TextStyle _getArabicTextStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    if (_currentLanguage == 'ar') {
      return GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    } else {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Splash delay
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final languageSelected = prefs.getBool('language_selected') ?? false;

      print('🔍 Checking login status...');
      print('Token exists: ${token != null}');
      print('Token length: ${token?.length ?? 0}');
      print('Language selected: $languageSelected');

      // Show language selection dialog first if not logged in and language not selected
      if (token == null || token.isEmpty) {
        if (!languageSelected && !_languageSelected) {
          if (!mounted) return;
          await _showLanguageSelectionDialog();
          // Reload language after selection
          await _loadLanguage();
        }
      }

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

  Future<void> _showLanguageSelectionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LanguageSelectionDialog();
      },
    );
    
    // Mark language as selected
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    if (mounted) {
      setState(() {
        _languageSelected = true;
      });
      await _loadLanguage();
    }
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              _t('welcome_car_wash'),
              style: _getArabicTextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              _t('welcome_message'),
              style: _getArabicTextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                child: Text(
                  _t('browse_as_guest'),
                  style: _getArabicTextStyle(),
                ),
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
                child: Text(
                  _t('login'),
                  style: _getArabicTextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: UpgradeAlert(
        upgrader: Upgrader(
          // Country code for App Store/Play Store
          countryCode: 'us',
          // Check immediately
          durationUntilAlertAgain: const Duration(days: 0),
          // Custom messages for force update
          messages: ForceUpdateMessages(),
        ),
        child: const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Image(
              image: AssetImage('assets/logo.png'),
              width: 300,
              height: 300,
            ),
          ),
        ),
      ),
    );
  }
}
