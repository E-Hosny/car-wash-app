import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_theme.dart';
import '../services/package_service.dart';

class EnhancedPackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final Map<String, dynamic>? userPackage;
  final VoidCallback? onPurchase;
  final VoidCallback? onViewDetails;

  const EnhancedPackageCard({
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
      height: 300, // Increased height for better image display
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
          // Enhanced Image Section
          Stack(
            children: [
              Container(
                height: 140, // Increased height for better image display
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: Colors.grey.shade50,
                ),
                child: _buildEnhancedPackageImage(),
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
                      style: GoogleFonts.poppins(
                        fontSize: 10,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Package Name and Check Icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package['name'] ?? 'Premium Package',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentPackage)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Description
                  if (package['description'] != null)
                    Text(
                      package['description'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
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
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${package['price']} SAR',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Points',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            PackageService.formatPoints(package['points']),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: AppTheme.primaryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${userPackage!['remaining_points']} points remaining',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Enhanced Action Button
                  SizedBox(
                    width: double.infinity,
                    child: _buildEnhancedActionButton(isCurrentPackage),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPackageImage() {
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
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildEnhancedPlaceholderImage();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                color: Colors.grey.shade200,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildEnhancedPlaceholderImage();
  }

  Widget _buildEnhancedPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        color: Colors.grey.shade200,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard,
              size: 40,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Package',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedActionButton(bool isCurrentPackage) {
    if (isCurrentPackage) {
      return ElevatedButton(
        onPressed: onViewDetails ??
            () {
              // Fallback action if onViewDetails is null
              print('View Details pressed for current package');
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.primaryColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'View Details',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: onPurchase ??
            () {
              // Fallback action if onPurchase is null
              print('Buy Package pressed');
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Buy Package',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }
}
