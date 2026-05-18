import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'screens/wash_type_selection_screen.dart';
import 'services/wash_context_service.dart';
import 'utils/post_login_navigation.dart';
import 'utils/single_wash_navigation.dart';
import 'widgets/wash_category_chip_bar.dart';
import 'multi_car_order_screen.dart';
import 'all_packages_screen.dart';
import 'my_orders_screen.dart';
import 'screens/support_screen.dart';
import 'single_wash_order_screen.dart';
import 'translations.dart';
import 'services/config_service.dart';
import 'services/language_service.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  final int refreshToken;

  const HomeScreen({
    super.key,
    required this.token,
    this.refreshToken = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentLanguage = 'en';
  bool _isRTL = false;
  late StreamSubscription _languageSubscription;
  HomeBannerConfig? _bannerConfig;
  WashContext _washContext = const WashContext(category: WashCategory.car);

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadWashContext();
    _loadBannerConfigCachedThenFromApi();
    _languageSubscription = LanguageService.languageStream.listen((languageCode) async {
      await _loadLanguage();
    });
  }

  /// يعرض أحدث سيارة على الرئيسية؛ بلا سيارات يُوجَّه لاختيار نوع الغسلة.
  Future<void> reloadWashContext() async {
    await _loadWashContext();
  }

  Future<void> _loadWashContext() async {
    final hasCars = await PostLoginNavigation.userHasCars(widget.token);
    if (!mounted) return;

    if (!hasCars) {
      final saved = await WashContextService.load();
      if (!mounted) return;
      if (!WashContextService.canEnterHomeWithoutRegisteredCars(saved)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WashTypeSelectionScreen(
              token: widget.token,
              allowSkip: false,
            ),
          ),
        );
        return;
      }
      setState(() => _washContext = saved);
      return;
    }

    final ctx = await WashContextService.syncHomeEntryContext(widget.token);
    if (!mounted || ctx == null) return;
    setState(() => _washContext = ctx);
  }

  bool get _usesSpecialistHomeActions {
    return (_washContext.category == WashCategory.caravan &&
            _washContext.caravanSize != null) ||
        _washContext.category == WashCategory.motorcycle;
  }

  Future<void> _loadBannerConfigCachedThenFromApi() async {
    final cached = await ConfigService.getCachedHomeBannerConfig();
    if (mounted) setState(() => _bannerConfig = cached);
    final config = await ConfigService.fetchHomeBannerConfig();
    if (mounted) setState(() => _bannerConfig = config);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadWashContext();
    }
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
        SingleWashNavigation.open(context, widget.token);
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

              WashCategoryChipBar(
                token: widget.token,
                washContext: _washContext,
                onChanged: reloadWashContext,
              ),
              const SizedBox(height: 16),

              // Banner Image (from API or fallback to asset)
              _buildBanner(),

              // Service Cards
              Column(
                children: _usesSpecialistHomeActions
                    ? [
                        if (_washContext.category == WashCategory.caravan &&
                            _washContext.caravanSize != null)
                          _buildServiceCard(
                            context: context,
                            title: _t('caravan_wash_action'),
                            subtitle: _t('caravan_wash_action_subtitle'),
                            icon: Icons.rv_hookup,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SingleWashOrderScreen(
                                    token: widget.token,
                                    washCategory: WashCategory.caravan,
                                    caravanSize: _washContext.caravanSize,
                                  ),
                                ),
                              );
                            },
                          )
                        else if (_washContext.category ==
                            WashCategory.motorcycle)
                          _buildServiceCard(
                            context: context,
                            title: _t('bike_wash_action'),
                            subtitle: _t('bike_wash_action_subtitle'),
                            icon: Icons.two_wheeler,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SingleWashOrderScreen(
                                    token: widget.token,
                                    washCategory: WashCategory.motorcycle,
                                  ),
                                ),
                              );
                            },
                          ),
                      ]
                    : [
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
                            SingleWashNavigation.open(context, widget.token);
                          },
                        ),
                        const SizedBox(height: 24),
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
}
