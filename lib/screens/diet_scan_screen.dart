import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class DietScanScreen extends StatefulWidget {
  const DietScanScreen({super.key});

  @override
  State<DietScanScreen> createState() => _DietScanScreenState();
}

class _DietScanScreenState extends State<DietScanScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _foodNameController =
      TextEditingController(); // Controller for the input
  bool _isLoading = false;
  String? _analysisResult;

  // Function to Pick Image
  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _image = File(photo.path);
        _analysisResult = null; // Reset results
        _foodNameController.clear(); // Reset text field
      });
    }
  }

  // Function to Send to AI
  Future<void> _analyzeFood() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      // Pass the optional text description to the API
      String result = await ApiService.analyzeFoodImage(_image!,
          userDescription: _foodNameController.text.trim());

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _analysisResult =
            "Error connecting to AI Doctor. Please check internet.";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Allow scrolling if the keyboard covers the screen
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKGROUND IMAGE
          _image == null
              ? Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.camera_alt, color: Colors.grey, size: 80),
                  ),
                )
              : Image.file(_image!, fit: BoxFit.cover),

          // 2. OVERLAY CONTROLS
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LOADING INDICATOR
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )

                  // RESULT BOX
                  else if (_analysisResult != null)
                    Container(
                      padding: const EdgeInsets.all(15),
                      margin: const EdgeInsets.only(bottom: 20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Column(
                        children: [
                          const Text("Dr. AI Analysis:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text(_analysisResult!, textAlign: TextAlign.center),
                        ],
                      ),
                    ),

                  // INPUTS
                  if (_image == null) ...[
                    // INITIAL STATE
                    const Text(
                      "Scan Your Meal",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Point camera at food to check if it fits your diet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera),
                      label: const Text("Take Photo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Upload from Gallery"),
                    ),
                  ] else ...[
                    // PHOTO TAKEN STATE

                    // Optional Text Field for Clarity
                    TextField(
                      controller: _foodNameController,
                      decoration: InputDecoration(
                        labelText: "What is this? (Optional)",
                        hintText: "e.g. Tuwon Shinkafa, Semo",
                        prefixIcon:
                            const Icon(Icons.edit, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _image = null;
                            _analysisResult = null;
                          }),
                          child: const Text("Retake"),
                        ),
                        ElevatedButton(
                          onPressed: _analyzeFood,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                          ),
                          child: const Text("Analyze Diet"),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
