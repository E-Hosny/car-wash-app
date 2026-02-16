import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'single_wash_order_screen.dart';
import 'multi_car_order_screen.dart';
import 'all_packages_screen.dart';
import 'my_orders_screen.dart';
import 'screens/support_screen.dart';
import 'translations.dart';
import 'services/config_service.dart';
import 'services/language_service.dart';

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({super.key, required this.token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentLanguage = 'en';
  bool _isRTL = false;
  late StreamSubscription _languageSubscription;
  HomeBannerConfig? _bannerConfig;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadBannerConfigCachedThenFromApi();
    _languageSubscription = LanguageService.languageStream.listen((languageCode) async {
      await _loadLanguage();
    });
  }

  /// عرض البانر من الذاكرة المحلية فوراً ثم تحديثه من الـ API في الخلفية
  Future<void> _loadBannerConfigCachedThenFromApi() async {
    final cached = await ConfigService.getCachedHomeBannerConfig();
    if (mounted) setState(() => _bannerConfig = cached);
    final config = await ConfigService.fetchHomeBannerConfig();
    if (mounted) setState(() => _bannerConfig = config);
  }

  @override
  void dispose() {
    _languageSubscription.cancel(); // Cancel subscription
    super.dispose();
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

  Widget _buildBanner() {
    final config = _bannerConfig;
    final hasLink = config != null &&
        config.linkType.isNotEmpty &&
        config.linkType != 'none';
    // إذا لم يُضف أدمن أي صورة من الباكند، نعرض الصورة الافتراضية الحالية (assets/banner.png)
    final bannerUrl = config?.imageUrl;
    final imageWidget = bannerUrl != null && bannerUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: bannerUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            placeholder: (context, url) => _bannerPlaceholder(),
            errorWidget: (context, url, error) => _bannerPlaceholder(),
          )
        : Image.asset(
            'assets/banner.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => _bannerPlaceholder(),
          );

    final content = Container(
      width: double.infinity,
      height: 180,
      margin: const EdgeInsets.only(bottom: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: imageWidget,
      ),
    );

    if (!hasLink) return content;
    return InkWell(
      onTap: () => _onBannerTap(config),
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.local_car_wash, size: 60, color: Colors.grey[400]),
    );
  }

  Future<void> _onBannerTap(HomeBannerConfig config) async {
    switch (config.linkType) {
      case 'single_wash':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SingleWashOrderScreen(token: widget.token),
          ),
        );
        break;
      case 'multi_car':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiCarOrderScreen(token: widget.token),
          ),
        );
        break;
      case 'packages':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllPackagesScreen(
              token: widget.token,
              isGuest: false,
            ),
          ),
        );
        break;
      case 'orders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyOrdersScreen(token: widget.token),
          ),
        );
        break;
      case 'support':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupportScreen(token: widget.token),
          ),
        );
        break;
      case 'external':
        final url = config.externalUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF5F5F7)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('welcome_to'),
                        style: _getArabicTextStyle(
                          fontSize: 24,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        _t('luxuria_car_wash'),
                        style: _getArabicTextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('choose_service_type'),
                        style: _getArabicTextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

              // Banner Image (from API or fallback to asset)
              _buildBanner(),

              // Service Cards
              Column(
                children: [
                  // Single Car Wash Card
                  _buildServiceCard(
                    context: context,
                    title: _t('single_car_wash'),
                    subtitle: _t('single_car_wash_subtitle'),
                    icon: Icons.local_car_wash,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SingleWashOrderScreen(token: widget.token),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Multi-Car Order Card
                  _buildServiceCard(
                    context: context,
                    title: _t('multi_car_order'),
                    subtitle: _t('multi_car_order_subtitle'),
                    icon: Icons.directions_car,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MultiCarOrderScreen(token: widget.token),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // How It Works Section
              _buildHowItWorksSection(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _getArabicTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: _getArabicTextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isRTL ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('how_it_works'),
          style: _getArabicTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        _buildStep(
          number: '1',
          title: _t('step_1_title'),
          description: _t('step_1_description'),
          icon: Icons.touch_app,
        ),
        _buildStep(
          number: '2',
          title: _t('step_2_title'),
          description: _t('step_2_description'),
          icon: Icons.checklist,
        ),
        _buildStep(
          number: '3',
          title: _t('step_3_title'),
          description: _t('step_3_description'),
          icon: Icons.payment,
        ),
        _buildStep(
          number: '4',
          title: _t('step_4_title'),
          description: _t('step_4_description'),
          icon: Icons.location_on,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    bool isLast = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: _getArabicTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.only(top: 8),
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: _getArabicTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: _getArabicTextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
