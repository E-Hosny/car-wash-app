import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'order_request_screen.dart';

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

  final TextEditingController colorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchBrands();
    fetchYears();
  }

  Future<void> fetchBrands() async {
    final res = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/brands'),
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
    final res = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/brands/$brandId/models'),
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
      print('❌ Failed to load models: ${res.body}');
    }
  }

  Future<void> fetchYears() async {
    final res = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/car-years'),
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
    final res = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/cars'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode({
        'brand_id': selectedBrandId,
        'model_id': selectedModelId,
        'car_year_id': selectedYearId,
        'color': colorController.text,
      }),
    );

    if (res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Car added successfully')),
      );

      Navigator.pop(context, true);
    } else {
      print(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to add car')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Car',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
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
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: InputDecoration(
                  labelText: 'Color',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
                child: const Text('Add Car',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
