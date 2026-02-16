import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';

/// Business logic for chat: separate from UI
class ChatProvider extends ChangeNotifier {
  List<Map<String, dynamic>> messages = [
    {
      'sender': 'bot',
      'text':
          'Sannu! I am Dr. Mobile Doc. I have your medical file. How are you feeling right now?',
      'metadata': null
    }
  ];

  bool isLoading = false;
  String patientContextSummary = "Loading Patient File...";

  // Load patient data on init
  Future<void> loadPatientData() async {
    try {
      String context = await PatientDataService.getContextString();
      String name = "Patient";
      if (context.contains("- Name: ")) {
        final start = context.indexOf("- Name: ") + 8;
        final end = context.indexOf("\n", start);
        if (end != -1) name = context.substring(start, end).trim();
      }

      final history = await PatientDataService.getChatHistory();

      patientContextSummary = "Medical File Active: $name";
      // Merge loaded history with initial message
      if (history.isNotEmpty) {
        messages = history.map((m) => {...m, 'metadata': null}).toList();
      }
      notifyListeners();
    } catch (e) {
      patientContextSummary = "Error loading patient file";
      notifyListeners();
    }
  }

  // Send message and handle response
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    messages.add({'sender': 'user', 'text': text, 'metadata': null});
    isLoading = true;
    notifyListeners();

    await PatientDataService.saveChatMessage('user', text);

    try {
      final GemmaResponse response = await ApiService.sendToGemma(text);

      // Check if response is a clarification request
      final bool isClarification = response.suggestedDiagnosis == null &&
          response.suggestedPrescriptions.isEmpty &&
          response.suggestedTests.isEmpty &&
          response.botReply.toLowerCase().contains('need more information');

      await PatientDataService.saveChatMessage('bot', response.botReply);

      messages.add({
        'sender': 'bot',
        'text': response.botReply,
        'metadata': isClarification ? null : response,
        'isClarification': isClarification,
      });
    } catch (e) {
      messages.add({
        'sender': 'bot',
        'text': 'Network error. Please try again.',
        'metadata': null,
      });
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Confirm and save medical actions
  Future<void> confirmAndSaveAction(GemmaResponse data) async {
    if (data.suggestedDiagnosis != null) {
      await PatientDataService.addDiagnosis(data.suggestedDiagnosis!);
    }
    for (var rx in data.suggestedPrescriptions) {
      await PatientDataService.addPrescription(rx, "Confirmed via AI");
    }
    notifyListeners();
  }
}
