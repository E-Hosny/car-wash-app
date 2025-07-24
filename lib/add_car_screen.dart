import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddCarScreen extends StatefulWidget {
  final String token;
  const AddCarScreen({super.key, required this.token});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  List<dynamic> brands = [];
  List<dynamic> models = [];
  List<dynamic> years = [];

  int? selectedBrandId;
  int? selectedModelId;
  int? selectedYearId;
  String? selectedColor;
  final TextEditingController licensePlateController = TextEditingController();

  // Common car colors list
  final List<Map<String, dynamic>> carColors = [
    {'name': 'Black', 'code': '#000000'},
    {'name': 'White', 'code': '#FFFFFF'},
    {'name': 'Silver', 'code': '#C0C0C0'},
    {'name': 'Gray', 'code': '#808080'},
    {'name': 'Red', 'code': '#FF0000'},
    {'name': 'Blue', 'code': '#0000FF'},
    {'name': 'Green', 'code': '#008000'},
    {'name': 'Brown', 'code': '#A52A2A'},
    {'name': 'Beige', 'code': '#F5F5DC'},
    {'name': 'Gold', 'code': '#FFD700'},
  ];

  final TextEditingController colorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchBrands();
    fetchYears();
  }

  Future<void> fetchBrands() async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.get(
      Uri.parse('$baseUrl/api/brands'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      setState(() {
        brands = decoded is List ? decoded : [];
      });
    }
  }

  Future<void> fetchModels(int brandId) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.get(
      Uri.parse('$baseUrl/api/brands/$brandId/models'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      setState(() {
        models = decoded is List ? decoded : [];
      });
    } else {
      debugPrint('❌ Failed to load models: ${res.body}');
    }
  }

  Future<void> fetchYears() async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.get(
      Uri.parse('$baseUrl/api/car-years'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      setState(() {
        years = decoded is List ? decoded : [];
      });
    }
  }

  Future<void> addCar() async {
    if (selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car color'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.post(
      Uri.parse('$baseUrl/api/cars'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode({
        'brand_id': selectedBrandId,
        'model_id': selectedModelId,
        'car_year_id': selectedYearId,
        'color': selectedColor,
        'license_plate': licensePlateController.text.isEmpty
            ? null
            : licensePlateController.text,
      }),
    );

    if (res.statusCode == 201) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Car added successfully')),
      );

      Navigator.pop(context, true);
    } else {
      debugPrint(res.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to add car')),
      );
    }
  }

  @override
  void dispose() {
    licensePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                    top: 8.0, left: 0.0, right: 0.0, bottom: 0.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                ),
              ),
              buildDropdown(
                hint: 'Select Brand',
                value: selectedBrandId,
                items: brands,
                onChanged: (val) {
                  setState(() {
                    selectedBrandId = val;
                    selectedModelId = null;
                    models = [];
                  });
                  if (val != null) fetchModels(val);
                },
              ),
              const SizedBox(height: 12),
              buildDropdown(
                hint: 'Select Model',
                value: selectedModelId,
                items: models,
                onChanged: (val) => setState(() => selectedModelId = val),
              ),
              const SizedBox(height: 12),
              buildDropdown(
                hint: 'Select Year',
                value: selectedYearId,
                items: years,
                labelKey: 'year',
                onChanged: (val) => setState(() => selectedYearId = val),
              ),
              const SizedBox(height: 20),
              const Text(
                'License Plate (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: licensePlateController,
                decoration: InputDecoration(
                  hintText: 'Enter license plate number',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Car Color',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: carColors.map((color) {
                        final isSelected = selectedColor == color['name'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedColor = color['name']),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                  color['code'].replaceAll('#', '0xFF'))),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    if (selectedColor != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(int.parse(carColors
                                    .firstWhere((c) =>
                                        c['name'] == selectedColor)['code']
                                    .replaceAll('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Selected Color: $selectedColor',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: addCar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add Car',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDropdown({
    required String hint,
    required int? value,
    required List items,
    required void Function(int?) onChanged,
    String labelKey = 'name',
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      hint: Text(hint),
      items: items.map<DropdownMenuItem<int>>((item) {
        return DropdownMenuItem<int>(
          value: item['id'],
          child: Text(item[labelKey].toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
