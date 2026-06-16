import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/weight_chart.dart';
import '../widgets/consistency_tracker.dart';
import 'account_screen.dart';
import 'history_tab.dart';
import 'nutrition_screen.dart';

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
  
  // États locaux synchronisés pour le profil
  int _targetKcal = 2500;
  int _targetProt = 150;
  int _targetCarbs = 250;
  int _targetLipids = 80;
  
  double _currentWeight = 75.0;
  double _targetWeight = 80.0;
  List<double> _weightHistory = [75.0];

  @override
  void initState() {
    super.initState();
    _fetchSessionAverageDuration();
    _loadProfileData();
  }

  // 📐 CHARGE TOUTES L'ÉVOLUTION DE PHYSIQUE ET LES CIBLES DEPUIS LE PROFIL UTILISATEUR
  Future<void> _loadProfileData() async {
    if (user == null) return;
    try {
      // Si ta colonne s'appelle target_gluc au lieu de target_carbs :
final data = await supabase.from('user_profiles').select('target_kcal, target_prot, target_gluc, target_lipids, current_weight, target_weight, weight_history').eq('user_id', user!.id).maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _targetKcal = data['target_kcal'] ?? 2500;
          _targetProt = data['target_prot'] ?? 150;
          _targetCarbs = data['target_gluc'] ?? 250; 
          _targetLipids = data['target_lipids'] ?? 80;
          _currentWeight = (data['current_weight'] ?? 75.0).toDouble();
          _targetWeight = (data['target_weight'] ?? 80.0).toDouble();
          
          if (data['weight_history'] != null) {
            _weightHistory = List<double>.from((data['weight_history'] as List).map((e) => (e as num).toDouble()));
          }
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement profil : $e");
    }
  }

  Future<void> _fetchSessionAverageDuration() async {
    if (user == null || widget.nextSessionName.isEmpty) return;
    try {
      final response = await supabase.from('workouts').select('duration_minutes').eq('user_id', user!.id).eq('name', widget.nextSessionName);
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
      if (mounted) setState(() => _averageDurationText = "-- min");
    }
  }

  Future<void> _saveWeightToSupabase(double weight, double target) async {
    if (user == null) return;
    try {
      final currentData = await supabase.from('user_profiles').select('weight_history').eq('user_id', user!.id).maybeSingle();
      List<double> history = [];
      if (currentData != null && currentData['weight_history'] != null) {
        history = List<double>.from((currentData['weight_history'] as List).map((e) => (e as num).toDouble()));
      }

      history.add(weight);
      if (history.length > 7) history.removeAt(0);

      await supabase.from('user_profiles').upsert({
        'user_id': user!.id,
        'current_weight': weight,
        'target_weight': target,
        'weight_history': history,
      });
      
      // Force le rafraîchissement local sur l'écran
      _loadProfileData();
    } catch (e) {
      debugPrint("Erreur sauvegarde poids : $e");
    }
  }

  void _logMorningWeight(double currentWeight, double targetWeight) {
    final weightController = TextEditingController(text: currentWeight.toString());
    final targetController = TextEditingController(text: targetWeight.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Pesée & Objectif', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
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
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
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

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('daily_nutrition')
          .stream(primaryKey: ['id'])
          .order('date', ascending: false),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        final nutritionData = rows.firstWhere(
          (row) => row['user_id'] == user!.id && row['date'] == todayStr,
          orElse: () => <String, dynamic>{},
        );
        
        int consumedKcal = nutritionData['consumed_kcal'] ?? 0;
        int consumedProt = nutritionData['consumed_prot'] ?? 0;
        int consumedCarbs = nutritionData['consumed_carbs'] ?? 0;
        int consumedLipids = nutritionData['consumed_lipids'] ?? 0;

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
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())).then((_) => _loadProfileData()),
                        ),
                      ],
                    ),
                  ),

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
                                    Text(_averageDurationText, style: TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.w600)),
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
                  
                  // --- NUTRITION DU JOUR DYNAMIQUE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nutrition du jour', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionScreen())).then((_) => _loadProfileData()),
                        icon: Icon(Icons.restaurant_menu, size: 16, color: accentCyan),
                        label: Text("Plats", style: TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: cardColor,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionScreen())).then((_) => _loadProfileData());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCircularMacro('Kcal', consumedKcal, _targetKcal, accentCyan),
                            _buildCircularMacro('Prot', consumedProt, _targetProt, Colors.redAccent.shade200),
                            _buildCircularMacro('Gluc', consumedCarbs, _targetCarbs, Colors.greenAccent.shade400),
                            _buildCircularMacro('Lip', consumedLipids, _targetLipids, Colors.orangeAccent.shade200),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- SECTION POIDS DE CORPS DYNAMIQUE ---
                  Text('Poids de corps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
                  const SizedBox(height: 12),
                  Card(
                    color: cardColor, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), 
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start, 
                                children: [
                                  Text('${_currentWeight.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textMain)), 
                                  if (_targetWeight > 0) Text('Objectif : ${_targetWeight.toStringAsFixed(1)} kg', style: TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.bold))
                                ]
                              ),
                              IconButton(
                                onPressed: () => _logMorningWeight(_currentWeight, _targetWeight), 
                                icon: Icon(Icons.add_circle, color: accentCyan, size: 36)
                              ),
                            ]
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180, 
                            child: WeightChart(
                              weightHistory: _weightHistory, 
                              targetWeight: _targetWeight
                            )
                          ),
                        ]
                      )
                    )
                  ),
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