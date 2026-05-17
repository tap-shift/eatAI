import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eatAI - Fitness & Macro Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(color: Color(0xFF1E1E1E), elevation: 4),
      ),
      home: const FoodScannerScreen(),
    );
  }
}

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Daily Tracking pools
  int _consumedCalories = 0;
  int _consumedProtein = 0;
  final int _targetCalories = 2500;
  final int _targetProtein = 140;

  Map<String, dynamic>? _lastNutritionResult;

  // PUBLIC CONFIGURATION TEMPLATE
  // Replace this placeholder with your host deployment IP address or backend endpoint domain
  final String serverUrl = 'http://YOUR_SERVER_IP_HERE:3000/api/scan';

  Future<void> _takePicture() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 378,
        maxHeight: 378,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });

        Future.delayed(const Duration(milliseconds: 250), () {
          _sendImageToServer();
        });
      }
    } catch (e) {
      _showSnackBar('Camera initialization failed.', Colors.redAccent);
    }
  }

  Future<void> _sendImageToServer() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

      var streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _lastNutritionResult = data;

          _consumedCalories += (data['total_calories'] as num? ?? 0).toInt();
          _consumedProtein += (data['protein_g'] as num? ?? 0).toInt();
        });
        _showSnackBar('Plate analyzed successfully!', Colors.green);
      } else {
        _showSnackBar('Server Error Code: ${response.statusCode}', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Connection failed or timed out.', Colors.orangeAccent);
      debugPrint(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eatAI • Fitness Tracker', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isTablet = constraints.maxWidth > 650;
          double contentWidth = isTablet ? 600 : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: contentWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDashboardMetrics(),
                    const SizedBox(height: 20),
                    _buildImagePreviewView(),
                    const SizedBox(height: 15),
                    _buildActionButton(),
                    const SizedBox(height: 25),
                    if (_isLoading) _buildLoadingBarIndicator(),
                    if (!_isLoading && _lastNutritionResult != null) _buildNutritionCardAnalysis(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardMetrics() {
    double calProgress = (_consumedCalories / _targetCalories).clamp(0.0, 1.0);
    double proteinProgress = (_consumedProtein / _targetProtein).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Progress Targets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 15),
            Text('🔥 Calories: $_consumedCalories / $_targetCalories kcal', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: calProgress, color: Colors.orangeAccent, backgroundColor: Colors.grey[800], minHeight: 8),
            const SizedBox(height: 15),
            Text('💪 Protein: $_consumedProtein / $_targetProtein g', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: proteinProgress, color: Colors.greenAccent, backgroundColor: Colors.grey[800], minHeight: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewView() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
      ),
      child: _image == null
          ? const Center(child: Text('No meal image captured yet', style: TextStyle(color: Colors.grey, fontSize: 15)))
          : null,
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _takePicture,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        disabledBackgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.camera_alt, color: Colors.white),
      label: const Text('Capture & Scan Meal', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLoadingBarIndicator() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 15),
              const Text('Processing plate metrics...', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                'Running local vision model & querying live nutrition database. Please wait.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionCardAnalysis() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lastNutritionResult!['dish_name'] ?? 'Analyzed Plate Info',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Divider(height: 25, color: Colors.grey),
            _buildMacroLine('🔥 Total Calories', '${_lastNutritionResult!['total_calories']} kcal', isBold: true),
            const SizedBox(height: 8),
            _buildMacroLine('💪 Total Proteins', '${_lastNutritionResult!['protein_g']} g'),
            _buildMacroLine('🍞 Total Carbs', '${_lastNutritionResult!['carbs_g']} g'),
            _buildMacroLine('🥑 Total Fats', '${_lastNutritionResult!['fat_g']} g'),
            const Divider(height: 25, color: Colors.grey),
            const Text('Database Matches:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (_lastNutritionResult!['ingredients'] != null)
              ...(pathToList(_lastNutritionResult!['ingredients'])).map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '➔ ${item['name']} (${item['weight_g']}g) ~ ${item['calories']} kcal',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroLine(String title, String value, {bool isBold = false}) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isBold ? Colors.orangeAccent : Colors.white)),
      ],
    );
  }

  List<dynamic> pathToList(dynamic input) {
    if (input is List) return input;
    return [];
  }
}
