import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Récupération de l'utilisateur Supabase actuel via l'instance globale
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF13171C),
      appBar: AppBar(
        title: const Text("Compte", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header Profile
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1F252D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF38B6FF),
                    child: Icon(Icons.person, color: Colors.black, size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Athlète LiftLog",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.email ?? "Aucun email",
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Options
            _buildMenuItem(Icons.settings_outlined, "Paramètres"),
            _buildMenuItem(Icons.help_outline, "Support"),
            const Spacer(),
            
            // Déconnexion
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton.icon(
                onPressed: () async {
                  // Déconnexion native de Supabase
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (_) => const LoginScreen()), 
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1F252D), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}