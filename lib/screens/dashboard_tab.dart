import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/weight_chart.dart';
import '../widgets/consistency_tracker.dart'; // 👈 Import de ton nouveau tracker

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
  // --- Palette de couleurs LiftLog (Thème sombre) ---
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  // Poids
  List<double> _weightHistory = [];
  double _currentWeight = 0.0;
  double _targetWeight = 0.0;

  // Nutrition
  int targetKcal = 2500;
  int consumedKcal = 0;
  int targetProt = 150;
  int consumedProt = 0;
  int targetCarbs = 250;
  int consumedCarbs = 0;
  int targetLipids = 80;
  int consumedLipids = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // 1. Chargement de la Nutrition
      consumedKcal = prefs.getInt('consumed_kcal') ?? 0;
      consumedProt = prefs.getInt('consumed_prot') ?? 0;
      consumedCarbs = prefs.getInt('consumed_carbs') ?? 0;
      consumedLipids = prefs.getInt('consumed_lipids') ?? 0;

      targetKcal = prefs.getInt('target_kcal') ?? 2500;
      targetProt = prefs.getInt('target_prot') ?? 150;
      targetCarbs = prefs.getInt('target_carbs') ?? 250;
      targetLipids = prefs.getInt('target_lipids') ?? 80;

      // 2. Chargement de l'historique de Poids
      List<String>? savedHistory = prefs.getStringList('weight_history');
      if (savedHistory != null && savedHistory.isNotEmpty) {
        _weightHistory = savedHistory.map((e) => double.parse(e)).toList();
        _currentWeight = _weightHistory.last;
      } else {
        _currentWeight = 75.0; 
      }
      
      _targetWeight = prefs.getDouble('target_weight') ?? 0.0;
    });
  }

  void _logMorningWeight() {
    final weightController = TextEditingController(text: _currentWeight.toString());
    final targetController = TextEditingController(text: _targetWeight > 0 ? _targetWeight.toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Pesée & Objectif', style: TextStyle(color: textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textMain),
              decoration: InputDecoration(
                labelText: 'Poids du jour (kg)', 
                labelStyle: TextStyle(color: textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentCyan)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textMain),
              decoration: InputDecoration(
                labelText: 'Objectif à atteindre (kg)', 
                hintText: 'Ex: 80.0',
                hintStyle: TextStyle(color: Colors.grey.shade700),
                labelStyle: TextStyle(color: textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Annuler', style: TextStyle(color: textMuted))
          ),
          ElevatedButton(
            onPressed: () async {
              double? newWeight = double.tryParse(weightController.text);
              double? newTarget = double.tryParse(targetController.text);
              
              if (newWeight != null) {
                final prefs = await SharedPreferences.getInstance();
                
                setState(() {
                  _currentWeight = newWeight;
                  if (newTarget != null) _targetWeight = newTarget;
                  
                  _weightHistory.add(newWeight);
                  if (_weightHistory.length > 7) {
                    _weightHistory.removeAt(0);
                  }
                });

                List<String> stringHistory = _weightHistory.map((w) => w.toString()).toList();
                await prefs.setStringList('weight_history', stringHistory);
                await prefs.setDouble('target_weight', _targetWeight);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildCircularMacro(String label, int consumed, int target, Color color) {
    double progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(width: 65, height: 65, child: CircularProgressIndicator(value: 1.0, strokeWidth: 6, color: bgColor)),
            SizedBox(
              width: 65, height: 65,
              child: CircularProgressIndicator(
                value: progress, strokeWidth: 6, strokeCap: StrokeCap.round, backgroundColor: Colors.transparent,
                color: progress >= 1.0 ? Colors.redAccent : color,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$consumed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textMain)),
                Text('/$target', style: TextStyle(color: textMuted, fontSize: 9)),
              ],
            )
          ],
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Accueil', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)), 
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // PROCHAINE SÉANCE
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: accentCyan, width: 1.5), 
                borderRadius: BorderRadius.circular(16)
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entraînement', style: TextStyle(fontSize: 14, color: textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(widget.nextSessionName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textMain)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: widget.onStartSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCyan, 
                        foregroundColor: bgColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: const Text('Lancer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ACTIVITÉ (Le nouveau composant remplace l'ancien graphique)
            const ConsistencyTracker(),
            const SizedBox(height: 32),

            // NUTRITION DU JOUR
            Text('Nutrition du jour', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
            const SizedBox(height: 12),
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircularMacro('Kcal', consumedKcal, targetKcal, accentCyan),
                    _buildCircularMacro('Prot', consumedProt, targetProt, Colors.redAccent.shade200),
                    _buildCircularMacro('Gluc', consumedCarbs, targetCarbs, Colors.greenAccent.shade400),
                    _buildCircularMacro('Lip', consumedLipids, targetLipids, Colors.orangeAccent.shade200),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // POIDS DE CORPS
            Text('Poids de corps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
            const SizedBox(height: 12),
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            Text('$_currentWeight kg', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textMain)),
                            if (_targetWeight > 0)
                              Text('Objectif : $_targetWeight kg', style: TextStyle(fontSize: 14, color: accentCyan, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        IconButton(
                          onPressed: _logMorningWeight,
                          icon: Icon(Icons.add_circle, color: accentCyan, size: 36),
                          tooltip: 'Nouvelle pesée',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 180, 
                      width: double.infinity,
                      padding: const EdgeInsets.only(right: 16, top: 10),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                      child: WeightChart(weightHistory: _weightHistory, targetWeight: _targetWeight),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}