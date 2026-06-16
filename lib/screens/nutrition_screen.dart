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
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
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

  // 📐 LOGIQUE DE CALCUL DU TMB ET DES MACROS JUSQU'À L'OBJECTIF
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
          // 1kg de gras de réserve ~ 7700 kcal. On lisse l'apport de manière safe (max 1000 kcal de deficit/surplus)
          ajustementCalorique = (kgParSemaine * 7700 / 7).round().clamp(-1000, 1000);
        }
      }

      // Calcul des calories cibles finales
      int finalKcal = (bej + ajustementCalorique).round().clamp(1500, 5000);

      // 4. Répartition des Macros d'un sportif de force
      int prot = (currentWeight * 2.0).round(); // 2g / kg de poids de corps
      int lipids = (currentWeight * 1.0).round(); // 1g / kg de poids de corps
      
      // Le reste des calories va aux glucides (1g prot = 4kcal, 1g lip = 9kcal, 1g gluc = 4kcal)
      int caloriesRestantes = finalKcal - (prot * 4) - (lipids * 9);
      int carbs = (caloriesRestantes / 4).round().clamp(50, 800);

      setState(() {
        _targetKcal = finalKcal;
        _targetProt = prot;
        _targetLipids = lipids;
        _targetCarbs = carbs;
      });

      // Mettre à jour en tâche de fond dans Supabase pour que le dashboard lise les bonnes valeurs cibles
      await _supabase.from('user_profiles').upsert({
        'user_id': user.id,
        'consumed_kcal': data['consumed_kcal'] ?? 0, // Ne pas écraser la nutrition du jour
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

  // 📝 QUESTIONNAIRE INTUITIF EN POPUP POUR METTRE À JOUR LE PROFIL NUTRITIONNEL
  void _showSetupNutritionDialog() async {
    final bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NutritionSetupScreen()),
    );

    if (updated == true) {
      _loadAllData(); // Recharge les macros et le bandeau après le questionnaire
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nutrition mise à jour ! 🍳"), backgroundColor: Colors.green));
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
              title: Text("Nouveau plat composé", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: mealNameController, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Nom du plat (ex: Riz Poulet Curry)", labelStyle: TextStyle(color: textMuted, fontSize: 13))),
                      const SizedBox(height: 20),
                      Text("AJOUTER UN ALIMENT", style: TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            dropdownColor: cardColor,
                            hint: Text("Choisir un ingrédient...", style: TextStyle(color: textMuted, fontSize: 14)),
                            value: selectedFood,
                            isExpanded: true,
                            items: _foodCatalog.map((food) {
                              return DropdownMenuItem<Map<String, dynamic>>(value: food, child: Text("${food['name']} (100g)", style: TextStyle(color: textMain, fontSize: 14)));
                            }).toList(),
                            onChanged: (value) => setDialogState(() => selectedFood = value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: weightController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: textMain, fontSize: 14),
                                decoration: InputDecoration(labelText: "Quantité / Poids (g)", labelStyle: TextStyle(color: textMuted, fontSize: 12), filled: true, fillColor: bgColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: bgColor, side: BorderSide(color: accentCyan.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
                            child: Text("Ajouter", style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (tempIngredients.isNotEmpty) ...[
                        Text("COMPOSITION DU PLAT", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
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
                                  color: Colors.redAccent.withOpacity(0.2),
                                  child: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                ),
                                onDismissed: (direction) {
                                  // Utilise setDialogState fourni par le StatefulBuilder de la popup
                                  setDialogState(() {
                                    tempIngredients.removeAt(idx);
                                    // Recalcule automatiquement les totaux affichés dans la preview du plat
                                    recalculateTotals();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("${ing.name} (${ing.weight}g)", style: TextStyle(color: textMain, fontSize: 13)),
                                      Text("${ing.kcal} kcal", style: TextStyle(color: textMuted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 24),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Calories totales :", style: TextStyle(color: textMuted, fontSize: 13)), Text("$totalKcal kcal", style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 14))]),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("P: ${totalProt}g", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text("G: ${totalCarbs}g", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text("L: ${totalLipids}g", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
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
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler", style: TextStyle(color: textMuted))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
                  onPressed: () async {
                    final user = _supabase.auth.currentUser;
                    if (user == null || mealNameController.text.trim().isEmpty || tempIngredients.isEmpty) return;

                    final meal = CustomMeal(name: mealNameController.text.trim(), kcal: totalKcal, prot: totalProt, carbs: totalCarbs, lipids: totalLipids);
                    await _supabase.from('custom_meals').insert(meal.toMap(user.id));
                    Navigator.pop(context);
                    _loadAllData();
                  },
                  child: const Text("Enregistrer le plat", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
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
        title: Text("Ajouter un ingrédient de base (100g)", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Nom de l'ingrédient", labelStyle: TextStyle(color: textMuted))),
              TextField(controller: kcalController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Calories (pour 100g)", labelStyle: TextStyle(color: textMuted))),
              TextField(controller: protController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Protéines (pour 100g)", labelStyle: TextStyle(color: textMuted))),
              TextField(controller: carbsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Glucides (pour 100g)", labelStyle: TextStyle(color: textMuted))),
              TextField(controller: lipidsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Lipides (pour 100g)", labelStyle: TextStyle(color: textMuted))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler", style: TextStyle(color: textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
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

              Navigator.pop(context);
              _loadAllData();
            },
            child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text("Ma Nutrition", style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
        actions: [
          IconButton(icon: const Icon(Icons.playlist_add), onPressed: _showCreateBaseFoodDialog),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentCyan))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BANDEAU DES MACROS CIBLES AUTOMATIQUES ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accentCyan.withOpacity(0.2))),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cible calculée", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text("$_targetKcal kcal / jour", style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _showSetupNutritionDialog,
                              icon: Icon(Icons.tune, size: 16, color: accentCyan),
                              label: Text("Ajuster", style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("P: ${_targetProt}g", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("G: ${_targetCarbs}g", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("L: ${_targetLipids}g", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
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
                      icon: const Icon(Icons.calculate_outlined),
                      style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      label: const Text("Composer un plat (au gramme)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text("MES PLATS ENREGISTRÉS", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _customMeals.isEmpty
                        ? Center(child: Text("Aucun plat enregistré.\nClique en haut pour composer ta première recette !", style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center))
                        : ListView.builder(
                            itemCount: _customMeals.length,
                            itemBuilder: (context, index) {
                              final meal = _customMeals[index];
                              return Card(
                                color: cardColor,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(meal.name, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      "${meal.kcal} kcal  |  P: ${meal.prot}g  |  G: ${meal.carbs}g  |  L: ${meal.lipids}g",
                                      style: TextStyle(color: textMuted, fontSize: 13),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: accentCyan, size: 28),
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