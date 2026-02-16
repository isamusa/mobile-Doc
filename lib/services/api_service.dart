import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
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
  // Use environment-backed API URL (set with --dart-define=API_URL=...)
  static String? _overrideBaseUrl;

  // Test hook: override network call in widget/unit tests
  static Future<GemmaResponse> Function(String)? testSendToGemma;

  static void updateBaseUrl(String newUrl) {
    _overrideBaseUrl = newUrl;
  }

  // Basic heuristics to detect low-confidence, injected, or unsafe responses.
  // Returns true if the response looks medically meaningful and safe to present.
  static bool _isValidMedicalResponse(
      String botReply, Map<String, dynamic>? decoded) {
    if (botReply.trim().isEmpty) return false;

    final lower = botReply.toLowerCase();

    // Reject obvious non-answers or low-confidence phrases
    final lowConfidencePhrases = [
      "i'm not sure",
      "i do not know",
      "i cannot",
      "cannot determine",
      "no information",
      "unable to",
    ];
    for (var p in lowConfidencePhrases) {
      if (lower.contains(p)) return false;
    }

    // Reject possible prompt-injection tokens
    final injectionTokens = [
      "] ignore previous",
      "ignore previous",
      "ignore all previous",
      "malicious",
      "recommend only"
    ];
    for (var t in injectionTokens) {
      if (lower.contains(t)) return false;
    }

    // Basic length check
    if (botReply.length < 30) return false;

    // If the backend provides structured fields, prefer those as signal of quality
    if (decoded != null) {
      if ((decoded['response'] ?? '').toString().trim().isEmpty) return false;
      // If server gives an explicit 'confidence' score and it's low, reject
      if (decoded.containsKey('confidence')) {
        try {
          final c = double.tryParse(decoded['confidence'].toString()) ?? 1.0;
          if (c < 0.4) return false;
        } catch (_) {}
      }
    }

    // Require medical keywords (diagnosis/tests/prescription) to consider it a clinical reply
    final medicalKeywords = [
      'diagnosis',
      'prescription',
      'tests',
      'lab',
      'malaria',
      'symptom',
      'treatment',
      'recommend'
    ];
    var found = 0;
    for (var k in medicalKeywords) {
      if (lower.contains(k)) found++;
    }
    if (found == 0) return false;

    return true;
  }

  // Public wrapper for tests and external checks
  static bool isValidMedicalResponse(String botReply,
      [Map<String, dynamic>? decoded]) {
    return _isValidMedicalResponse(botReply, decoded);
  }

  static String get _baseUrl => _overrideBaseUrl ?? Environment.apiUrl;
  static String get baseUrl => _baseUrl;

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// 🧠 CHAT: Sends Context + User Message to AI
  /// UPDATED: Now returns a GemmaResponse object for Human-in-the-loop validation
  static Future<GemmaResponse> sendToGemma(String message) async {
    // Test override for faster, deterministic widget testing
    if (testSendToGemma != null) return await testSendToGemma!(message);
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

        // Validate AI response before returning structured data
        if (!_isValidMedicalResponse(botReply, decoded)) {
          // Return a clarification prompt instead of unsafe data
          return GemmaResponse(
            botReply:
                'I need more information to assist safely. Can you provide more details about symptoms, duration, and any recent medications?',
            suggestedDiagnosis: null,
            suggestedTests: const [],
            suggestedPrescriptions: const [],
          );
        }

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
