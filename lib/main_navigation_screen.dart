import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'my_orders_screen.dart';
import 'all_packages_screen.dart';
import 'guest_services_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'login_screen.dart';
import 'services/config_service.dart';
import 'services/data_preloader_service.dart';
import 'services/language_service.dart';
import 'services/cache_service.dart';
import 'screens/support_screen.dart';
import 'translations.dart';

class MainNavigationScreen extends StatefulWidget {
  final String? token; // Made nullable to support guest mode
  final int initialIndex;
  final bool isGuest;
  final bool forceOrdersTab; // New parameter to force orders tab
  final bool showPaymentSuccess; // New parameter to show payment success message
  final bool forceRefreshOrders; // New parameter to force refresh orders when navigating

  const MainNavigationScreen({
    super.key,
    this.token,
    this.initialIndex = 0,
    this.isGuest = false,
    this.forceOrdersTab = false,
    this.showPaymentSuccess = false,
    this.forceRefreshOrders = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int currentIndex;
  bool packagesEnabled = true;
  bool loadingConfig = true;
  List<Widget>? screens; // Store screens to prevent recreation
  String _currentLanguage = 'en';
  bool _isRTL = false;

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
    _loadLanguage();
    _loadConfig();
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

  void _buildScreens() {
    screens = widget.isGuest
        ? (packagesEnabled
            ? [
                GuestServicesScreen(key: ValueKey('guest_services_$_currentLanguage')),
                AllPackagesScreen(token: widget.token, isGuest: true),
                const _LoginPromptScreen(),
              ]
            : [
                GuestServicesScreen(key: ValueKey('guest_services_$_currentLanguage')),
                const _LoginPromptScreen(),
              ])
        : (packagesEnabled
            ? [
                HomeScreen(token: widget.token!),
                AllPackagesScreen(token: widget.token, isGuest: false),
                MyOrdersScreen(
                  token: widget.token!, 
                  showSuccessMessage: widget.showPaymentSuccess,
                  forceRefresh: widget.forceRefreshOrders,
                ),
              ]
            : [
                HomeScreen(token: widget.token!),
                MyOrdersScreen(
                  token: widget.token!, 
                  showSuccessMessage: widget.showPaymentSuccess,
                  forceRefresh: widget.forceRefreshOrders,
                ),
              ]);
  }

  Future<void> _loadConfig() async {
    try {
      final enabled = await ConfigService.fetchPackagesEnabled();
      if (!mounted) return;
      
      setState(() {
        packagesEnabled = enabled;
        loadingConfig = false;

        // Build screens once after config is loaded
        _buildScreens();

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

      // Preload critical data in background for logged-in users only
      // This improves performance for Single Car Wash screen
      if (!widget.isGuest && widget.token != null && widget.token!.isNotEmpty) {
        _preloadDataInBackground();
      }
    } catch (e) {
      print('⚠️ Error loading config: $e');
      if (!mounted) return;
      // Default to enabled if error occurs
      setState(() {
        packagesEnabled = true;
        loadingConfig = false;
        _buildScreens();
      });

      // Still try to preload data even if config loading failed
      if (!widget.isGuest && widget.token != null && widget.token!.isNotEmpty) {
        _preloadDataInBackground();
      }
    }
  }

  /// Preload critical data in background without blocking UI
  void _preloadDataInBackground() {
    // Start preload in background, don't await it
    DataPreloaderService().preloadCriticalData(widget.token!).catchError((e) {
      print('⚠️ Error during background data preload: $e');
      // Don't show error to user, this is a background operation
      return false;
    });
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              _t('login_required'),
              style: _getArabicTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              _t('login_required_message'),
              style: _getArabicTextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                child: Text(
                  _t('cancel'),
                  style: _getArabicTextStyle(),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(
                  _t('login'),
                  style: _getArabicTextStyle(),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingConfig || screens == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                  label: _t('services'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.card_giftcard_outlined),
                  activeIcon: const Icon(Icons.card_giftcard),
                  label: _t('packages'),
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
                  label: _t('orders'),
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
                  label: _t('services'),
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
                  label: _t('orders'),
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
                  label: _t('home'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.card_giftcard_outlined),
                  activeIcon: const Icon(Icons.card_giftcard),
                  label: _t('packages'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: _t('orders'),
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
                  label: _t('home'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: _t('orders'),
                ),
              ]);

    // Ensure currentIndex is within range
    if (currentIndex >= screens!.length) {
      currentIndex = 0;
    }

    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
          title: widget.isGuest
              ? Text(
                  _t('browse_services'),
                  style: _getArabicTextStyle(
                    fontSize: 18,
                    color: Colors.black,
                  ),
                )
              : null,
          actions: [
            if (widget.isGuest) ...[
              // Language Toggle Button
              IconButton(
                icon: Icon(
                  Icons.language,
                  color: Colors.grey[700],
                  size: 24,
                ),
                tooltip: _t('language'),
                onPressed: () async {
                  final newLang = _currentLanguage == 'ar' ? 'en' : 'ar';
                  await LanguageService.setCurrentLanguage(newLang);
                  
                  // Invalidate services cache to force reload with new language
                  final cacheService = CacheService();
                  final token = widget.token ?? '';
                  cacheService.invalidateServices(token);
                  
                  if (mounted) {
                    setState(() {
                      _currentLanguage = newLang;
                      _isRTL = newLang == 'ar';
                    });
                    
                    // Force rebuild of screens to reload services with new language
                    _buildScreens();
                    setState(() {}); // Trigger rebuild
                  }
                },
              ),
              // Login Button
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: Text(
                  _t('login'),
                  style: _getArabicTextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
            else
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: _t('logout'),
                onPressed: () async {
                // تسجيل الخروج من OneSignal
                try {
                  await OneSignal.logout();
                  print("✅ OneSignal user logged out");
                } catch (e) {
                  print("⚠️ Warning: OneSignal logout failed: $e");
                }
                
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
      body: IndexedStack(
        index: currentIndex,
        children: screens!,
      ),
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
        selectedLabelStyle: _getArabicTextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: items,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupportScreen(token: widget.token),
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.help, color: Colors.white),
      ),
      floatingActionButtonLocation: _isRTL 
          ? FloatingActionButtonLocation.startFloat 
          : FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class _LoginPromptScreen extends StatefulWidget {
  const _LoginPromptScreen();

  @override
  State<_LoginPromptScreen> createState() => _LoginPromptScreenState();
}

class _LoginPromptScreenState extends State<_LoginPromptScreen> {
  String _currentLanguage = 'en';
  bool _isRTL = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
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
                _t('login_required'),
                style: _getArabicTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t('login_required_message'),
                textAlign: TextAlign.center,
                style: _getArabicTextStyle(
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
                child: Text(
                  _t('login_now'),
                  style: _getArabicTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
