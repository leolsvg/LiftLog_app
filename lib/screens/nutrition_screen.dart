import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_model.dart';
import 'nutrition_setup_screen.dart';

class RecipeIngredient {
  final String name;
  final int weight;
  final int kcal;
  final int prot;
  final int carbs;
  final int lipids;

  RecipeIngredient({
    required this.name,
    required this.weight,
    required this.kcal,
    required this.prot,
    required this.carbs,
    required this.lipids,
  });
}

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  final _supabase = Supabase.instance.client;
  List<CustomMeal> _customMeals = [];
  List<Map<String, dynamic>> _foodCatalog = [];
  bool _isLoading = false;

  // Variables d'objectifs calculés
  int _targetKcal = 2500;
  int _targetProt = 150;
  int _targetCarbs = 250;
  int _targetLipids = 80;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _loadUserProfileAndCalculate();
    await _loadCustomMeals();
    await _loadFoodCatalog();
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserProfileAndCalculate() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase.from('user_profiles').select().eq('user_id', user.id).maybeSingle();
      if (data == null) return;

      double currentWeight = (data['current_weight'] ?? 75.0).toDouble();
      double targetWeight = (data['target_weight'] ?? 75.0).toDouble();
      int age = data['age'] ?? 20;
      int height = data['height'] ?? 175;
      String gender = data['gender'] ?? 'homme';
      String activityLevel = data['activity_level'] ?? 'modere';
      String? targetDateStr = data['target_date'];

      // 1. Calcul du TMB (Formule de Mifflin-St Jeor)
      double tmb = (10 * currentWeight) + (6.25 * height) - (5 * age);
      tmb = (gender == 'homme') ? tmb + 5 : tmb - 161;

      // 2. Facteur d'activité (BEJ)
      double facteur = 1.2;
      if (activityLevel == 'leger') facteur = 1.375;
      if (activityLevel == 'modere') facteur = 1.55;
      if (activityLevel == 'actif') facteur = 1.725;
      double bej = tmb * facteur;

      // 3. Ajustement selon l'objectif de poids sur une durée
      double deltaPoids = targetWeight - currentWeight; 
      int ajustementCalorique = 0;

      if (deltaPoids != 0 && targetDateStr != null) {
        DateTime targetDate = DateTime.parse(targetDateStr);
        int joursRestants = targetDate.difference(DateTime.now()).inDays;
        
        if (joursRestants > 7) {
          double semaines = joursRestants / 7;
          double kgParSemaine = deltaPoids / semaines;
          ajustementCalorique = (kgParSemaine * 7700 / 7).round().clamp(-1000, 1000);
        }
      }

      int finalKcal = (bej + ajustementCalorique).round().clamp(1500, 5000);

      int prot = (currentWeight * 2.0).round(); 
      int lipids = (currentWeight * 1.0).round(); 
      
      int caloriesRestantes = finalKcal - (prot * 4) - (lipids * 9);
      int carbs = (caloriesRestantes / 4).round().clamp(50, 800);

      setState(() {
        _targetKcal = finalKcal;
        _targetProt = prot;
        _targetLipids = lipids;
        _targetCarbs = carbs;
      });

      await _supabase.from('user_profiles').upsert({
        'user_id': user.id,
        'consumed_kcal': data['consumed_kcal'] ?? 0, 
        'target_kcal': _targetKcal,
        'target_prot': _targetProt,
        'target_carbs': _targetCarbs,
        'target_lipids': _targetLipids,
      });

    } catch (e) {
      debugPrint("Erreur calcul métabolique : $e");
    }
  }

  Future<void> _loadCustomMeals() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final response = await _supabase.from('custom_meals').select().eq('user_id', user.id).order('name', ascending: true);
    _customMeals = (response as List).map((e) => CustomMeal.fromSupabase(e)).toList();
  }

  Future<void> _loadFoodCatalog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final response = await _supabase.from('food_catalog').select().eq('user_id', user.id).order('name', ascending: true);
    _foodCatalog = List<Map<String, dynamic>>.from(response);
  }

  void _showSetupNutritionDialog() async {
    final bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NutritionSetupScreen()),
    );

    if (updated == true) {
      _loadAllData(); 
    }
  }

  Future<void> _addMacrosToToday(int kcal, int prot, int carbs, int lipids) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final currentData = await _supabase.from('daily_nutrition').select().eq('user_id', user.id).eq('date', todayStr).maybeSingle();
      int currentKcal = 0, currentProt = 0, currentCarbs = 0, currentLipids = 0;

      if (currentData != null) {
        currentKcal = currentData['consumed_kcal'] ?? 0;
        currentProt = currentData['consumed_prot'] ?? 0;
        currentCarbs = currentData['consumed_carbs'] ?? 0;
        currentLipids = currentData['consumed_lipids'] ?? 0;
      }

      await _supabase.from('daily_nutrition').upsert({
        'user_id': user.id,
        'date': todayStr,
        'consumed_kcal': currentKcal + kcal,
        'consumed_prot': currentProt + prot,
        'consumed_carbs': currentCarbs + carbs,
        'consumed_lipids': currentLipids + lipids,
      }, onConflict: 'user_id,date');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Nutrition mise à jour ! 🍳", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)), 
            backgroundColor: cardColor,
          )
        );
      }
    } catch (e) {
      debugPrint("Erreur ajout macros : $e");
    }
  }

  void _showCreateMealWithCalculator() {
    final mealNameController = TextEditingController();
    final weightController = TextEditingController();
    Map<String, dynamic>? selectedFood;
    List<RecipeIngredient> tempIngredients = [];
    int totalKcal = 0, totalProt = 0, totalCarbs = 0, totalLipids = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void recalculateTotals() {
              totalKcal = tempIngredients.fold(0, (sum, item) => sum + item.kcal);
              totalProt = tempIngredients.fold(0, (sum, item) => sum + item.prot);
              totalCarbs = tempIngredients.fold(0, (sum, item) => sum + item.carbs);
              totalLipids = tempIngredients.fold(0, (sum, item) => sum + item.lipids);
            }

            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Nouveau plat composé", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: mealNameController, 
                        style: TextStyle(color: textMain, fontFamily: 'Inter'), 
                        decoration: InputDecoration(
                          labelText: "Nom du plat (ex: Riz Poulet Curry)", 
                          labelStyle: TextStyle(color: textMuted, fontSize: 13),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text("AJOUTER UN ALIMENT", style: TextStyle(color: accentGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'Inter')),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            dropdownColor: cardColor,
                            hint: Text("Choisir un ingrédient...", style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter')),
                            value: selectedFood,
                            isExpanded: true,
                            items: _foodCatalog.map((food) {
                              return DropdownMenuItem<Map<String, dynamic>>(value: food, child: Text("${food['name']} (100g)", style: TextStyle(color: textMain, fontSize: 13, fontFamily: 'Inter')));
                            }).toList(),
                            onChanged: (value) => setDialogState(() => selectedFood = value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                              child: TextField(
                                controller: weightController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: textMain, fontSize: 14, fontFamily: 'Inter'),
                                decoration: InputDecoration(labelText: "Poids (g)", labelStyle: TextStyle(color: textMuted, fontSize: 11), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: bgColor, elevation: 0, side: BorderSide(color: accentGold.withValues(alpha:0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () {
                                final int? weight = int.tryParse(weightController.text);
                                if (selectedFood == null || weight == null || weight <= 0) return;

                                final int k = ((selectedFood!['kcal_per_100g'] as int) * weight ~/ 100);
                                final int p = ((selectedFood!['prot_per_100g'] as int) * weight ~/ 100);
                                final int c = ((selectedFood!['carbs_per_100g'] as int) * weight ~/ 100);
                                final int l = ((selectedFood!['lipids_per_100g'] as int) * weight ~/ 100);

                                setDialogState(() {
                                  tempIngredients.add(RecipeIngredient(name: selectedFood!['name'], weight: weight, kcal: k, prot: p, carbs: c, lipids: l));
                                  recalculateTotals();
                                  weightController.clear();
                                  selectedFood = null;
                                });
                              },
                              child: Text("Ajouter", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (tempIngredients.isNotEmpty) ...[
                        Text("COMPOSITION DU PLAT", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'Inter')),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: tempIngredients.length,
                            itemBuilder: (context, idx) {
                              final ing = tempIngredients[idx];
                              return Dismissible(
                                key: UniqueKey(),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 12.0),
                                  decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha:0.15), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 18),
                                ),
                                onDismissed: (direction) {
                                  setDialogState(() {
                                    tempIngredients.removeAt(idx);
                                    recalculateTotals();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("${ing.name} (${ing.weight}g)", style: TextStyle(color: textMain, fontSize: 13, fontFamily: 'Inter')),
                                      Text("${ing.kcal} kcal", style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(color: Colors.grey.shade900, height: 1),
                        ),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Calories totales :", style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Inter')), Text("$totalKcal kcal", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter'))]),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("P: ${totalProt}g", style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                Text("G: ${totalCarbs}g", style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                Text("L: ${totalLipids}g", style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text("Annuler", style: TextStyle(color: textMuted, fontFamily: 'Inter')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold, 
                    foregroundColor: bgColor, 
                    elevation: 0, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final user = _supabase.auth.currentUser;
                    if (user == null || mealNameController.text.trim().isEmpty || tempIngredients.isEmpty) return;

                    // 1. Capture de l'instance de navigation AVANT le gap asynchrone
                    final navigator = Navigator.of(context);

                    final meal = CustomMeal(
                      name: mealNameController.text.trim(), 
                      kcal: totalKcal, 
                      prot: totalProt, 
                      carbs: totalCarbs, 
                      lipids: totalLipids,
                    );
                    
                    await _supabase.from('custom_meals').insert(meal.toMap(user.id));
                    
                    // 2. Vérification réglementaire du BuildContext après le await
                    if (!context.mounted) return;

                    // 3. Utilisation de la référence locale sécurisée
                    navigator.pop();
                    _loadAllData();
                  },
                  child: const Text("Enregistrer le plat", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _showCreateBaseFoodDialog() {
    final nameController = TextEditingController();
    final kcalController = TextEditingController();
    final protController = TextEditingController();
    final carbsController = TextEditingController();
    final lipidsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Ajouter un ingrédient (100g)", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, style: TextStyle(color: textMain, fontFamily: 'Inter'), decoration: InputDecoration(labelText: "Nom de l'ingrédient", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)))),
              TextField(controller: kcalController, keyboardType: TextInputType.number, style: TextStyle(color: textMain, fontFamily: 'Inter'), decoration: InputDecoration(labelText: "Calories (pour 100g)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)))),
              TextField(controller: protController, keyboardType: TextInputType.number, style: TextStyle(color: textMain, fontFamily: 'Inter'), decoration: InputDecoration(labelText: "Protéines (pour 100g)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)))),
              TextField(controller: carbsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain, fontFamily: 'Inter'), decoration: InputDecoration(labelText: "Glucides (pour 100g)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)))),
              TextField(controller: lipidsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain, fontFamily: 'Inter'), decoration: InputDecoration(labelText: "Lipides (pour 100g)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler", style: TextStyle(color: textMuted, fontFamily: 'Inter'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final user = _supabase.auth.currentUser;
              if (user == null || nameController.text.trim().isEmpty) return;

              await _supabase.from('food_catalog').insert({
                'user_id': user.id,
                'name': nameController.text.trim(),
                'kcal_per_100g': int.tryParse(kcalController.text) ?? 0,
                'prot_per_100g': int.tryParse(protController.text) ?? 0,
                'carbs_per_100g': int.tryParse(carbsController.text) ?? 0,
                'lipids_per_100g': int.tryParse(lipidsController.text) ?? 0,
              });

              // 🦾 CORRECTIF : On s'assure que l'arbre des widgets est toujours actif avant de fermer la boîte de dialogue
              if (!context.mounted) return;

              Navigator.pop(context);
              _loadAllData();
            },
            child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("MA NUTRITION", style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
        actions: [
          IconButton(icon: Icon(Icons.playlist_add_rounded, color: textMain, size: 22), onPressed: _showCreateBaseFoodDialog),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BANDEAU DES MACROS CIBLES AUTOMATIQUES ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: accentGold.withValues(alpha:0.15))),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cible calculée", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                const SizedBox(height: 2),
                                Text("$_targetKcal kcal / jour", style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _showSetupNutritionDialog,
                              icon: Icon(Icons.tune_rounded, size: 14, color: accentGold),
                              label: Text("Ajuster", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter')),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("P: ${_targetProt}g", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
                            Text("G: ${_targetCarbs}g", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
                            Text("L: ${_targetLipids}g", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateMealWithCalculator,
                      icon: Icon(Icons.calculate_outlined, size: 18, color: bgColor),
                      style: ElevatedButton.styleFrom(backgroundColor: accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      label: Text("Composer un plat (au gramme)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: bgColor, fontFamily: 'Inter')),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text("MES PLATS ENREGISTRÉS", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _customMeals.isEmpty
                        ? Center(child: Text("Aucun plat enregistré.\nClique en haut pour composer ta première recette !", style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter'), textAlign: TextAlign.center))
                        : ListView.builder(
                            itemCount: _customMeals.length,
                            key: const PageStorageKey('custom_meals_list'),
                            itemBuilder: (context, index) {
                              final meal = _customMeals[index];
                              return Card(
                                color: cardColor,
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  title: Text(meal.name, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter')),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      "${meal.kcal} kcal  |  P: ${meal.prot}g  |  G: ${meal.carbs}g  |  L: ${meal.lipids}g",
                                      style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Inter'),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.add_circle_outline_rounded, color: accentGold, size: 22),
                                    onPressed: () => _addMacrosToToday(meal.kcal, meal.prot, meal.carbs, meal.lipids),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

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