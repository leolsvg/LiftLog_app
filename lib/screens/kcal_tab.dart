import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // 👈 Indispensable pour transformer nos listes en texte pour la sauvegarde
import '../models/nutrition_model.dart';
import 'add_food_screen.dart';

class KcalTab extends StatefulWidget {
  const KcalTab({super.key});

  @override
  State<KcalTab> createState() => _KcalTabState();
}

class _KcalTabState extends State<KcalTab> {
  final UserProfile _profile = UserProfile(
    weight: 80.0, 
    height: 180.0, 
    age: 19, 
    gender: "Homme",
    activityFactor: 1.55, 
    caloriesOffset: 300, 
    morphotype: "Mésomorphe",
  );
  
  final DailyNutrition _todayNutrition = DailyNutrition(consumedCalories: 0, proteins: 0, carbs: 0, lipids: 0);

  // Le compteur total par repas
  final Map<String, int> _mealCalories = {
    "Petit-déjeuner": 0,
    "Déjeuner": 0,
    "Dîner": 0,
    "Extra / Collation": 0,
  };

  // 🆕 NOUVEAU : Une liste détaillée des aliments pour chaque repas
  final Map<String, List<Map<String, dynamic>>> _mealFoods = {
    "Petit-déjeuner": [],
    "Déjeuner": [],
    "Dîner": [],
    "Extra / Collation": [],
  };

  // --- Palette de couleurs (Thème sombre) ---
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  @override
  void initState() {
    super.initState();
    _loadNutritionData();
  }

  // 🔄 LOGIQUE DE REMISE À ZÉRO ET CHARGEMENT
  Future<void> _loadNutritionData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final savedDate = prefs.getString('last_nutrition_date');

    if (savedDate == todayString) {
      setState(() {
        _todayNutrition.consumedCalories = prefs.getInt('consumed_kcal') ?? 0;
        _todayNutrition.proteins = prefs.getInt('consumed_prot') ?? 0;
        _todayNutrition.carbs = prefs.getInt('consumed_carbs') ?? 0;
        _todayNutrition.lipids = prefs.getInt('consumed_lipids') ?? 0;

        _mealCalories["Petit-déjeuner"] = prefs.getInt('breakfast_kcal') ?? 0;
        _mealCalories["Déjeuner"] = prefs.getInt('lunch_kcal') ?? 0;
        _mealCalories["Dîner"] = prefs.getInt('dinner_kcal') ?? 0;
        _mealCalories["Extra / Collation"] = prefs.getInt('snack_kcal') ?? 0;

        // 🆕 Chargement des listes d'aliments
        for (String meal in _mealFoods.keys) {
          String? foodsJson = prefs.getString('${meal}_foods');
          if (foodsJson != null) {
            List<dynamic> decoded = jsonDecode(foodsJson);
            _mealFoods[meal] = decoded.map((e) => e as Map<String, dynamic>).toList();
          }
        }
      });
    } else {
      await prefs.setString('last_nutrition_date', todayString);
      await prefs.setInt('consumed_kcal', 0);
      await prefs.setInt('consumed_prot', 0);
      await prefs.setInt('consumed_carbs', 0);
      await prefs.setInt('consumed_lipids', 0);

      await prefs.setInt('breakfast_kcal', 0);
      await prefs.setInt('lunch_kcal', 0);
      await prefs.setInt('dinner_kcal', 0);
      await prefs.setInt('snack_kcal', 0);

      // 🆕 Suppression des anciennes listes
      for (String meal in _mealFoods.keys) {
        await prefs.remove('${meal}_foods');
      }
      
      setState(() {
        _todayNutrition.consumedCalories = 0;
        _todayNutrition.proteins = 0;
        _todayNutrition.carbs = 0;
        _todayNutrition.lipids = 0;

        _mealCalories["Petit-déjeuner"] = 0;
        _mealCalories["Déjeuner"] = 0;
        _mealCalories["Dîner"] = 0;
        _mealCalories["Extra / Collation"] = 0;

        for (String meal in _mealFoods.keys) {
          _mealFoods[meal] = [];
        }
      });
    }
  }

  // 💾 SAUVEGARDE APRÈS AVOIR AJOUTÉ UN REPAS
  Future<void> _saveNutritionData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('consumed_kcal', _todayNutrition.consumedCalories);
    await prefs.setInt('consumed_prot', _todayNutrition.proteins);
    await prefs.setInt('consumed_carbs', _todayNutrition.carbs);
    await prefs.setInt('consumed_lipids', _todayNutrition.lipids);

    await prefs.setInt('breakfast_kcal', _mealCalories["Petit-déjeuner"]!);
    await prefs.setInt('lunch_kcal', _mealCalories["Déjeuner"]!);
    await prefs.setInt('dinner_kcal', _mealCalories["Dîner"]!);
    await prefs.setInt('snack_kcal', _mealCalories["Extra / Collation"]!);

    await prefs.setInt('target_kcal', _profile.targetCalories);
    await prefs.setInt('target_prot', _profile.targetMacros["proteins"]!);
    await prefs.setInt('target_carbs', _profile.targetMacros["carbs"]!);
    await prefs.setInt('target_lipids', _profile.targetMacros["lipids"]!);

    // 🆕 Sauvegarde des listes d'aliments en format Texte (JSON)
    for (String meal in _mealFoods.keys) {
      await prefs.setString('${meal}_foods', jsonEncode(_mealFoods[meal]));
    }
  }

  // 🛠️ DIALOGUE PROFIL ET TMB (Inchangé pour raccourcir, garde ton code actuel pour ce bloc)
  void _showUpdateProfileDialog() {
    // ... Garde ton code existant ici ...
  }

  // 🚀 NAVIGATION VERS LE SCANNER 
  void _navigateToAddFood(String mealName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFoodScreen()),
    );

    // Attention: On vérifie juste `Map` maintenant car les valeurs peuvent être String (le nom) et int (les macros)
    if (result != null && result is Map) {
      int addedKcal = (result['kcal'] ?? 0) as int;
      String foodName = (result['name'] ?? "Aliment scanné") as String; // 👈 Récupère le nom
      
      setState(() {
        // 1. Ajout au total global
        _todayNutrition.consumedCalories += addedKcal;
        _todayNutrition.proteins += (result['proteins'] ?? 0) as int;
        _todayNutrition.carbs += (result['carbs'] ?? 0) as int;
        _todayNutrition.lipids += (result['lipids'] ?? 0) as int;

        // 2. Ajout au repas spécifique
        if (_mealCalories.containsKey(mealName)) {
          _mealCalories[mealName] = (_mealCalories[mealName] ?? 0) + addedKcal;
          
          // 3. 🆕 Ajout à la liste détaillée
          _mealFoods[mealName]!.add({
            'name': foodName,
            'kcal': addedKcal,
          });
        }
      });
      _saveNutritionData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Nutrition", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: textMain),
            onPressed: _showUpdateProfileDialog,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopCounters(),
            const SizedBox(height: 24),

            Text("Journal du jour", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
            const SizedBox(height: 16),
            
            // 🆕 NOUVEAU : On passe la liste des aliments à chaque widget
            _buildMealRectangle(
              title: "Petit-déjeuner", 
              icon: Icons.free_breakfast_outlined, 
              kcal: _mealCalories["Petit-déjeuner"]!,
              foods: _mealFoods["Petit-déjeuner"]!
            ),
            const SizedBox(height: 12),
            _buildMealRectangle(
              title: "Déjeuner", 
              icon: Icons.lunch_dining_outlined, 
              kcal: _mealCalories["Déjeuner"]!,
              foods: _mealFoods["Déjeuner"]!
            ),
            const SizedBox(height: 12),
            _buildMealRectangle(
              title: "Dîner", 
              icon: Icons.dinner_dining_outlined, 
              kcal: _mealCalories["Dîner"]!,
              foods: _mealFoods["Dîner"]!
            ),
            const SizedBox(height: 12),
            _buildMealRectangle(
              title: "Extra / Collation", 
              icon: Icons.cookie_outlined, 
              kcal: _mealCalories["Extra / Collation"]!,
              foods: _mealFoods["Extra / Collation"]!
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET : Bloc des compteurs du haut (Inchangé) ---
  Widget _buildTopCounters() {
    int target = _profile.targetCalories;
    int eaten = _todayNutrition.consumedCalories;
    int remaining = target - eaten;
    Map<String, int> macros = _profile.targetMacros;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKcalStat("Consommé", eaten.toString(), textMain),
              Container(width: 1, height: 40, color: Colors.grey.shade800),
              _buildKcalStat("Restant", remaining > 0 ? remaining.toString() : "0", accentCyan),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Colors.grey.shade800),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroStat("Protéines", _todayNutrition.proteins.toDouble(), macros["proteins"]!.toDouble(), Colors.redAccent.shade200),
              _buildMacroStat("Glucides", _todayNutrition.carbs.toDouble(), macros["carbs"]!.toDouble(), accentCyan),
              _buildMacroStat("Lipides", _todayNutrition.lipids.toDouble(), macros["lipids"]!.toDouble(), Colors.orangeAccent.shade200),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKcalStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: valueColor)),
        Text(label, style: TextStyle(fontSize: 14, color: textMuted)),
      ],
    );
  }

  Widget _buildMacroStat(String label, double eaten, double total, Color color) {
    double progress = total > 0 ? (eaten / total) : 0;
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textMain)),
        const SizedBox(height: 4),
        Text("${eaten.toInt()} / ${total.toInt()}g", style: TextStyle(fontSize: 12, color: textMuted)),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.black38,
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        )
      ],
    );
  }

  // --- WIDGET : Rectangle pour un repas ---
  // 🆕 NOUVEAU : On reçoit la liste "foods"
  Widget _buildMealRectangle({required String title, required IconData icon, required int kcal, required List<Map<String, dynamic>> foods}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: accentCyan),
                  const SizedBox(width: 12),
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
                ],
              ),
              IconButton(
                onPressed: () => _navigateToAddFood(title),
                icon: Icon(Icons.add_circle, color: accentCyan),
                iconSize: 32,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
          const SizedBox(height: 8),
          
          Text(
            kcal > 0 ? "$kcal kcal consommées" : "Ajouter des aliments",
            style: TextStyle(
              color: kcal > 0 ? accentCyan : textMuted, 
              fontSize: 14,
              fontWeight: kcal > 0 ? FontWeight.bold : FontWeight.normal
            ),
          ),

          // 🆕 NOUVEAU : L'affichage de la liste des aliments !
          if (foods.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            // On fait une boucle (map) pour afficher chaque aliment
            ...foods.map((food) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    food['name'], 
                    style: TextStyle(color: textMain, fontSize: 15)
                  ),
                  Text(
                    "${food['kcal']} kcal", 
                    style: TextStyle(color: textMuted, fontSize: 14)
                  ),
                ],
              ),
            )),
          ]
        ],
      ),
    );
  }
}