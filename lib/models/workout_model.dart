class WorkoutSet {
  int weight;
  int reps;
  int duration; // en minutes (Cardio)
  double distance; // en km (Cardio)
  bool isCompleted;

  WorkoutSet({
    this.weight = 0,
    this.reps = 0,
    this.duration = 0,
    this.distance = 0.0,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'duration': duration,
    'distance': distance,
    'isCompleted': isCompleted,
  };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    weight: json['weight'] ?? 0,
    reps: json['reps'] ?? 0,
    duration: json['duration'] ?? 0,
    distance: (json['distance'] ?? 0.0).toDouble(),
    isCompleted: json['isCompleted'] ?? false,
  );
}

class Exercise {
  final String name;
  final List<WorkoutSet> sets;
  final bool isCardio; // Permet de différencier le type d'affichage

  Exercise({
    required this.name,
    required this.sets,
    this.isCardio = false,
  });

  factory Exercise.createTarget({
    required String name, 
    int targetSets = 3, 
    int targetReps = 10, 
    int targetWeight = 60,
    int targetDuration = 30,
    double targetDistance = 5.0,
    bool isCardio = false,
  }) {
    return Exercise(
      name: name,
      isCardio: isCardio,
      sets: List.generate(targetSets, (_) => WorkoutSet(
        weight: targetWeight, 
        reps: targetReps,
        duration: targetDuration,
        distance: targetDistance,
      )),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'isCardio': isCardio,
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    name: json['name'],
    isCardio: json['isCardio'] ?? false,
    sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
  );
}

class WorkoutSession {
  String name;
  final List<Exercise> exercises;

  WorkoutSession({
    required this.name,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    name: json['name'],
    exercises: (json['exercises'] as List).map((e) => Exercise.fromJson(e)).toList(),
  );
}