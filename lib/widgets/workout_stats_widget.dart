import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutStatsWidget extends StatefulWidget {
  const WorkoutStatsWidget({super.key});

  @override
  State<WorkoutStatsWidget> createState() => _WorkoutStatsWidgetState();
}

class _WorkoutStatsWidgetState extends State<WorkoutStatsWidget> {
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  double _averageDuration = 0.0;
  int _totalWorkouts = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGlobalStats();
  }

  Future<void> _fetchGlobalStats() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      // Récupère uniquement les colonnes nécessaires de toutes les séances
      final response = await supabase
          .from('workouts')
          .select('duration_minutes')
          .eq('user_id', user.id);

      final List<dynamic> data = response as List<dynamic>;

      if (data.isNotEmpty) {
        int totalMinutes = 0;
        int countWithDuration = 0;

        for (var row in data) {
          final duration = row['duration_minutes'] as int?;
          if (duration != null && duration > 0) {
            totalMinutes += duration;
            countWithDuration++;
          }
        }

        setState(() {
          _totalWorkouts = data.length;
          _averageDuration = countWithDuration > 0 ? totalMinutes / countWithDuration : 0.0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Erreur lors du calcul des stats globales : $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(color: Color(0xFF38B6FF)),
      ));
    }

    if (_totalWorkouts == 0) {
      return const SizedBox.shrink(); // Rien à afficher si aucune séance n'existe encore
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800.withValues(alpha:0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Bloc Nb total de séances
            Column(
              children: [
                Text(
                  "Séances totales",
                  style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "$_totalWorkouts",
                  style: TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            
            // Séparateur vertical discret
            Container(height: 30, width: 1, color: Colors.grey.shade800),

            // Bloc Durée Moyenne
            Column(
              children: [
                Text(
                  "Durée moyenne",
                  style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _averageDuration.toStringAsFixed(0), // Arrondi propre
                      style: TextStyle(color: accentCyan, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "min",
                      style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}