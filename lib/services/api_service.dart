import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://719be037537e.ngrok-free.app";

  static const bool useMockData = true;

  // CHAT FUNCTION
  static Future<String> sendChatMessage(String message) async {
    if (useMockData) {
      await Future.delayed(const Duration(seconds: 1));
      return "Mock AI: I heard you say '$message'. Please visit a clinic.";
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_text": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        return "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection Error. Is the Python backend running?";
    }
  }

  // IMAGE FUNCTION (Updated to accept description)
  static Future<String> analyzeFoodImage(File imageFile,
      {String? userDescription}) async {
    // MOCK DATA LOGIC
    if (useMockData) {
      await Future.delayed(const Duration(seconds: 2));

      // If the user typed something, we include it in the fake response
      String foodName = userDescription != null && userDescription.isNotEmpty
          ? userDescription
          : "Pounded Yam (Detected)";

      return "Analysis for: $foodName\n\n⚠️ Nutritional Info: High carbohydrate density.\nAdvice: Since you are managing weight, limit to half portion and add more vegetable soup.";
    }

    // REAL BACKEND LOGIC
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze_image'));

      // Add the image
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      // Add the text description if it exists
      if (userDescription != null && userDescription.isNotEmpty) {
        request.fields['description'] = userDescription;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        return "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection Error. Is the Python backend running?";
    }
  }
}
