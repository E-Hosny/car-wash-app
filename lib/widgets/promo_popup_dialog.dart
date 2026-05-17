import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/config_service.dart';

class PromoPopupDialog extends StatelessWidget {
  const PromoPopupDialog({
    super.key,
    required this.config,
    required this.isRTL,
    required this.languageCode,
    required this.onAction,
  });

  final AppPromoPopupConfig config;
  final bool isRTL;
  final String languageCode;
  final VoidCallback onAction;

  bool get _isArabic => languageCode == 'ar';

  String get _title {
    if (_isArabic && config.titleAr.isNotEmpty) return config.titleAr;
    if (config.title.isNotEmpty) return config.title;
    return config.titleAr;
  }

  String get _body {
    if (_isArabic && config.bodyAr.isNotEmpty) return config.bodyAr;
    if (config.body.isNotEmpty) return config.body;
    return config.bodyAr;
  }

  String get _buttonLabel {
    if (_isArabic && config.buttonTextAr.isNotEmpty) return config.buttonTextAr;
    if (config.buttonText.isNotEmpty) return config.buttonText;
    return config.buttonTextAr.isNotEmpty ? config.buttonTextAr : (_isArabic ? 'اكتشف العرض' : 'View Offer');
  }

  TextStyle _textStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    if (_isArabic) {
      return GoogleFonts.cairo(fontSize: fontSize, fontWeight: fontWeight, color: color);
    }
    return GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final hasAction = config.linkType.isNotEmpty && config.linkType != 'none';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF8E7),
                  Color(0xFFFFE4B5),
                  Color(0xFFFFD89B),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.imageUrl != null && config.imageUrl!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        config.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.white24,
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    )
                  else
                    _imagePlaceholder(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      children: [
                        if (_title.isNotEmpty)
                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: _textStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        if (_title.isNotEmpty && _body.isNotEmpty)
                          const SizedBox(height: 10),
                        if (_body.isNotEmpty)
                          Text(
                            _body,
                            textAlign: TextAlign.center,
                            style: _textStyle(
                              fontSize: 15,
                              color: const Color(0xFF4A4A4A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 22),
                        if (hasAction)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: onAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A1A1A),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: Colors.black26,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.card_giftcard_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _buttonLabel,
                                      style: _textStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            _isArabic ? 'لاحقاً' : 'Maybe later',
                            style: _textStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
            ),
          ),
          Positioned(
            top: 36,
            right: isRTL ? null : 8,
            left: isRTL ? 8 : null,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(false),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 20, color: Colors.black54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB74D)],
        ),
      ),
      child: const Icon(Icons.celebration_rounded, size: 64, color: Colors.white70),
    );
  }
}
