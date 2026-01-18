import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/patient_data_service.dart';
import 'medical_screen.dart'; // Ensure this exists or point to ProfileScreen for history

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
  String _medicationReminder = "No active medications.";
  String _healthInsight = "Stay hydrated today.";
  bool _hasPrescriptions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // 1. Get Name from Profile
    final contextStr = await PatientDataService.getContextString();

    String name = "User";
    if (contextStr.contains("- Name: ")) {
      final start = contextStr.indexOf("- Name: ") + 8;
      final end = contextStr.indexOf("\n", start);
      if (end != -1) name = contextStr.substring(start, end).trim();
    }

    // 2. Get Prescriptions for Insights
    final meds = await PatientDataService.getPrescriptions();

    // 3. Logic for Insights
    String medText = "No active medications.";
    String insight = "Great job keeping healthy!";
    bool hasMeds = false;

    if (meds.isNotEmpty) {
      hasMeds = true;
      medText = "Time to take: ${meds.first.split('-')[0].trim()}";
      insight = "Adhere to your dosage for full recovery.";
    } else if (contextStr.contains("Malaria")) {
      insight = "Use a mosquito net tonight.";
    }

    if (mounted) {
      setState(() {
        _patientName = name;
        _medicationReminder = medText;
        _healthInsight = insight;
        _hasPrescriptions = hasMeds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine greeting based on time
    final hour = DateTime.now().hour;
    String greeting = "Good Morning,";
    if (hour >= 12 && hour < 17)
      greeting = "Good Afternoon,";
    else if (hour >= 17) greeting = "Good Evening,";

    return SafeArea(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 1,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                  Text(_patientName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textDark),
                  onPressed: _loadUserData,
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none,
                          color: AppColors.textDark),
                      onPressed: () {},
                    ),
                    if (_hasPrescriptions)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search symptoms, food, tips...',
                            prefixIcon: const Icon(Icons.search),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 64, maxWidth: 120),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          onPressed: () => widget.onChatTap(),
                          child: const FittedBox(child: Text('Ask AI')),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Metrics Row
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Status',
                            value: _hasPrescriptions ? 'Treatment' : 'Healthy',
                            icon: Icons.favorite,
                            color: _hasPrescriptions
                                ? Colors.orange
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: _MetricCard(
                            title: 'Calories',
                            value:
                                '1,850', // Placeholder for now, connect to Diet Service later
                            icon: Icons.local_fire_department,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quick Actions Grid
                    const Text('Quick Actions',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        _SquareAction(
                            icon: Icons.medical_services,
                            label: 'Symptom',
                            onTap: widget.onChatTap),
                        _SquareAction(
                            icon: Icons.camera_alt,
                            label: 'Diet Scan',
                            onTap: widget.onDietTap),

                        // Link to History / Medical Profile
                        _SquareAction(
                            icon: Icons.history,
                            label: 'History',
                            onTap: () {
                              // If MedicalScreen exists, navigate there, else fallback logic
                              // Assuming MedicalScreen or similar profile view is available
                              try {
                                Navigator.pushNamed(context,
                                    '/medical'); // or push MaterialPageRoute
                              } catch (e) {
                                // Fallback if route not defined
                              }
                            }),

                        _SquareAction(
                            icon: Icons.local_hospital,
                            label: 'Find Clinic',
                            onTap: () {}),
                        _SquareAction(
                            icon: Icons.insights,
                            label: 'Trends',
                            onTap: () {}),
                        _SquareAction(
                            icon: Icons.settings,
                            label: 'Settings',
                            onTap: () {}),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tips Carousel
                    const Text('Health Tips',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const [
                          _TipCard(
                              title: 'Stay Hydrated',
                              subtitle: 'Drink 8 glasses of water daily.'),
                          _TipCard(
                              title: 'Balanced Diet',
                              subtitle: 'Include vegetables in each meal.'),
                          _TipCard(
                              title: 'Exercise',
                              subtitle: '30 mins walk every day.'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Recent Insights',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // Dynamic Insight Tiles
                    if (_hasPrescriptions)
                      _InsightTile(
                        title: 'Medication Reminder',
                        subtitle: _medicationReminder,
                        icon: Icons.medication,
                        color: AppColors.primary,
                      )
                    else
                      const _InsightTile(
                        title: 'All Clear',
                        subtitle: 'No pending medications. Keep it up!',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),

                    _InsightTile(
                      title: 'Health Tip',
                      subtitle: _healthInsight,
                      icon: Icons.lightbulb,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SquareAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4)
                      ]),
                  child: Icon(icon, color: AppColors.primary, size: 22)),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TipCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        color: const Color(0xFFE8EAF6), // Light Indigo
        margin: const EdgeInsets.only(right: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
              const SizedBox(height: 6),
              Text(subtitle,
                  style:
                      const TextStyle(color: Color(0xFF5C6BC0), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _InsightTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade100)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
