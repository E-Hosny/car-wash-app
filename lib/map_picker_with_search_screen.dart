import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class MapPickerWithSearchScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerWithSearchScreen({Key? key, required this.initialLocation})
      : super(key: key);

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
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_searchController.text.length > 2) {
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

  // دالة لتحديد نوع المكان وإرجاع الأيقونة المناسبة
  Map<String, dynamic> _getPlaceTypeInfo(List<dynamic>? types) {
    if (types == null || types.isEmpty) {
      return {'icon': Icons.location_on, 'type': 'موقع', 'color': Colors.grey};
    }

    for (String type in types) {
      switch (type) {
        case 'shopping_mall':
        case 'store':
        case 'establishment':
          return {
            'icon': Icons.store,
            'type': 'مكان تجاري',
            'color': Colors.blue
          };
        case 'restaurant':
        case 'food':
          return {
            'icon': Icons.restaurant,
            'type': 'مطعم',
            'color': Colors.orange
          };
        case 'hospital':
        case 'health':
          return {
            'icon': Icons.local_hospital,
            'type': 'مستشفى',
            'color': Colors.red
          };
        case 'school':
        case 'university':
          return {
            'icon': Icons.school,
            'type': 'مدرسة/جامعة',
            'color': Colors.purple
          };
        case 'airport':
          return {'icon': Icons.flight, 'type': 'مطار', 'color': Colors.indigo};
        case 'bank':
          return {
            'icon': Icons.account_balance,
            'type': 'بنك',
            'color': Colors.green
          };
        case 'gas_station':
          return {
            'icon': Icons.local_gas_station,
            'type': 'محطة وقود',
            'color': Colors.amber
          };
        case 'route':
        case 'street_address':
          return {'icon': Icons.route, 'type': 'شارع', 'color': Colors.brown};
        case 'locality':
        case 'sublocality':
          return {
            'icon': Icons.location_city,
            'type': 'منطقة',
            'color': Colors.teal
          };
        case 'park':
          return {
            'icon': Icons.park,
            'type': 'حديقة',
            'color': Colors.lightGreen
          };
        case 'mosque':
        case 'church':
        case 'place_of_worship':
          return {
            'icon': Icons.place,
            'type': 'مكان عبادة',
            'color': Colors.deepPurple
          };
        default:
          return {
            'icon': Icons.location_on,
            'type': 'موقع',
            'color': Colors.grey
          };
      }
    }
    return {'icon': Icons.location_on, 'type': 'موقع', 'color': Colors.grey};
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

      // استخدام Geocoding API مع اللغة المحددة تلقائياً
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedQuery&key=$apiKey&region=ae&language=$detectedLanguage&components=country:ae|country:sa|country:kw|country:qa|country:bh|country:om';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'] != null) {
        List<Map<String, dynamic>> results = [];
        for (var result in data['results']) {
          // استخراج تفاصيل أكثر من العنوان
          String fullAddress = result['formatted_address'];
          List<String> addressParts = fullAddress.split(',');

          // تحديد الاسم الرئيسي والتفاصيل الثانوية
          String mainText =
              addressParts.isNotEmpty ? addressParts[0].trim() : fullAddress;
          String secondaryText = addressParts.length > 1
              ? addressParts.skip(1).join(', ').trim()
              : '';

          // تحديد نوع المكان
          var placeTypeInfo = _getPlaceTypeInfo(result['types']);

          results.add({
            'description': fullAddress,
            'place_id': result['place_id'],
            'main_text': mainText,
            'secondary_text': secondaryText,
            'place_type': placeTypeInfo['type'],
            'place_icon': placeTypeInfo['icon'],
            'place_color': placeTypeInfo['color'],
            'types': result['types'],
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
        print('✅ Enhanced Geocoding API: Found ${results.length} results');
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        print('Geocoding API error: ${data['status']}');

        // عرض رسالة خطأ للمستخدم
        if (data['status'] == 'REQUEST_DENIED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Google Places API is not enabled. Please enable it in Google Cloud Console'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else if (data['status'] == 'ZERO_RESULTS') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No results found. Try searching with different keywords'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
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

        _searchController.text = result['formatted_address'];
      } else {
        print('Error getting place details: ${data['status']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting place details: ${data['status']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error getting place details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting place details: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                      if (cleanedValue.length > 2) {
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final prediction = _searchResults[index];
                        return InkWell(
                          onTap: () => _onPlaceSelected(prediction),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: index < _searchResults.length - 1
                                  ? Border(
                                      bottom:
                                          BorderSide(color: Colors.grey[200]!),
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
                                      // الاسم الرئيسي
                                      Text(
                                        prediction['main_text'] ?? '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
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
                                              color: prediction['place_color'],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      SizedBox(height: 4),
                                      // التفاصيل الثانوية
                                      if (prediction['secondary_text'] !=
                                              null &&
                                          prediction['secondary_text']
                                              .isNotEmpty)
                                        Text(
                                          prediction['secondary_text'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
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
                    Navigator.pop(context,
                        {'latlng': _selectedLocation, 'address': address});
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
}
