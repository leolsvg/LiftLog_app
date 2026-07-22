import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_model.dart';

import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  final _supabase = Supabase.instance.client;
  late User? _user;
  
  final _targetWeightController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isImporting = false; 
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
            content: Text("Impossible d'ouvrir la page : $e", style: const TextStyle(fontFamily: 'Inter')),
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
            content: const Text("Objectifs mis à jour ! 🦾", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            backgroundColor: accentGold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la sauvegarde", style: TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importWorkoutHistory() async {
    if (_user == null) return;

    int asInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isImporting = true);

    try {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      dynamic parsedJson = jsonDecode(content);

      List<dynamic> importedWorkouts = [];
      List<dynamic> importedTemplates = [];
      List<dynamic> customExercises = [];

      if (parsedJson is Map<String, dynamic>) {
        importedWorkouts = parsedJson['history'] ?? [];
        importedTemplates = parsedJson['templates'] ?? [];
        customExercises = parsedJson['custom_exercises'] ?? [];
      } else if (parsedJson is List<dynamic>) {
        importedWorkouts = parsedJson;
      }

      // 1. ENREGISTREMENT DES EXERCICES PERSONNALISÉS
      final Set<String> allExerciseNames = {};

      for (var e in customExercises) {
        if (e != null && e.toString().isNotEmpty) {
          allExerciseNames.add(e.toString());
        }
      }

      for (var session in importedWorkouts) {
        List<dynamic> sets = session['sets'] ?? [];
        for (var set in sets) {
          if (set['exercise_name'] != null) {
            allExerciseNames.add(set['exercise_name'].toString());
          }
        }
      }

      for (var exName in allExerciseNames) {
        try {
          await _supabase.from('custom_exercises').upsert({
            'user_id': _user!.id,
            'name': exName,
          });
        } catch (_) {}
      }

      // 2. IMPORTATION DES PROGRAMMES / TEMPLATES
      if (importedTemplates.isNotEmpty) {
        for (var tpl in importedTemplates) {
          final String templateName = tpl['name'] ?? 'Programme Importé';
          final List<dynamic> rawExoList = tpl['exercises'] ?? [];

          final List<Exercise> exerciseObjects = rawExoList.map((exoName) {
            return Exercise.createTarget(
              name: exoName.toString(),
              targetSets: 3,
              targetReps: 10,
            );
          }).toList();

          await _supabase.from('workout_templates').insert({
            'user_id': _user!.id,
            'name': templateName,
            'exercises': exerciseObjects.map((e) => e.toJson()).toList(),
          });
        }
      }

      // 3. IMPORTATION DE L'HISTORIQUE (AVEC CHAMPS COMPLETS)
      for (var session in importedWorkouts) {
        final String sessionName = session['workout_name'] ?? 'Séance Importée';
        
        final workoutResponse = await _supabase.from('workouts').insert({
          'user_id': _user!.id,
          'name': sessionName,
          'duration_minutes': asInt(session['duration'], fallback: 60),
          'created_at': session['date'],
        }).select('id').single();

        final workoutId = workoutResponse['id'];
        List<dynamic> rawSets = session['sets'] ?? [];

        // Regroupement des séries par exercice
        final Map<String, List<dynamic>> groupedSets = {};
        for (var set in rawSets) {
          final String exName = set['exercise_name'] ?? 'Exercice Importé';
          groupedSets.putIfAbsent(exName, () => []);
          groupedSets[exName]!.add(set);
        }

        for (var entry in groupedSets.entries) {
          final String exerciseName = entry.key;
          final List<dynamic> exerciseSets = entry.value;

          final exerciseResponse = await _supabase.from('workout_exercises').insert({
            'workout_id': workoutId,
            'exercise_name': exerciseName,
            'notes': exerciseSets.first['notes'],
          }).select('id').single();

          final exerciseId = exerciseResponse['id'];

          for (var set in exerciseSets) {
            final int setOrder = asInt(set['set_number'] ?? set['set_index'], fallback: 1);
            final int reps = asInt(set['reps']);
            final int weight = asInt(set['weight']);
            final int rir = asInt(set['rir'], fallback: 0);

            // 💡 Insertion complète avec is_completed = true
            await _supabase.from('exercise_sets').insert({
              'exercise_id': exerciseId,
              'weight': weight,
              'reps': reps,
              'set_order': setOrder,
              'is_completed': true, // 👈 Permet l'affichage dans l'historique et le graphique
              'rir': rir,
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Importation réussie ! Données complètement synchronisées. 🔥",
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'importation : $e",
              style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showImportInstructions() {
    const String templateJson = '[\n  {\n    "workout_name": "Push Day",\n    "date": "2026-06-11T18:30:00Z",\n    "duration": 60,\n    "sets": [\n      {\n        "exercise_name": "Développé Couché",\n        "set_index": 1,\n        "weight": 80.0,\n        "reps": 10\n      }\n    ]\n  }\n]';

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text("Guide de Migration 🚀", style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  const SizedBox(height: 16),
                  _buildStepRow("1", "Crée un fichier texte vide sur ton PC/téléphone et renomme-le en extension .json (ex: historique.json)."),
                  _buildStepRow("2", "Colle l'historique de tes entraînements en respectant exactement le format requis (modèle ci-dessous)."),
                  _buildStepRow("3", "Transfère le fichier sur ton téléphone, clique sur la case d'import et sélectionne-le."),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("STRUCTURE DU FICHIER (.JSON)", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      TextButton.icon(
                        icon: Icon(Icons.copy_rounded, size: 14, color: accentGold),
                        label: Text("Copier le modèle", style: TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: templateJson));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Modèle copié ! 📋", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)), backgroundColor: cardColor));
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade900)),
                    child: const Text(
                      templateJson,
                      style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 11, backgroundColor: accentGold.withValues(alpha: 0.08), child: Text(number, style: TextStyle(color: accentGold, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: textMuted, fontSize: 13, height: 1.4, fontFamily: 'Inter'))),
        ],
      ),
    );
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || newEmail == _user?.email) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      
      if (!mounted) return; // 🦾 Sécurise le BuildContext après le await
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Un mail de confirmation a été envoyé ! ✉️", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          backgroundColor: cardColor,
        ),
      );
      setState(() => _showEmailFields = false);
    } on AuthException catch (e) {
      if (!mounted) return; // 🦾 Sécurise le BuildContext ici aussi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: const TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.redAccent),
      );
    } finally { // 🦾 Corrigé : c'était écrit "final" au lieu de "finally", ce qui cassait la compilation !
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) return;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas", style: TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mot de passe mis à jour ! 🔐", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
        );
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordFields = false);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: const TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.redAccent),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Déconnexion", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
        content: Text("Es-tu sûr de vouloir quitter GAIN ?", style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler", style: TextStyle(color: textMuted, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900], 
              foregroundColor: Colors.white, 
              elevation: 0,
            ),
            onPressed: () async {
  Navigator.pop(context);
  await _supabase.auth.signOut();
  
  // 🦾 Sécurité absolue basée sur le BuildContext lui-même
  if (!context.mounted) return; 

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
    (route) => false,
  );
},
            child: const Text("Quitter", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
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
        title: Text("PARAMÈTRES", style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1 : PROFIL ---
                  Text("MON COMPTE", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: bgColor,
                          radius: 24,
                          child: Icon(Icons.person_rounded, color: accentGold, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Utilisateur connecté", style: TextStyle(color: textMuted, fontSize: 11, fontFamily: 'Inter')),
                              const SizedBox(height: 2),
                              Text(
                                _user?.email ?? "Non connecté",
                                style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
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
                  Text("SÉCURITÉ DU COMPTE", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: accentGold, size: 20),
                          title: Text("Modifier l'adresse email", style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          trailing: Icon(_showEmailFields ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18),
                          onTap: () => setState(() => _showEmailFields = !_showEmailFields),
                        ),
                        if (_showEmailFields)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: TextStyle(color: textMain, fontSize: 14, fontFamily: 'Inter'),
                                      decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _updateEmail,
                                  style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                                  child: const Text("Mettre à jour", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter')),
                                )
                              ],
                            ),
                          ),
                        
                        Divider(height: 1, color: bgColor),

                        ListTile(
                          leading: Icon(Icons.lock_outline_rounded, color: accentGold, size: 20),
                          title: Text("Modifier le mot de passe", style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          trailing: Icon(_showPasswordFields ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18),
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
                                  style: TextStyle(color: textMain, fontFamily: 'Inter'),
                                  decoration: InputDecoration(
                                    labelText: "Nouveau mot de passe",
                                    labelStyle: TextStyle(color: textMuted, fontSize: 12),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade900)),
                                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  style: TextStyle(color: textMain, fontFamily: 'Inter'),
                                  decoration: InputDecoration(
                                    labelText: "Confirmer le mot de passe",
                                    labelStyle: TextStyle(color: textMuted, fontSize: 12),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade900)),
                                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: _updatePassword,
                                    style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    child: const Text("Changer le mot de passe", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13)),
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
                  Text("OBJECTIFS PHYSIQUE", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Poids cible global", style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        const SizedBox(height: 4),
                        Text(
                          "Modifie ton objectif de masse. Il s'affichera directement sur le graphique de ton accueil.",
                          style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Inter'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                                child: TextField(
                                  controller: _targetWeightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                  decoration: InputDecoration(
                                    labelText: "Objectif (kg)",
                                    labelStyle: TextStyle(color: textMuted, fontSize: 11),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _saveProfile,
                                icon: Icon(Icons.save_rounded, size: 16, color: bgColor),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentGold,
                                  foregroundColor: bgColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                label: const Text("Sauver", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 4 : IMPORTATION DES DONNÉES ---
                  Text("MIGRATION", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: _isImporting 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: accentGold, strokeWidth: 1.5))
                        : Icon(Icons.file_upload_outlined, color: accentGold, size: 20),
                      title: Text("Migrer d'une autre application", style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      subtitle: Text("Importe tes séries et reps (Format JSON)", style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Inter')),
                      trailing: IconButton(
                        icon: Icon(Icons.help_outline_rounded, color: accentGold, size: 18),
                        onPressed: _showImportInstructions, 
                      ),
                      onTap: _isImporting ? null : _importWorkoutHistory,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 5 : LÉGAL & RGPD ---
                  Text("LÉGAL", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.gavel_outlined, color: accentGold, size: 18),
                          title: Text("Mentions Légales", style: TextStyle(color: textMain, fontSize: 13, fontFamily: 'Inter')),
                          trailing: Icon(Icons.open_in_new_rounded, color: textMuted, size: 14),
                          onTap: () => _launchLegalUrl("https://liftlog-privacy.vercel.app"),
                        ),
                        Divider(height: 1, color: bgColor),
                        ListTile(
                          leading: Icon(Icons.privacy_tip_outlined, color: accentGold, size: 20),
                          title: Text("Politique de Confidentialité", style: TextStyle(color: textMain, fontSize: 14, fontFamily: 'Inter')),
                          trailing: Icon(Icons.open_in_new, color: textMuted, size: 14),
                          onTap: () => _launchLegalUrl("https://liftlog-privacy.vercel.app"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 6 : ACTIONS ---
                  Text("ACTIONS", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _handleSignOut,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardColor, 
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15), width: 1)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 12),
                              Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                            ],
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.redAccent, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- METADATA APP ---
                  Center(
                    child: Column(
                      children: [
                        Text("GAIN v1.1.0", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        const SizedBox(height: 4),
                        Text(
                          "Conçu pour l'esthétique et la performance.", 
                          style: TextStyle(color: textMuted.withValues(alpha: 0.4), fontSize: 11, fontFamily: 'Inter')
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}