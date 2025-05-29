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

      // ⬇️ الانتقال إلى صفحة الطلب بعد نجاح الإضافة
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
      appBar: AppBar(title: const Text('Add Car')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                value: selectedBrandId,
                hint: const Text('Select Brand'),
                items: brands.map<DropdownMenuItem<int>>((b) {
                  return DropdownMenuItem<int>(
                    value: b['id'],
                    child: Text(b['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedBrandId = val;
                    selectedModelId = null;
                    models = [];
                  });
                  if (val != null) {
                    fetchModels(val);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedModelId,
                hint: const Text('Select Model'),
                items: models.map<DropdownMenuItem<int>>((m) {
                  return DropdownMenuItem<int>(
                    value: m['id'],
                    child: Text(m['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedModelId = val),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedYearId,
                hint: const Text('Select Year'),
                items: years.map<DropdownMenuItem<int>>((y) {
                  return DropdownMenuItem<int>(
                    value: y['id'],
                    child: Text(y['year'].toString()),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedYearId = val),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Color'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: addCar,
                child: const Text('Add Car'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
