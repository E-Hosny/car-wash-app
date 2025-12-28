import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_theme.dart';
import '../services/package_service.dart';

class PackageGridView extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  final Map<String, dynamic>? userPackage;
  final Function(Map<String, dynamic>) onPurchase;
  final VoidCallback onViewDetails;

  const PackageGridView({
    super.key,
    required this.packages,
    this.userPackage,
    required this.onPurchase,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Available Packages',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),

        // Grid View
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final package = packages[index];
            return _buildPackageCard(package, context);
          },
        ),
      ],
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package, BuildContext context) {
    final isCurrentPackage =
        userPackage != null && userPackage!['package']['id'] == package['id'];

    return Container(
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
          // Image Section
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    color: Colors.grey.shade50,
                  ),
                  child: _buildPackageImage(package),
                ),
                if (isCurrentPackage)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Current',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Package Name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package['name'] ?? 'Package',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
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
                          size: 14,
                        ),
                    ],
                  ),

                  const SizedBox(height: 2),

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
                              fontSize: 8,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${package['price']} AED',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
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
                              fontSize: 8,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatServices(package['services']),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child:
                        _buildActionButton(isCurrentPackage, package, context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageImage(Map<String, dynamic> package) {
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
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 30,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isCurrentPackage, Map<String, dynamic> package,
      BuildContext context) {
    if (isCurrentPackage) {
      return ElevatedButton(
        onPressed: onViewDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppTheme.primaryColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          elevation: 0,
        ),
        child: Text(
          'View Details',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: () => onPurchase(package),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          elevation: 0,
        ),
        child: Text(
          'Buy',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
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
}
