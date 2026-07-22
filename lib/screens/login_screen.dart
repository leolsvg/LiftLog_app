import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  // Signatures Design GAIN - Or & Anthracite
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur inattendue est survenue'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> signInWithApple() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'liftlog://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      debugPrint("🔥 Connexion Apple lancée");
    } catch (e) {
      debugPrint("❌ Erreur Connexion Apple : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🖼️ TON NOUVEAU LOGO PREMIUM DÉTOURÉ
                Image.asset(
                  'assets/img/logo_trans.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                
                Text(
                  "Connecte-toi pour suivre tes performances",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 40),

                // Champ Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Adresse Email",
                    labelStyle: TextStyle(color: textMuted),
                    prefixIcon: Icon(Icons.email_outlined, color: textMuted),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentGold), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Champ Mot de passe
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Mot de passe",
                    labelStyle: TextStyle(color: textMuted),
                    prefixIcon: Icon(Icons.lock_outlined, color: textMuted),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentGold), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // Bouton Connexion
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: bgColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: bgColor, strokeWidth: 2))
                      : const Text("Se connecter", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade800)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("Ou continuer avec", style: TextStyle(color: textMuted, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade800)),
                  ],
                ),
                const SizedBox(height: 24),

                // Bouton Apple
                _socialButton(
                  text: "Continuer avec Apple",
                  icon: FontAwesomeIcons.apple,
                  iconColor: Colors.white,
                  onPressed: () => signInWithApple(),
                ),

                const SizedBox(height: 32),

                // Lien Inscription
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Tu n'as pas de compte ?", style: TextStyle(color: textMuted)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                      },
                      child: Text("S'inscrire", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required String text,
    required dynamic icon,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade800),
      ),
      icon: FaIcon(icon, color: iconColor, size: 20),
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Inter')),
    );
  }
}