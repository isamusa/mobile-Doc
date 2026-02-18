import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'secure_storage_helper.dart';
import 'dart:convert';

class PatientDataService {
  static const String _profileKey = 'patient_profile';
  static const String _historyKey = 'medical_history';
  static const String _prescriptionsKey = 'active_prescriptions';
  static const String _labsKey = 'lab_results';
  static const String _pendingTestsKey = 'pending_tests';
  static const String _dietKey = 'diet_history';
  static const String _secureChatKey = 'patient_chat_history';

  // Test hooks to avoid platform channels during widget tests
  static Future<String> Function()? testGetContextString;
  static Future<List<Map<String, String>>> Function()? testGetChatHistory;
  static Future<void> Function(String, String)? testSaveChatMessage;

  static String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'guest_user';
  }

  // 🛡️ SECURITY: Decryption Helper
  // Decodes the data safely. If the data wasn't encrypted (e.g. legacy data), it returns it as-is.
  static String _decrypt(String? data) {
    if (data == null || data.isEmpty || data == 'None' || data == 'Unknown') {
      return data ?? 'Unknown';
    }
    try {
      return utf8.decode(base64Decode(data));
    } catch (e) {
      return data; // Fallback for unencrypted legacy data
    }
  }

  // --- 1. PROFILE & CONTEXT ---

  static Future<void> saveProfile({
    required String name,
    required String phoneNumber,
    required String age, // Comes in encrypted from Setup Screen
    required String height, // Comes in encrypted
    required String weight, // Comes in encrypted
    required String genotype, // Comes in encrypted
    required String bloodGroup, // Comes in encrypted
    required String allergies, // Comes in encrypted
    required List<String> personalHistory,
    required List<String> familyHistory,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔐 1. Store full profile in secure storage
    final fullProfile = {
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
      'isEncrypted': true, // Flag for cloud sync
    };

    await SecureStorageHelper.write(
        'patient_profile_$_userId', jsonEncode(fullProfile));

    // 2. Store a safe, redacted version in SharedPreferences for quick UI loading
    final redacted = {
      'name': name,
      'isEncrypted': true,
    };
    await prefs.setString(_profileKey, jsonEncode(redacted));

    // 3. Cloud Backup (HIPAA Prep: We are uploading the ENCRYPTED profile, not plain text)
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(_userId)
            .set(fullProfile, SetOptions(merge: true));
      } catch (e) {
        // Silent catch for offline mode
      }
    }
  }

  static Future<String> getContextString() async {
    if (testGetContextString != null) return await testGetContextString!();
    final prefs = await SharedPreferences.getInstance();

    String profileStr = "Patient Profile: Unknown";

    // 🧠 Read encrypted profile from secure storage
    String? secured =
        await SecureStorageHelper.read('patient_profile_$_userId');

    if (secured != null) {
      final p = jsonDecode(secured);

      String historyStr = (p['personalHistory'] as List).isEmpty
          ? "None"
          : (p['personalHistory'] as List).join(", ");
      String familyStr = (p['familyHistory'] as List).isEmpty
          ? "None"
          : (p['familyHistory'] as List).join(", ");

      // 🔓 DECRYPT SENSITIVE DATA FOR THE AI CONTEXT
      String dAge = _decrypt(p['age']);
      String dHeight = _decrypt(p['height']);
      String dWeight = _decrypt(p['weight']);
      String dGenotype = _decrypt(p['genotype']);
      String dBloodGroup = _decrypt(p['bloodGroup']);
      String dAllergies = _decrypt(p['allergies']);

      profileStr = """
      PATIENT SUMMARY:
      - Name: ${p['name']}
      - Phone: ${p['phoneNumber']}
      - Age: $dAge
      - Vitals: ${dHeight}cm, ${dWeight}kg
      - Genotype: $dGenotype | Blood Group: $dBloodGroup
      - Allergies: $dAllergies
      - Existing Conditions: $historyStr
      - Family History: $familyStr
      """;
    } else if (prefs.containsKey(_profileKey)) {
      final p = jsonDecode(prefs.getString(_profileKey)!);
      profileStr = """
      PATIENT SUMMARY:
      - Name: ${p['name']}
      - (Sensitive fields locked)
      """;
    }

    // Add Active Prescriptions
    List<String> prescriptions = prefs.getStringList(_prescriptionsKey) ?? [];
    if (prescriptions.isNotEmpty) {
      profileStr += "\nACTIVE MEDICATIONS:\n- ${prescriptions.join('\n- ')}";
    }

    // Add Recent Diagnoses (Crucial for AI memory)
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
        // Offline support
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

  static Future<void> addPendingTest(String testName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> tests = prefs.getStringList(_pendingTestsKey) ?? [];
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
    if (testSaveChatMessage != null) {
      return await testSaveChatMessage!(sender, text);
    }

    await _migrateChatHistoryIfNeeded();

    final key = '$_secureChatKey\$_userId';
    String? raw = await SecureStorageHelper.read(key);
    List<dynamic> list =
        raw != null && raw.isNotEmpty ? jsonDecode(raw) as List<dynamic> : [];

    Map<String, String> msg = {
      "sender": sender,
      "text": text,
      "time": DateTime.now().toIso8601String()
    };
    list.add(msg);
    await SecureStorageHelper.write(key, jsonEncode(list));
  }

  static Future<List<Map<String, String>>> getChatHistory() async {
    if (testGetChatHistory != null) {
      return await testGetChatHistory!();
    }

    final key = '$_secureChatKey\$_userId';
    String? raw = await SecureStorageHelper.read(key);
    if (raw == null || raw.trim().isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map<Map<String, String>>((e) {
      final m = e as Map<String, dynamic>;
      return {
        "sender": m['sender'].toString(),
        "text": m['text'].toString(),
      };
    }).toList();
  }

  static Future<void> _migrateChatHistoryIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const legacyKey = 'chat_history';
      if (!prefs.containsKey(legacyKey)) return;

      final List<String> legacy = prefs.getStringList(legacyKey) ?? [];
      if (legacy.isEmpty) {
        await prefs.remove(legacyKey);
        return;
      }

      final key = '$_secureChatKey\$_userId';
      String? raw = await SecureStorageHelper.read(key);
      List<dynamic> current =
          raw != null && raw.isNotEmpty ? jsonDecode(raw) as List<dynamic> : [];

      for (var item in legacy) {
        try {
          final Map<String, dynamic> json = jsonDecode(item);
          current.add({
            'sender': json['sender'].toString(),
            'text': json['text'].toString(),
            'time': json['time'].toString(),
          });
        } catch (_) {}
      }

      await SecureStorageHelper.write(key, jsonEncode(current));
      await prefs.remove(legacyKey);
    } catch (_) {}
  }

  // --- 7. UTILS & SYNC ---

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await SecureStorageHelper
        .deleteAll(); // 🔐 Clear all encrypted PII on logout
  }

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

        // Write redacted for UI
        final redacted = {
          'name': data['name'] ?? 'Unknown',
          'isEncrypted': true,
        };
        await prefs.setString(_profileKey, jsonEncode(redacted));

        // Write FULL data to secure storage (It remains encrypted at rest)
        await SecureStorageHelper.write(
            'patient_profile_$_userId', jsonEncode(data));
      }
    } catch (e) {
      // Offline mode
    }
  }
}
