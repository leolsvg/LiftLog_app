import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/weight_chart.dart';
import '../widgets/consistency_tracker.dart';
import 'account_screen.dart'; // Import important pour le bouton compte

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

  final User? user = FirebaseAuth.instance.currentUser;

  Future<void> _saveWeightToFirestore(double weight, double target) async {
    if (user == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final doc = await docRef.get();
    List<dynamic> history = doc.exists ? (doc.data() as Map)['weightHistory'] ?? [] : [];
    
    history.add(weight);
    if (history.length > 7) history.removeAt(0);

    await docRef.set({
      'currentWeight': weight,
      'targetWeight': target,
      'weightHistory': history,
    }, SetOptions(merge: true));
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
              if (w != null) _saveWeightToFirestore(w, t ?? 0.0);
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: accentCyan)));
        
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        int consumedKcal = data['consumedKcal'] ?? 0;
        int consumedProt = data['consumedProt'] ?? 0;
        int consumedCarbs = data['consumedCarbs'] ?? 0;
        int consumedLipids = data['consumedLipids'] ?? 0;
        double currentWeight = (data['currentWeight'] ?? 75.0).toDouble();
        double targetWeight = (data['targetWeight'] ?? 0.0).toDouble();
        List<dynamic> weightHistory = data['weightHistory'] ?? [75.0];

        return Scaffold(
          backgroundColor: bgColor,
          // PAS D'APPBAR ICI -> On utilise une SafeArea + un custom Row
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CUSTOM HEADER (Remplace l'AppBar) ---
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
                  // ----------------------------------------

                  // Carte Séance
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(side: BorderSide(color: accentCyan, width: 1.5), borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Entraînement', style: TextStyle(color: textMuted)), const SizedBox(height: 6), Text(widget.nextSessionName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textMain))])),
                          ElevatedButton(onPressed: widget.onStartSession, style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor), child: const Text('Lancer')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const ConsistencyTracker(),
                  const SizedBox(height: 32),
                  
                  // Nutrition
                  Text('Nutrition du jour', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain)),
                  const SizedBox(height: 12),
                  Card(color: cardColor, child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _buildCircularMacro('Kcal', consumedKcal, 2500, accentCyan),
                    _buildCircularMacro('Prot', consumedProt, 150, Colors.redAccent.shade200),
                    _buildCircularMacro('Gluc', consumedCarbs, 250, Colors.greenAccent.shade400),
                    _buildCircularMacro('Lip', consumedLipids, 80, Colors.orangeAccent.shade200),
                  ]))),
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