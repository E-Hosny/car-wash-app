import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../add_car_screen.dart';
import '../services/config_service.dart';
import '../services/language_service.dart';
import '../services/wash_context_service.dart';
import '../translations.dart';

class CarTypeSelectionScreen extends StatefulWidget {
  const CarTypeSelectionScreen({super.key, required this.token});

  final String token;

  @override
  State<CarTypeSelectionScreen> createState() => _CarTypeSelectionScreenState();
}

class _CarTypeSelectionScreenState extends State<CarTypeSelectionScreen> {
  static const _iconBlue = Color(0xFF1565C0);
  static const _iconBg = Color(0xFFE3F2FD);

  List<CarTypePricingRule> rules = [];
  bool loading = true;
  String _lang = 'en';
  bool _isRTL = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lang = await LanguageService.getCurrentLanguage();
    final isRTL = await LanguageService.isRTL();
    final fetched = await ConfigService.fetchCarTypePricingRules();
    if (mounted) {
      setState(() {
        _lang = lang;
        _isRTL = isRTL;
        rules = fetched;
        loading = false;
      });
    }
  }

  String _t(String key) => AppTranslations.getTextWithFallback(key, _lang);

  TextStyle _style({double size = 16, FontWeight weight = FontWeight.normal}) {
    return (_lang == 'ar' ? GoogleFonts.cairo : GoogleFonts.poppins)(
      fontSize: size,
      fontWeight: weight,
    );
  }

  Future<void> _onSelect(CarTypePricingRule rule) async {
    await WashContextService.save(
      WashContext(category: WashCategory.car, carTypeKey: rule.key),
    );
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddCarScreen(
          token: widget.token,
          preselectedCarTypeKey: rule.key,
          navigateToServicesOnSuccess: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_t('select_car_type'), style: _style(weight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ...rules.map((rule) {
                    final label = rule.labelForLanguage(_lang);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _onSelect(rule),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _iconBg,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    size: 32,
                                    color: _iconBlue,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: _style(size: 17, weight: FontWeight.bold),
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
