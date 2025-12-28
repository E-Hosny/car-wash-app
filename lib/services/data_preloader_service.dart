import 'cache_service.dart';

/// Service to preload critical data in the background when app starts
/// This improves performance for Single Car Wash screen by having data ready in cache
class DataPreloaderService {
  static final DataPreloaderService _instance = DataPreloaderService._internal();
  factory DataPreloaderService() => _instance;
  DataPreloaderService._internal();

  bool _isPreloading = false;
  DateTime? _lastPreloadTime;

  /// Preload critical data for Single Car Wash screen
  /// This includes: Services, Cars, Addresses, and Time Slots for today
  /// 
  /// [token] - User authentication token
  /// Returns true if preload was initiated, false if already preloading or recently preloaded
  Future<bool> preloadCriticalData(String token) async {
    // Prevent multiple simultaneous preloads
    if (_isPreloading) {
      print('⏳ Data preload already in progress, skipping...');
      return false;
    }

    // Don't preload if we just preloaded recently (within last 30 seconds)
    if (_lastPreloadTime != null) {
      final timeSinceLastPreload = DateTime.now().difference(_lastPreloadTime!);
      if (timeSinceLastPreload.inSeconds < 30) {
        print('⏳ Data was preloaded recently (${timeSinceLastPreload.inSeconds}s ago), skipping...');
        return false;
      }
    }

    // Check if token is valid
    if (token.isEmpty) {
      print('⚠️ Cannot preload data: token is empty');
      return false;
    }

    _isPreloading = true;
    _lastPreloadTime = DateTime.now();

    print('🚀 Starting data preload for Single Car Wash...');

    try {
      final cacheService = CacheService();
      final today = DateTime.now();

      // Check what needs to be preloaded (only if cache is expired or missing)
      final cachedServices = cacheService.getCachedServices(token);
      final cachedCars = cacheService.getCachedCars(token);
      final cachedAddresses = cacheService.getCachedAddresses(token);
      final cachedTimeSlots = cacheService.getCachedTimeSlots(token, today);

      List<Future> preloadTasks = [];

      // Preload services if cache is expired or missing
      if (cachedServices == null || cachedServices.isEmpty) {
        print('📦 Preloading services...');
        preloadTasks.add(
          cacheService.getServices(token).catchError((e) {
            print('⚠️ Error preloading services: $e');
            return <dynamic>[];
          }),
        );
      } else {
        print('✅ Services already cached');
      }

      // Preload cars if cache is expired or missing
      if (cachedCars == null || cachedCars.isEmpty) {
        print('📦 Preloading cars...');
        preloadTasks.add(
          cacheService.getCars(token).catchError((e) {
            print('⚠️ Error preloading cars: $e');
            return <dynamic>[];
          }),
        );
      } else {
        print('✅ Cars already cached');
      }

      // Preload addresses if cache is expired or missing
      if (cachedAddresses == null || cachedAddresses.isEmpty) {
        print('📦 Preloading addresses...');
        preloadTasks.add(
          cacheService.getAddresses(token).catchError((e) {
            print('⚠️ Error preloading addresses: $e');
            return <Map<String, dynamic>>[];
          }),
        );
      } else {
        print('✅ Addresses already cached');
      }

      // Preload time slots for today if cache is expired or missing
      if (cachedTimeSlots == null) {
        print('📦 Preloading time slots for today...');
        preloadTasks.add(
          cacheService.getBookedTimeSlots(token, today).catchError((e) {
            print('⚠️ Error preloading time slots: $e');
            return <String, dynamic>{'booked_hours': <int>[], 'unavailable_hours': <int>[]};
          }),
        );
      } else {
        print('✅ Time slots already cached');
      }

      // Execute all preload tasks in parallel
      if (preloadTasks.isNotEmpty) {
        await Future.wait(preloadTasks);
        print('✅ Data preload completed successfully');
      } else {
        print('✅ All data already cached, no preload needed');
      }

      return true;
    } catch (e) {
      print('❌ Error during data preload: $e');
      return false;
    } finally {
      _isPreloading = false;
    }
  }

  /// Force preload all critical data (ignores cache and recent preload checks)
  /// Useful for manual refresh
  Future<void> forcePreload(String token) async {
    _isPreloading = false;
    _lastPreloadTime = null;
    await preloadCriticalData(token);
  }

  /// Check if preload is currently in progress
  bool get isPreloading => _isPreloading;

  /// Get time since last preload
  Duration? get timeSinceLastPreload {
    if (_lastPreloadTime == null) return null;
    return DateTime.now().difference(_lastPreloadTime!);
  }
}

