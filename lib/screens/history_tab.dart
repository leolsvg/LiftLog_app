import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _supabase = Supabase.instance.client;
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
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
        body: Center(child: Text("Connecte-toi pour voir ton historique", style: TextStyle(color: textMain))),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Historique des séances", style: TextStyle(color: textMain, fontWeight: FontWeight.w900, fontSize: 22)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            return Center(child: CircularProgressIndicator(color: accentCyan));
          }

          final workoutSessions = snapshot.data ?? [];

          if (workoutSessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center_outlined, color: textMuted, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Aucune séance enregistrée.\nIl est temps de pousser ! 🦾",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted, fontSize: 15, height: 1.4),
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
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: accentCyan.withOpacity(0.1),
                    radius: 20,
                    child: Icon(Icons.emoji_events_outlined, color: accentCyan, size: 20),
                  ),
                  title: Text(
                    sessionName,
                    style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      dateFormatted,
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentCyan.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, color: accentCyan, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "$duration min",
                          style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.bold),
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