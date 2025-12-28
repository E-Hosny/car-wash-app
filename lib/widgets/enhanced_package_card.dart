import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      height: 360, // Increased height for better image display
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
                height: 180, // Increased height for better image display
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
                            '${package['price']} AED',
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
                            _formatServices(package['services']),
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
                              _getPackageServicesText(userPackage!),
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
    // Check for image_url first (full URL like services)
    String? imageUrl;
    if (package['image_url'] != null && package['image_url'].toString().isNotEmpty) {
      imageUrl = package['image_url'].toString();
      print('🖼️ Loading package image from image_url: $imageUrl');
    } else if (package['image'] != null && package['image'].toString().isNotEmpty) {
      // Build URL from image path
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      imageUrl = '$baseUrl/storage/${package['image']}';
      print('🖼️ Loading package image from image path: $imageUrl');
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              color: Colors.grey.shade200,
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            print('❌ Error loading package image: $url');
            print('❌ Error details: $error');
            return _buildEnhancedPlaceholderImage();
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

  String _formatServices(dynamic services) {
    if (services == null || services is! List || services.isEmpty) {
      return '0 Services';
    }
    final servicesList = services as List;
    int totalQuantity = 0;
    for (var service in servicesList) {
      final qty = service['quantity'];
      if (qty != null) {
        totalQuantity += qty is int ? qty : (qty is num ? qty.toInt() : 0);
      }
    }
    return '$totalQuantity Services';
  }

  String _getPackageServicesText(Map<String, dynamic> userPackage) {
    final services = userPackage['services'] as List? ?? [];
    int totalRemaining = 0;
    
    for (var service in services) {
      final remaining = service['remaining_quantity'] ?? 0;
      totalRemaining += remaining is int ? remaining : (remaining is String ? int.tryParse(remaining) ?? 0 : 0);
    }
    
    return '$totalRemaining services remaining';
  }
}
