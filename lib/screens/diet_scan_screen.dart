import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 🎨 For better result rendering
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';
import 'chat_screen.dart';

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
        hint = "e.g. Chest X-Ray, CT Scan";
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
        title: Text(title,
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _descController,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
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

    String description =
        _descController.text.isEmpty ? "Medical Scan" : _descController.text;
    setState(() => _isAnalyzing = true);

    try {
      // 1. Vision Analysis using Med-Gemma 4B
      final response =
          await ApiService.analyzeImage(_image!, description, mode: _scanMode);

      // 2. Data Processing (Non-prescriptive)
      if (_scanMode == 'diet') {
        _handleDietResult(description, response);
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
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _handleDietResult(String foodName, String text) async {
    String calories = "Unknown";
    final calorieRegex =
        RegExp(r'(\d+)\s*(?:kcal|calories)', caseSensitive: false);
    final match = calorieRegex.firstMatch(text);
    if (match != null) calories = "${match.group(1)} kcal";

    // Save to local history - non-clinical data is safe to auto-save
    await PatientDataService.addDietScan(foodName, calories);
  }

  // 🚀 UPDATED BRIDGE: Hands off to ChatScreen with structured prompt
  void _consultDoctor() {
    if (_resultText == null) return;

    String typeLabel = _scanMode == 'diet'
        ? "meal"
        : (_scanMode == 'lab' ? "lab report" : "medical scan");

    // Constructing a prompt that forces the Chat AI to reference the Vision result
    String initialMessage = """
I've scanned a $typeLabel (${_descController.text}). 
The analysis says: "$_resultText". 

Based on my medical history, what are the next steps I should take?
""";

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
        title: const Text("Smart Scanner",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. Image Preview
          if (_image != null)
            Positioned.fill(child: Image.file(_image!, fit: BoxFit.cover))
          else
            _buildPlaceholder(),

          // 2. Mode Switcher
          if (_resultText == null && !_isAnalyzing) _buildModeSwitcher(),

          // 3. Results Sheet
          if (_resultText != null) _buildResultsOverlay(),

          // 4. Capture Controls
          if (_resultText == null && !_isAnalyzing) _buildCaptureControls(),

          // 5. Loading State
          if (_isAnalyzing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildResultsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      _descController.text.isEmpty
                          ? "Analysis"
                          : _descController.text,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  IconButton(icon: const Icon(Icons.close), onPressed: _reset),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              MarkdownBody(
                data: _resultText!,
                styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        fontSize: 15, height: 1.5, color: Colors.black87)),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _consultDoctor,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Consult Dr. Mobile Doc",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                  child: TextButton(
                      onPressed: _reset,
                      child: const Text("Scan Something Else"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
              icon: Icons.photo_library,
              label: "Library",
              onTap: () => _pickImage(ImageSource.gallery)),
          FloatingActionButton.large(
            backgroundColor:
                _scanMode == 'diet' ? Colors.green : AppColors.primary,
            onPressed: () => _pickImage(ImageSource.camera),
            child: const Icon(Icons.camera_alt, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 60), // Spacer
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            _ModeButton(
                title: "Diet",
                icon: Icons.restaurant,
                isActive: _scanMode == 'diet',
                onTap: () => setState(() => _scanMode = 'diet')),
            _ModeButton(
                title: "Lab",
                icon: Icons.description,
                isActive: _scanMode == 'lab',
                onTap: () => setState(() => _scanMode = 'lab')),
            _ModeButton(
                title: "Scan",
                icon: Icons.biotech,
                isActive: _scanMode == 'scan',
                onTap: () => setState(() => _scanMode = 'scan')),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_scanMode == 'diet' ? Icons.restaurant : Icons.medical_services,
              color: Colors.white12, size: 100),
          const SizedBox(height: 20),
          Text("Align your $_scanMode here",
              style: const TextStyle(color: Colors.white38, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text("Dr. Mobile Doc is analyzing...",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
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
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
