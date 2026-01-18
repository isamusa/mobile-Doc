import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';

class DietScanScreen extends StatefulWidget {
  const DietScanScreen({super.key});

  @override
  State<DietScanScreen> createState() => _DietScanScreenState();
}

class _DietScanScreenState extends State<DietScanScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _foodNameController = TextEditingController();

  bool _isAnalyzing = false;
  String? _resultText;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _image = File(photo.path);
        _resultText = null;
      });
      // After picking, ask for food name or context
      _showFoodNameDialog();
    }
  }

  void _showFoodNameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("What dish is this?"),
        content: TextField(
          controller: _foodNameController,
          decoration: const InputDecoration(
            hintText: "e.g. Jollof Rice, Pounded Yam",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog but don't analyze
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _analyzeFood();
            },
            child: const Text("Analyze"),
          )
        ],
      ),
    );
  }

  Future<void> _analyzeFood() async {
    if (_image == null) return;

    String foodName = _foodNameController.text.isEmpty
        ? "Nigerian Food"
        : _foodNameController.text;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // 1. Send to AI
      final response = await ApiService.analyzeImage(_image!, foodName);

      // 2. Save to History
      // Extract calories if possible, otherwise just save the name
      String calories = "Analyzed";
      // Simple logic to find calorie number in text if AI mentions it (e.g. "Contains 400 kcal")
      // For now, we save the full response or a summary.
      // Ideally, the AI should return JSON, but for text generation we save the name.
      await PatientDataService.addDietScan(foodName, calories);

      if (mounted) {
        setState(() {
          _resultText = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _resultText = null;
      _foodNameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Diet Scanner"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Check if we can pop, otherwise go to home
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Fallback if accessed directly (e.g. from main wrapper)
              // Just do nothing or maybe switch tab if controlled externally
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Image Preview Area
          if (_image != null)
            Positioned.fill(
              child: Image.file(_image!, fit: BoxFit.cover),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt,
                      color: Colors.white.withOpacity(0.5), size: 80),
                  const SizedBox(height: 16),
                  Text(
                    'Snap your meal to analyze',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 18),
                  ),
                ],
              ),
            ),

          // Analysis Overlay (Draggable Scroll Sheet look-alike)
          if (_resultText != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _foodNameController.text.isEmpty
                                  ? "Food Analysis"
                                  : _foodNameController.text,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: _reset,
                          )
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        _resultText!,
                        style: const TextStyle(
                            fontSize: 16, height: 1.5, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _reset,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text("Scan Next Meal"),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Controls (Only visible when no result)
          if (_resultText == null && !_isAnalyzing)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlBtn(
                    icon: Icons.photo_library,
                    label: "Gallery",
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  FloatingActionButton.large(
                    heroTag: "camera_main",
                    backgroundColor: AppColors.primary,
                    onPressed: () => _pickImage(ImageSource.camera),
                    child: const Icon(Icons.camera_alt,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(
                      width: 60), // Spacer to balance layout if needed
                ],
              ),
            ),

          // Loading Indicator
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      "Dr. Mobile Doc is analyzing...",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
