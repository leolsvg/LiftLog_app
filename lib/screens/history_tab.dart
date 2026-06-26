import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _supabase = Supabase.instance.client;

  // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  // Traduction manuelle pour éviter le crash de LocaleData
  final List<String> _daysFr = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"];
  final List<String> _monthsFr = [
    "Janvier", "Février", "Mars", "Avril", "Mai", "Juin", 
    "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"
  ];

  String _formatDateFr(String isoString) {
    try {
      final DateTime date = DateTime.parse(isoString).toLocal();
      final String dayName = _daysFr[date.weekday - 1];
      final String monthName = _monthsFr[date.month - 1];
      return "$dayName ${date.day} $monthName";
    } catch (_) {
      return "Date inconnue";
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Text("Connecte-toi pour voir ton historique", style: TextStyle(color: textMain, fontFamily: 'Inter'))),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("HISTORIQUE", style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('workouts')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2));
          }

          final workoutSessions = snapshot.data ?? [];

          if (workoutSessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center_outlined, color: textMuted.withValues(alpha:0.3), size: 40),
                    const SizedBox(height: 16),
                    Text(
                      "Aucune séance enregistrée.\nIl est temps de s'entraîner ! 🦾",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted, fontSize: 13, height: 1.4, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: workoutSessions.length,
            itemBuilder: (context, index) {
              final session = workoutSessions[index];
              final String dateFormatted = _formatDateFr(session['created_at'] ?? '');
              final int duration = session['duration_minutes'] ?? 0;
              final String sessionName = session['name'] ?? "Séance sans nom";

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.emoji_events_outlined, color: accentGold, size: 18),
                  ),
                  title: Text(
                    sessionName,
                    style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter'),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      dateFormatted,
                      style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Inter'),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade900),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, color: accentGold, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "$duration min",
                          style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}