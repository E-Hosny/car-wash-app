import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_theme.dart';
import '../services/package_service.dart';

class PackageDisplayCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final Map<String, dynamic>? userPackage;
  final VoidCallback? onPurchase;
  final VoidCallback? onViewDetails;

  const PackageDisplayCard({
    super.key,
    required this.package,
    this.userPackage,
    this.onPurchase,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentPackage =
        userPackage != null && userPackage!['package']['id'] == package['id'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(
          color:
              isCurrentPackage ? AppTheme.primaryColor : Colors.grey.shade200,
          width: isCurrentPackage ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentPackage
                ? AppTheme.primaryColor.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Package Image with Current Package Badge
          Stack(
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: Colors.grey.shade50,
                ),
                child: _buildPackageImage(),
              ),
              if (isCurrentPackage)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Current Package',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Package Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package['name'] ?? 'Premium Package',
                          style: AppTheme.heading4.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentPackage)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  if (package['description'] != null)
                    Text(
                      package['description'],
                      style: AppTheme.bodySmall.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 8),

                  // Price and Points
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: AppTheme.caption.copyWith(fontSize: 9),
                          ),
                          Text(
                            '${package['price']} AED',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Points',
                            style: AppTheme.caption.copyWith(fontSize: 9),
                          ),
                          Text(
                            PackageService.formatPoints(package['points']),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Current Package Info
                  if (isCurrentPackage) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: AppTheme.primaryColor,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${userPackage!['remaining_points']} points remaining',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(isCurrentPackage),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageImage() {
    final imagePath = package['image'];

    if (imagePath != null && imagePath.toString().isNotEmpty) {
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      final imageUrl = '$baseUrl/storage/$imagePath';

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage();
          },
        ),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        color: Colors.grey.shade200,
      ),
      child: Icon(
        Icons.card_giftcard,
        size: 50,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildActionButton(bool isCurrentPackage) {
    if (isCurrentPackage) {
      return ElevatedButton(
        onPressed: onViewDetails,
        style: AppTheme.secondaryButton.copyWith(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        child: Text(
          'View Details',
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: onPurchase,
        style: AppTheme.primaryButton.copyWith(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        child: Text(
          'Buy Package',
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      );
    }
  }
}
