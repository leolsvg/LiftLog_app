import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- Importation essentielle pour ouvrir les liens
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // --- Palette de couleurs LiftLog ---
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  final _supabase = Supabase.instance.client;
  late User? _user;
  
  final _targetWeightController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showEmailFields = false;
  bool _showPasswordFields = false;

  @override
  void initState() {
    super.initState();
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _emailController.text = _user!.email ?? "";
    }
    _loadUserProfile();
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🌐 FONCTION MANQUANTE : OUVRIR LES LIENS RGPD
  Future<void> _launchLegalUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossible d\'ouvrir le lien $urlString');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible d'ouvrir la page : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('user_profiles')
          .select('target_weight')
          .eq('user_id', _user!.id)
          .maybeSingle();

      if (data != null && data['target_weight'] != null) {
        _targetWeightController.text = data['target_weight'].toString();
      }
    } catch (e) {
      debugPrint("Erreur chargement profil : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    final targetWeight = double.tryParse(_targetWeightController.text.trim()) ?? 0.0;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('user_profiles').upsert({
        'user_id': _user!.id,
        'target_weight': targetWeight,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Objectifs mis à jour ! 🦾", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: accentCyan.withOpacity(0.8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la sauvegarde"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || newEmail == _user?.email) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Un mail de confirmation a été envoyé à ta nouvelle adresse ! ✉️"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _showEmailFields = false);
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) return;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mot de passe mis à jour avec succès ! 🔐"), backgroundColor: Colors.green),
        );
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordFields = false);
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("Déconnexion", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        content: Text("Es-tu sûr de vouloir quitter LiftLog ?", style: TextStyle(color: textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler", style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Quitter", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Paramètres", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: accentCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1 : PROFIL ---
                  Text("MON COMPTE", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: accentCyan.withOpacity(0.1),
                          radius: 26,
                          child: Icon(Icons.person, color: accentCyan, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Utilisateur connecté", style: TextStyle(color: textMuted, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                _user?.email ?? "Non connecté",
                                style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 2 : SÉCURITÉ (EMAIL & MDP) ---
                  Text("SÉCURITÉ DU COMPTE", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: accentCyan),
                          title: Text("Modifier l'adresse email", style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: Icon(_showEmailFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: textMuted),
                          onTap: () => setState(() => _showEmailFields = !_showEmailFields),
                        ),
                        if (_showEmailFields)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 45,
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: TextStyle(color: textMain, fontSize: 14),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: bgColor,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _updateEmail,
                                  style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: const Text("Mettre à jour", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                )
                              ],
                            ),
                          ),
                        
                        Divider(height: 1, color: bgColor),

                        ListTile(
                          leading: Icon(Icons.lock_outline, color: accentCyan),
                          title: Text("Modifier le mot de passe", style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w600)),
                          trailing: Icon(_showPasswordFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: textMuted),
                          onTap: () => setState(() => _showPasswordFields = !_showPasswordFields),
                        ),
                        if (_showPasswordFields)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: TextStyle(color: textMain),
                                  decoration: InputDecoration(
                                    labelText: "Nouveau mot de passe",
                                    labelStyle: TextStyle(color: textMuted, fontSize: 13),
                                    filled: true,
                                    fillColor: bgColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  style: TextStyle(color: textMain),
                                  decoration: InputDecoration(
                                    labelText: "Confirmer le nouveau mot de passe",
                                    labelStyle: TextStyle(color: textMuted, fontSize: 13),
                                    filled: true,
                                    fillColor: bgColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton(
                                    onPressed: _updatePassword,
                                    style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    child: const Text("Changer le mot de passe", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                )
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 3 : OBJECTIFS PHYSIQUE ---
                  Text("OBJECTIFS PHYSIQUE", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Poids cible global", style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          "Modifie ton objectif de masse. Il s'affichera directement sur le graphique de ton accueil.",
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 45,
                                child: TextField(
                                  controller: _targetWeightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: "Objectif (kg)",
                                    labelStyle: TextStyle(color: textMuted, fontSize: 13),
                                    filled: true,
                                    fillColor: bgColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: _saveProfile,
                                icon: const Icon(Icons.save, size: 18),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentCyan,
                                  foregroundColor: bgColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                label: const Text("Sauver", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 4 : LÉGAL & RGPD ---
                  Text("LÉGAL", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.gavel_outlined, color: accentCyan, size: 20),
                          title: Text("Mentions Légales", style: TextStyle(color: textMain, fontSize: 14)),
                          trailing: Icon(Icons.open_in_new, color: textMuted, size: 16),
                          // Modifie les chaînes ci-dessous par tes vraies URLs le moment venu
                          onTap: () => _launchLegalUrl("https://liftlog-privacy.vercel.app"),
                        ),
                        Divider(height: 1, color: bgColor),
                        ListTile(
                          leading: Icon(Icons.privacy_tip_outlined, color: accentCyan, size: 20),
                          title: Text("Politique de Confidentialité", style: TextStyle(color: textMain, fontSize: 14)),
                          trailing: Icon(Icons.open_in_new, color: textMuted, size: 16),
                          onTap: () => _launchLegalUrl("https://liftlog-privacy.vercel.app"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 5 : ACTIONS ---
                  Text("ACTIONS", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _handleSignOut,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardColor, 
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1)
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                              SizedBox(width: 12),
                              Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Icon(Icons.chevron_right, color: Colors.redAccent, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- METADATA APP ---
                  Center(
                    child: Column(
                      children: [
                        Text("LiftLog v1.0.0", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          "Conçu pour soulever lourd et souder du métal.", 
                          style: TextStyle(color: textMuted.withOpacity(0.5), fontSize: 11, fontStyle: FontStyle.italic)
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}