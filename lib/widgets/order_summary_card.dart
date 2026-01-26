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
                  'Order Summary',
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
                  'Selected Services',
                  style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                ),
                Text(
                  '$selectedServicesCount services',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Payment Method
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: usePackage
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
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
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usePackage ? 'Package Payment' : 'Regular Payment',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: usePackage
                                ? Colors.green
                                : AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usePackage
                              ? 'Using package services'
                              : 'Pay with credit card or cash',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Services Information (if using package)
            if (usePackage && remainingPoints != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Services to Use',
                    style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                  ),
                  Text(
                    '${totalPointsUsed ?? 0} services',
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
                    'Remaining Services',
                    style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                  ),
                  Text(
                    '${remainingPoints! - (totalPointsUsed ?? 0)} services',
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
                    'Services Usage',
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
                      'Total Amount',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${totalPrice.toStringAsFixed(2)} AED',
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
                        'Free with Package!',
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
