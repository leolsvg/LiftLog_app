class WorkoutSet {
  int weight;
  int reps;
  bool isCompleted;

  WorkoutSet({
    required this.weight,
    required this.reps,
    this.isCompleted = false,
  });
}