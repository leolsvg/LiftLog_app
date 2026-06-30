import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeightHistoryPoint {
  final DateTime date;
  final double weight;
  final int reps;
  final int rir;

  WeightHistoryPoint({
    required this.date, 
    required this.weight, 
    required this.reps, 
    required this.rir
  });

  // Calcule le 1RM théorique pour ce point précis
  double get estimatedOneRepMax {
    int totalReps = reps + rir;
    if (totalReps <= 0) return weight;
    return weight * (1 + (totalReps / 30.0));
  }

  factory WeightHistoryPoint.fromSupabase(Map<String, dynamic> data) {
    final workoutDate = DateTime.parse(data['workout_exercises']['workouts']['created_at']);
    final weightParam = data['weight'].toString();
    final weight = double.tryParse(weightParam) ?? 0.0;
    final reps = data['reps'] is int ? data['reps'] : int.tryParse(data['reps'].toString()) ?? 0;
    // Récupération sécurisée du RIR (0 si nul)
    final rir = data['rir'] is int ? data['rir'] : int.tryParse(data['rir'].toString()) ?? 0;
    
    return WeightHistoryPoint(date: workoutDate, weight: weight, reps: reps, rir: rir);
  }
}

class ExerciseProgressScreen extends StatefulWidget {
  final String exerciseName;

  const ExerciseProgressScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  List<FlSpot> _progressSpots = [];
  bool _isLoading = true;
  double _highestOneRepMax = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchRealProgressData();
  }

  Future<void> _fetchRealProgressData() async {
    try {
      // 🔌 MISE À REQUÊTE : On demande aussi reps et rir pour faire le calcul
      final response = await Supabase.instance.client
          .from('exercise_sets')
          .select('''
            weight,
            reps,
            rir,
            workout_exercises!inner(
              exercise_name,
              workouts!inner(created_at)
            )
          ''')
          .eq('workout_exercises.exercise_name', widget.exerciseName)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      Map<String, double> max1RMPerDay = {};
      
      for (var row in data) {
        final point = WeightHistoryPoint.fromSupabase(row);
        String dateKey = "${point.date.year}-${point.date.month}-${point.date.day}";
        double calculated1RM = point.estimatedOneRepMax;
        
        // On conserve le meilleur 1RM théorique calculé de la journée
        if (!max1RMPerDay.containsKey(dateKey) || calculated1RM > max1RMPerDay[dateKey]!) {
          max1RMPerDay[dateKey] = calculated1RM;
        }
      }

      List<FlSpot> spots = [];
      int index = 1;
      double peak1RM = 0.0;

      max1RMPerDay.forEach((date, max1RM) {
        spots.add(FlSpot(index.toDouble(), max1RM));
        if (max1RM > peak1RM) peak1RM = max1RM;
        index++;
      });

      setState(() {
        _progressSpots = spots;
        _highestOneRepMax = peak1RM;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur Supabase: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("PROGRESSION", style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2))
          : _progressSpots.isEmpty 
              ? Center(child: Text("Aucune donnée enregistrée pour cet exercice.", style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter')))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.exerciseName.toUpperCase(),
                        style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Évolution de ton 1RM maximal estimé (Formule d'Epley + RIR)",
                        style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 32),

                      // Zone du Graphique Épurée
                      Container(
                        height: 280,
                        padding: const EdgeInsets.only(right: 20, left: 4, top: 20, bottom: 8),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade900,
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        "S${value.toInt()}",
                                        style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Inter'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 42,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      "${value.toInt()}kg",
                                      style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 1,
                            maxX: _progressSpots.length.toDouble(),
                            minY: _progressSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5,
                            maxY: _progressSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _progressSpots,
                                isCurved: true,
                                color: accentGold,
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 4,
                                    color: bgColor,
                                    strokeWidth: 2.5,
                                    strokeColor: accentGold,
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: accentGold.withValues(alpha:0.06),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Record 1RM Estimé", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_highestOneRepMax.round()} kg",
                                    style: TextStyle(color: accentGold, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Gain de force total", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                  const SizedBox(height: 4),
                                  Text(
                                    "+${(_progressSpots.last.y - _progressSpots.first.y).round()} kg",
                                    style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
    );
  }
}