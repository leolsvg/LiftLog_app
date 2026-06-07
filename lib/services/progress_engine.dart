import '../models/workout_model.dart';

class PredictionResult {
  final int nextWeight;
  final int nextReps;
  final String advice;
  final bool triggerDeload;

  PredictionResult({
    required this.nextWeight,
    required this.nextReps,
    required this.advice,
    this.triggerDeload = false,
  });
}

class ProgressEngine {
  /// Analyse les performances actuelles d'un exercice et prédit la suite
  static PredictionResult predictNextSession({
    required Exercise currentExercise,
    required int targetReps,
  }) {
    // 1. Protection : Si aucune série n'est validée (cochée), on maintient l'objectif actuel
    List<WorkoutSet> completedSets = currentExercise.sets.where((s) => s.isCompleted).toList();
    if (completedSets.isEmpty) {
      int currentWeight = currentExercise.sets.isNotEmpty ? currentExercise.sets.first.weight : 60;
      return PredictionResult(
        nextWeight: currentWeight,
        nextReps: targetReps,
        advice: "Pense à cocher tes séries une fois validées à la salle !",
      );
    }

    // On récupère le poids de travail principal et le nombre de séries prévues
    int currentWeight = completedSets.first.weight;
    int totalTargetSets = currentExercise.sets.length;

    // 2. Vérification du succès complet (Toutes les séries cochées ont atteint ou dépassé les reps visées)
    bool allSetsAchievedTarget = completedSets.length == totalTargetSets && 
        completedSets.every((set) => set.reps >= targetReps);

    if (allSetsAchievedTarget) {
      // Calcul de la progression selon la charge
      int weightIncrement = currentWeight >= 100 ? 5 : 2; // +5kg si lourd (Squat/Couché), sinon +2.5kg (arrondi à 2)
      int nextWeight = currentWeight + weightIncrement;
      
      return PredictionResult(
        nextWeight: nextWeight,
        nextReps: targetReps,
        advice: "🔥 Cycle validé ! Progression validée : +$weightIncrement kg pour la prochaine fois.",
      );
    }

    // 3. Cas de stagnation sévère (L'utilisateur régresse ou n'atteint pas du tout la moyenne)
    // Si la moyenne des reps validées est inférieure à 70% de l'objectif sur les séries tentées
    double avgReps = completedSets.map((s) => s.reps).reduce((a, b) => a + b) / completedSets.length;
    if (avgReps < (targetReps * 0.7)) {
      int deloadWeight = (currentWeight * 0.9).round(); // -10% sur la barre (Règle de déload automatique)
      return PredictionResult(
        nextWeight: deloadWeight,
        nextReps: targetReps,
        advice: "⚠️ Fatigue détectée ou charge trop lourde. Déload recommandé de -10% pour reconstruire proprement.",
        triggerDeload: true,
      );
    }

    // 4. Cas intermédiaire : On maintient le poids pour valider les reps manquantes au prochain coup
    return PredictionResult(
      nextWeight: currentWeight,
      nextReps: targetReps,
      advice: "💪 C'est bien bataillé. Reste à ce poids la prochaine fois pour valider toutes tes répétitions.",
    );
  }
}