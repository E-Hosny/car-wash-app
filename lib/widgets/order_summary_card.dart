import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../translations.dart';

class OrderSummaryCard extends StatelessWidget {
  final double totalPrice;
  final bool usePackage;
  final int selectedServicesCount;
  final int? remainingPoints;
  final int? totalPointsUsed;
  final String? currency;
  final String? language;

  const OrderSummaryCard({
    super.key,
    required this.totalPrice,
    required this.usePackage,
    required this.selectedServicesCount,
    this.remainingPoints,
    this.totalPointsUsed,
    this.currency,
    this.language,
  });

  String _t(String key) {
    return AppTranslations.getTextWithFallback(key, language ?? 'en');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  usePackage ? Icons.card_giftcard : Icons.receipt,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _t('order_summary'),
                  style: AppTheme.heading4.copyWith(fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Services Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('selected_services'),
                  style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                ),
                Text(
                  '$selectedServicesCount ${selectedServicesCount == 1 ? _t('service') : _t('services')}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Services Information (if using package)
            if (usePackage && remainingPoints != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('services_to_use'),
                    style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                  ),
                  Text(
                    '${totalPointsUsed ?? 0} ${((totalPointsUsed ?? 0) == 1) ? _t('service') : _t('services')}',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('remaining_services'),
                    style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                  ),
                  Text(
                    '${remainingPoints! - (totalPointsUsed ?? 0)} ${(remainingPoints! - (totalPointsUsed ?? 0)) == 1 ? _t('service') : _t('services')}',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Progress Bar for Services
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('services_usage'),
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: remainingPoints! > 0
                        ? (totalPointsUsed ?? 0) / remainingPoints!
                        : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    minHeight: 5,
                  ),
                ],
              ),
            ],

            // Total Price (if not using package)
            if (!usePackage) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('total_amount'),
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${totalPrice.toStringAsFixed(2)} ${currency ?? 'AED'}',
                      style: AppTheme.heading3.copyWith(
                        fontSize: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Free Message (if using package)
            if (usePackage) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('free_with_package'),
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
