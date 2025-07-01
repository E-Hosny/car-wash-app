import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({Key? key, required this.initialLocation})
      : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _loading = false;
  String? _address;
  bool _addressLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _loading = false);
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
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
            onMapCreated: (controller) => _mapController = controller,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
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
