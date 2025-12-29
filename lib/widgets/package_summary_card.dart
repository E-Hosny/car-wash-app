import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PackageSummaryCard extends StatelessWidget {
  final Map<String, dynamic> userPackage;
  final bool usePackage;
  final VoidCallback onTogglePackage;
  final VoidCallback? onViewDetails;

  const PackageSummaryCard({
    super.key,
    required this.userPackage,
    required this.usePackage,
    required this.onTogglePackage,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final package = userPackage['package'];
    final services = userPackage['services'] as List? ?? [];
    
    // Calculate total and remaining quantities
    int totalQuantity = 0;
    int remainingQuantity = 0;
    
    for (var service in services) {
      final total = service['total_quantity'] ?? 0;
      final remaining = service['remaining_quantity'] ?? 0;
      totalQuantity += total is int ? total : (total is String ? int.tryParse(total) ?? 0 : 0);
      remainingQuantity += remaining is int ? remaining : (remaining is String ? int.tryParse(remaining) ?? 0 : 0);
    }
    
    final usedQuantity = totalQuantity - remainingQuantity;
    final progressPercentage = totalQuantity > 0 ? usedQuantity / totalQuantity : 0.0;

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
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Current Package',
                        style: AppTheme.heading4,
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        package['name'] ?? 'Package',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewDetails != null)
                  IconButton(
                    onPressed: onViewDetails,
                    icon: Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Services Information
            Row(
              children: [
                Expanded(
                  child: _buildPointsCard(
                    'Remaining',
                    remainingQuantity,
                    AppTheme.primaryColor,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildPointsCard(
                    'Total',
                    totalQuantity,
                    AppTheme.textSecondaryColor,
                    Icons.inventory,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Usage Progress',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progressPercentage * 100).toInt()}%',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  minHeight: 6,
                ),
              ],
            ),

            if (userPackage['expires_at'] != null) ...[
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
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Package Expiration Date',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatExpirationDate(userPackage['expires_at']),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_getDaysRemaining(userPackage['expires_at']) != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDaysRemaining(userPackage['expires_at'])! <= 7
                              ? Colors.orange
                              : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDaysRemainingText(userPackage['expires_at']),
                          style: AppTheme.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppTheme.spacingL),

            // Package Toggle
            Container(
              decoration: BoxDecoration(
                color: usePackage
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: usePackage
                      ? AppTheme.primaryColor.withOpacity(0.3)
                      : AppTheme.borderColor,
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  'Use Package for this Order',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: usePackage
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),
                  subtitle: Text(
                  usePackage
                      ? 'Services will be used from package'
                      : 'Services will be charged normally',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                value: usePackage,
                onChanged: (value) => onTogglePackage(),
                activeColor: AppTheme.primaryColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard(
      String title, int points, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            points.toString(),
            style: AppTheme.heading2.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            title,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpirationDate(dynamic expiresAt) {
    try {
      final date = DateTime.parse(expiresAt.toString());
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return expiresAt.toString();
    }
  }

  int? _getDaysRemaining(dynamic expiresAt) {
    try {
      final date = DateTime.parse(expiresAt.toString());
      final now = DateTime.now();
      final difference = date.difference(now);
      return difference.inDays;
    } catch (e) {
      return null;
    }
  }

  String _getDaysRemainingText(dynamic expiresAt) {
    final days = _getDaysRemaining(expiresAt);
    if (days == null) return '';
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires Today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }
}

class PackageEmptyCard extends StatelessWidget {
  final VoidCallback onBrowsePackages;

  const PackageEmptyCard({
    super.key,
    required this.onBrowsePackages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No Active Package',
              style: AppTheme.heading3.copyWith(
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'You don\'t have any active packages. Browse our available packages to get started.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBrowsePackages,
                style: AppTheme.primaryButton,
                child: Text(
                  'Browse Packages',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
