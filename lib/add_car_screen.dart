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

  // Custom input controllers
  final TextEditingController customBrandController = TextEditingController();
  final TextEditingController customModelController = TextEditingController();
  final TextEditingController customYearController = TextEditingController();

  // Flags to track if user selected "Other"
  bool isCustomBrand = false;
  bool isCustomModel = false;
  bool isCustomYear = false;

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
    // Validation
    if (selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car color'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isCustomBrand && selectedBrandId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a brand'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isCustomBrand && customBrandController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom brand name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isCustomModel && selectedModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a model'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isCustomModel && customModelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom model name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isCustomYear && selectedYearId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a year'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isCustomYear && customYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom year'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final baseUrl = dotenv.env['BASE_URL']!;

    // Prepare request body
    Map<String, dynamic> requestBody = {
      'color': selectedColor,
      'license_plate': licensePlateController.text.isEmpty
          ? null
          : licensePlateController.text,
    };

    // Add brand data
    if (isCustomBrand) {
      requestBody['custom_brand'] = customBrandController.text.trim();
    } else {
      requestBody['brand_id'] = selectedBrandId;
    }

    // Add model data
    if (isCustomModel) {
      requestBody['custom_model'] = customModelController.text.trim();
    } else {
      requestBody['model_id'] = selectedModelId;
    }

    // Add year data
    if (isCustomYear) {
      requestBody['custom_year'] = customYearController.text.trim();
    } else {
      requestBody['car_year_id'] = selectedYearId;
    }

    final res = await http.post(
      Uri.parse('$baseUrl/api/cars'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode(requestBody),
    );

    if (res.statusCode == 201) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Car added successfully')),
      );

      Navigator.pop(context, true);
    } else {
      debugPrint('❌ Failed to add car: ${res.statusCode}');
      debugPrint('Response body: ${res.body}');

      if (!mounted) return;

      String errorMessage = '❌ Failed to add car';

      // Try to parse error message from response
      try {
        final errorResponse = jsonDecode(res.body);
        if (errorResponse['message'] != null) {
          errorMessage = '❌ ${errorResponse['message']}';
        }
      } catch (e) {
        debugPrint('Could not parse error response: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    licensePlateController.dispose();
    colorController.dispose();
    customBrandController.dispose();
    customModelController.dispose();
    customYearController.dispose();
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
              // Brand Selection
              _buildBrandSection(),
              const SizedBox(height: 16),

              // Model Selection
              _buildModelSection(),
              const SizedBox(height: 16),

              // Year Selection
              _buildYearSection(),
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

  Widget _buildBrandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Brand',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (!isCustomBrand)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<int>(
              value: selectedBrandId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              hint: const Text('Select Brand'),
              items: [
                ...brands.map<DropdownMenuItem<int>>((item) {
                  return DropdownMenuItem<int>(
                    value: item['id'],
                    child: Text(item['name'].toString()),
                  );
                }),
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Other (Enter Custom)',
                          style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  if (val == -1) {
                    isCustomBrand = true;
                    selectedBrandId = null;
                    // When brand is custom, model should also be custom
                    isCustomModel = true;
                    selectedModelId = null;
                    models = [];
                  } else {
                    selectedBrandId = val;
                    isCustomBrand = false;
                    selectedModelId = null;
                    models = [];
                    isCustomModel = false;
                  }
                });
                if (val != null && val != -1) fetchModels(val);
              },
            ),
          )
        else
          Column(
            children: [
              TextFormField(
                controller: customBrandController,
                decoration: InputDecoration(
                  hintText: 'Enter brand name (e.g., Tesla, BYD)',
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade300),
                  ),
                  prefixIcon:
                      Icon(Icons.directions_car, color: Colors.blue.shade600),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        isCustomBrand = false;
                        isCustomModel = false;
                        customBrandController.clear();
                        customModelController.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to list'),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Model',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (isCustomBrand || isCustomModel)
          // Show custom input if brand is custom OR user chose custom model
          Column(
            children: [
              TextFormField(
                controller: customModelController,
                decoration: InputDecoration(
                  hintText: 'Enter model name (e.g., Model S, Corolla)',
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade300),
                  ),
                  prefixIcon:
                      Icon(Icons.car_rental, color: Colors.blue.shade600),
                ),
              ),
              if (!isCustomBrand) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          isCustomModel = false;
                          customModelController.clear();
                        });
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to list'),
                    ),
                  ],
                ),
              ],
            ],
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<int>(
              value: selectedModelId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              hint: const Text('Select Model'),
              items: [
                ...models.map<DropdownMenuItem<int>>((item) {
                  return DropdownMenuItem<int>(
                    value: item['id'],
                    child: Text(item['name'].toString()),
                  );
                }),
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Other (Enter Custom)',
                          style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  if (val == -1) {
                    isCustomModel = true;
                    selectedModelId = null;
                  } else {
                    selectedModelId = val;
                    isCustomModel = false;
                  }
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildYearSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Year',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (!isCustomYear)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<int>(
              value: selectedYearId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              hint: const Text('Select Year'),
              items: [
                ...years.map<DropdownMenuItem<int>>((item) {
                  return DropdownMenuItem<int>(
                    value: item['id'],
                    child: Text(item['year'].toString()),
                  );
                }),
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Other (Enter Custom)',
                          style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  if (val == -1) {
                    isCustomYear = true;
                    selectedYearId = null;
                  } else {
                    selectedYearId = val;
                    isCustomYear = false;
                  }
                });
              },
            ),
          )
        else
          Column(
            children: [
              TextFormField(
                controller: customYearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter year (e.g., 2024)',
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade300),
                  ),
                  prefixIcon:
                      Icon(Icons.calendar_today, color: Colors.blue.shade600),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        isCustomYear = false;
                        customYearController.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to list'),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
