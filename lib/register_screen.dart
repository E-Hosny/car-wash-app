import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart'; // تأكد إنه موجود بنفس المسار أو صحح المسار

class RegisterScreen extends StatefulWidget {
  final String? initialPhone;
  const RegisterScreen({Key? key, this.initialPhone}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      phoneController.text = widget.initialPhone!;
    }
  }

  String normalizePhone(String input) {
    String phone = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('00')) phone = phone.substring(2);
    if (phone.startsWith('966')) return phone;
    if (phone.startsWith('5')) return '966$phone';
    if (phone.startsWith('05')) return '966${phone.substring(1)}';
    if (phone.startsWith('971')) return phone;
    if (phone.startsWith('0')) return '971${phone.substring(1)}';
    return phone;
  }

  Future<void> register() async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/api/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameController.text,
          'phone': normalizePhone(phoneController.text.trim()),
          'email': emailController.text,
          'password': passwordController.text,
          'password_confirmation': passwordController.text,
          'role': 'customer',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Success: $data');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        final error = jsonDecode(response.body);
        print('❌ Error: $error');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${error['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('❗ Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e')),
      );
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
                  'Create a New Account',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _buildTextField('Full Name', controller: nameController),
                const SizedBox(height: 15),
                _buildTextField('Phone Number', controller: phoneController),
                const SizedBox(height: 15),
                _buildTextField('Email Address', controller: emailController),
                const SizedBox(height: 15),
                _buildTextField('Password',
                    controller: passwordController, obscure: true),
                const SizedBox(height: 30),

                // زر التسجيل
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Register'),
                  ),
                ),

                const SizedBox(height: 20),

                // النص التحويلي لتسجيل الدخول
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account?",
                      style: TextStyle(color: Colors.black),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(color: Colors.blue),
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

  Widget _buildTextField(String hint,
      {bool obscure = false, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
