import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/language_service.dart';
import '../translations.dart';

class LanguageSelectionDialog extends StatefulWidget {
  const LanguageSelectionDialog({super.key});

  @override
  State<LanguageSelectionDialog> createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final lang = await LanguageService.getCurrentLanguage();
    if (mounted) {
      setState(() {
        _selectedLanguage = lang;
      });
    }
  }

  Future<void> _selectLanguage(String language) async {
    await LanguageService.setCurrentLanguage(language);
    if (mounted) {
      setState(() {
        _selectedLanguage = language;
      });
      Navigator.of(context).pop();
    }
  }

  String _t(String key) {
    return AppTranslations.getTextWithFallback(key, _selectedLanguage);
  }

  TextStyle _getArabicTextStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    if (_selectedLanguage == 'ar') {
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
    final isRTL = _selectedLanguage == 'ar';
    
    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          _t('select_language'),
          style: _getArabicTextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          _t('select_language_message'),
          style: _getArabicTextStyle(fontSize: 16),
        ),
        actions: [
          // Arabic Button
          ElevatedButton(
            onPressed: () => _selectLanguage('ar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLanguage == 'ar' 
                  ? Colors.blue 
                  : Colors.grey[300],
              foregroundColor: _selectedLanguage == 'ar' 
                  ? Colors.white 
                  : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _t('arabic'),
              style: _getArabicTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _selectedLanguage == 'ar' ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // English Button
          ElevatedButton(
            onPressed: () => _selectLanguage('en'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLanguage == 'en' 
                  ? Colors.blue 
                  : Colors.grey[300],
              foregroundColor: _selectedLanguage == 'en' 
                  ? Colors.white 
                  : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _t('english'),
              style: _getArabicTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _selectedLanguage == 'en' ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
