import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class PatientDataService {
  static const String _profileKey = 'patient_profile';
  static const String _historyKey = 'medical_history';
  static const String _prescriptionsKey = 'active_prescriptions';
  static const String _labsKey = 'lab_results';
  static const String _pendingTestsKey =
      'pending_tests'; // New key for AI-suggested tests
  static const String _dietKey = 'diet_history';
  static const String _chatKey = 'chat_history';

  static String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'guest_user';
  }

  // --- 1. PROFILE & CONTEXT ---

  static Future<void> saveProfile({
    required String name,
    required String phoneNumber,
    required String age,
    required String height,
    required String weight,
    required String genotype,
    required String bloodGroup,
    required String allergies,
    required List<String> personalHistory,
    required List<String> familyHistory,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = {
      'name': name,
      'phoneNumber': phoneNumber,
      'age': age,
      'height': height,
      'weight': weight,
      'genotype': genotype,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'personalHistory': personalHistory,
      'familyHistory': familyHistory,
    };
    await prefs.setString(_profileKey, jsonEncode(profile));

    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(_userId)
            .set(profile, SetOptions(merge: true));
      } catch (e) {
        print("⚠️ Cloud Backup Failed: $e");
      }
    }
  }

  static Future<String> getContextString() async {
    final prefs = await SharedPreferences.getInstance();

    String profileStr = "Patient Profile: Unknown";
    if (prefs.containsKey(_profileKey)) {
      final p = jsonDecode(prefs.getString(_profileKey)!);

      String historyStr = (p['personalHistory'] as List).isEmpty
          ? "None"
          : (p['personalHistory'] as List).join(", ");
      String familyStr = (p['familyHistory'] as List).isEmpty
          ? "None"
          : (p['familyHistory'] as List).join(", ");

      profileStr = """
      PATIENT SUMMARY:
      - Name: ${p['name']}
      - Phone: ${p['phoneNumber']}
      - Age: ${p['age']}
      - Vitals: ${p['height']}cm, ${p['weight']}kg
      - Genotype: ${p['genotype']} | Blood Group: ${p['bloodGroup']}
      - Allergies: ${p['allergies']}
      - Existing Conditions: $historyStr
      - Family History: $familyStr
      """;
    }

    // Add Active Prescriptions to Context
    List<String> prescriptions = prefs.getStringList(_prescriptionsKey) ?? [];
    if (prescriptions.isNotEmpty) {
      profileStr += "\nACTIVE MEDICATIONS:\n- ${prescriptions.join('\n- ')}";
    }

    List<String> diagnosishistory = prefs.getStringList(_historyKey) ?? [];
    String recentDiagnoses = "";
    if (diagnosishistory.isNotEmpty) {
      final recent = diagnosishistory.reversed.take(3).toList();
      recentDiagnoses = "RECENT CONSULTATIONS: ${recent.join('; ')}";
    }

    return "$profileStr \n $recentDiagnoses";
  }

  // --- 2. DIAGNOSIS HISTORY ---

  static Future<void> addDiagnosis(String diagnosis) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    String entry = "${DateTime.now().toString().split(' ')[0]}: $diagnosis";
    history.add(entry);
    await prefs.setStringList(_historyKey, history);

    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(_userId)
            .collection('history')
            .add({
          'diagnosis': diagnosis,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("⚠️ Cloud Sync Failed: $e");
      }
    }
  }

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  // --- 3. PRESCRIPTIONS ---

  static Future<void> addPrescription(String medication, String dosage) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> meds = prefs.getStringList(_prescriptionsKey) ?? [];
    meds.add("$medication - $dosage");
    await prefs.setStringList(_prescriptionsKey, meds);
  }

  static Future<List<String>> getPrescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prescriptionsKey) ?? [];
  }

  static Future<void> removePrescription(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> meds = prefs.getStringList(_prescriptionsKey) ?? [];
    if (index < meds.length) {
      meds.removeAt(index);
      await prefs.setStringList(_prescriptionsKey, meds);
    }
  }

  // --- 4. LAB RESULTS & PENDING TESTS ---

  static Future<void> addLabResult(String testName, String result) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> labs = prefs.getStringList(_labsKey) ?? [];
    labs.add(
        "${DateTime.now().toString().split(' ')[0]}: $testName - Result: $result");
    await prefs.setStringList(_labsKey, labs);
  }

  static Future<List<String>> getLabResults() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_labsKey) ?? [];
  }

  // New Methods for AI Suggested Tests (For generating Slips)
  static Future<void> addPendingTest(String testName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> tests = prefs.getStringList(_pendingTestsKey) ?? [];

    // Avoid duplicates
    if (!tests.contains(testName)) {
      tests.add(testName);
      await prefs.setStringList(_pendingTestsKey, tests);
    }
  }

  static Future<List<String>> getPendingTests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pendingTestsKey) ?? [];
  }

  static Future<void> removePendingTest(String testName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> tests = prefs.getStringList(_pendingTestsKey) ?? [];
    tests.remove(testName);
    await prefs.setStringList(_pendingTestsKey, tests);
  }

  static Future<void> clearPendingTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTestsKey);
  }

  // --- 5. DIET HISTORY ---

  static Future<void> addDietScan(String foodName, String calories) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> diet = prefs.getStringList(_dietKey) ?? [];
    diet.add(
        "${DateTime.now().toString().split(' ')[0]}: $foodName ($calories)");
    await prefs.setStringList(_dietKey, diet);
  }

  static Future<List<String>> getDietHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_dietKey) ?? [];
  }

  // --- 6. CHAT HISTORY ---

  static Future<void> saveChatMessage(String sender, String text) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> chats = prefs.getStringList(_chatKey) ?? [];

    // Store as JSON string: {"sender": "user", "text": "Hi", "time": "..."}
    Map<String, String> msg = {
      "sender": sender,
      "text": text,
      "time": DateTime.now().toIso8601String()
    };
    chats.add(jsonEncode(msg));
    await prefs.setStringList(_chatKey, chats);

    // Sync to Cloud
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(_userId)
            .collection('chats')
            .add({
          ...msg,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("⚠️ Cloud Chat Sync Failed: $e");
      }
    }
  }

  static Future<List<Map<String, String>>> getChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawChats = prefs.getStringList(_chatKey) ?? [];

    return rawChats.map((str) {
      Map<String, dynamic> json = jsonDecode(str);
      return {
        "sender": json['sender'].toString(),
        "text": json['text'].toString(),
      };
    }).toList();
  }

  // --- 7. UTILS ---

  static Future<void> restoreFromCloud() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_profileKey, jsonEncode(data));
        print("✅ Restored Profile from Cloud");
      }
      // Note: Restoring full chat history from Firestore might be heavy,
      // typically we rely on local cache or implement pagination.
    } catch (e) {
      print("❌ Restore Failed: $e");
    }
  }

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
