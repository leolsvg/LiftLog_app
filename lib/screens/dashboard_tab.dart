import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/weight_chart.dart';
import '../widgets/consistency_tracker.dart';
import 'account_screen.dart';
import 'nutrition_screen.dart'; // <-- Importation du nouvel écran de nutrition

class DashboardTab extends StatefulWidget {
  final String nextSessionName;
  final VoidCallback onStartSession;

  const DashboardTab({
    super.key,
    required this.nextSessionName,
    required this.onStartSession,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  final User? user = Supabase.instance.client.auth.currentUser;
  final supabase = Supabase.instance.client;

  String _averageDurationText = "Calcul...";

  @override
  void initState() {
    super.initState();
    _fetchSessionAverageDuration();
  }

  @override
  void didUpdateWidget(covariant DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextSessionName != widget.nextSessionName) {
      _fetchSessionAverageDuration();
    }
  }

  Future<void> _fetchSessionAverageDuration() async {
    if (user == null || widget.nextSessionName.isEmpty) return;

    try {
      final response = await supabase
          .from('workouts')
          .select('duration_minutes')
          .eq('user_id', user!.id)
          .eq('name', widget.nextSessionName);

      final List<dynamic> data = response as List<dynamic>;

      if (data.isNotEmpty) {
        int totalMinutes = 0;
        int count = 0;

        for (var row in data) {
          final duration = row['duration_minutes'] as int?;
          if (duration != null && duration > 0) {
            totalMinutes += duration;
            count++;
          }
        }

        if (mounted) {
          setState(() {
            _averageDurationText = count > 0 
                ? "Durée moyenne : ${(totalMinutes / count).toStringAsFixed(0)} min"
                : "Première fois pour cette séance !";
          });
        }
      } else {
        if (mounted) setState(() => _averageDurationText = "Pas encore d'historique");
      }
    } catch (e) {
      debugPrint("Erreur durée moyenne : $e");
      if (mounted) setState(() => _averageDurationText = "-- min");
    }
  }

  Future<void> _saveWeightToSupabase(double weight, double target) async {
    if (user == null) return;

    try {
      final currentData = await supabase
          .from('user_profiles')
          .select('weight_history')
          .eq('user_id', user!.id)
          .maybeSingle();

      List<double> history = [];
      if (currentData != null && currentData['weight_history'] != null) {
        history = List<double>.from(
          (currentData['weight_history'] as List).map((e) => (e as num).toDouble()),
        );
      }

      history.add(weight);
      if (history.length > 7) history.removeAt(0);

      await supabase.from('user_profiles').upsert({
        'user_id': user!.id,
        'current_weight': weight,
        'target_weight': target,
        'weight_history': history,
      });
    } catch (e) {
      debugPrint("Erreur lors de la sauvegarde du poids : $e");
    }
  }

  void _logMorningWeight(double currentWeight, double targetWeight) {
    final weightController = TextEditingController(text: currentWeight.toString());
    final targetController = TextEditingController(text: targetWeight.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Pesée & Objectif', style: TextStyle(color: textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textMain), decoration: InputDecoration(labelText: 'Poids du jour (kg)', labelStyle: TextStyle(color: textMuted))),
            TextField(controller: targetController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textMain), decoration: InputDecoration(labelText: 'Objectif (kg)', labelStyle: TextStyle(color: textMuted))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted))),
          ElevatedButton(
            onPressed: () {
              double? w = double.tryParse(weightController.text);
              double? t = double.tryParse(targetController.text);
              if (w != null) _saveWeightToSupabase(w, t ?? 0.0);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
            child: const Text('Enregistrer'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(backgroundColor: bgColor, body: Center(child: Text("Connecte-toi", style: TextStyle(color: textMain))));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('user_profiles').stream(primaryKey: ['user_id']).eq('user_id', user!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: accentCyan)));
        }

        final data = (snapshot.data != null && snapshot.data!.isNotEmpty) ? snapshot.data!.first : {};
        
        int consumedKcal = data['consumed_kcal'] ?? 0;
        int consumedProt = data['consumed_prot'] ?? 0;
        int consumedCarbs = data['consumed_carbs'] ?? 0;
        int consumedLipids = data['consumed_lipids'] ?? 0;
        double currentWeight = (data['current_weight'] ?? 75.0).toDouble();
        double targetWeight = (data['target_weight'] ?? 0.0).toDouble();
        List<dynamic> weightHistory = data['weight_history'] ?? [75.0];

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CUSTOM HEADER ---
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0, bottom: 20.0, left: 4.0, right: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Accueil', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textMain)),
                        IconButton(
                          icon: Icon(Icons.account_circle_outlined, color: textMain, size: 30),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
                        ),
                      ],
                    ),
                  ),
                  // ---------------------

                  // Carte Séance
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(side: BorderSide(color: accentCyan, width: 1.5), borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Entraînement', style: TextStyle(color: textMuted)), 
                                const SizedBox(height: 4), 
                                Text(widget.nextSessionName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textMain)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: accentCyan.withOpacity(0.8)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _averageDurationText, 
                                      style: TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.w600)
                                    ),
                                  ],
                                ),
                              ]
                            )
                          ),
                          ElevatedButton(onPressed: widget.onStartSession, style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor), child: const Text('Lancer')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const ConsistencyTracker(),
                  const SizedBox(height: 32),
                  
                  // --- NUTRITION DU JOUR (MAINTENANT CLIQUABLE) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nutrition du jour', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionScreen())),
                        icon: Icon(Icons.restaurant_menu, size: 16, color: accentCyan),
                        label: Text("Plats", style: TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: cardColor,
                    clipBehavior: Clip.antiAlias, // Assure que l'effet InkWell épouse bien les angles de la Card
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () {
                        // Le clic sur le conteneur ouvre la gestion de la nutrition et des plats perso
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NutritionScreen()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCircularMacro('Kcal', consumedKcal, 2500, accentCyan),
                            _buildCircularMacro('Prot', consumedProt, 150, Colors.redAccent.shade200),
                            _buildCircularMacro('Gluc', consumedCarbs, 250, Colors.greenAccent.shade400),
                            _buildCircularMacro('Lip', consumedLipids, 80, Colors.orangeAccent.shade200),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Poids
                  Text('Poids de corps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
                  const SizedBox(height: 12),
                  Card(color: cardColor, child: Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$currentWeight kg', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textMain)), if (targetWeight > 0) Text('Objectif : $targetWeight kg', style: TextStyle(color: accentCyan))]),
                      IconButton(onPressed: () => _logMorningWeight(currentWeight, targetWeight), icon: Icon(Icons.add_circle, color: accentCyan, size: 36)),
                    ]),
                    SizedBox(height: 180, child: WeightChart(weightHistory: weightHistory.map((e) => (e as num).toDouble()).toList(), targetWeight: targetWeight)),
                  ]))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircularMacro(String label, int consumed, int target, Color color) {
    double progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(width: 65, height: 65, child: CircularProgressIndicator(value: 1.0, strokeWidth: 6, color: bgColor)),
        SizedBox(width: 65, height: 65, child: CircularProgressIndicator(value: progress, strokeWidth: 6, color: color)),
        Text('$consumed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textMain)),
      ]),
      const SizedBox(height: 10),
      Text(label, style: TextStyle(color: textMuted, fontSize: 13)),
    ]);
  }
}