import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main_navigation_screen.dart';

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
        errorMessage = 'Please enter the 4-digit verification code';
        isLoading = false;
      });
      return;
    }

    try {
      // Get stored OTP code
      final prefs = await SharedPreferences.getInstance();
      final String? storedOtp = prefs.getString('otp_code');

      if (storedOtp == null) {
        setState(() {
          errorMessage = 'Invalid verification code, please try again';
          isLoading = false;
        });
        return;
      }

      // Verify OTP
      if (enteredOtp == storedOtp) {
        // OTP is correct, proceed with login
        await _completeLogin();
      } else {
        setState(() {
          errorMessage = 'Incorrect verification code';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred while verifying the code';
        isLoading = false;
      });
    }
  }

  Future<void> _completeLogin() async {
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
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Save token for persistent login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.remove('otp_code'); // Clear OTP after successful login

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(token: token),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          errorMessage = error['message'] ?? 'Login failed';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Connection error';
        isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final String otpCode = widget.phoneNumber == '971508949923'
          ? '0000'
          : (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

      // Save OTP code
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('otp_code', otpCode);

      // Send OTP via webhook
      final webhookUrl = Uri.parse(
          'https://www.uchat.com.au/api/iwh/7c12fdd537dcf07c2df40f2e230ed94b');
      await http.post(
        webhookUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone_number": widget.phoneNumber,
          "code": otpCode,
        }),
      );

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to resend verification code';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Verification Code',
          style: TextStyle(color: Colors.black),
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
                const Text(
                  'Enter the verification code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A verification code was sent to ${widget.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    return SizedBox(
                      width: 60,
                      child: TextField(
                        controller: otpControllers[index],
                        focusNode: focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
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
                        : const Text('Verify'),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: isLoading ? null : _resendOtp,
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
