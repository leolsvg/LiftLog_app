import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text("Connexion", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Bon retour sur LiftLog", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
              const SizedBox(height: 40),

              _inputField(_emailController, "Email", Icons.email_outlined),
              const SizedBox(height: 16),
              _inputField(_passController, "Mot de passe", Icons.lock_outline, obscure: true),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final user = await _auth.signIn(_emailController.text, _passController.text);
                    if (user != null && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                  },
                  child: const Text("SE CONNECTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.grey)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("Ou continuer avec", style: TextStyle(color: Colors.grey[600]))),
                  const Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),

              _socialButton(
                text: "Continuer avec Apple",
                icon: FontAwesomeIcons.apple,
                iconColor: Colors.white,
                onPressed: () async {
                  final user = await _auth.signInWithApple();
                  if (user != null && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                },
              ),
              const SizedBox(height: 16),
              _socialButton(
                text: "Continuer avec Google",
                icon: FontAwesomeIcons.google,
                iconColor: const Color(0xFFDB4437),
                onPressed: () async {
                  final user = await _auth.signInWithGoogle();
                  if (user != null && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                },
              ),

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: RichText(
                    text: TextSpan(text: "Pas encore de compte ? ", style: const TextStyle(color: Colors.grey), children: [
                      TextSpan(text: "S'inscrire", style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller, obscureText: obscure, style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), prefixIcon: Icon(icon, color: Colors.grey), filled: true, fillColor: cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }

  Widget _socialButton({required String text, required dynamic icon, required Color iconColor, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey[700]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: Colors.white),
        onPressed: onPressed,
        icon: FaIcon(icon, size: 20, color: iconColor),
        label: Text(text),
      ),
    );
  }
}