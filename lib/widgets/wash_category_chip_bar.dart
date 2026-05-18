import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/wash_type_selection_screen.dart';
import '../services/language_service.dart';
import '../services/wash_context_service.dart';
import '../translations.dart';

class WashCategoryChipBar extends StatelessWidget {
  const WashCategoryChipBar({
    super.key,
    required this.token,
    required this.washContext,
    this.onChanged,
  });

  final String token;
  final WashContext washContext;
  final VoidCallback? onChanged;

  String _label(WashContext ctx, String lang) {
    switch (ctx.category) {
      case WashCategory.car:
        final carName = ctx.carDisplayName;
        if (carName != null && carName.isNotEmpty) {
          return '${AppTranslations.getTextWithFallback('wash_type_car', lang)} · $carName';
        }
        final type = ctx.carTypeKey;
        if (type != null && type.isNotEmpty) {
          return '${AppTranslations.getTextWithFallback('wash_type_car', lang)} · $type';
        }
        return AppTranslations.getTextWithFallback('wash_type_car', lang);
      case WashCategory.caravan:
        final sizeKey = switch (ctx.caravanSize) {
          CaravanSize.small => 'caravan_size_small',
          CaravanSize.medium => 'caravan_size_medium',
          CaravanSize.large => 'caravan_size_large',
          null => '',
        };
        final sizeLabel = sizeKey.isEmpty
            ? ''
            : AppTranslations.getTextWithFallback(sizeKey, lang);
        return '${AppTranslations.getTextWithFallback('wash_type_caravan', lang)}${sizeLabel.isEmpty ? '' : ' · $sizeLabel'}';
      case WashCategory.motorcycle:
        return AppTranslations.getTextWithFallback('wash_type_motorcycle', lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: LanguageService.getCurrentLanguage(),
      builder: (context, snapshot) {
        final lang = snapshot.data ?? 'en';
        final isAr = lang == 'ar';
        return Material(
          color: const Color(0xFFF5F5F7),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WashTypeSelectionScreen(
                    token: token,
                    allowSkip: true,
                  ),
                ),
              );
              onChanged?.call();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.local_car_wash, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _label(washContext, lang),
                      style: (isAr ? GoogleFonts.cairo : GoogleFonts.poppins)(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    AppTranslations.getTextWithFallback('change_wash_type', lang),
                    style: (isAr ? GoogleFonts.cairo : GoogleFonts.poppins)(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.blue),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
