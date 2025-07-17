import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_theme.dart';
import '../services/package_service.dart';

class PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showBuyButton;

  const PackageCard({
    super.key,
    required this.package,
    this.onTap,
    this.isSelected = false,
    this.showBuyButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: isSelected ? AppTheme.shadowLarge : AppTheme.shadowMedium,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusL),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.grey.shade50,
                child: _buildPackageImage(),
              ),
            ),

            // Package Details
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Package Name
                  Text(
                    package['name'] ?? 'Premium Package',
                    style: AppTheme.heading4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: AppTheme.spacingS),

                  // Package Description
                  if (package['description'] != null)
                    Text(
                      package['description'],
                      style: AppTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: AppTheme.spacingM),

                  // Price and Points Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price',
                              style: AppTheme.caption,
                            ),
                            Text(
                              '${package['price'] ?? 0} SAR',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: AppTheme.spacingM),

                      // Points Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Points',
                              style: AppTheme.caption,
                            ),
                            Text(
                              PackageService.formatPoints(package['points']),
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Buy Button
                  if (showBuyButton) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: AppTheme.primaryButton.copyWith(
                          padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingS),
                          ),
                        ),
                        child: Text(
                          'Buy',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageImage() {
    final imagePath = package['image'];

    if (imagePath != null && imagePath.toString().isNotEmpty) {
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      final imageUrl = '$baseUrl/storage/$imagePath';

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: AppTheme.primaryColor,
            ),
          );
        },
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
      ),
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 40,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class PackagePurchaseDialog extends StatelessWidget {
  final Map<String, dynamic> package;
  final VoidCallback onPurchase;

  const PackagePurchaseDialog({
    super.key,
    required this.package,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      title: Text(
        'Purchase Package',
        style: AppTheme.heading3,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Package Image
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: _buildPackageImage(),
            ),
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Package Name
          Text(
            package['name'] ?? 'Premium Package',
            style: AppTheme.heading4,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppTheme.spacingS),

          // Package Description
          if (package['description'] != null)
            Text(
              package['description'],
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: AppTheme.spacingM),

          // Price and Points
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    'Price',
                    style: AppTheme.caption,
                  ),
                  Text(
                    '${package['price'] ?? 0} SAR',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Points',
                    style: AppTheme.caption,
                  ),
                  Text(
                    PackageService.formatPoints(package['points']),
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onPurchase();
          },
          style: AppTheme.primaryButton,
          child: Text(
            'Buy Now',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageImage() {
    final imagePath = package['image'];

    if (imagePath != null && imagePath.toString().isNotEmpty) {
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      final imageUrl = '$baseUrl/storage/$imagePath';

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        color: Colors.grey.shade200,
      ),
      child: Icon(
        Icons.card_giftcard,
        size: 50,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
