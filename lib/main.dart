import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:upgrader/upgrader.dart';
import 'splash_screen.dart'; // أو login_screen.dart

/// Custom messages for Force Update in English
class CustomUpgraderMessages extends UpgraderMessages {
  CustomUpgraderMessages({super.code = 'en'});

  @override
  String get title => 'Update Available';

  @override
  String get body =>
      'A new version of the app is available. Please update to continue.';

  @override
  String get buttonTitleUpdate => 'Update Now';

  @override
  String get buttonTitleIgnore => ''; // Empty to hide ignore button

  @override
  String get buttonTitleLater => ''; // Empty to hide later button
}

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UpgradeAlert(
        // Force Update Configuration
        barrierDismissible:
            false, // Prevent dismissing the dialog - FORCE UPDATE
        showIgnore: false, // Hide "Ignore" button
        showLater: false, // Hide "Later" button
        upgrader: Upgrader(
          // Custom Messages in English
          messages: CustomUpgraderMessages(),
          // Additional Configuration
          durationUntilAlertAgain:
              const Duration(days: 0), // Check immediately every time
          // minAppVersion can be set to force update for specific versions
          // minAppVersion: '1.2.0', // Uncomment and set when you need to force update
        ),
        child: const SplashScreen(),
      ),
    );
  }
}
