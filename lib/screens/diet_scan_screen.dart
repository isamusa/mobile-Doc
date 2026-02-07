import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';
import 'chat_screen.dart'; // Ensure this import points to your Chat Screen

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  // Modes: 'diet' (Food), 'lab' (Paper Reports), 'scan' (X-Ray/CT/Microscope)
  String _scanMode = 'diet';
  bool _isAnalyzing = false;
  String? _resultText;

  // 🧹 HELPER: Clean AI Response (Remove **, ##, fix lists)
  String _cleanResponse(String text) {
    return text
        .replaceAll('**', '') // Remove bolding markers
        .replaceAll('##', '') // Remove header markers
        .replaceAll(RegExp(r'^\* ', multiLine: true), '• ') // Fix bullet points
        .trim();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _image = File(photo.path);
        _resultText = null;
      });
      _showDescriptionDialog();
    }
  }

  void _showDescriptionDialog() {
    String title;
    String hint;

    // Dynamic Context based on Mode
    switch (_scanMode) {
      case 'diet':
        title = "What dish is this?";
        hint = "e.g. Jollof Rice, Pounded Yam";
        break;
      case 'lab':
        title = "What report is this?";
        hint = "e.g. Malaria Result, Widal Test";
        break;
      case 'scan':
        title = "What type of scan?";
        hint = "e.g. Chest X-Ray, CT Scan, Blood Smear";
        break;
      default:
        title = "Describe the image";
        hint = "Medical description";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: AppColors.primary)),
        content: TextField(
          controller: _descController,
          // 🎨 VISIBILITY FIX: Force text to be black
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade100, // Light background for contrast
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _analyzeImage();
            },
            child: const Text("Analyze"),
          )
        ],
      ),
    );
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    // Default descriptions if empty
    String description = _descController.text;
    if (description.isEmpty) {
      if (_scanMode == 'diet')
        description = "Nigerian Food";
      else if (_scanMode == 'lab')
        description = "Lab Report";
      else
        description = "Medical Scan";
    }

    setState(() => _isAnalyzing = true);

    try {
      // 1. Send to AI with selected mode
      final response =
          await ApiService.analyzeImage(_image!, description, mode: _scanMode);

      // 2. Save Data & Smart Parsing
      if (_scanMode == 'diet') {
        _handleDietResult(description, response);
      } else {
        // Labs and Scans go to Diagnosis History
        await PatientDataService.addDiagnosis(
            "$_scanMode Analysis ($description): $response");
      }

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
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _handleDietResult(String foodName, String text) async {
    String calories = "Unknown";
    // Regex to find "350 kcal" or "350 calories"
    final calorieRegex =
        RegExp(r'(\d+)\s*(?:kcal|calories)', caseSensitive: false);
    final match = calorieRegex.firstMatch(text);
    if (match != null) {
      calories = "${match.group(1)} kcal";
    }
    await PatientDataService.addDietScan(foodName, calories);
  }

  // 🚀 THE BRIDGE: Transfer result to Chat Screen
  void _consultDoctor() {
    if (_resultText == null) return;

    String typeLabel = _scanMode == 'diet'
        ? "meal"
        : (_scanMode == 'lab' ? "lab report" : "medical scan");

    // We send the raw result to the chat, the Chat Screen will format it there too
    String initialMessage =
        "I just analyzed my $typeLabel (${_descController.text}). The result is: $_resultText. What does this mean for my health?";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(initialQuery: initialMessage),
      ),
    );
  }

  void _reset() {
    setState(() {
      _image = null;
      _resultText = null;
      _descController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Smart Scanner"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Image
          if (_image != null)
            Positioned.fill(child: Image.file(_image!, fit: BoxFit.cover))
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getModeIcon(),
                    color: Colors.white.withOpacity(0.3),
                    size: 100,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _getPromptText(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 18),
                  ),
                ],
              ),
            ),

          // 🔄 MODE SWITCHER (Top)
          if (_resultText == null && !_isAnalyzing)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  children: [
                    _ModeButton(
                      title: "Diet",
                      icon: Icons.restaurant,
                      isActive: _scanMode == 'diet',
                      onTap: () => setState(() => _scanMode = 'diet'),
                    ),
                    _ModeButton(
                      title: "Lab",
                      icon: Icons.description,
                      isActive: _scanMode == 'lab',
                      onTap: () => setState(() => _scanMode = 'lab'),
                    ),
                    _ModeButton(
                      title: "Scan", // X-Ray, MRI, etc.
                      icon: Icons.qr_code_scanner, // Or Icons.medical_services
                      isActive: _scanMode == 'scan',
                      onTap: () => setState(() => _scanMode = 'scan'),
                    ),
                  ],
                ),
              ),
            ),

          // 📄 RESULTS OVERLAY
          if (_resultText != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75),
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
                              _descController.text.isEmpty
                                  ? "Analysis Result"
                                  : _descController.text,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark),
                            ),
                          ),
                          IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: _reset)
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      // 🧹 CLEANED RESPONSE TEXT
                      Text(
                        _cleanResponse(_resultText!),
                        style: const TextStyle(
                            fontSize: 16, height: 1.5, color: Colors.black87),
                      ),

                      const SizedBox(height: 24),

                      // 👨‍⚕️ CONSULT DOCTOR BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors
                                .purple, // Distinct color for doctor action
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _consultDoctor,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Consult Mobile Doc about this"),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SCAN AGAIN
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text("Scan Another Item"),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

          // CAMERA CONTROLS
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
                    backgroundColor:
                        _scanMode == 'diet' ? Colors.green : AppColors.primary,
                    onPressed: () => _pickImage(ImageSource.camera),
                    child:
                        Icon(Icons.camera_alt, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),

          // LOADING OVERLAY
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      "Dr. Mobile Doc is analyzing...",
                      style: const TextStyle(
                          color: Colors.white,
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

  IconData _getModeIcon() {
    if (_scanMode == 'diet') return Icons.restaurant;
    if (_scanMode == 'lab') return Icons.description;
    return Icons.medical_services; // Scan/Xray
  }

  String _getPromptText() {
    if (_scanMode == 'diet') return 'Snap your meal';
    if (_scanMode == 'lab') return 'Snap lab report';
    return 'Snap X-Ray / CT';
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton(
      {required this.title,
      required this.icon,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: isActive ? AppColors.primary : Colors.white),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isActive ? AppColors.primary : Colors.white,
                ),
              ),
            ],
          ),
        ),
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
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
