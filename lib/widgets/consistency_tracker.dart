import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsistencyTracker extends StatefulWidget {
  const ConsistencyTracker({super.key});

  @override
  State<ConsistencyTracker> createState() => _ConsistencyTrackerState();
}

class _ConsistencyTrackerState extends State<ConsistencyTracker> {
  List<String> _completedDates = [];

  // --- Couleurs de ton thème LiftLog ---
  final Color cardColor = const Color(0xFF1F252D);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);
  final Color colorDone = Colors.greenAccent.shade400; 
  final Color colorEmpty = const Color(0xFF2A323C); 

  @override
  void initState() {
    super.initState();
    _loadTrackerData();
  }

  Future<void> _loadTrackerData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _completedDates = prefs.getStringList('completed_workouts') ?? [];
    });
  }

  // 🧹 FONCTION SECRÈTE DE DÉBOGAGE : TOUT EFFACER
  Future<void> _resetTracker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('completed_workouts'); // Supprime la clé de la mémoire
    setState(() {
      _completedDates = []; // Vide l'affichage instantanément
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Calendrier réinitialisé 🧹", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
    final List<String> weekDays = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Régularité (7 derniers jours)", style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold)),
              
              // 🔥 L'icône est maintenant cliquable pour effacer les données
              InkWell(
                onLongPress: _resetTracker, // Un clic long déclenche le reset
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.local_fire_department, color: colorDone),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: last7Days.map((date) {
              String dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              bool isDone = _completedDates.contains(dateString);
              
              return Column(
                children: [
                  Text(
                    weekDays[date.weekday - 1], 
                    style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: isDone ? colorDone.withOpacity(0.2) : colorEmpty,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone ? colorDone : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isDone ? Icon(Icons.check, size: 20, color: colorDone) : null,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}