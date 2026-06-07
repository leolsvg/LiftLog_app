import 'package:flutter/material.dart';
import '../models/workout_model.dart';

class SessionsTab extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final Function(WorkoutSession) onLaunchSession;
  final Function(WorkoutSession) onEditSession;
  final Function(int) onDeleteSession;
  final VoidCallback onCreateSession;

  const SessionsTab({
    super.key,
    required this.sessions,
    required this.onLaunchSession,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.onCreateSession,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13171C),
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: const Color(0xFF171C22),
        elevation: 0,
        title: const Text(
          'Mes Programmes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.2),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.18)),
                ),
                child: Text(
                  '${sessions.length} séance(s)',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF171C22), Color(0xFF0E1115)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Colors.orangeAccent, Color(0xFF38B6FF)],
                  ),
                ),
              ),
              Expanded(
                child: sessions.isEmpty
                    ? _buildEmpty(context)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final exerciseCount = session.exercises.length;

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => onLaunchSession(session),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.orangeAccent.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.fitness_center, color: Colors.orangeAccent, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              session.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$exerciseCount exercice(s)',
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ActionIconButton(
                                            icon: Icons.edit,
                                            tooltip: 'Modifier le programme',
                                            onPressed: () => onEditSession(session),
                                          ),
                                          const SizedBox(width: 4),
                                          _ActionIconButton(
                                            icon: Icons.delete_outline,
                                            tooltip: 'Supprimer la séance',
                                            onPressed: () => onDeleteSession(index),
                                            iconColor: Colors.white70,
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.06),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
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
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: onCreateSession,
                    icon: const Icon(Icons.add),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF13171C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    label: const Text(
                      'Créer un nouveau programme',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F25),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.event_busy, color: Colors.white70, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucune séance pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crée ton premier programme pour commencer à t’entraîner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onCreateSession,
                  icon: const Icon(Icons.add),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF13171C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  label: const Text(
                    'Créer un programme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
