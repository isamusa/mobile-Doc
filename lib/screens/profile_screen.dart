import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Health Profile"),
        automaticallyImplyLeading: false,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.edit))],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const SizedBox(height: 12),
          const Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.secondary,
              child: Text("MI",
                  style: TextStyle(fontSize: 28, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text("Musa Ibrahim",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const Center(
              child: Text("musa.ibrahim@email.com",
                  style: TextStyle(color: AppColors.textLight))),
          const SizedBox(height: 18),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.history),
                  title: Text("History"),
                  subtitle: Text("Past diagnoses and chats"),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.person_pin_circle),
                  title: Text("Location"),
                  subtitle: Text("Jos, Plateau State"),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text("Settings"),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const LoginScreen()));
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
