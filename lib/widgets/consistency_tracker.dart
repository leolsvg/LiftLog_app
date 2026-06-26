import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsistencyTracker extends StatefulWidget {
  const ConsistencyTracker({super.key});

  @override
  State<ConsistencyTracker> createState() => _ConsistencyTrackerState();
}

class _ConsistencyTrackerState extends State<ConsistencyTracker> {
  List<String> _completedDates = [];

  // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
  final Color cardColor = const Color(0xFF242424);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);
  final Color colorDone = const Color(0xFFC7AA0C); 
  final Color colorEmpty = const Color(0xFF1E1E1E); 

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

  // 🧹 REINITIALISATION DU TRACKER (Déclenchable par clic long sur la flamme)
  Future<void> _resetTracker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('completed_workouts'); 
    setState(() {
      _completedDates = []; 
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Calendrier réinitialisé 🧹", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          backgroundColor: cardColor,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Régularité (7 derniers jours)", style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              
              InkWell(
                onLongPress: _resetTracker, 
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.local_fire_department_rounded, color: colorDone, size: 20),
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
                    style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter')
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDone ? colorDone.withValues(alpha:0.08) : colorEmpty,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone ? colorDone : Colors.grey.shade900,
                        width: isDone ? 1.5 : 1.0,
                      ),
                    ),
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