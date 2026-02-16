import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'patient_data_service.dart';

/// Structured response to handle Clinical Safety validation in the UI
class GemmaResponse {
  final String botReply;
  final String? suggestedDiagnosis;
  final List<String> suggestedTests;
  final List<String> suggestedPrescriptions;

  GemmaResponse({
    required this.botReply,
    this.suggestedDiagnosis,
    this.suggestedTests = const [],
    this.suggestedPrescriptions = const [],
  });
}

class ApiService {
  // 🔴 ENSURE THIS MATCHES YOUR NGROK URL
  static String _baseUrl = 'https://choice-peacock-presently.ngrok-free.app';
  static String get baseUrl => _baseUrl;

  static void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// 🧠 CHAT: Sends Context + User Message to AI
  /// UPDATED: Now returns a GemmaResponse object for Human-in-the-loop validation
  static Future<GemmaResponse> sendToGemma(String message) async {
    try {
      String medicalContext = await PatientDataService.getContextString();
      String fullPrompt =
          "[SYSTEM CONTEXT: $medicalContext] \n USER SAYS: $message";

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: _headers,
            body: jsonEncode({'user_text': fullPrompt}),
          )
          .timeout(const Duration(seconds: 45)); // Handling Kaggle cold starts

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String botReply = decoded['response'];

        // --- DRAFT DATA PARSING (For UI Confirmation) ---
        String? diagnosis;
        List<String> tests = [];
        List<String> prescriptions = [];

        // 1. Extract Diagnosis Draft
        if (botReply.contains("Diagnosis:") || botReply.contains("likely")) {
          diagnosis = botReply.split('\n').firstWhere(
              (line) => line.contains("Diagnosis") || line.contains("likely"),
              orElse: () => "Consultation");
        }

        // 2. Extract Lab Test Drafts
        List<dynamic> serverTests = decoded['suggested_tests'] ?? [];
        if (serverTests.isNotEmpty) {
          tests.addAll(serverTests.map((e) => e.toString()));
        } else if (botReply.contains("**Tests:**") ||
            botReply.contains("Test:")) {
          if (botReply.contains("MP")) tests.add("Malaria Parasite (MP)");
          if (botReply.contains("Widal")) tests.add("Widal Reaction Test");
          if (botReply.contains("FBC")) tests.add("Full Blood Count (FBC)");
        }

        // 3. Extract Prescription Drafts
        if (botReply.contains("Prescription:") || botReply.contains("Plan:")) {
          final lines = botReply.split('\n');
          bool inBlock = false;
          for (var line in lines) {
            if (line.contains("Prescription:") || line.contains("Plan:")) {
              inBlock = true;
              continue;
            }
            if (inBlock) {
              if (line.trim().isEmpty ||
                  line.contains("Tests:") ||
                  line.contains("Diagnosis:")) {
                inBlock = false;
              } else if (RegExp(r'^\d+\.|-').hasMatch(line.trim())) {
                prescriptions
                    .add(line.replaceAll(RegExp(r'^\d+\.|-'), '').trim());
              }
            }
          }
        }

        return GemmaResponse(
          botReply: botReply,
          suggestedDiagnosis: diagnosis,
          suggestedTests: tests,
          suggestedPrescriptions: prescriptions,
        );
      }
      throw Exception('Server Error: ${response.statusCode}');
    } catch (e) {
      return GemmaResponse(botReply: 'Connection Failed. Is Dr. Gemma online?');
    }
  }

  /// 👁️ VISION: Analyze Image (Diet, Lab, General)
  static Future<String> analyzeImage(File imageFile, String description,
      {String mode = 'general'}) async {
    try {
      String medicalContext = await PatientDataService.getContextString();

      var request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze_image'));
      request.headers.addAll(_headers);
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      request.fields['description'] = "$description. ($medicalContext)";
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
