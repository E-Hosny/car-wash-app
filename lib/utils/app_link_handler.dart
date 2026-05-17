import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../all_packages_screen.dart';
import '../multi_car_order_screen.dart';
import '../my_orders_screen.dart';
import '../screens/support_screen.dart';
import '../single_wash_order_screen.dart';

/// Handles deep links from banners, promo popups, etc.
class AppLinkHandler {
  static Future<void> navigate({
    required BuildContext context,
    required String linkType,
    required String token,
    String? externalUrl,
    bool packagesEnabled = true,
    void Function(int tabIndex)? onTabSelected,
  }) async {
    switch (linkType) {
      case 'home':
        onTabSelected?.call(0);
        break;
      case 'packages':
        if (packagesEnabled && onTabSelected != null) {
          onTabSelected(1);
        } else if (packagesEnabled) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllPackagesScreen(token: token, isGuest: false),
            ),
          );
        }
        break;
      case 'orders':
        if (onTabSelected != null) {
          onTabSelected(packagesEnabled ? 2 : 1);
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyOrdersScreen(token: token),
            ),
          );
        }
        break;
      case 'single_wash':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SingleWashOrderScreen(token: token),
          ),
        );
        break;
      case 'multi_car':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiCarOrderScreen(token: token),
          ),
        );
        break;
      case 'support':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupportScreen(token: token),
          ),
        );
        break;
      case 'external':
        final url = externalUrl?.trim();
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      default:
        break;
    }
  }
}
