import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeightHistoryPoint {
  final DateTime date;
  final double weight;

  WeightHistoryPoint({required this.date, required this.weight});

  factory WeightHistoryPoint.fromSupabase(Map<String, dynamic> data) {
    final workoutDate = DateTime.parse(data['workout_exercises']['workouts']['created_at']);
    final weightParam = data['weight'].toString();
    final weight = double.tryParse(weightParam) ?? 0.0;
    
    return WeightHistoryPoint(date: workoutDate, weight: weight);
  }
}

class ExerciseProgressScreen extends StatefulWidget {
  final String exerciseName;

  const ExerciseProgressScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  // --- Palette de couleurs LiftLog ---
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  List<FlSpot> _progressSpots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRealProgressData();
  }

  Future<void> _fetchRealProgressData() async {
    try {
      final response = await Supabase.instance.client
          .from('exercise_sets')
          .select('''
            weight,
            workout_exercises!inner(
              exercise_name,
              workouts!inner(created_at)
            )
          ''')
          .eq('workout_exercises.exercise_name', widget.exerciseName)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      Map<String, double> maxWeightPerDay = {};
      
      for (var row in data) {
        final point = WeightHistoryPoint.fromSupabase(row);
        String dateKey = "${point.date.year}-${point.date.month}-${point.date.day}";
        
        if (!maxWeightPerDay.containsKey(dateKey) || point.weight > maxWeightPerDay[dateKey]!) {
          maxWeightPerDay[dateKey] = point.weight;
        }
      }

      List<FlSpot> spots = [];
      int index = 1;
      maxWeightPerDay.forEach((date, maxWeight) {
        spots.add(FlSpot(index.toDouble(), maxWeight));
        index++;
      });

      setState(() {
        _progressSpots = spots;
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
        title: const Text("Progression", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: accentCyan))
          : _progressSpots.isEmpty 
              ? Center(child: Text("Aucune donnée enregistrée pour cet exercice.", style: TextStyle(color: textMuted, fontSize: 15)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.exerciseName,
                        style: TextStyle(color: textMain, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      Text(
                        "Évolution de ton poids max (kg) au fil des séances",
                        style: TextStyle(color: textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // Zone du Graphique
                      Container(
                        height: 300,
                        padding: const EdgeInsets.only(right: 24, left: 8, top: 24, bottom: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade800.withOpacity(0.5),
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
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        "S${value.toInt()}",
                                        style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 12),
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
                                      style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold),
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
                                color: accentCyan,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 5,
                                    color: bgColor,
                                    strokeWidth: 3,
                                    strokeColor: accentCyan,
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: accentCyan.withOpacity(0.15),
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
                                  Text("Record Actuel", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_progressSpots.last.y} kg",
                                    style: TextStyle(color: accentCyan, fontSize: 20, fontWeight: FontWeight.w900),
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
                                  Text("Progression totale", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "+${_progressSpots.last.y - _progressSpots.first.y} kg",
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.w900),
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