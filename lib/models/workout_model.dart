class WorkoutSet {
  int weight;
  int reps;
  bool isCompleted;
  int duration; // seconds for cardio sets
  double distance; // meters for cardio sets

  WorkoutSet({this.weight = 0, this.reps = 0, this.isCompleted = false, this.duration = 0, this.distance = 0.0});

  Map<String, dynamic> toMap() => {
        'weight': weight,
        'reps': reps,
        'isCompleted': isCompleted,
        'duration': duration,
        'distance': distance,
      };

  factory WorkoutSet.fromMap(Map<String, dynamic> map) => WorkoutSet(
        weight: map['weight'] ?? 0,
        reps: map['reps'] ?? 0,
        isCompleted: map['isCompleted'] ?? false,
        duration: map['duration'] ?? 0,
        distance: (map['distance'] ?? 0.0).toDouble(),
      );
}

class Exercise {
  final String name;
  final List<WorkoutSet> sets;
  final bool isCardio;

  Exercise({required this.name, required this.sets, this.isCardio = false});

  // Helper factory to create a targetted exercise quickly
  factory Exercise.createTarget({required String name, int targetSets = 3, int targetReps = 8, int targetWeight = 0, int targetDuration = 30, double targetDistance = 0.0, bool isCardio = false}) {
    return Exercise(
      name: name,
      isCardio: isCardio,
      sets: List.generate(targetSets, (_) => WorkoutSet(weight: targetWeight, reps: targetReps, duration: targetDuration, distance: targetDistance)),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'isCardio': isCardio,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  Map<String, dynamic> toJson() => toFirestore();

  factory Exercise.fromFirestore(Map<String, dynamic> data) => Exercise(
        name: data['name'] ?? 'Exercice',
        isCardio: data['isCardio'] ?? false,
        sets: (data['sets'] as List?)?.map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>)).toList() ?? [],
      );

  factory Exercise.fromJson(Map<String, dynamic> data) => Exercise.fromFirestore(data);
}

class WorkoutSession {
  String name;
  final List<Exercise> exercises;

  WorkoutSession({required this.name, required this.exercises});

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'exercises': exercises.map((e) => e.toFirestore()).toList(),
      };

  Map<String, dynamic> toJson() => toFirestore();

  factory WorkoutSession.fromFirestore(Map<String, dynamic> data) => WorkoutSession(
        name: data['name'] ?? 'Session',
        exercises: (data['exercises'] as List?)?.map((e) => Exercise.fromFirestore(e as Map<String, dynamic>)).toList() ?? [],
      );

  factory WorkoutSession.fromJson(Map<String, dynamic> data) => WorkoutSession.fromFirestore(data);
}