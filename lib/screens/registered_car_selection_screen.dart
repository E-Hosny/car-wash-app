import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/cache_service.dart';
import '../services/language_service.dart';
import '../services/wash_context_service.dart';
import '../translations.dart';
import 'car_type_selection_screen.dart';

class RegisteredCarSelectionScreen extends StatefulWidget {
  const RegisteredCarSelectionScreen({super.key, required this.token});

  final String token;

  @override
  State<RegisteredCarSelectionScreen> createState() =>
      _RegisteredCarSelectionScreenState();
}

class _RegisteredCarSelectionScreenState
    extends State<RegisteredCarSelectionScreen> {
  static const _iconBlue = Color(0xFF1565C0);
  static const _iconBg = Color(0xFFE3F2FD);

  List<dynamic> cars = [];
  int? selectedCarId;
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
    final ctx = await WashContextService.load();
    final fetched = await CacheService().getCars(widget.token);
    if (!mounted) return;
    setState(() {
      _lang = lang;
      _isRTL = isRTL;
      cars = fetched;
      selectedCarId = ctx.carId;
      loading = false;
    });
  }

  String _t(String key) => AppTranslations.getTextWithFallback(key, _lang);

  TextStyle _style({
    double size = 16,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    return (_lang == 'ar' ? GoogleFonts.cairo : GoogleFonts.poppins)(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  String _carTitle(Map car) => WashContextService.carDisplayName(car);

  String? _carSubtitle(Map car) {
    final parts = <String>[];
    try {
      final year = car['year'] is Map
          ? car['year']['year']?.toString()
          : car['year']?.toString();
      if (year != null && year.isNotEmpty) {
        parts.add('${_t('year')}: $year');
      }
    } catch (_) {}

    final color = car['color']?.toString();
    if (color != null && color.isNotEmpty) {
      parts.add('${_t('color')}: $color');
    }

    final plate = car['license_plate']?.toString();
    if (plate != null && plate.isNotEmpty) {
      parts.add(plate);
    }

    return parts.isEmpty ? null : parts.join(' • ');
  }

  int? _parseCarId(dynamic id) {
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Future<void> _selectCar(Map car) async {
    final carId = _parseCarId(car['id']);
    await WashContextService.save(
      WashContext(
        category: WashCategory.car,
        carTypeKey: car['car_type']?.toString(),
        carId: carId,
        carDisplayName: WashContextService.carDisplayName(car),
      ),
    );
    if (!mounted) return;
    _returnToHome();
  }

  void _returnToHome() {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _addNewCar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarTypeSelectionScreen(token: widget.token),
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
          title: Text(_t('select_your_car'), style: _style(weight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          _t('select_your_car_hint'),
                          textAlign: TextAlign.center,
                          style: _style(size: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        ...cars.map((raw) {
                          final car = Map<String, dynamic>.from(raw as Map);
                          final carId = _parseCarId(car['id']);
                          final isSelected = selectedCarId != null &&
                              carId != null &&
                              selectedCarId == carId;
                          final subtitle = _carSubtitle(car);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: isSelected
                                  ? _iconBg
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _selectCar(car),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _iconBlue
                                              : _iconBg,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.directions_car,
                                          size: 32,
                                          color: isSelected
                                              ? Colors.white
                                              : _iconBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _carTitle(car),
                                              style: _style(
                                                size: 18,
                                                weight: FontWeight.bold,
                                              ),
                                            ),
                                            if (subtitle != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                subtitle,
                                                style: _style(
                                                  size: 13,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: _iconBlue.withOpacity(0.5),
                                      ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: OutlinedButton.icon(
                      onPressed: _addNewCar,
                      icon: const Icon(Icons.add, color: _iconBlue),
                      label: Text(
                        _t('add_new_car'),
                        style: _style(
                          weight: FontWeight.bold,
                          color: _iconBlue,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: _iconBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
