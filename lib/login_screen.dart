import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logrocket_flutter/logrocket_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import 'main_navigation_screen.dart'; // Added import for MainNavigationScreen
import 'services/config_service.dart';
import 'services/language_service.dart';
import 'translations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  String? phoneError;
  String? generalError;
  bool isLoading = false;
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

  String normalizePhone(String input) {
    String phone = input.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    if (phone.startsWith('00')) phone = phone.substring(2);

    // Handle Saudi Arabia (+966) - for testing from Saudi Arabia
    if (phone.startsWith('966')) return phone;
    if (phone.startsWith('5') && phone.length == 9) {
      // Check if it's likely Saudi (for testing) or UAE
      // For testing purposes, if user is from Saudi, they should enter 966XXXXXXXXX
      // For UAE users, 5XXXXXXXX will be treated as UAE
      return '971$phone'; // Default to UAE for 5XXXXXXXX format
    }
    if (phone.startsWith('05') && phone.length == 10) {
      // For Saudi testing: 966XXXXXXXXX
      // For UAE: 971XXXXXXXXX
      return '971${phone.substring(1)}'; // Default to UAE
    }

    // Handle UAE (+971) - default for UAE users
    if (phone.startsWith('971')) return phone;
    if (phone.startsWith('0') && phone.length == 9)
      return '971${phone.substring(1)}'; // UAE landline

    // Default to UAE if no country code detected
    return '971$phone';
  }

  bool isValidUAEPhone(String input) {
    String phone = input.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    if (phone.startsWith('00')) phone = phone.substring(2);

    // Check if it's a valid UAE phone number
    if (phone.startsWith('971') && phone.length == 12) return true;
    if (phone.startsWith('5') && phone.length == 9) return true;
    if (phone.startsWith('05') && phone.length == 10) return true;
    if (phone.startsWith('0') && phone.length == 9) return true;

    // Check if it's a valid Saudi phone number (for testing)
    if (phone.startsWith('966') && phone.length == 12) return true;

    return false;
  }

  Future<void> sendOtp() async {
    setState(() {
      phoneError = null;
      generalError = null;
      isLoading = true;
    });

    final String rawPhone = phoneController.text.trim();
    final String phoneNumber = normalizePhone(rawPhone);
    // print('Normalized phone sent to API: $phoneNumber');

    if (rawPhone.isEmpty) {
      setState(() {
        phoneError = _t('phone_required');
        isLoading = false;
      });
      return;
    }

    if (!isValidUAEPhone(rawPhone)) {
      setState(() {
        phoneError = _t('invalid_phone');
        isLoading = false;
      });
      return;
    }

    try {
      // Check if user exists in the system
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/api/check-phone');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phoneNumber,
        }),
      );
      // print('API check-phone response: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exists'] == true) {
          // Special case: bypass OTP for 971000000000
          if (phoneNumber == '971000000000') {
            // Direct login without OTP for this specific number
            await _directLogin(phoneNumber);
            return;
          }

          // إرسال OTP من الـ API (الرقم الجديد فقط — لا webhook قديم)
          final requestOtpUrl = Uri.parse('$baseUrl/api/request-otp');
          final otpResponse = await http.post(
            requestOtpUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': phoneNumber}),
          );

          if (!mounted) return;
          if (otpResponse.statusCode != 200) {
            final err = jsonDecode(otpResponse.body);
            setState(() {
              generalError = err['message'] ?? _t('connection_error');
              isLoading = false;
            });
            return;
          }

          setState(() => isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(phoneNumber: phoneNumber),
            ),
          );
        } else {
          setState(() {
            generalError = _t('phone_not_registered');
            isLoading = false;
          });
        }
      } else {
        setState(() {
          generalError = _t('connection_error');
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        generalError = _t('connection_error');
        isLoading = false;
      });
    }
  }

  // New method for direct login without OTP
  Future<void> _directLogin(String phoneNumber) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/api/login-with-otp');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Save token for persistent login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await ConfigService.resetPromoPopupForNewLogin();

        // تحديد المستخدم في LogRocket
        // استخدام user_id الحقيقي من API response أو phoneNumber مؤقتاً
        final userId = data['user_id'] ?? data['user']?['id'] ?? phoneNumber;
        final userName = data['user']?['name'] ?? data['name'] ?? phoneNumber;
        final userEmail = data['user']?['email'] ?? data['email'] ?? '';

        try {
          LogRocket.identify(
            userId,
            {
              'name': userName,
              'email': userEmail,
            },
          );
          print("✅ LogRocket user identified: $userId");
        } catch (e) {
          print("⚠️ Warning: LogRocket identify failed: $e");
          // Continue without LogRocket identification
        }

        // ربط المستخدم بـ OneSignal
        try {
          // التحقق من حالة الاشتراك قبل ربط المستخدم (خاصة iOS)
          final subscription = OneSignal.User.pushSubscription;
          final isOptedIn = subscription.optedIn ?? false;
          final subscriptionId = subscription.id;
          
          if (isOptedIn && subscriptionId != null && subscriptionId.isNotEmpty) {
            await OneSignal.login(userId.toString());
            print("✅ OneSignal user linked: $userId");
            print("   Subscription ID: $subscriptionId");
          } else {
            print("⚠️ OneSignal subscription not ready yet");
            print("   Opted In: $isOptedIn");
            print("   Subscription ID: $subscriptionId");
            
            // محاولة طلب الصلاحيات مرة أخرى إذا لم تكن ممنوحة
            if (!isOptedIn) {
              final permission = await OneSignal.Notifications.requestPermission(true);
              print("   Permission requested: $permission");
              
              // إعادة المحاولة بعد منح الصلاحيات
              if (permission) {
                // انتظار قليل حتى يتم إنشاء الاشتراك
                await Future.delayed(const Duration(seconds: 1));
                final newSubscription = OneSignal.User.pushSubscription;
                if (newSubscription.optedIn == true && newSubscription.id != null) {
                  await OneSignal.login(userId.toString());
                  print("✅ OneSignal user linked after permission grant: $userId");
                }
              }
            }
          }
        } catch (e) {
          print("⚠️ Warning: OneSignal login failed: $e");
          // Continue without OneSignal user linking
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('login_successful'))),
        );

        // Navigate directly to main screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(token: token),
          ),
        );
      } else {
        setState(() {
          generalError = _t('login_failed');
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        generalError = _t('connection_error');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset('assets/logo.png', width: 250, height: 250),
                  const SizedBox(height: 30),
                  Text(
                    _t('login'),
                    style: _getArabicTextStyle(
                      fontSize: 24,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t('enter_phone'),
                    style: _getArabicTextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: _isRTL ? TextDirection.ltr : TextDirection.ltr, // Keep phone numbers LTR
                    decoration: InputDecoration(
                      labelText: _t('uae_phone_number'),
                      hintText: _t('phone_placeholder'),
                      errorText: phoneError,
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (generalError != null)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          generalError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (generalError == _t('phone_not_registered'))
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(
                                      initialPhone:
                                          phoneController.text.trim()),
                                ),
                              );
                            },
                            child: Text(
                              _t('register'),
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
                    ],
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _t('send_verification_code'),
                            style: _getArabicTextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _t('dont_have_account'),
                      style: _getArabicTextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              initialPhone: phoneController.text.trim(),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        _t('register'),
                        style: _getArabicTextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Browse as Guest button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainNavigationScreen(
                            isGuest: true,
                            initialIndex: 0, // Start with services tab
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black54, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _t('browse_as_guest'),
                      style: _getArabicTextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
