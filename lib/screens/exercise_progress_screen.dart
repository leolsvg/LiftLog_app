import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetPerformance {
  final int setOrder;
  final double weight;
  final int reps;
  final int rir;

  SetPerformance({
    required this.setOrder,
    required this.weight,
    required this.reps,
    required this.rir,
  });

  double get estimated1RM {
    int totalReps = reps + rir;
    if (totalReps <= 0) return weight;
    return weight * (1 + (totalReps / 30.0));
  }
}

class SessionPerformance {
  final DateTime date;
  final List<SetPerformance> sets;

  SessionPerformance({required this.date, required this.sets});

  double get max1RM {
    if (sets.isEmpty) return 0.0;
    return sets.map((s) => s.estimated1RM).reduce((a, b) => a > b ? a : b);
  }

  SetPerformance? get bestSet {
    if (sets.isEmpty) return null;
    return sets.reduce((a, b) => a.estimated1RM > b.estimated1RM ? a : b);
  }
}

class ExerciseProgressScreen extends StatefulWidget {
  final String exerciseName;

  const ExerciseProgressScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  // --- Palette de couleurs GAIN ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color cardLightColor = const Color(0xFF2E2E2E);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  List<SessionPerformance> _sessions = [];
  List<FlSpot> _progressSpots = [];
  bool _isLoading = true;
  double _highestOneRepMax = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchRealProgressData();
  }

  Future<void> _fetchRealProgressData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final String searchExo = widget.exerciseName.trim();

      // 1. Récupérer les séances de l'utilisateur
      final userWorkoutsResponse = await Supabase.instance.client
          .from('workouts')
          .select('id, created_at')
          .eq('user_id', user.id);

      final List<dynamic> userWorkouts = userWorkoutsResponse as List<dynamic>;

      if (userWorkouts.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final Map<dynamic, String> workoutDates = {
        for (var w in userWorkouts) w['id']: w['created_at'].toString()
      };

      // 2. Récupérer les exercices et séries
      final exercisesResponse = await Supabase.instance.client
          .from('workout_exercises')
          .select('''
            id,
            exercise_name,
            workout_id,
            exercise_sets(set_order, weight, reps, rir)
          ''')
          .ilike('exercise_name', '%$searchExo%');

      final List<dynamic> rawExercises = exercisesResponse as List<dynamic>;

      // Filtre utilisateur
      final List<dynamic> exercisesData = rawExercises.where((row) {
        return workoutDates.containsKey(row['workout_id']);
      }).toList();

      Map<String, SessionPerformance> sessionMap = {};

      for (var exerciseRow in exercisesData) {
        final workoutId = exerciseRow['workout_id'];
        final rawDate = workoutDates[workoutId];
        if (rawDate == null) continue;

        final DateTime workoutDate = DateTime.parse(rawDate);
        final List<dynamic> rawSets = exerciseRow['exercise_sets'] ?? [];

        List<SetPerformance> sets = [];
        for (var s in rawSets) {
          sets.add(
            SetPerformance(
              setOrder: s['set_order'] is int ? s['set_order'] : int.tryParse(s['set_order'].toString()) ?? 1,
              weight: double.tryParse(s['weight'].toString()) ?? 0.0,
              reps: s['reps'] is int ? s['reps'] as int : int.tryParse(s['reps'].toString()) ?? 0,
              rir: s['rir'] is int ? s['rir'] as int : int.tryParse(s['rir'].toString()) ?? 0,
            ),
          );
        }

        sets.sort((a, b) => a.setOrder.compareTo(b.setOrder));

        String dateKey = "${workoutDate.year}-${workoutDate.month.toString().padLeft(2, '0')}-${workoutDate.day.toString().padLeft(2, '0')}";

        if (!sessionMap.containsKey(dateKey)) {
          sessionMap[dateKey] = SessionPerformance(date: workoutDate, sets: sets);
        } else {
          sessionMap[dateKey]!.sets.addAll(sets);
        }
      }

      // Tri chronologique ascendant pour le graphique
      final sortedChronological = sessionMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      List<FlSpot> spots = [];
      int index = 1;
      double peak1RM = 0.0;

      for (var session in sortedChronological) {
        double max1RM = session.max1RM;
        spots.add(FlSpot(index.toDouble(), max1RM));
        if (max1RM > peak1RM) peak1RM = max1RM;
        index++;
      }

      // Tri antéchronologique (plus récent en premier) pour la liste
      final recentFirstSessions = List<SessionPerformance>.from(sortedChronological.reversed);

      if (mounted) {
        setState(() {
          _sessions = recentFirstSessions;
          _progressSpots = spots;
          _highestOneRepMax = peak1RM;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement progression : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFrenchDate(DateTime dt) {
    const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    double minY = _progressSpots.isNotEmpty
        ? (_progressSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity)
        : 0.0;
    double maxY = _progressSpots.isNotEmpty
        ? _progressSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5
        : 100.0;

    double progressGain = _progressSpots.length > 1
        ? (_progressSpots.last.y - _progressSpots.first.y)
        : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.exerciseName.toUpperCase(),
            style: TextStyle(color: textMain, fontFamily: 'Inter', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2))
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text("Aucune donnée enregistrée pour cet exercice.", style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 1. KPI CARDS COMPACTES (1RM + Progression) ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              title: "1RM ESTIMÉ MAX",
                              value: "${_highestOneRepMax.round()} kg",
                              icon: Icons.emoji_events_rounded,
                              valueColor: accentGold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              title: "PROGRESSION",
                              value: "${progressGain >= 0 ? '+' : ''}${progressGain.round()} kg",
                              icon: Icons.trending_up_rounded,
                              valueColor: progressGain >= 0 ? Colors.greenAccent.shade400 : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              title: "SÉANCES",
                              value: "${_sessions.length}",
                              icon: Icons.fitness_center_rounded,
                              valueColor: textMain,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // --- 2. GRAPHIQUE COMPACT (1RM) ---
                      Container(
                        height: 180,
                        padding: const EdgeInsets.only(right: 16, left: 4, top: 16, bottom: 8),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade900, strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  interval: 1,
                                  getTitlesWidget: (val, meta) => Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text("S${val.toInt()}", style: TextStyle(color: textMuted, fontSize: 10, fontFamily: 'Inter')),
                                  ),
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 38,
                                  getTitlesWidget: (val, meta) => Text("${val.toInt()}kg", style: TextStyle(color: textMuted, fontSize: 10, fontFamily: 'Inter')),
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0.5,
                            maxX: _progressSpots.length > 1 ? _progressSpots.length.toDouble() + 0.5 : 2.0,
                            minY: minY,
                            maxY: maxY,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _progressSpots,
                                isCurved: _progressSpots.length > 1,
                                color: accentGold,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 3.5,
                                    color: bgColor,
                                    strokeWidth: 2,
                                    strokeColor: accentGold,
                                  ),
                                ),
                                belowBarData: BarAreaData(show: true, color: accentGold.withValues(alpha: 0.08)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // --- 3. HISTORIQUE DÉTAILLÉ (POIDS × REPS) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("HISTORIQUE DES PERFORMANCES", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Inter')),
                          Text("${_sessions.length} entrées", style: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 11, fontFamily: 'Inter')),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final bestSet = session.bestSet;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Entête Séance (Date + Badge Max 1RM)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 14, color: accentGold),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatFrenchDate(session.date),
                                          style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter'),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: accentGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                      child: Text(
                                        "Max 1RM: ${session.max1RM.round()} kg",
                                        style: TextStyle(color: accentGold, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                                const SizedBox(height: 12),

                                // Grille / Liste des séries (Poids × Reps)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: session.sets.map((set) {
                                    bool isBest = bestSet != null && set == bestSet;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isBest ? accentGold.withValues(alpha: 0.15) : cardLightColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isBest ? accentGold.withValues(alpha: 0.4) : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "S${set.setOrder}  ",
                                            style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                          ),
                                          Text(
                                            "${set.weight % 1 == 0 ? set.weight.toInt() : set.weight} kg",
                                            style: TextStyle(color: isBest ? accentGold : textMain, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Inter'),
                                          ),
                                          Text(
                                            " × ${set.reps}",
                                            style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'),
                                          ),
                                          if (set.rir > 0)
                                            Text(
                                              " (RIR ${set.rir})",
                                              style: TextStyle(color: textMuted, fontSize: 10, fontFamily: 'Inter'),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'Inter'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}