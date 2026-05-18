import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main_navigation_screen.dart';
import '../services/language_service.dart';
import '../services/wash_context_service.dart';
import '../translations.dart';

class CaravanSizeSelectionScreen extends StatefulWidget {
  const CaravanSizeSelectionScreen({super.key, required this.token});

  final String token;

  @override
  State<CaravanSizeSelectionScreen> createState() =>
      _CaravanSizeSelectionScreenState();
}

class _CaravanSizeSelectionScreenState extends State<CaravanSizeSelectionScreen> {
  static const _iconBlue = Color(0xFF1565C0);
  static const _iconBg = Color(0xFFE3F2FD);

  String _lang = 'en';
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
        _lang = lang;
        _isRTL = isRTL;
      });
    }
  }

  String _t(String key) => AppTranslations.getTextWithFallback(key, _lang);

  Future<void> _select(CaravanSize size) async {
    await WashContextService.save(
      WashContext(category: WashCategory.caravan, caravanSize: size),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(token: widget.token),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _lang == 'ar' ? GoogleFonts.cairo : GoogleFonts.poppins;
    final sizes = [
      (CaravanSize.small, 'caravan_size_small', Icons.rv_hookup),
      (CaravanSize.medium, 'caravan_size_medium', Icons.airport_shuttle),
      (CaravanSize.large, 'caravan_size_large', Icons.local_shipping),
    ];

    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_t('select_caravan_size'), style: style(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _t('select_caravan_size_hint'),
              textAlign: TextAlign.center,
              style: style(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ...sizes.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _select(item.$1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _iconBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(item.$3, size: 32, color: _iconBlue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _t(item.$2),
                              style: style(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: _iconBlue.withOpacity(0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
