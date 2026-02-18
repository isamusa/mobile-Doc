import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/patient_data_service.dart';
import '../services/secure_storage_helper.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onChatTap;
  final VoidCallback onDietTap;

  const HomeScreen(
      {super.key, required this.onChatTap, required this.onDietTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _patientName = "User";
  Map<String, dynamic>? _profile;
  List<String> _pendingTests = [];
  String _medicationReminder = "No active medications.";
  String _healthInsight = "Stay hydrated today.";
  bool _hasPrescriptions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // 🛡️ SECURITY: Decrypt data for UI display
  String _decryptData(String? encryptedText) {
    if (encryptedText == null ||
        encryptedText.isEmpty ||
        encryptedText == 'Unknown' ||
        encryptedText == 'None') {
      return encryptedText ?? '--';
    }
    try {
      return utf8.decode(base64Decode(encryptedText));
    } catch (e) {
      // Fallback in case of legacy unencrypted data
      return encryptedText;
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    // 1. Load Profile and Context (Context is already decrypted by the service)
    final contextStr = await PatientDataService.getContextString();

    // 2. Fetch the FULL encrypted profile from Secure Storage
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
    final securedData =
        await SecureStorageHelper.read('patient_profile_$userId');

    Map<String, dynamic>? profileMap;
    if (securedData != null && securedData.isNotEmpty) {
      profileMap = jsonDecode(securedData);
    } else {
      // Fallback to shared preferences if secure storage is empty
      final prefs = await SharedPreferences.getInstance();
      final profileData = prefs.getString('patient_profile');
      if (profileData != null) {
        profileMap = jsonDecode(profileData);
      }
    }

    // 3. Load Pending AI Suggestions (Human-in-the-Loop logic)
    final tests = await PatientDataService.getPendingTests();
    final meds = await PatientDataService.getPrescriptions();

    String name = "User";
    if (contextStr.contains("- Name: ")) {
      final start = contextStr.indexOf("- Name: ") + 8;
      final end = contextStr.indexOf("\n", start);
      if (end != -1) name = contextStr.substring(start, end).trim();
    }

    // 4. Logic for Insights & Reminders
    String medText = "No active medications.";
    String insight = "Great job keeping healthy!";
    bool hasMeds = meds.isNotEmpty;

    if (hasMeds) {
      medText = "Next dose: ${meds.first.split('-')[0].trim()}";
      insight = "Complete your full course as advised.";
    } else if (contextStr.contains("Malaria")) {
      insight = "Ensure you sleep under a treated net tonight.";
    }

    if (mounted) {
      setState(() {
        _patientName = name;
        _profile = profileMap;
        _pendingTests = tests;
        _medicationReminder = medText;
        _healthInsight = insight;
        _hasPrescriptions = hasMeds;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? "Good Morning,"
        : hour < 17
            ? "Good Afternoon,"
            : "Good Evening,";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(greeting),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHealthSnapshot(),
                        const SizedBox(height: 24),
                        if (_pendingTests.isNotEmpty) _buildPendingActions(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildInsights(),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar(String greeting) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textLight)),
            Text(_patientName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.textDark),
          onPressed: _loadDashboardData,
        ),
        _buildNotificationIcon(),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: AppColors.textDark),
          onPressed: () {},
        ),
        if (_hasPrescriptions || _pendingTests.isNotEmpty)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  Widget _buildHealthSnapshot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Health Snapshot",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 🔓 Applying Decryption to the raw profile map values
                _buildVitalMetric("Height", _decryptData(_profile?['height']),
                    "cm", Icons.height, Colors.blue),
                _buildVitalMetric("Weight", _decryptData(_profile?['weight']),
                    "kg", Icons.monitor_weight, Colors.orange),
                _buildVitalMetric("Age", _decryptData(_profile?['age']), "yrs",
                    Icons.calendar_today, Colors.green),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalMetric(
      String label, String value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text("$label ($unit)",
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPendingActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Pending AI Suggestions",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange)),
        const SizedBox(height: 12),
        ..._pendingTests.map((test) => Card(
              color: Colors.orange.shade50,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade100)),
              child: ListTile(
                leading: const Icon(Icons.science, color: Colors.orange),
                title: Text(test,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    "AI suggested this test based on your symptoms.",
                    style: TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.orange),
                  onPressed: () async {
                    await PatientDataService.removePendingTest(test);
                    _loadDashboardData();
                  },
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _ActionSquare(
                icon: Icons.chat_bubble_rounded,
                label: "Ask AI Doc",
                color: Colors.blue,
                onTap: widget.onChatTap),
            _ActionSquare(
                icon: Icons.fastfood_rounded,
                label: "Scan Diet",
                color: Colors.green,
                onTap: widget.onDietTap),
            _ActionSquare(
                icon: Icons.history_rounded,
                label: "Med History",
                color: Colors.purple,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileScreen()))),
          ],
        ),
      ],
    );
  }

  Widget _buildInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Daily Insights",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _InsightCard(
          title: "Medication",
          desc: _medicationReminder,
          icon: Icons.medication_liquid,
          color: _hasPrescriptions ? Colors.red : Colors.grey,
        ),
        const SizedBox(height: 8),
        _InsightCard(
          title: "Doctor's Tip",
          desc: _healthInsight,
          icon: Icons.tips_and_updates,
          color: Colors.amber,
        ),
      ],
    );
  }
}

class _ActionSquare extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionSquare(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _InsightCard(
      {required this.title,
      required this.desc,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
