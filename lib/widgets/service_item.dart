import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/package_service.dart';

class ServiceItem extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool isSelected;
  final bool usePackage;
  final List<dynamic> availableServices;
  final Function(int, double, bool) onToggle;
  final VoidCallback? onTap;

  const ServiceItem({
    super.key,
    required this.service,
    required this.isSelected,
    required this.usePackage,
    required this.availableServices,
    required this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(service['price'].toString()) ?? 0.0;
    final isAvailableInPackage = usePackage &&
        PackageService.isServiceAvailableInPackage(
            availableServices, service['id']);
    final pointsRequired = usePackage && isAvailableInPackage
        ? PackageService.getPointsRequiredForService(
            availableServices, service['id'])
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected ? AppTheme.shadowMedium : AppTheme.shadowSmall,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spacingM),
        leading: Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(
            _getServiceIcon(service['name']),
            color: isSelected ? AppTheme.secondaryColor : AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                service['name'] ?? 'Service',
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimaryColor,
                ),
              ),
            ),
            _buildPriceOrPoints(pointsRequired, price, isAvailableInPackage),
          ],
        ),
        subtitle: service['description'] != null
            ? Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                child: Text(
                  service['description'],
                  style: AppTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        trailing: Checkbox(
          value: isSelected,
          activeColor: AppTheme.primaryColor,
          onChanged: (val) => onToggle(service['id'], price, val ?? false),
        ),
        onTap: onTap ?? () => onToggle(service['id'], price, !isSelected),
      ),
    );
  }

  Widget _buildPriceOrPoints(
      int? pointsRequired, double price, bool isAvailableInPackage) {
    if (usePackage && isAvailableInPackage) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Text(
          '${pointsRequired ?? 0} Points',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Text(
        '${price.toStringAsFixed(2)} AED',
        style: AppTheme.bodyLarge.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  IconData _getServiceIcon(String? serviceName) {
    if (serviceName == null) return Icons.car_repair;

    final name = serviceName.toLowerCase();

    if (name.contains('wash') || name.contains('غسيل')) {
      return Icons.water_drop;
    } else if (name.contains('polish') || name.contains('تلميع')) {
      return Icons.auto_fix_high;
    } else if (name.contains('vacuum') || name.contains('شفط')) {
      return Icons.cleaning_services;
    } else if (name.contains('wax') || name.contains('شمع')) {
      return Icons.auto_fix_normal;
    } else if (name.contains('interior') || name.contains('داخلي')) {
      return Icons.chair;
    } else if (name.contains('exterior') || name.contains('خارجي')) {
      return Icons.car_rental;
    } else if (name.contains('engine') || name.contains('محرك')) {
      return Icons.engineering;
    } else if (name.contains('tire') || name.contains('إطار')) {
      return Icons.tire_repair;
    } else {
      return Icons.car_repair;
    }
  }
}

class ServiceListSection extends StatelessWidget {
  final List<dynamic> services;
  final List<int> selectedServices;
  final bool usePackage;
  final List<dynamic> availableServices;
  final Function(int, double, bool) onToggleService;
  final VoidCallback? onServiceTap;

  const ServiceListSection({
    super.key,
    required this.services,
    required this.selectedServices,
    required this.usePackage,
    required this.availableServices,
    required this.onToggleService,
    this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Icon(
              Icons.car_repair_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No Services Available',
              style: AppTheme.heading4.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'No services are currently available',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.car_repair,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Services',
              style: AppTheme.heading3,
            ),
            const Spacer(),
            if (usePackage)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border:
                      Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  'Package Mode',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        ...services
            .map((service) => ServiceItem(
                  service: service,
                  isSelected: selectedServices.contains(service['id']),
                  usePackage: usePackage,
                  availableServices: availableServices,
                  onToggle: onToggleService,
                  onTap: onServiceTap,
                ))
            .toList(),
      ],
    );
  }
}
