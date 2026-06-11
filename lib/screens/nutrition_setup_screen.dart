import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionSetupScreen extends StatefulWidget {
  const NutritionSetupScreen({super.key});

  @override
  State<NutritionSetupScreen> createState() => _NutritionSetupScreenState();
}

class _NutritionSetupScreenState extends State<NutritionSetupScreen> {
  // Navigation
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalSteps = 7;

  // Design
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);

  // Données récoltées
  String _gender = 'homme';
  int _age = 25;
  int _height = 175;
  double _currentWeight = 75.0;
  double _targetWeight = 80.0;
  int _durationWeeks = 12;
  String _activityLevel = 'modere';

  // Résultats calculés
  int _resKcal = 0;
  int _resProt = 0;
  int _resCarbs = 0;
  int _resLipids = 0;

  void _calculateFinal() {
    // 1. TMB (Mifflin-St Jeor)
    double tmb = (10 * _currentWeight) + (6.25 * _height) - (5 * _age);
    tmb = (_gender == 'homme') ? tmb + 5 : tmb - 161;

    // 2. TDEE (Activité)
    double factor = 1.2; 
    if (_activityLevel == 'leger') factor = 1.375;
    if (_activityLevel == 'modere') factor = 1.55;
    if (_activityLevel == 'actif') factor = 1.725;
    double tdee = tmb * factor;

    // 3. Delta Poids (1kg = 7700 kcal)
    double kgDiff = _targetWeight - _currentWeight;
    double totalCaloriesRequired = kgDiff * 7700;
    double dailyAdjustment = totalCaloriesRequired / (_durationWeeks * 7);

    // 4. Cible Calorique (limites de sécurité)
    _resKcal = (tdee + dailyAdjustment).round().clamp(1500, 4500);

    // 5. Macros (2g prot/kg, 1g lip/kg, reste glucides)
    _resProt = (_currentWeight * 2.0).round();
    _resLipids = (_currentWeight * 1.0).round();
    int remainingKcal = _resKcal - (_resProt * 4) - (_resLipids * 9);
    _resCarbs = (remainingKcal / 4).round().clamp(50, 800);
  }

  // 💾 SAUVEGARDE SÉCURISÉE SUR SUPABASE AVEC CATCH DES ERREURS
  Future<void> _saveAndExit() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur : Aucun utilisateur connecté"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final targetDate = DateTime.now().add(Duration(days: _durationWeeks * 7));

    // Affiche un loader de synchronisation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF38B6FF))),
    );

    try {
      await supabase.from('user_profiles').upsert({
        'user_id': user.id,
        'age': _age,
        'height': _height,
        'current_weight': _currentWeight,
        'target_weight': _targetWeight,
        'gender': _gender,
        'activity_level': _activityLevel,
        'target_date': targetDate.toIso8601String().substring(0, 10),
        'target_kcal': _resKcal,
        'target_prot': _resProt,
        'target_carbs': _resCarbs,
        'target_lipids': _resLipids,
      });

      if (mounted) {
        Navigator.pop(context); // Ferme le loader
        Navigator.pop(context, true); // Quitte l'assistant et signale la réussite
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Ferme le loader
        debugPrint("Erreur Supabase Upsert: $e");
        
        // Alerte visuelle pour savoir précisément ce qui bloque la base (ex: RLS, colonne manquante)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de synchronisation : $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Barre supérieure avec bouton annuler
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / (_totalSteps + 1),
                      backgroundColor: cardColor,
                      valueColor: AlwaysStoppedAnimation<Color>(accentCyan),
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Le fameux bouton pour fermer et annuler si clic par erreur
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 22),
                    onPressed: () => Navigator.pop(context, false), // Ferme sans déclencher de mise à jour
                  )
                ],
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _stepGender(),
                  _stepAge(),
                  _stepHeight(),
                  _stepWeight(),
                  _stepActivity(),
                  _stepGoalWeight(),
                  _stepDuration(),
                  _stepSummary(),
                ],
              ),
            ),

            // Boutons de navigation bas de page
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: Text("RETOUR", style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold)),
                    )
                  else
                    const SizedBox.shrink(),
                  
                  if (_currentPage < _totalSteps)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCyan,
                        foregroundColor: bgColor,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_currentPage == _totalSteps - 1) _calculateFinal();
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: const Text("SUIVANT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE CHAQUE ÉTAPE ---

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 40),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
  );

  Widget _stepGender() => Column(
    children: [
      _title("Quel est ton sexe ?"),
      const SizedBox(height: 40),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _choiceCard(Icons.male, "Homme", _gender == 'homme', () => setState(() => _gender = 'homme')),
          const SizedBox(width: 20),
          _choiceCard(Icons.female, "Femme", _gender == 'femme', () => setState(() => _gender = 'femme')),
        ],
      )
    ],
  );

  Widget _stepAge() => _inputStep("Quel âge as-tu ?", (val) => _age = int.tryParse(val) ?? 25, "ans", _age.toString());

  Widget _stepHeight() => _inputStep("Combien mesures-tu ?", (val) => _height = int.tryParse(val) ?? 175, "cm", _height.toString());

  Widget _stepWeight() => _inputStep("Ton poids actuel ?", (val) => _currentWeight = double.tryParse(val) ?? 75.0, "kg", _currentWeight.toString());

  Widget _stepGoalWeight() => _titleAndSubtitleStep("Ton poids cible ?", "Définit si tu dois être en surplus ou en déficit.", (val) => _targetWeight = double.tryParse(val) ?? 80.0, "kg", _targetWeight.toString());

  Widget _stepActivity() => Column(
    children: [
      _title("Niveau d'activité"),
      const SizedBox(height: 20),
      _activityTile("Sédentaire", "Bureau, peu de marche", 'sedentaire'),
      _activityTile("Légère", "Muscu 1-2x / semaine", 'leger'),
      _activityTile("Modérée", "Muscu 3-5x / semaine", 'modere'),
      _activityTile("Intense", "Entraînement quotidien", 'actif'),
    ],
  );

  Widget _stepDuration() => _inputStep("En combien de semaines ?", (val) => _durationWeeks = int.tryParse(val) ?? 12, "semaines", _durationWeeks.toString());

  Widget _stepSummary() => Column(
    children: [
      _title("Ton plan est prêt ! 🦾"),
      Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: accentCyan.withOpacity(0.3))),
          child: Column(
            children: [
              _resRow("Calories", "$_resKcal kcal", accentCyan),
              const Divider(color: Colors.white10, height: 30),
              _resRow("Protéines", "${_resProt}g", Colors.redAccent.shade200),
              _resRow("Glucides", "${_resCarbs}g", Colors.greenAccent.shade400),
              _resRow("Lipides", "${_resLipids}g", Colors.orangeAccent.shade200),
            ],
          ),
        ),
      ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: _saveAndExit,
            child: Text("APPLIQUER CE PLAN", style: TextStyle(color: bgColor, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ),
      )
    ],
  );

  // --- HELPERS ---

  Widget _resRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _inputStep(String t, Function(String) onCh, String unit, String initial) => Column(
    children: [
      _title(t),
      const SizedBox(height: 50),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: TextField(
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: " $unit", 
            suffixStyle: const TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.normal), 
            hintText: initial, 
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            border: InputBorder.none
          ),
          onChanged: onCh,
        ),
      ),
    ],
  );

  Widget _titleAndSubtitleStep(String t, String sub, Function(String) onCh, String unit, String initial) => Column(
    children: [
      _title(t),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      const SizedBox(height: 50),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: TextField(
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: " $unit", 
            suffixStyle: const TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.normal), 
            hintText: initial, 
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            border: InputBorder.none
          ),
          onChanged: onCh,
        ),
      ),
    ],
  );

  Widget _choiceCard(IconData icon, String label, bool isSel, VoidCallback onT) => InkWell(
    onTap: onT,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 130, height: 130,
      decoration: BoxDecoration(
        color: isSel ? accentCyan.withOpacity(0.1) : cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSel ? accentCyan : Colors.transparent, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSel ? accentCyan : Colors.white54, size: 40),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: isSel ? accentCyan : Colors.white54, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );

  Widget _activityTile(String t, String s, String val) {
    bool isSel = _activityLevel == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: () => setState(() => _activityLevel = val),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isSel ? accentCyan.withOpacity(0.1) : cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSel ? accentCyan : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: TextStyle(color: isSel ? accentCyan : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(s, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              if (isSel) Icon(Icons.check_circle, color: accentCyan),
            ],
          ),
        ),
      ),
    );
  }
}