import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onChatTap;
  final VoidCallback onDietTap;

  const HomeScreen(
      {super.key, required this.onChatTap, required this.onDietTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Good Afternoon,",
                        style: TextStyle(color: AppColors.textLight)),
                    Text("Musa Ibrahim",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.secondary,
                    child: Icon(Icons.person))
              ],
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF004D40)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Daily Health Score",
                          style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 6),
                      Text("85%",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text("Keep it up!",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Column(
                    children: const [
                      Icon(Icons.favorite, color: Colors.white, size: 44),
                      SizedBox(height: 8),
                      Text('Heart Rate',
                          style: TextStyle(color: Colors.white70)),
                      Text('72 bpm', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("Quick Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.medical_services_outlined,
                    title: "Check Symptoms",
                    color: const Color.fromARGB(255, 97, 104, 109),
                    iconColor: Colors.blue,
                    onTap: onChatTap,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.camera_alt_outlined,
                    title: "Scan Diet",
                    color: Colors.orange.shade50,
                    iconColor: Colors.orange,
                    onTap: onDietTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.color,
      required this.iconColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
