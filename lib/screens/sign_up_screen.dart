import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔴 Import
import '../theme/app_theme.dart';
import '../services/patient_data_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // Account Details
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Basic Medical
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  // Dropdowns
  String _genotype = 'AA';
  String _bloodGroup = 'O+';
  final _allergiesCtrl = TextEditingController();

  // Checklists
  final Map<String, bool> _personalHistory = {
    'Hypertension': false,
    'Diabetes': false,
    'Ulcer': false,
    'Asthma': false,
    'Sickle Cell Disease': false,
  };

  final Map<String, bool> _familyHistory = {
    'Hypertension': false,
    'Diabetes': false,
    'Heart Disease': false,
    'Cancer': false,
  };

  bool _obscurePassword = true;
  bool _isSaving = false;

  // Helper to fake email
  String _emailFromPhone(String phone) => "$phone@mobiledoc.com";

  void _saveData() async {
    if (_nameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in Name, Phone, and Password')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Create User in Firebase Auth
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailFromPhone(_phoneCtrl.text.trim()),
        password: _passwordCtrl.text,
      );

      // 2. Prepare Data Lists
      List<String> personalDiseases = _personalHistory.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      List<String> familyDiseases = _familyHistory.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      // 3. Save Profile to DB (Now using the new Auth UID inside the service)
      await PatientDataService.saveProfile(
        name: _nameCtrl.text,
        phoneNumber: _phoneCtrl.text,
        age: _ageCtrl.text,
        height: _heightCtrl.text,
        weight: _weightCtrl.text,
        genotype: _genotype,
        bloodGroup: _bloodGroup,
        allergies: _allergiesCtrl.text.isEmpty ? 'None' : _allergiesCtrl.text,
        personalHistory: personalDiseases,
        familyHistory: familyDiseases,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account Created! Welcome to Mobile Doc.')),
        );
        // Navigate to Main App directly after registration
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Registration Failed";
      if (e.code == 'weak-password') {
        msg = "The password provided is too weak.";
      } else if (e.code == 'email-already-in-use') {
        msg = "An account already exists for this phone number.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              const Text("Let's get you set up.",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const Text("Your health data helps the AI Doctor assist you.",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _buildSectionHeader("Account Information"),
              _buildTextField("Full Name", _nameCtrl, icon: Icons.person),
              const SizedBox(height: 12),
              _buildTextField("Phone Number", _phoneCtrl,
                  icon: Icons.phone, isNumber: true),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("Body Metrics"),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField("Age", _ageCtrl,
                          icon: Icons.calendar_today, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildDropdown(
                          "Genotype",
                          ['AA', 'AS', 'SS', 'AC'],
                          _genotype,
                          (v) => setState(() => _genotype = v!))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField("Height (cm)", _heightCtrl,
                          isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTextField("Weight (kg)", _weightCtrl,
                          isNumber: true)),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("Medical Profile"),
              Row(
                children: [
                  Expanded(
                      child: _buildDropdown(
                          "Blood Group",
                          ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                          _bloodGroup,
                          (v) => setState(() => _bloodGroup = v!))),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField("Allergies (Food/Drug)", _allergiesCtrl,
                  icon: Icons.warning_amber_rounded),
              const SizedBox(height: 24),
              _buildSectionHeader("Your Medical History"),
              ..._personalHistory.keys.map((key) => CheckboxListTile(
                    title: Text(key),
                    value: _personalHistory[key],
                    activeColor: AppColors.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) =>
                        setState(() => _personalHistory[key] = val!),
                  )),
              const SizedBox(height: 24),
              _buildSectionHeader("Family History"),
              ..._familyHistory.keys.map((key) => CheckboxListTile(
                    title: Text(key),
                    value: _familyHistory[key],
                    activeColor: AppColors.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) =>
                        setState(() => _familyHistory[key] = val!),
                  )),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("Register & Save Profile",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const Divider(thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      {IconData? icon, bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String currentValue,
      ValueChanged<String?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          items: items.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
