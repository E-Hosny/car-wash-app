import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'splash_screen.dart'; // أو login_screen.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: "assets/.env");
    print("✅ .env file loaded successfully");

    // إعداد Stripe مع Apple Pay
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    Stripe.merchantIdentifier = 'merchant.com.washluxuria';
    await Stripe.instance.applySettings();

    print("✅ Stripe initialized with Apple Pay support");
    print("   Merchant ID: merchant.com.washluxuria");
  } catch (e) {
    print("Warning: Could not load .env file or initialize Stripe: $e");
    // Continue without .env file
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // أو LoginScreen() حسب حالة البداية
    );
  }
}
