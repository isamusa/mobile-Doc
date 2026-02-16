import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_doc/screens/chat_screen.dart';
import 'package:mobile_doc/services/api_service.dart';
import 'package:mobile_doc/services/patient_data_service.dart';

void main() {
  tearDown(() {
    ApiService.testSendToGemma = null;
    PatientDataService.testGetContextString = null;
    PatientDataService.testGetChatHistory = null;
    PatientDataService.testSaveChatMessage = null;
  });

  testWidgets('shows clarification dialog when API requests more info',
      (WidgetTester tester) async {
    // Arrange: provide deterministic test hooks
    PatientDataService.testGetContextString =
        () async => 'PATIENT SUMMARY:\n- Name: Test\n';
    PatientDataService.testGetChatHistory = () async => <Map<String, String>>[];
    PatientDataService.testSaveChatMessage = (sender, text) async {};

    ApiService.testSendToGemma = (message) async {
      return GemmaResponse(
        botReply:
            'I need more information to assist safely. Can you provide more details about symptoms, duration, and any recent medications?',
        suggestedDiagnosis: null,
        suggestedTests: const [],
        suggestedPrescriptions: const [],
      );
    };

    // Act: pump the ChatScreen
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));

    // Enter some text and tap send
    await tester.enterText(find.byType(TextField), 'I have a fever');
    await tester.tap(find.byIcon(Icons.send));

    // Allow animations and dialog to appear
    await tester.pumpAndSettle();

    // Assert: dialog is shown and contains the clarification text
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('More details needed'), findsOneWidget);
    expect(find.textContaining('I need more information'), findsWidgets);
  });
}
