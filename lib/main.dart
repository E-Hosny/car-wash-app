import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:upgrader/upgrader.dart';
import 'package:logrocket_flutter/logrocket_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/force_update_messages.dart';
import 'splash_screen.dart'; // أو login_screen.dart
import 'screens/order_details_screen.dart';
import 'screens/rate_app_screen.dart';

// Global navigator key for navigation from OneSignal handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // تهيئة OneSignal Push Notifications
  try {
    OneSignal.initialize("d0faba84-d731-4666-a1a8-e0672654e3a9");
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.Notifications.requestPermission(true);
    print("✅ OneSignal initialized successfully");

    // Foreground notification handler
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print("📱 OneSignal Foreground Notification:");
      print("   Title: ${event.notification.title}");
      print("   Body: ${event.notification.body}");
      print("   Data: ${event.notification.additionalData}");
    });

    // Click handler for notifications
    OneSignal.Notifications.addClickListener((event) {
      print("👆 OneSignal Notification Clicked:");
      print("   Full Payload: ${event.notification.additionalData}");
      
      final data = event.notification.additionalData;
      if (data != null) {
        final type = data['type']?.toString();
        final screen = data['screen']?.toString();
        
        // Handle rating notification - navigate to RateAppScreen
        if (type == 'ORDER_COMPLETED_RATING' && screen == 'rate_app') {
          print("   Rating notification detected, navigating to RateAppScreen");
          
          // Get token from SharedPreferences
          SharedPreferences.getInstance().then((prefs) {
            final token = prefs.getString('auth_token');
            
            if (token != null && token.isNotEmpty) {
              // Navigate to RateAppScreen
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => RateAppScreen(token: token),
                ),
              );
            } else {
              print("⚠️ No auth token found, cannot navigate to rating screen");
            }
          });
          
          return; // Exit early, don't navigate to order details
        }
        
        // Handle other notifications with order_id - navigate to OrderDetailsScreen
        if (data['order_id'] != null) {
          final orderId = data['order_id'].toString();
          print("   Navigating to OrderDetails with order_id: $orderId");
          
          // Navigate to OrderDetailsScreen using navigatorKey
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(orderId: orderId),
            ),
          );
        }
      }
    });
  } catch (e) {
    print("⚠️ Warning: OneSignal initialization failed: $e");
    // Continue without OneSignal
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
        navigatorKey: navigatorKey,
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
