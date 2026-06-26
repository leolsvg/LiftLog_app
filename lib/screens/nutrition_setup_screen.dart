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

  // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2)),
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
        Navigator.pop(context); 
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        debugPrint("Erreur Supabase Upsert: $e");
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de synchronisation : $e", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
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
            // Barre supérieure avec indicateur de progression fin
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / (_totalSteps + 1),
                        backgroundColor: cardColor,
                        valueColor: AlwaysStoppedAnimation<Color>(accentGold),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                    onPressed: () => Navigator.pop(context, false), 
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

            // Boutons de navigation bas de page épurés
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: Text("RETOUR", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter', letterSpacing: 0.5)),
                    )
                  else
                    const SizedBox.shrink(),
                  
                  if (_currentPage < _totalSteps)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: bgColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_currentPage == _totalSteps - 1) _calculateFinal();
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: const Text("SUIVANT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Inter', letterSpacing: 0.5)),
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
    padding: const EdgeInsets.only(bottom: 6, top: 40, left: 24, right: 24),
    child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textMain, fontFamily: 'Inter', letterSpacing: -0.5)),
  );

  Widget _stepGender() => Column(
    children: [
      _title("Quel est ton sexe ?"),
      const SizedBox(height: 40),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _choiceCard(Icons.male_rounded, "Homme", _gender == 'homme', () => setState(() => _gender = 'homme')),
          const SizedBox(width: 16),
          _choiceCard(Icons.female_rounded, "Femme", _gender == 'femme', () => setState(() => _gender = 'femme')),
        ],
      )
    ],
  );

  Widget _stepAge() => _inputStep(
        "Quel âge as-tu ?",
        (val) => setState(() => _age = int.tryParse(val) ?? 25),
        "ans",
        _age.toString(),
      );

  Widget _stepHeight() => _inputStep(
        "Combien mesures-tu ?",
        (val) => setState(() => _height = int.tryParse(val) ?? 175),
        "cm",
        _height.toString(),
      );

  Widget _stepWeight() => _inputStep(
        "Ton poids actuel ?",
        (val) => setState(() => _currentWeight = double.tryParse(val) ?? 75.0),
        "kg",
        _currentWeight.toString(),
      );

  Widget _stepGoalWeight() => _titleAndSubtitleStep(
        "Ton poids cible ?",
        "Détermine si tu dois être en surplus ou en déficit.",
        (val) => setState(() => _targetWeight = double.tryParse(val) ?? 80.0),
        "kg",
        _targetWeight.toString(),
      );

  Widget _stepDuration() => _inputStep(
        "En combien de semaines ?",
        (val) => setState(() => _durationWeeks = int.tryParse(val) ?? 12),
        "semaines",
        _durationWeeks.toString(),
      );

  Widget _stepSummary() => Column(
    children: [
      _title("Ton plan est prêt ! 🦾"),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: accentGold.withValues(alpha:0.15))),
          child: Column(
            children: [
              _resRow("Calories", "$_resKcal kcal", accentGold),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Colors.grey.shade900, height: 1),
              ),
              _resRow("Protéines", "${_resProt}g", textMain),
              _resRow("Glucides", "${_resCarbs}g", textMain),
              _resRow("Lipides", "${_resLipids}g", textMain),
            ],
          ),
        ),
      ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _saveAndExit,
            child: Text("APPLIQUER CE PLAN", style: TextStyle(color: bgColor, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'Inter')),
          ),
        ),
      )
    ],
  );

  Widget _stepActivity() => Column(
    children: [
      _title("Niveau d'activité"),
      const SizedBox(height: 24),
      _activityTile("Sédentaire", "Bureau, peu de marche", 'sedentaire'),
      _activityTile("Légère", "Muscu 1-2x / semaine", 'leger'),
      _activityTile("Modérée", "Muscu 3-5x / semaine", 'modere'),
      _activityTile("Intense", "Entraînement quotidien", 'actif'),
    ],
  );

  // --- HELPERS ---

  Widget _resRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
      ],
    ),
  );

  Widget _inputStep(String t, Function(String) onCh, String unit, String initial) => Column(
    children: [
      _title(t),
      const SizedBox(height: 40),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: TextField(
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textMain, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
          decoration: InputDecoration(
            suffixText: " $unit", 
            suffixStyle: TextStyle(fontSize: 16, color: textMuted, fontWeight: FontWeight.normal, fontFamily: 'Inter'), 
            hintText: initial, 
            hintStyle: TextStyle(color: textMain.withValues(alpha:0.1)),
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
      Text(sub, style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter')),
      const SizedBox(height: 40),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: TextField(
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textMain, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
          decoration: InputDecoration(
            suffixText: " $unit", 
            suffixStyle: TextStyle(fontSize: 16, color: textMuted, fontWeight: FontWeight.normal, fontFamily: 'Inter'), 
            hintText: initial, 
            hintStyle: TextStyle(color: textMain.withValues(alpha:0.1)),
            border: InputBorder.none
          ),
          onChanged: onCh,
        ),
      ),
    ],
  );

  Widget _choiceCard(IconData icon, String label, bool isSel, VoidCallback onT) => InkWell(
    onTap: onT,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: 125, height: 125,
      decoration: BoxDecoration(
        color: isSel ? accentGold.withValues(alpha:0.06) : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSel ? accentGold : Colors.transparent, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSel ? accentGold : textMuted.withValues(alpha:0.5), size: 36),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isSel ? accentGold : textMuted.withValues(alpha:0.6), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
        ],
      ),
    ),
  );

  Widget _activityTile(String t, String s, String val) {
    bool isSel = _activityLevel == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: () => setState(() => _activityLevel = val),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSel ? accentGold.withValues(alpha:0.06) : cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? accentGold : Colors.transparent, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(t, style: TextStyle(color: isSel ? accentGold : textMain, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter')),
                    const SizedBox(height: 2),
                    Text(s, style: TextStyle(color: textMuted, fontSize: 11, fontFamily: 'Inter')),
                  ]
                ),
              ),
              if (isSel) Icon(Icons.check_circle_rounded, color: accentGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}