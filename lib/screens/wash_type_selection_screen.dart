import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main_navigation_screen.dart';
import '../screens/caravan_size_selection_screen.dart';
import '../screens/car_type_selection_screen.dart';
import '../services/language_service.dart';
import '../services/wash_context_service.dart';
import '../translations.dart';

class WashTypeSelectionScreen extends StatefulWidget {
  const WashTypeSelectionScreen({
    super.key,
    required this.token,
    this.allowSkip = false,
  });

  final String token;
  final bool allowSkip;

  @override
  State<WashTypeSelectionScreen> createState() => _WashTypeSelectionScreenState();
}

class _WashTypeSelectionScreenState extends State<WashTypeSelectionScreen> {
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

  TextStyle _style({double size = 16, FontWeight weight = FontWeight.normal, Color? color}) {
    final font = _lang == 'ar' ? GoogleFonts.cairo : GoogleFonts.poppins;
    return font(fontSize: size, fontWeight: weight, color: color);
  }

  Future<void> _selectCar() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarTypeSelectionScreen(token: widget.token),
      ),
    );
  }

  Future<void> _selectCaravan() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaravanSizeSelectionScreen(token: widget.token),
      ),
    );
  }

  Future<void> _selectMotorcycle() async {
    await WashContextService.save(
      const WashContext(category: WashCategory.motorcycle),
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
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_t('wash_type_title'), style: _style(weight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: widget.allowSkip,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t('wash_type_subtitle'),
                textAlign: TextAlign.center,
                style: _style(size: 15, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              _WashTypeCard(
                icon: Icons.directions_car_filled,
                title: _t('wash_type_car'),
                subtitle: _t('wash_type_car_hint'),
                onTap: _selectCar,
              ),
              const SizedBox(height: 16),
              _WashTypeCard(
                icon: Icons.airport_shuttle,
                title: _t('wash_type_caravan'),
                subtitle: _t('wash_type_caravan_hint'),
                onTap: _selectCaravan,
              ),
              const SizedBox(height: 16),
              _WashTypeCard(
                icon: Icons.two_wheeler,
                title: _t('wash_type_motorcycle'),
                subtitle: _t('wash_type_motorcycle_hint'),
                onTap: _selectMotorcycle,
              ),
              const Spacer(),
              if (widget.allowSkip)
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MainNavigationScreen(token: widget.token),
                      ),
                    );
                  },
                  child: Text(_t('continue_to_home')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WashTypeCard extends StatelessWidget {
  const _WashTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const _iconBlue = Color(0xFF1565C0);
  static const _iconBg = Color(0xFFE3F2FD);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F8FA),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
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
                child: Icon(icon, color: _iconBlue, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: _iconBlue.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
