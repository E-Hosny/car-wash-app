import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:upgrader/upgrader.dart';
import 'package:logrocket_flutter/logrocket_flutter.dart';
import 'services/force_update_messages.dart';
import 'splash_screen.dart'; // أو login_screen.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: "assets/.env");
    print("✅ .env file loaded successfully");

    // إعداد Stripe مع Apple Pay
    final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    if (stripeKey.isNotEmpty) {
      Stripe.publishableKey = stripeKey;
      Stripe.merchantIdentifier = 'merchant.com.washluxuria';
      try {
        await Stripe.instance
            .applySettings()
            .timeout(const Duration(seconds: 5));
        print("✅ Stripe initialized with Apple Pay support");
        print("   Merchant ID: merchant.com.washluxuria");
      } catch (e) {
        print("⚠️ Warning: Stripe initialization failed: $e");
        // Continue without Stripe
      }
    } else {
      print("⚠️ Warning: STRIPE_PUBLISHABLE_KEY not found in .env");
    }
  } catch (e) {
    print("⚠️ Warning: Could not load .env file: $e");
    // Continue without .env file
  }

  // تهيئة LogRocket مع تفعيل Session Replay
  LogRocket.wrapAndInitialize(
    LogRocketWrapConfiguration(),
    LogRocketInitConfiguration(appID: 'ejxk6d/luxuria-car-wash'),
    () => runApp(const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LogRocketWidget(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: UpgradeAlert(
          upgrader: Upgrader(
            // Country code for App Store/Play Store
            countryCode: 'us',
            // Check immediately
            durationUntilAlertAgain: const Duration(days: 0),
            // Custom messages for force update
            messages: ForceUpdateMessages(),
          ),
          child: const SplashScreen(),
        ),
      ),
    );
  }
}
