import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class OrderSummaryCard extends StatelessWidget {
  final double totalPrice;
  final bool usePackage;
  final int selectedServicesCount;
  final int? remainingPoints;
  final int? totalPointsUsed;

  const OrderSummaryCard({
    super.key,
    required this.totalPrice,
    required this.usePackage,
    required this.selectedServicesCount,
    this.remainingPoints,
    this.totalPointsUsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  usePackage ? Icons.card_giftcard : Icons.receipt,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Order Summary',
                  style: AppTheme.heading4,
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Services Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Services',
                  style: AppTheme.bodyMedium,
                ),
                Text(
                  '$selectedServicesCount services',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Payment Method
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: usePackage
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: usePackage
                      ? Colors.green.withOpacity(0.3)
                      : AppTheme.borderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    usePackage ? Icons.card_giftcard : Icons.payment,
                    color:
                        usePackage ? Colors.green : AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usePackage ? 'Package Payment' : 'Regular Payment',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: usePackage
                                ? Colors.green
                                : AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          usePackage
                              ? 'Using package points for services'
                              : 'Pay with credit card or cash',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Points Information (if using package)
            if (usePackage && remainingPoints != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Points to Use',
                    style: AppTheme.bodyMedium,
                  ),
                  Text(
                    '${totalPointsUsed ?? 0} points',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingS),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining Points',
                    style: AppTheme.bodyMedium,
                  ),
                  Text(
                    '${remainingPoints! - (totalPointsUsed ?? 0)} points',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Progress Bar for Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Points Usage',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  LinearProgressIndicator(
                    value: remainingPoints! > 0
                        ? (totalPointsUsed ?? 0) / remainingPoints!
                        : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    minHeight: 6,
                  ),
                ],
              ),
            ],

            // Total Price (if not using package)
            if (!usePackage) ...[
              const SizedBox(height: AppTheme.spacingL),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${totalPrice.toStringAsFixed(2)} AED',
                      style: AppTheme.heading3.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Free Message (if using package)
            if (usePackage) ...[
              const SizedBox(height: AppTheme.spacingL),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Free with Package Points!',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
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
