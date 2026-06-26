import 'package:flutter/material.dart';
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
    age: 20, // Reste calé sur tes données réelles de profil
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
    _syncWithSupabase();
  }

  Future<void> _syncWithSupabase() async {
    await _loadSupabaseTargets();
    await _loadNutritionFromSupabase();
  }

  // ☁️ ENVOIE TOUT LE JOURNAL ET LES MACROS SUR SUPABASE
  Future<void> _syncNutritionToSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    int totalKcal = 0;
    int totalProt = 0;
    int totalCarbs = 0;
    int totalLipids = 0;

    for (var mealTitle in _mealCalories.keys) {
      final List<Map<String, dynamic>> foods = _mealFoods[mealTitle] ?? []; 
      for (var food in foods) {
        totalKcal += (food['kcal'] ?? 0) as int;
        totalProt += (food['proteins'] ?? 0) as int;
        totalCarbs += (food['carbs'] ?? 0) as int;
        totalLipids += (food['lipids'] ?? 0) as int;
      }
    }

    try {
      await _supabase.from('daily_nutrition').upsert({
        'user_id': user.id,
        'date': todayStr,
        'consumed_kcal': totalKcal,
        'consumed_prot': totalProt,
        'consumed_carbs': totalCarbs,
        'consumed_lipids': totalLipids,
        'meals_json': _mealFoods, // 💾 Sauvegarde la structure complète de la journée au format JSON
      });
      debugPrint("🔥 Nutrition entièrement sauvegardée sur le Cloud !");
    } catch (e) {
      debugPrint("❌ Erreur de synchro nutrition : $e");
    }
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

  // ☁️ RÉCUPÈRE LE JOURNAL DEPUIS LE CLOUD TIMÉ SUR AUJOURD'HUI
  Future<void> _loadNutritionFromSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final data = await _supabase
          .from('daily_nutrition')
          .select('consumed_kcal, consumed_prot, consumed_carbs, consumed_lipids, meals_json')
          .eq('user_id', user.id)
          .eq('date', todayStr)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _todayNutrition.consumedCalories = data['consumed_kcal'] ?? 0;
          _todayNutrition.proteins = data['consumed_prot'] ?? 0;
          _todayNutrition.carbs = data['consumed_carbs'] ?? 0;
          _todayNutrition.lipids = data['consumed_lipids'] ?? 0;

          if (data['meals_json'] != null) {
            final Map<String, dynamic> decodedMeals = data['meals_json'] as Map<String, dynamic>;
            
            for (String meal in _mealFoods.keys) {
              if (decodedMeals.containsKey(meal)) {
                _mealFoods[meal] = List<Map<String, dynamic>>.from(decodedMeals[meal]);
                
                // On recalcule les calories par repas
                int mealKcal = 0;
                for (var food in _mealFoods[meal]!) {
                  mealKcal += (food['kcal'] ?? 0) as int;
                }
                _mealCalories[meal] = mealKcal;
              }
            }
          }
        });
      } else {
        // Si aucune donnée pour aujourd'hui, on initialise une journée propre à 0
        _resetLocalStateData();
      }
    } catch (e) {
      debugPrint("Erreur de chargement nutrition cloud : $e");
    }
  }

  void _resetLocalStateData() {
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
              ListTypeIcon(
                leading: Icon(Icons.auto_awesome, color: accentCyan),
                title: Text("Calculateur guidé (Objectif de poids)", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                subtitle: const Text("Formule adaptative étape par étape", style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _redirectToWizardSetup();
                },
              ),
              Divider(color: Colors.grey.shade800, height: 1),
              ListTypeIcon(
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
                if (context.mounted) Navigator.pop(context);
                _loadSupabaseTargets(); 
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
            'proteins': (result['proteins'] ?? 0) as int,
            'carbs': (result['carbs'] ?? 0) as int,
            'lipids': (result['lipids'] ?? 0) as int,
          });
        }
      });
      await _syncNutritionToSupabase(); 
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
            onPressed: _showAjustementOptions,
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
            ...foods.map((food) {
              final String foodKey = "${food['name']}_${foods.indexOf(food)}";
              
              return Dismissible(
                key: Key(foodKey),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                ),
                onDismissed: (direction) {
                  setState(() {
                    _todayNutrition.consumedCalories -= (food['kcal'] ?? 0) as int;
                    _todayNutrition.proteins -= (food['proteins'] ?? 0) as int;
                    _todayNutrition.carbs -= (food['carbs'] ?? 0) as int;
                    _todayNutrition.lipids -= (food['lipids'] ?? 0) as int;

                    _mealCalories[title] = (_mealCalories[title] ?? 0) - (food['kcal'] ?? 0) as int;
                    foods.remove(food);
                  });
                  
                  _syncNutritionToSupabase(); // Aligné directement en ligne après suppression

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${food['name']} supprimé"),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(food['name'], style: TextStyle(color: textMain, fontSize: 15)),
                      Text("${food['kcal']} kcal", style: TextStyle(color: textMuted, fontSize: 14)),
                    ],
                  ),
                ),
              );
            }),
          ]
        ],
      ),  
    );
  }
}

// Remplacement temporaire pour compilation propre si besoin
class ListTypeIcon extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  const ListTypeIcon({super.key, required this.leading, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: leading, title: title, subtitle: subtitle, onTap: onTap);
  }
}