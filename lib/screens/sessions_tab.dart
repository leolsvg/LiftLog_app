import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import 'history_tab.dart'; 

class SessionsTab extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final Function(WorkoutSession) onLaunchSession;
  final Function(WorkoutSession) onEditSession;
  final Function(int) onDeleteSession;
  final VoidCallback onCreateSession;
  // 🖐️ NOUVEAU : Callback pour enregistrer le réordonnancement
  final Function(int oldIndex, int newIndex) onReorderSessions;

  const SessionsTab({
    super.key,
    required this.sessions,
    required this.onLaunchSession,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.onCreateSession,
    required this.onReorderSessions,
  });

  @override
  Widget build(BuildContext context) {
    // --- Palette de couleurs GAIN (Or & Anthracite unifié) ---
    final Color bgColor = const Color(0xFF191919);
    final Color cardColor = const Color(0xFF242424);
    final Color accentGold = const Color(0xFFC7AA0C);
    final Color textMain = Colors.white;
    final Color textMuted = const Color(0xFFA0AAB5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MES PROGRAMMES',
          style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 16, letterSpacing: 0.5),
        ),
        actions: [
          // 📜 BOUTON HISTORIQUE
          IconButton(
            tooltip: 'Voir l’historique des séances',
            icon: Icon(Icons.history_rounded, color: accentGold, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryTab()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade900),
                ),
                child: Text(
                  '${sessions.length} programme(s)',
                  style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Inter'),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Divider(color: Colors.grey.shade900, height: 1),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: sessions.isEmpty
                  ? _buildEmpty(context, bgColor, cardColor, accentGold, textMain, textMuted)
                  // 🖐️ REORDERABLE LIST VIEW (Remplaçant du ListView.separated)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: sessions.length,
                      onReorder: (oldIndex, newIndex) {
                        onReorderSessions(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final exerciseCount = session.exercises.length;

                        return Container(
                          // 🔑 Chaque élément doit avoir une clé unique
                          key: ValueKey('${session.name}_$index'),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => onLaunchSession(session),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // 🖐️ Poignée de glissement (Drag Handle)
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: textMuted.withValues(alpha: 0.4),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Icône Programme
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.fitness_center_rounded, color: accentGold, size: 18),
                                    ),
                                    const SizedBox(width: 12),

                                    // Titre & Nb d'exercices
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.name,
                                            style: TextStyle(
                                              color: textMain,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$exerciseCount exercice(s)',
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 12,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Actions (Éditer / Supprimer / Lancer)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _ActionIconButton(
                                          icon: Icons.edit_rounded,
                                          tooltip: 'Modifier le programme',
                                          onPressed: () => onEditSession(session),
                                          cardColor: bgColor,
                                          iconColor: textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        _ActionIconButton(
                                          icon: Icons.delete_outline_rounded,
                                          tooltip: 'Supprimer la séance',
                                          onPressed: () => onDeleteSession(index),
                                          cardColor: bgColor,
                                          iconColor: textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade900),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.play_arrow_rounded, color: accentGold, size: 20),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'Lancer la séance',
                                            onPressed: () => onLaunchSession(session),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onCreateSession,
                  icon: Icon(Icons.add_rounded, size: 18, color: bgColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: bgColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  label: const Text(
                    'Créer un nouveau programme',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color bgColor, Color cardColor, Color accentGold, Color textMain, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_busy_rounded, color: textMuted.withValues(alpha: 0.5), size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune séance pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 6),
              Text(
                'Crée ton premier programme pour commencer à t’entraîner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, height: 1.4, fontSize: 13, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onCreateSession,
                  icon: Icon(Icons.add_rounded, size: 18, color: bgColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: bgColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  label: const Text(
                    'Créer un programme',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color iconColor;
  final Color cardColor;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.cardColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 16),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}