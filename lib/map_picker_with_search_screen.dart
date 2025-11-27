import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/cache_service.dart';
import 'dart:convert';
import 'dart:async';

class MapPickerWithSearchScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String? token; // Optional token for saving address
  const MapPickerWithSearchScreen({
    Key? key,
    required this.initialLocation,
    this.token,
  }) : super(key: key);

  @override
  State<MapPickerWithSearchScreen> createState() =>
      _MapPickerWithSearchScreenState();
}

class _MapPickerWithSearchScreenState extends State<MapPickerWithSearchScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _loading = false;
  String? _address;
  bool _addressLoading = false;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  bool _isSelectingPlace = false; // متغير لمنع البحث عند اختيار مكان

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToCurrentLocation();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // منع البحث إذا كان المستخدم يختار مكاناً
    if (_isSelectingPlace) return;

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_searchController.text.length > 0) {
        _searchPlaces(_searchController.text);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  // دالة لتحديد اللغة تلقائياً بناءً على النص المكتوب
  String _detectLanguage(String text) {
    // فحص إذا كان النص يحتوي على أحرف عربية
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    if (arabicRegex.hasMatch(text)) {
      return 'ar'; // العربية
    } else {
      return 'en'; // الإنجليزية
    }
  }

  // دالة لفلترة النتائج العامة (مثل الدول والمناطق الواسعة)
  bool _shouldFilterResult(String mainText, String secondaryText) {
    // فلترة النتائج التي تكون فقط أسماء دول أو مناطق واسعة
    List<String> countryOnlyTerms = [
      'united arab emirates',
      'الإمارات العربية المتحدة',
      'saudi arabia',
      'المملكة العربية السعودية',
      'kuwait',
      'الكويت',
      'qatar',
      'قطر',
      'bahrain',
      'البحرين',
      'oman',
      'عمان',
    ];

    // إذا كان النص الرئيسي فقط هو اسم الدولة، فلتره
    String mainTextLower = mainText.toLowerCase().trim();
    for (String term in countryOnlyTerms) {
      if (mainTextLower == term.toLowerCase()) {
        return true; // فلترة هذا النتيجة
      }
    }

    // فلترة النتائج التي تحتوي على كلمات عامة جداً في النص الرئيسي فقط
    if (mainTextLower.contains('country') ||
        mainTextLower.contains('state') ||
        mainTextLower.contains('nation') ||
        mainTextLower.contains('emirate') ||
        mainTextLower.contains('kingdom') ||
        mainTextLower.contains('دولة') ||
        mainTextLower.contains('بلاد') ||
        mainTextLower.contains('إمارة') ||
        mainTextLower.contains('مملكة')) {
      return true;
    }

    return false; // لا نفلتر هذه النتيجة
  }

  // دالة لإرجاع اقتراحات افتراضية عندما لا توجد نتائج
  List<Map<String, dynamic>> _getDefaultSuggestions(String query) {
    List<Map<String, dynamic>> suggestions = [];

    // تحديد اللغة المكتشفة
    String detectedLanguage = _detectLanguage(query);

    // اقتراحات عامة بناءً على النص المكتوب
    String lowerQuery = query.toLowerCase();

    // اقتراحات للمطاعم
    if (lowerQuery.contains('rest') ||
        lowerQuery.contains('food') ||
        lowerQuery.contains('eat')) {
      suggestions.addAll([
        {
          'description': 'Restaurant - Dubai - United Arab Emirates',
          'place_id': 'default_restaurant_1',
          'main_text': 'Restaurant',
          'secondary_text': 'Dubai - United Arab Emirates',
          'place_type': detectedLanguage == 'en' ? 'Restaurant' : 'مطعم',
          'place_icon': Icons.restaurant,
          'place_color': Colors.orange,
          'types': ['restaurant'],
        },
        {
          'description': 'Food Court - Dubai Mall - United Arab Emirates',
          'place_id': 'default_restaurant_2',
          'main_text': 'Food Court',
          'secondary_text': 'Dubai Mall - United Arab Emirates',
          'place_type': detectedLanguage == 'en' ? 'Restaurant' : 'مطعم',
          'place_icon': Icons.restaurant,
          'place_color': Colors.orange,
          'types': ['restaurant'],
        },
      ]);
    }

    // اقتراحات للمستشفيات
    if (lowerQuery.contains('hospital') ||
        lowerQuery.contains('medical') ||
        lowerQuery.contains('doctor')) {
      suggestions.addAll([
        {
          'description': 'Hospital - Dubai - United Arab Emirates',
          'place_id': 'default_hospital_1',
          'main_text': 'Hospital',
          'secondary_text': 'Dubai - United Arab Emirates',
          'place_type': detectedLanguage == 'en' ? 'Hospital' : 'مستشفى',
          'place_icon': Icons.local_hospital,
          'place_color': Colors.red,
          'types': ['hospital'],
        },
        {
          'description': 'Medical Center - Abu Dhabi - United Arab Emirates',
          'place_id': 'default_hospital_2',
          'main_text': 'Medical Center',
          'secondary_text': 'Abu Dhabi - United Arab Emirates',
          'place_type': detectedLanguage == 'en' ? 'Hospital' : 'مستشفى',
          'place_icon': Icons.local_hospital,
          'place_color': Colors.red,
          'types': ['hospital'],
        },
      ]);
    }

    // اقتراحات عامة
    suggestions.addAll([
      {
        'description': 'Dubai Mall - Dubai - United Arab Emirates',
        'place_id': 'default_mall_1',
        'main_text': 'Dubai Mall',
        'secondary_text': 'Dubai - United Arab Emirates',
        'place_type': detectedLanguage == 'en' ? 'Business' : 'مكان تجاري',
        'place_icon': Icons.store,
        'place_color': Colors.blue,
        'types': ['shopping_mall'],
      },
      {
        'description': 'Burj Khalifa - Dubai - United Arab Emirates',
        'place_id': 'default_landmark_1',
        'main_text': 'Burj Khalifa',
        'secondary_text': 'Dubai - United Arab Emirates',
        'place_type': detectedLanguage == 'en' ? 'Landmark' : 'معلم',
        'place_icon': Icons.location_on,
        'place_color': Colors.purple,
        'types': ['landmark'],
      },
      {
        'description':
            'Dubai International Airport - Dubai - United Arab Emirates',
        'place_id': 'default_airport_1',
        'main_text': 'Dubai International Airport',
        'secondary_text': 'Dubai - United Arab Emirates',
        'place_type': detectedLanguage == 'en' ? 'Airport' : 'مطار',
        'place_icon': Icons.flight,
        'place_color': Colors.deepPurple,
        'types': ['airport'],
      },
      {
        'description': 'Sheikh Zayed Road - Dubai - United Arab Emirates',
        'place_id': 'default_street_1',
        'main_text': 'Sheikh Zayed Road',
        'secondary_text': 'Dubai - United Arab Emirates',
        'place_type': detectedLanguage == 'en' ? 'Street' : 'شارع',
        'place_icon': Icons.route,
        'place_color': Colors.brown,
        'types': ['route'],
      },
      {
        'description': 'Marina Walk - Dubai - United Arab Emirates',
        'place_id': 'default_area_1',
        'main_text': 'Marina Walk',
        'secondary_text': 'Dubai - United Arab Emirates',
        'place_type': detectedLanguage == 'en' ? 'Area' : 'منطقة',
        'place_icon': Icons.location_city,
        'place_color': Colors.teal,
        'types': ['locality'],
      },
    ]);

    // إرجاع أول 10 اقتراحات افتراضية
    return suggestions.take(10).toList();
  }

  // دالة لتحديد نوع المكان وإرجاع الأيقونة المناسبة
  Map<String, dynamic> _getPlaceTypeInfo(List<dynamic>? types,
      {String language = 'ar'}) {
    if (types == null || types.isEmpty) {
      return {
        'icon': Icons.location_on,
        'type': language == 'en' ? 'Location' : 'موقع',
        'color': Colors.grey
      };
    }

    for (String type in types) {
      switch (type) {
        case 'shopping_mall':
        case 'store':
        case 'establishment':
        case 'point_of_interest':
          return {
            'icon': Icons.store,
            'type': language == 'en' ? 'Business' : 'مكان تجاري',
            'color': Colors.blue
          };
        case 'restaurant':
        case 'food':
          return {
            'icon': Icons.restaurant,
            'type': language == 'en' ? 'Restaurant' : 'مطعم',
            'color': Colors.orange
          };
        case 'hospital':
        case 'health':
          return {
            'icon': Icons.local_hospital,
            'type': language == 'en' ? 'Hospital' : 'مستشفى',
            'color': Colors.red
          };
        case 'school':
        case 'university':
          return {
            'icon': Icons.school,
            'type': language == 'en' ? 'School/University' : 'مدرسة/جامعة',
            'color': Colors.purple
          };
        case 'airport':
          return {
            'icon': Icons.flight,
            'type': language == 'en' ? 'Airport' : 'مطار',
            'color': Colors.indigo
          };
        case 'bank':
          return {
            'icon': Icons.account_balance,
            'type': language == 'en' ? 'Bank' : 'بنك',
            'color': Colors.green
          };
        case 'gas_station':
          return {
            'icon': Icons.local_gas_station,
            'type': language == 'en' ? 'Gas Station' : 'محطة وقود',
            'color': Colors.amber
          };
        case 'route':
        case 'street_address':
          return {
            'icon': Icons.route,
            'type': language == 'en' ? 'Street' : 'شارع',
            'color': Colors.brown
          };
        case 'locality':
        case 'sublocality':
          return {
            'icon': Icons.location_city,
            'type': language == 'en' ? 'Area' : 'منطقة',
            'color': Colors.teal
          };
        case 'park':
          return {
            'icon': Icons.park,
            'type': language == 'en' ? 'Park' : 'حديقة',
            'color': Colors.lightGreen
          };
        case 'mosque':
        case 'church':
        case 'place_of_worship':
          return {
            'icon': Icons.place,
            'type': language == 'en' ? 'Place of Worship' : 'مكان عبادة',
            'color': Colors.deepPurple
          };
        case 'neighborhood':
        case 'political':
          return {
            'icon': Icons.location_city,
            'type': language == 'en' ? 'Neighborhood' : 'حي',
            'color': Colors.teal
          };
        case 'natural_feature':
          return {
            'icon': Icons.landscape,
            'type': language == 'en' ? 'Natural Feature' : 'معلم طبيعي',
            'color': Colors.green
          };
        case 'landmark':
          return {
            'icon': Icons.location_on,
            'type': language == 'en' ? 'Landmark' : 'معلم',
            'color': Colors.purple
          };
        case 'transit_station':
        case 'subway_station':
          return {
            'icon': Icons.train,
            'type': language == 'en' ? 'Transit Station' : 'محطة مواصلات',
            'color': Colors.blue
          };
        case 'taxi_stand':
          return {
            'icon': Icons.local_taxi,
            'type': language == 'en' ? 'Taxi Stand' : 'موقف تاكسي',
            'color': Colors.yellow
          };
        default:
          return {
            'icon': Icons.location_on,
            'type': language == 'en' ? 'Location' : 'موقع',
            'color': Colors.grey
          };
      }
    }
    return {
      'icon': Icons.location_on,
      'type': language == 'en' ? 'Location' : 'موقع',
      'color': Colors.grey
    };
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission denied. Please enable location access in settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;

      _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });

      print('✅ Moved to current location: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      setState(() => _loading = false);
      print('❌ Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting current location: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final apiKey = "AIzaSyCwdrmyLmP3mam7P4bH-1QVHAKdikHxDDQ";

      // تحديد اللغة تلقائياً بناءً على النص المكتوب
      final detectedLanguage = _detectLanguage(query);
      print('🔍 Detected language: $detectedLanguage for query: $query');

      // استخدام Places Autocomplete API للحصول على اقتراحات مفصلة مثل Google Maps
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedQuery&key=$apiKey&language=$detectedLanguage&components=country:ae&types=establishment|geocode&sessiontoken=session_${DateTime.now().millisecondsSinceEpoch}&radius=50000&strictbounds=false&origin=25.2048,55.2708&location=25.2048,55.2708&region=ae&offset=0';

      print('🔗 API URL: $url');
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      print('📡 API Response: ${response.statusCode}');
      print('📊 API Data: $data');
      print('📊 API Predictions Count: ${data['predictions']?.length ?? 0}');

      if (data['status'] == 'OK' && data['predictions'] != null) {
        List<Map<String, dynamic>> results = [];
        for (var prediction in data['predictions']) {
          // استخراج التفاصيل من الاقتراح
          String description = prediction['description'];
          String placeId = prediction['place_id'];

          // استخراج النص الرئيسي والثانوي من structured_formatting
          String mainText = '';
          String secondaryText = '';

          if (prediction['structured_formatting'] != null) {
            mainText = prediction['structured_formatting']['main_text'] ?? '';
            secondaryText =
                prediction['structured_formatting']['secondary_text'] ?? '';
          } else {
            // إذا لم يكن هناك structured_formatting، نقسم العنوان
            List<String> addressParts = description.split(',');
            mainText =
                addressParts.isNotEmpty ? addressParts[0].trim() : description;
            secondaryText = addressParts.length > 1
                ? addressParts.skip(1).join(', ').trim()
                : '';
          }

          // فلترة النتائج العامة (مثل الدول والمناطق الواسعة)
          // تعليق مؤقت للفلترة لاختبار النتائج
          // if (_shouldFilterResult(mainText, secondaryText)) {
          //   continue;
          // }

          // تحديد نوع المكان من types مع اللغة المكتشفة
          var placeTypeInfo = _getPlaceTypeInfo(prediction['types'],
              language: detectedLanguage);

          results.add({
            'description': description,
            'place_id': placeId,
            'main_text': mainText,
            'secondary_text': secondaryText,
            'place_type': placeTypeInfo['type'],
            'place_icon': placeTypeInfo['icon'],
            'place_color': placeTypeInfo['color'],
            'types': prediction['types'],
            'structured_formatting': {
              'main_text': mainText,
              'secondary_text': secondaryText,
            }
          });
        }

        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        print(
            '✅ Places Autocomplete API: Found ${results.length} filtered results out of ${data['predictions']?.length ?? 0} original predictions');
      } else {
        // إذا لم توجد نتائج، اعرض اقتراحات افتراضية
        List<Map<String, dynamic>> defaultResults =
            _getDefaultSuggestions(query);

        setState(() {
          _searchResults = defaultResults;
          _isSearching = false;
        });

        print(
            'Places Autocomplete API: ${data['status']} - Showing ${defaultResults.length} default suggestions');

        // عرض رسالة خطأ للمستخدم فقط للأخطاء الحقيقية
        if (data['status'] == 'REQUEST_DENIED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Google Places API is not enabled. Please enable it in Google Cloud Console'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Error searching places: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching places: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onPlaceSelected(Map<String, dynamic> prediction) async {
    try {
      // تعيين متغير منع البحث
      _isSelectingPlace = true;

      final apiKey = "AIzaSyCwdrmyLmP3mam7P4bH-1QVHAKdikHxDDQ";

      final placeId = prediction['place_id'];
      // تحديد اللغة بناءً على النص المحدد
      final detectedLanguage = _detectLanguage(prediction['description'] ?? '');
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey&language=$detectedLanguage';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['result'];
        final geometry = result['geometry'];
        final location = geometry['location'];

        final lat = location['lat'];
        final lng = location['lng'];

        setState(() {
          _selectedLocation = LatLng(lat, lng);
          _address = result['formatted_address'];
          _searchResults = [];
        });

        _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));

        // تحديث النص بدون إطلاق البحث
        _searchController.text = result['formatted_address'];

        // إعادة تعيين متغير منع البحث بعد تأخير قصير
        Future.delayed(Duration(milliseconds: 100), () {
          _isSelectingPlace = false;
        });
      } else {
        print('Error getting place details: ${data['status']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting place details: ${data['status']}'),
            backgroundColor: Colors.red,
          ),
        );
        _isSelectingPlace = false;
      }
    } catch (e) {
      print('Error getting place details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting place details: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _isSelectingPlace = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
          title: null,
          flexibleSpace: SafeArea(
            child: Center(
              child: Image.asset('assets/logo.png', height: 100),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation!,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_selectedLocation != null &&
                  _selectedLocation != widget.initialLocation) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(_selectedLocation!),
                );
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onCameraMove: (position) {
              setState(() {
                _selectedLocation = position.target;
                _address = null;
              });
            },
          ),
          Center(
            child: IgnorePointer(
              child: Icon(Icons.location_on, size: 48, color: Colors.red),
            ),
          ),

          // شريط البحث المحسن
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    enableSuggestions: true,
                    autocorrect: true,
                    decoration: InputDecoration(
                      hintText: 'Search for location...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _isSearching
                          ? Container(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      String cleanedValue = value.trim();
                      if (cleanedValue.length > 0) {
                        _searchPlaces(cleanedValue);
                      } else {
                        setState(() {
                          _searchResults = [];
                        });
                      }
                    },
                  ),
                ),

                // نتائج البحث المحسنة
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height *
                          0.6, // حد أقصى 60% من ارتفاع الشاشة لعرض المزيد من النتائج
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        // إخفاء لوحة المفاتيح عند بدء السحب
                        if (scrollInfo is ScrollStartNotification) {
                          FocusScope.of(context).unfocus();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        shrinkWrap: false, // عدم تقليص الحجم لعرض جميع النتائج
                        physics:
                            AlwaysScrollableScrollPhysics(), // تفعيل السحب دائماً
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final prediction = _searchResults[index];
                          return InkWell(
                            onTap: () {
                              // إخفاء لوحة المفاتيح عند اختيار اقتراح
                              FocusScope.of(context).unfocus();
                              _onPlaceSelected(prediction);
                            },
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: index < _searchResults.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                            color: Colors.grey[200]!),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // أيقونة نوع المكان
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: prediction['place_color']
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      prediction['place_icon'],
                                      color: prediction['place_color'],
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // الوصف التفصيلي الكامل
                                        Text(
                                          prediction['description'] ?? '',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 6),
                                        // نوع المكان
                                        if (prediction['place_type'] != null)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: prediction['place_color']
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              prediction['place_type'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    prediction['place_color'],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // سهم التنقل
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_addressLoading) const Center(child: CircularProgressIndicator()),

          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton(
              heroTag: 'current_location',
              backgroundColor: Colors.white,
              onPressed: _loading ? null : _goToCurrentLocation,
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 90,
            child: _address != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _address!,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_selectedLocation == null) return;

                  setState(() {
                    _addressLoading = true;
                  });
                  try {
                    List<Placemark> placemarks = await placemarkFromCoordinates(
                        _selectedLocation!.latitude,
                        _selectedLocation!.longitude);
                    String address = placemarks.isNotEmpty
                        ? [
                            placemarks.first.name,
                            placemarks.first.street,
                            placemarks.first.locality,
                            placemarks.first.country
                          ].where((e) => e != null && e.isNotEmpty).join(', ')
                        : 'Unknown location';
                    setState(() {
                      _address = address;
                      _addressLoading = false;
                    });

                    // Show Add Address Details modal if token is provided
                    if (widget.token != null && widget.token!.isNotEmpty) {
                      final result = await _showAddAddressDetailsDialog(
                        _selectedLocation!,
                        address,
                      );
                      if (result == true) {
                        // Address was saved, return the data
                        Navigator.pop(context,
                            {'latlng': _selectedLocation, 'address': address});
                      }
                      // If result is false or null, user cancelled, don't return
                    } else {
                      // No token, return directly
                      Navigator.pop(context,
                          {'latlng': _selectedLocation, 'address': address});
                    }
                  } catch (e) {
                    setState(() {
                      _addressLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to get address: $e')),
                    );
                    print('Geocoding error: $e');
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirm Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showAddAddressDetailsDialog(
      LatLng latlng, String address) async {
    final labelController = TextEditingController();
    final streetController = TextEditingController();
    final notesController = TextEditingController();
    bool isSaving = false;

    return await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add Address Details',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location Preview Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.map,
                                  color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Location',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      address,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Form Fields
                        _buildTextField(
                          controller: labelController,
                          label: 'Label',
                          hint: 'e.g. Home, Work, Office',
                          icon: Icons.label_outline,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: streetController,
                          label: 'Street',
                          hint: 'Enter street name',
                          icon: Icons.streetview,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: notesController,
                          label: 'Additional Notes',
                          hint: 'Any special instructions (optional)',
                          icon: Icons.note_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (labelController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Please enter a label for this address'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  try {
                                    final baseUrl = dotenv.env['BASE_URL'];
                                    if (baseUrl == null || baseUrl.isEmpty) {
                                      setDialogState(() => isSaving = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Configuration error: BASE_URL not found'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    final res = await http.post(
                                      Uri.parse('$baseUrl/api/addresses'),
                                      headers: {
                                        'Authorization':
                                            'Bearer ${widget.token}',
                                        'Content-Type': 'application/json',
                                      },
                                      body: jsonEncode({
                                        'label': labelController.text.trim(),
                                        'street': streetController.text.trim(),
                                        'notes': notesController.text.trim(),
                                        'address': address,
                                        'latitude': latlng.latitude,
                                        'longitude': latlng.longitude,
                                      }),
                                    );
                                    setDialogState(() => isSaving = false);
                                    if (res.statusCode == 201) {
                                      // Invalidate cache to ensure fresh data is fetched
                                      if (widget.token != null &&
                                          widget.token!.isNotEmpty) {
                                        CacheService()
                                            .invalidateAddresses(widget.token!);
                                      }
                                      Navigator.pop(context, true);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle,
                                                  color: Colors.white),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                    'Address saved successfully!'),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Failed to save address'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error saving address: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Save Address',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      ],
    );
  }
}
