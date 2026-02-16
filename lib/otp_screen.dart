import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logrocket_flutter/logrocket_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'main_navigation_screen.dart';
import 'services/language_service.dart';
import 'translations.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> otpControllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(4, (index) => FocusNode());

  String? errorMessage;
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

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    // Check if all OTP digits are entered
    if (index == 3 && value.length == 1) {
      _verifyOtp();
    }
  }

  String normalizePhone(String input) {
    String phone = input.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    if (phone.startsWith('00')) phone = phone.substring(2);

    // Handle Saudi Arabia (+966) - for testing from Saudi Arabia
    if (phone.startsWith('966')) return phone;
    if (phone.startsWith('5') && phone.length == 9) return '966$phone';
    if (phone.startsWith('05') && phone.length == 10)
      return '966${phone.substring(1)}';

    // Handle UAE (+971) - default for UAE users
    if (phone.startsWith('971')) return phone;
    if (phone.startsWith('5') && phone.length == 9)
      return '971$phone'; // UAE mobile
    if (phone.startsWith('05') && phone.length == 10)
      return '971${phone.substring(1)}'; // UAE mobile with 0
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
    if (phone.startsWith('5') && phone.length == 9)
      return true; // Could be Saudi or UAE
    if (phone.startsWith('05') && phone.length == 10)
      return true; // Could be Saudi or UAE

    return false;
  }

  Future<void> _verifyOtp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final String enteredOtp =
        otpControllers.map((controller) => controller.text).join();

    if (enteredOtp.length != 4) {
      setState(() {
        errorMessage = _t('please_enter_code');
        isLoading = false;
      });
      return;
    }

    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/api/login-with-otp');
      final normalizedPhone = normalizePhone(widget.phoneNumber);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': normalizedPhone,
          'otp': enteredOtp,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _completeLoginWithData(data);
      } else {
        String msg = _t('incorrect_code');
        try {
          final body = jsonDecode(response.body);
          final errors = body['errors'];
          if (errors != null && errors['otp'] != null && (errors['otp'] as List).isNotEmpty) {
            msg = (errors['otp'] as List).first.toString();
          }
        } catch (_) {}
        setState(() {
          errorMessage = msg;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = _t('error_verifying');
        isLoading = false;
      });
    }
  }

  Future<void> _completeLoginWithData(Map<String, dynamic> data) async {
    try {
      final normalizedPhone = normalizePhone(widget.phoneNumber);
      final token = data['token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.remove('otp_code');

      final userId = data['user_id'] ?? data['user']?['id'] ?? normalizedPhone;
      final userName = data['user']?['name'] ?? data['name'] ?? normalizedPhone;
      final userEmail = data['user']?['email'] ?? data['email'] ?? '';

      try {
        LogRocket.identify(
          userId.toString(),
          {
            'name': userName,
            'email': userEmail,
          },
        );
        print("✅ LogRocket user identified: $userId");
      } catch (e) {
        print("⚠️ Warning: LogRocket identify failed: $e");
      }

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
      }

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('login_successful'))),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigationScreen(token: token),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = _t('connection_error');
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/api/request-otp');
      final normalizedPhone = normalizePhone(widget.phoneNumber);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'phone': normalizedPhone}),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('code_resent'))),
        );
      } else {
        setState(() => errorMessage = _t('failed_to_resend'));
      }
    } catch (e) {
      setState(() {
        errorMessage = _t('failed_to_resend');
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            _t('verification_code'),
            style: _getArabicTextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 80,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _t('enter_verification_code'),
                    style: _getArabicTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_t('verification_code_sent')} ${widget.phoneNumber}',
                    style: _getArabicTextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // OTP Input Fields - Always LTR (Left to Right)
                  Directionality(
                    textDirection: TextDirection.ltr, // Force LTR for OTP fields
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) {
                        return SizedBox(
                          width: 60,
                          child: TextField(
                            controller: otpControllers[index],
                            focusNode: focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr, // Force LTR
                            maxLength: 1,
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.black, width: 2),
                              ),
                            ),
                            onChanged: (value) => _onOtpChanged(value, index),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyOtp,
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
                              _t('verify'),
                              style: _getArabicTextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: isLoading ? null : _resendOtp,
                    child: Text(
                      _t('resend_code'),
                      style: _getArabicTextStyle(color: Colors.black54),
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
