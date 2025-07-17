import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/package_service.dart';

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
    final remainingPoints =
        PackageService.validatePoints(userPackage['remaining_points']);
    final totalPoints =
        PackageService.validatePoints(userPackage['total_points']);
    final usedPoints = totalPoints - remainingPoints;
    final progressPercentage = totalPoints > 0 ? usedPoints / totalPoints : 0.0;

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

            // Points Information
            Row(
              children: [
                Expanded(
                  child: _buildPointsCard(
                    'Remaining',
                    remainingPoints,
                    AppTheme.primaryColor,
                    Icons.star,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildPointsCard(
                    'Total',
                    totalPoints,
                    AppTheme.textSecondaryColor,
                    Icons.star_border,
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
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppTheme.textSecondaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'Expires: ${userPackage['expires_at']}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
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
                      ? 'Services will be charged using package points'
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
