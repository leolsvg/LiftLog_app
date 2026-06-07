import 'dart:math';

class UserProfile {
  double weight;
  double height;
  int age;
  String gender;
  double activityFactor;
  int caloriesOffset;
  String morphotype;
  bool isManualMode;
  int manualTargetCalories;
  // Macros en mode manuel
  int manualProt;
  int manualCarbs;
  int manualLipids;

  UserProfile({
    required this.weight,
    required this.height,
    required this.age,
    required this.gender,
    required this.activityFactor,
    required this.caloriesOffset,
    required this.morphotype,
    this.isManualMode = false,
    this.manualTargetCalories = 2500,
    this.manualProt = 0,
    this.manualCarbs = 0,
    this.manualLipids = 0,
  });

  Map<String, dynamic> toFirestore() => {
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender,
        'activityFactor': activityFactor,
        'caloriesOffset': caloriesOffset,
        'morphotype': morphotype,
        'isManualMode': isManualMode,
        'manualTargetCalories': manualTargetCalories,
      };

  factory UserProfile.fromFirestore(Map<String, dynamic> data) => UserProfile(
        weight: (data['weight'] ?? 0.0).toDouble(),
        height: (data['height'] ?? 0.0).toDouble(),
        age: data['age'] ?? 20,
        gender: data['gender'] ?? 'Homme',
        activityFactor: (data['activityFactor'] ?? 1.2).toDouble(),
        caloriesOffset: data['caloriesOffset'] ?? 0,
        morphotype: data['morphotype'] ?? 'Mésomorphe',
        isManualMode: data['isManualMode'] ?? false,
        manualTargetCalories: data['manualTargetCalories'] ?? 2500,
      );

  // ... (Garde tes getters bmr, maintenanceCalories, targetCalories ici)
  double get bmr {
    double heightInMeters = height / 100;
    if (gender == "Homme") {
      double factor = 0.963 * pow(weight, 0.48) * pow(heightInMeters, 0.50) * pow(age, -0.13);
      return factor * (1000 / 4.1855);
    } else {
      double factor = 1.083 * pow(weight, 0.48) * pow(heightInMeters, 0.50) * pow(age, -0.13);
      return factor * (1000 / 4.1855);
    }
  }

  double get maintenanceCalories => bmr * activityFactor;
  int get targetCalories {
    if (isManualMode) return manualTargetCalories;
    return (maintenanceCalories + caloriesOffset).round();
  }

  // Retourne les macros cibles (prot, carbs, lipids) en grammes
  Map<String, int> get targetMacros {
    if (isManualMode) {
      return {
        'proteins': manualProt,
        'carbs': manualCarbs,
        'lipids': manualLipids,
      };
    }

    final kcals = targetCalories;
    // Répartition par défaut : Prot 30% / Glucides 45% / Lipides 25%
    final protKcal = (kcals * 0.30).round();
    final carbsKcal = (kcals * 0.45).round();
    final lipKcal = (kcals * 0.25).round();

    return {
      'proteins': (protKcal / 4).round(),
      'carbs': (carbsKcal / 4).round(),
      'lipids': (lipKcal / 9).round(),
    };
  }
}

// Classe simple pour stocker la nutrition du jour
class DailyNutrition {
  int consumedCalories;
  int proteins;
  int carbs;
  int lipids;

  DailyNutrition({this.consumedCalories = 0, this.proteins = 0, this.carbs = 0, this.lipids = 0});
}