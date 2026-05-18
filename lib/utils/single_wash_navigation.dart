import 'package:flutter/material.dart';

import '../screens/wash_type_selection_screen.dart';
import '../services/wash_context_service.dart';
import '../single_wash_order_screen.dart';
import 'post_login_navigation.dart';

class SingleWashNavigation {
  /// من الرئيسية: دائماً غسيل سيارة (أحدث سيارة) إن وُجدت، وإلا نوع الغسلة.
  static Future<void> open(BuildContext context, String token) async {
    final hasCars = await PostLoginNavigation.userHasCars(token);
    if (!context.mounted) return;

    if (!hasCars) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WashTypeSelectionScreen(
            token: token,
            allowSkip: false,
          ),
        ),
      );
      return;
    }

    await WashContextService.syncDefaultCarContext(token);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SingleWashOrderScreen(
          token: token,
          washCategory: WashCategory.car,
        ),
      ),
    );
  }

  static Future<void> openWashTypeSelection(
    BuildContext context,
    String token,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WashTypeSelectionScreen(
          token: token,
          allowSkip: true,
        ),
      ),
    );
  }
}
