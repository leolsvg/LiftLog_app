class WorkoutSet {
  int weight;
  int reps;
  bool isCompleted;
  int duration; // seconds for cardio sets
  double distance; // meters for cardio sets
  int? rir; // 🦾 RIR : Répétitions en réserve avant échec (ex: 0 = Échec, 1, 2...)

  WorkoutSet({
    this.weight = 0, 
    this.reps = 0, 
    this.isCompleted = false, 
    this.duration = 0, 
    this.distance = 0.0,
    this.rir, // Optionnel par défaut
  });

  Map<String, dynamic> toMap() => {
        'weight': weight,
        'reps': reps,
        'isCompleted': isCompleted,
        'duration': duration,
        'distance': distance,
        'rir': rir, // 🔌 Sauvegarde du RIR
      };

  factory WorkoutSet.fromMap(Map<String, dynamic> map) => WorkoutSet(
        weight: map['weight'] ?? 0,
        reps: map['reps'] ?? 0,
        isCompleted: map['isCompleted'] ?? false,
        duration: map['duration'] ?? 0,
        distance: (map['distance'] ?? 0.0).toDouble(),
        rir: map['rir'], // 🔌 Récupération du RIR
      );
}

class Exercise {
  String name; 
  final List<WorkoutSet> sets;
  final bool isCardio;
  final List<String> alternatives; 
  String? imageUrl; // 🧱 Propriété pour l'image anatomique rouge
  String? notes; // 📝 Note spécifique pour l'exercice lors de cette séance

  Exercise({
    required this.name, 
    required this.sets, 
    this.isCardio = false,
    this.alternatives = const [], 
    this.imageUrl, 
    this.notes, 
  });

  // ⚡ GETTER : Calcule le meilleur PR théorique estimé (e1RM) de l'exercice pour cette séance
  int? get estimatedOneRepMax {
    if (isCardio) return null;

    // On ne prend en compte que les séries validées durant la séance
    final completedSets = sets.where((s) => s.isCompleted).toList();
    if (completedSets.isEmpty) return null;

    double maxPR = 0;

    for (var set in completedSets) {
      int rirEffective = set.rir ?? 0; // Si pas de RIR entré, on assume l'échec (0)
      int totalRepsTheoriques = set.reps + rirEffective;

      if (totalRepsTheoriques > 0) {
        // Formule d'Epley
        double currentPR = set.weight * (1 + (totalRepsTheoriques / 30.0));
        if (currentPR > maxPR) {
          maxPR = currentPR;
        }
      }
    }

    return maxPR > 0 ? maxPR.round() : null;
  }

  // Helper factory mis à jour pour inclure les alternatives, l'image et la note initiale à la création
  factory Exercise.createTarget({
    required String name, 
    int targetSets = 3, 
    int targetReps = 8, 
    int targetWeight = 0, 
    int targetDuration = 30, 
    double targetDistance = 0.0, 
    bool isCardio = false,
    List<String> alternatives = const [],
    String? imageUrl, 
    String? notes, 
  }) {
    return Exercise(
      name: name,
      isCardio: isCardio,
      alternatives: alternatives,
      imageUrl: imageUrl,
      notes: notes,
      sets: List.generate(targetSets, (_) => WorkoutSet(weight: targetWeight, reps: targetReps, duration: targetDuration, distance: targetDistance)),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'isCardio': isCardio,
        'alternatives': alternatives, 
        'image_url': imageUrl, 
        'notes': notes, 
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  Map<String, dynamic> toJson() => toFirestore();

  factory Exercise.fromFirestore(Map<String, dynamic> data) => Exercise(
        name: data['name'] ?? 'Exercice',
        isCardio: data['isCardio'] ?? false,
        alternatives: List<String>.from(data['alternatives'] ?? []), 
        imageUrl: data['image_url'], 
        notes: data['notes'], 
        sets: (data['sets'] as List?)?.map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>)).toList() ?? [],
      );

  factory Exercise.fromJson(Map<String, dynamic> data) => Exercise.fromFirestore(data);
}

class WorkoutSession {
  String name;
  final List<Exercise> exercises;
  String? notes; // 📝 Note globale de la séance d'entraînement

  WorkoutSession({required this.name, required this.exercises, this.notes});

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'notes': notes, 
        'exercises': exercises.map((e) => e.toFirestore()).toList(),
      };

  Map<String, dynamic> toJson() => toFirestore();

  factory WorkoutSession.fromFirestore(Map<String, dynamic> data) => WorkoutSession(
        name: data['name'] ?? 'Session',
        notes: data['notes'], 
        exercises: (data['exercises'] as List?)?.map((e) => Exercise.fromFirestore(e as Map<String, dynamic>)).toList() ?? [],
      );

  factory WorkoutSession.fromJson(Map<String, dynamic> data) => WorkoutSession.fromFirestore(data);
}