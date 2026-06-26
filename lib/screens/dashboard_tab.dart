import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/weight_chart.dart';
import '../widgets/consistency_tracker.dart';
import 'account_screen.dart';
import 'history_tab.dart';

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
  // Styles & Palette Signatures
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  final User? user = Supabase.instance.client.auth.currentUser;
  final supabase = Supabase.instance.client;

  String _averageDurationText = "Calcul...";
  bool _isLoading = true;
  
  // Objectifs cibles (user_profiles)
  int _targetKcal = 2500;
  int _targetProt = 150;
  int _targetCarbs = 250;
  int _targetLipids = 80;
  
  // Consommation réelle du jour (daily_nutrition) connectée
  int _consumedKcal = 0;
  int _consumedProt = 0;
  int _consumedCarbs = 0;
  int _consumedLipids = 0;
  
  double _currentWeight = 75.0;
  double _targetWeight = 80.0;
  List<double> _weightHistory = [75.0];

  @override
  void initState() {
    super.initState();
    _fetchSessionAverageDuration();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _loadProfileData();
    await _loadNutritionData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    if (user == null) return;
    try {
      final data = await supabase
          .from('user_profiles')
          .select('target_kcal, target_prot, target_gluc, target_lipids, current_weight, target_weight, weight_history')
          .eq('user_id', user!.id)
          .maybeSingle();
          
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

  Future<void> _loadNutritionData() async {
    if (user == null) return;
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final data = await supabase
          .from('daily_nutrition')
          .select('consumed_kcal, consumed_prot, consumed_carbs, consumed_lipids')
          .eq('user_id', user!.id)
          .eq('date', todayStr)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _consumedKcal = data['consumed_kcal'] ?? 0;
          _consumedProt = data['consumed_prot'] ?? 0;
          _consumedCarbs = data['consumed_carbs'] ?? 0;
          _consumedLipids = data['consumed_lipids'] ?? 0;
        });
      } else {
        setState(() {
          _consumedKcal = 0;
          _consumedProt = 0;
          _consumedCarbs = 0;
          _consumedLipids = 0;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement nutrition du jour : $e");
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
                ? "${(totalMinutes / count).toStringAsFixed(0)} min en moyenne"
                : "Première fois pour cette séance !";
          });
        }
      } else {
        if (mounted) setState(() => _averageDurationText = "Nouvel entraînement");
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
      
      _loadAllData();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nouvelle pesée', style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textMain), decoration: InputDecoration(labelText: 'Poids actuel (kg)', labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
            TextField(controller: targetController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textMain), decoration: InputDecoration(labelText: 'Objectif final (kg)', labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
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
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(backgroundColor: bgColor, body: Center(child: Text("Authentification requise", style: TextStyle(color: textMain))));
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2))
            : RefreshIndicator(
                color: accentCyan,
                backgroundColor: cardColor,
                onRefresh: _loadAllData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER ---
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0, top: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Accueil', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textMain, letterSpacing: -0.5)),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.account_circle_outlined, color: textMuted, size: 26),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())).then((_) => _loadAllData()),
                            ),
                          ],
                        ),
                      ),

                      // --- SÉANCE DU JOUR ---
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accentCyan.withOpacity(0.25), width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PROCHAINE SÉANCE', style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)), 
                                  const SizedBox(height: 6), 
                                  Text(widget.nextSessionName.isEmpty ? "Aucune de planifiée" : widget.nextSessionName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.analytics_outlined, size: 13, color: accentCyan),
                                      const SizedBox(width: 6),
                                      Text(_averageDurationText, style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: widget.onStartSession, 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentCyan, 
                                foregroundColor: bgColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ), 
                              child: const Text('Lancer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- RÉGULARITÉ ---
                      const ConsistencyTracker(),
                      const SizedBox(height: 28),
                      
                      // --- NUTRITION SECTION ---
                      Text('Nutrition du jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain, letterSpacing: 0.2)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCircularMacro('Kcal', _consumedKcal, _targetKcal, accentCyan),
                            _buildCircularMacro('Prot', _consumedProt, _targetProt, Colors.redAccent.shade200),
                            _buildCircularMacro('Gluc', _consumedCarbs, _targetCarbs, Colors.greenAccent.shade400),
                            _buildCircularMacro('Lip', _consumedLipids, _targetLipids, Colors.orangeAccent.shade200),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- SUIVI CORPOREL ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Poids de corps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textMain, letterSpacing: 0.2)),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _logMorningWeight(_currentWeight, _targetWeight), 
                            icon: Icon(Icons.add_circle_outline_rounded, color: accentCyan, size: 22)
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20.0), 
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(_currentWeight.toStringAsFixed(1), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: textMain, letterSpacing: -0.5)), 
                                    const SizedBox(width: 4),
                                    Text('kg', style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (_targetWeight > 0) 
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                                    child: Text('Cible : ${_targetWeight.toStringAsFixed(1)} kg', style: TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 140, 
                              child: WeightChart(
                                weightHistory: _weightHistory, 
                                targetWeight: _targetWeight
                              )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Ronds sobres avec couleurs signatures d'origines conservées
  Widget _buildCircularMacro(String label, int consumed, int target, Color color) {
    double progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center, 
          children: [
            // Fond circulaire ultra-discret
            SizedBox(
              width: 60, 
              height: 60, 
              child: CircularProgressIndicator(value: 1.0, strokeWidth: 2.5, color: bgColor.withOpacity(0.4))
            ),
            // Arc de progression dynamique coloré
            SizedBox(
              width: 60, 
              height: 60, 
              child: CircularProgressIndicator(
                value: progress, 
                strokeWidth: 2.5, 
                color: color,
              )
            ),
            Text('$consumed', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textMain)),
          ]
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ],
    );
  }
}