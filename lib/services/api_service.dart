import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'patient_data_service.dart';

class ApiService {
  // 🔴 ENSURE THIS MATCHES YOUR NGROK URL
  static const String _baseUrl =
      'https://choice-peacock-presently.ngrok-free.app';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// 🧠 CHAT: Sends Context + User Message to AI
  static Future<String> sendToGemma(String message) async {
    try {
      String medicalContext = await PatientDataService.getContextString();
      print("🚀 Context Sent: $medicalContext");

      String fullPrompt =
          "[SYSTEM CONTEXT: $medicalContext] \n USER SAYS: $message";

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: _headers,
            body: jsonEncode({'user_text': fullPrompt}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String botReply = decoded['response'];

        // --- SMART DATA SAVING (Diagnosis, Tests, Meds) ---
        // 1. Diagnosis
        if (botReply.contains("Diagnosis:") || botReply.contains("likely")) {
          String diagnosisSummary = botReply.split('\n').firstWhere(
              (line) => line.contains("Diagnosis") || line.contains("likely"),
              orElse: () => "Consultation");
          await PatientDataService.addDiagnosis(diagnosisSummary);
        }

        // 2. Lab Tests
        List<dynamic> tests = decoded['suggested_tests'] ?? [];
        if (tests.isNotEmpty) {
          for (var test in tests) {
            await PatientDataService.addPendingTest(test.toString());
          }
        } else if (botReply.contains("**Tests:**") ||
            botReply.contains("Test:")) {
          if (botReply.contains("MP"))
            await PatientDataService.addPendingTest("Malaria Parasite (MP)");
          if (botReply.contains("Widal"))
            await PatientDataService.addPendingTest("Widal Reaction Test");
          if (botReply.contains("FBC"))
            await PatientDataService.addPendingTest("Full Blood Count (FBC)");
        }

        // 3. Prescriptions
        if (botReply.contains("Prescription:") || botReply.contains("Plan:")) {
          final lines = botReply.split('\n');
          bool inPrescriptionBlock = false;
          for (var line in lines) {
            if (line.contains("Prescription:") || line.contains("Plan:")) {
              inPrescriptionBlock = true;
              continue;
            }
            if (inPrescriptionBlock) {
              if (line.trim().isEmpty ||
                  line.contains("Tests:") ||
                  line.contains("Diagnosis:")) {
                inPrescriptionBlock = false;
              } else if (RegExp(r'^\d+\.|-').hasMatch(line.trim())) {
                await PatientDataService.addPrescription(
                    line.replaceAll(RegExp(r'^\d+\.|-'), '').trim(),
                    "As advised");
              }
            }
          }
        }
        // --------------------------------------------------

        return botReply;
      }
      return 'Server Error: ${response.statusCode}';
    } catch (e) {
      return 'Connection Failed. Is Dr. Gemma online?';
    }
  }

  /// 👁️ VISION: Analyze Image (Diet, Lab, General)
  /// [mode] can be 'diet', 'lab', or 'general'
  static Future<String> analyzeImage(File imageFile, String description,
      {String mode = 'general'}) async {
    try {
      String medicalContext = await PatientDataService.getContextString();

      var request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze_image'));
      request.headers.addAll(_headers);

      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      // 1. Send Description with Context
      request.fields['description'] = "$description. ($medicalContext)";

      // 2. Send Mode (Crucial for Backend Prompt Selection)
      request.fields['mode'] = mode;

      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['response'];
      }
      return 'Upload Failed: ${response.statusCode}';
    } catch (e) {
      return 'Error uploading image: $e';
    }
  }
}
