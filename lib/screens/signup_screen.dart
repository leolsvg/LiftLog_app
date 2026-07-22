import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Inscription Classique (Email/Mot de passe)
  Future<void> _handleEmailSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // On capture les instances de l'UI AVANT le await pour éviter les async gaps
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (!context.mounted) return; 
      
      messenger.showSnackBar(
        const SnackBar(content: Text('Inscription réussie !'), backgroundColor: Colors.green),
      );
      navigator.pop(); 
      
    } on AuthException catch (e) {
      if (!context.mounted) return; 
      
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!context.mounted) return; 
      
      messenger.showSnackBar(
        const SnackBar(content: Text('Une erreur inattendue est survenue'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Inscription Sociale (Apple)
Future<void> _handleSocialSignIn(OAuthProvider provider) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await _supabase.auth.signInWithOAuth(
      provider,
      // 💡 ALIGNEMENT : On utilise le protocole d'écoute configuré dans l'Info.plist
      redirectTo: 'liftlog://callback', 
    );
  } on AuthException catch (e) {
    if (!context.mounted) return; 
    messenger.showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
    );
  }
}
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/img/logo_trans.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                
                Text(
                  "Créer un compte",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textMain, fontFamily: 'Inter', letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  "Rejoins la plateforme pour planifier tes entraînements",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 36),

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
                const SizedBox(height: 16),

                // Confirmation Mot de passe
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Confirmer le mot de passe",
                    labelStyle: TextStyle(color: textMuted),
                    prefixIcon: Icon(Icons.lock_reset_outlined, color: textMuted),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentGold), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // Bouton Inscription
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: bgColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: bgColor, strokeWidth: 2))
                      : const Text("S'inscrire", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
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
                  onPressed: () => _handleSocialSignIn(OAuthProvider.apple),
                ),
                const SizedBox(height: 16),
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