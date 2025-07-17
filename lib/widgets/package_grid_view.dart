import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
            flex: 3,
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
                            '${package['price']} SAR',
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
                            PackageService.formatPoints(package['points']),
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
            return _buildPlaceholderImage();
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
                  strokeWidth: 2,
                ),
              ),
            );
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
}
