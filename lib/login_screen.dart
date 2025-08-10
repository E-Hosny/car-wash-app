import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import 'main_navigation_screen.dart'; // Added import for MainNavigationScreen

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
        phoneError = 'Phone number is required';
        isLoading = false;
      });
      return;
    }

    if (!isValidUAEPhone(rawPhone)) {
      setState(() {
        phoneError = 'Please enter a valid UAE phone number (e.g., 5XXXXXXXX)';
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

          // Only send OTP if user exists
          final String otpCode =
              (phoneNumber == '971508949923' || phoneNumber == '971999999999')
                  ? '0000'
                  : (1000 + (DateTime.now().millisecondsSinceEpoch % 9000))
                      .toString();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('otp_code', otpCode);

          final webhookUrl = Uri.parse(
              'https://www.uchat.com.au/api/iwh/7c12fdd537dcf07c2df40f2e230ed94b');
          await http.post(
            webhookUrl,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "phone_number": phoneNumber,
              "code": otpCode,
            }),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(phoneNumber: phoneNumber),
            ),
          );
        } else {
          setState(() {
            generalError = 'Phone number is not registered';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          generalError = 'Connection error. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        generalError = 'Connection error. Please try again.';
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

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful')),
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
          generalError = 'Login failed. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        generalError = 'Connection error. Please try again.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('assets/logo.png', width: 250, height: 250),
                const SizedBox(height: 30),
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your UAE phone number (e.g., 5XXXXXXXX)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'UAE Phone Number (+971)',
                    hintText: '5XXXXXXXX',
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
                      if (generalError == 'Phone number is not registered')
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
                            child: const Text('Register',
                                style: TextStyle(color: Colors.blue)),
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
                        : const Text('Send Verification Code'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.black54),
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
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}
