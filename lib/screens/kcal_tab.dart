import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_model.dart';
import 'add_food_screen.dart';
import 'nutrition_setup_screen.dart';

class KcalTab extends StatefulWidget {
  const KcalTab({super.key});

  @override
  State<KcalTab> createState() => _KcalTabState();
}

class _KcalTabState extends State<KcalTab> {
  final _supabase = Supabase.instance.client;

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

  final Map<String, int> _mealCalories = {
    "Petit-déjeuner": 0,
    "Déjeuner": 0,
    "Dîner": 0,
    "Extra / Collation": 0,
  };

  final Map<String, List<Map<String, dynamic>>> _mealFoods = {
    "Petit-déjeuner": [],
    "Déjeuner": [],
    "Dîner": [],
    "Extra / Collation": [],
  };

  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  @override
  void initState() {
    super.initState();
    _syncWithSupabaseAndLocal();
  }

  Future<void> _syncWithSupabaseAndLocal() async {
    await _loadSupabaseTargets();
    await _loadNutritionData();
  }

  Future<void> _loadSupabaseTargets() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('user_profiles')
          .select('target_kcal, target_prot, target_carbs, target_lipids, current_weight, height, age, gender')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _profile.manualTargetCalories = data['target_kcal'] ?? 2500;
          _profile.manualProt = data['target_prot'] ?? 150;
          _profile.manualCarbs = data['target_carbs'] ?? 250;
          _profile.manualLipids = data['target_lipids'] ?? 80;
          _profile.isManualMode = true; 

          _profile.weight = (data['current_weight'] ?? _profile.weight).toDouble();
          _profile.height = (data['height'] ?? _profile.height).toDouble();
          _profile.age = data['age'] ?? _profile.age;
          _profile.gender = data['gender'] ?? _profile.gender;
        });
      }
    } catch (e) {
      debugPrint("Erreur récupération targets Supabase : $e");
    }
  }

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

        for (String meal in _mealFoods.keys) {
          String? foodsJson = prefs.getString('${meal}_foods');
          if (foodsJson != null) {
            List<dynamic> decoded = jsonDecode(foodsJson);
            _mealFoods[meal] = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      });
    } else {
      await prefs.setString('last_nutrition_date', todayString);
      _resetLocalNutrition(prefs);
    }
  }

  void _resetLocalNutrition(SharedPreferences prefs) async {
    await prefs.setInt('consumed_kcal', 0);
    await prefs.setInt('consumed_prot', 0);
    await prefs.setInt('consumed_carbs', 0);
    await prefs.setInt('consumed_lipids', 0);
    await prefs.setInt('breakfast_kcal', 0);
    await prefs.setInt('lunch_kcal', 0);
    await prefs.setInt('dinner_kcal', 0);
    await prefs.setInt('snack_kcal', 0);

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

    for (String meal in _mealFoods.keys) {
      await prefs.setString('${meal}_foods', jsonEncode(_mealFoods[meal]));
    }
  }

  // 🛠️ DIALOGUE DE CHOIX : METTRE À JOUR VIA LE CALCULATEUR OU MANUELLEMENT
  void _showAjustementOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.auto_awesome, color: accentCyan),
                title: Text("Calculateur guidé (Objectif de poids)", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                subtitle: const Text("Formule adaptative étape par étape", style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _redirectToWizardSetup();
                },
              ),
              Divider(color: Colors.grey.shade800, height: 1),
              ListTile(
                leading: Icon(Icons.edit_note, color: accentCyan),
                title: Text("Modification manuelle des macros", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                subtitle: const Text("Rentre tes propres objectifs directement", style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _showManualEditDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 📝 DIALOGUE DE MODIFICATION MANUELLE EN DIRECT SUR SUPABASE
  void _showManualEditDialog() {
    final kcalController = TextEditingController(text: _profile.targetCalories.toString());
    final protController = TextEditingController(text: _profile.targetMacros["proteins"].toString());
    final carbsController = TextEditingController(text: _profile.targetMacros["carbs"].toString());
    final lipidsController = TextEditingController(text: _profile.targetMacros["lipids"].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("Objectifs manuels", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: kcalController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Calories cibles (kcal)", labelStyle: TextStyle(color: textMuted))),
            TextField(controller: protController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Protéines cibles (g)", labelStyle: TextStyle(color: textMuted))),
            TextField(controller: carbsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Glucides cibles (g)", labelStyle: TextStyle(color: textMuted))),
            TextField(controller: lipidsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Lipides cibles (g)", labelStyle: TextStyle(color: textMuted))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler", style: TextStyle(color: textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
            onPressed: () async {
              final user = _supabase.auth.currentUser;
              if (user == null) return;

              try {
                await _supabase.from('user_profiles').upsert({
                  'user_id': user.id,
                  'target_kcal': int.tryParse(kcalController.text) ?? 2500,
                  'target_prot': int.tryParse(protController.text) ?? 150,
                  'target_carbs': int.tryParse(carbsController.text) ?? 250,
                  'target_lipids': int.tryParse(lipidsController.text) ?? 80,
                });
                Navigator.pop(context);
                _loadSupabaseTargets(); // Recharger le bandeau
              } catch (e) {
                debugPrint("Erreur sauvegarde manuelle : $e");
              }
            },
            child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _redirectToWizardSetup() async {
    final bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NutritionSetupScreen()),
    );
    if (updated == true) {
      await _loadSupabaseTargets();
    }
  }

  void _navigateToAddFood(String mealName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFoodScreen()),
    );

    if (result != null && result is Map) {
      int addedKcal = (result['kcal'] ?? 0) as int;
      String foodName = (result['name'] ?? "Aliment scanné") as String;
      
      setState(() {
        _todayNutrition.consumedCalories += addedKcal;
        _todayNutrition.proteins += (result['proteins'] ?? 0) as int;
        _todayNutrition.carbs += (result['carbs'] ?? 0) as int;
        _todayNutrition.lipids += (result['lipids'] ?? 0) as int;

        if (_mealCalories.containsKey(mealName)) {
          _mealCalories[mealName] = (_mealCalories[mealName] ?? 0) + addedKcal;
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
            tooltip: 'Ajuster mes objectifs',
            icon: Icon(Icons.tune, color: textMain),
            onPressed: _showAjustementOptions, // 👈 Ouvre les options : Guidé ou Manuel
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
            
            _buildMealRectangle(title: "Petit-déjeuner", icon: Icons.free_breakfast_outlined, kcal: _mealCalories["Petit-déjeuner"]!, foods: _mealFoods["Petit-déjeuner"]!),
            const SizedBox(height: 12),
            _buildMealRectangle(title: "Déjeuner", icon: Icons.lunch_dining_outlined, kcal: _mealCalories["Déjeuner"]!, foods: _mealFoods["Déjeuner"]!),
            const SizedBox(height: 12),
            _buildMealRectangle(title: "Dîner", icon: Icons.dinner_dining_outlined, kcal: _mealCalories["Dîner"]!, foods: _mealFoods["Dîner"]!),
            const SizedBox(height: 12),
            _buildMealRectangle(title: "Extra / Collation", icon: Icons.cookie_outlined, kcal: _mealCalories["Extra / Collation"]!, foods: _mealFoods["Extra / Collation"]!),
          ],
        ),
      ),
    );
  }

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
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

  Widget _buildMealRectangle({required String title, required IconData icon, required int kcal, required List<Map<String, dynamic>> foods}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
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
            style: TextStyle(color: kcal > 0 ? accentCyan : textMuted, fontSize: 14, fontWeight: kcal > 0 ? FontWeight.bold : FontWeight.normal),
          ),
          if (foods.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            ...foods.map((food) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(food['name'], style: TextStyle(color: textMain, fontSize: 15)),
                  Text("${food['kcal']} kcal", style: TextStyle(color: textMuted, fontSize: 14)),
                ],
              ),
            )),
          ]
        ],
      ),
    );
  }
}