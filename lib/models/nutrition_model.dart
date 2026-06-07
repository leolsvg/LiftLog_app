import 'dart:math';

class UserProfile {
  double weight;         
  double height;         
  int age;
  String gender;         
  double activityFactor; 
  int caloriesOffset;    
  String morphotype;     

  // 🆕 Les nouveaux champs pour le mode 100% libre
  bool isManualMode;
  int manualTargetCalories;
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
    this.isManualMode = false, // Désactivé par défaut
    this.manualTargetCalories = 2500,
    this.manualProt = 150,
    this.manualCarbs = 250,
    this.manualLipids = 80,
  });

  // Calcul du Métabolisme de Base
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

  // 🎯 Cible Calorique Intelligente (Choisit le mode automatique OU manuel)
  int get targetCalories {
    if (isManualMode) return manualTargetCalories;
    return (maintenanceCalories + caloriesOffset).round();
  }

  // 🎯 Cible des Macros Intelligente
  Map<String, int> get targetMacros {
    if (isManualMode) {
      return {
        "proteins": manualProt,
        "carbs": manualCarbs,
        "lipids": manualLipids,
      };
    }

    int totalKcal = targetCalories;
    int proteinGrams = (2 * weight).round();
    int proteinKcal = proteinGrams * 4;
    
    int remainingKcal = totalKcal - proteinKcal;
    double carbRatio = 0.50;
    double lipidRatio = 0.30;

    if (morphotype == "Ectomorphe") {
      carbRatio = 0.60; 
      lipidRatio = 0.20;
    } else if (morphotype == "Endomorphe") {
      carbRatio = 0.40; 
      lipidRatio = 0.40;
    }

    int carbGrams = ((remainingKcal * carbRatio) / 4).round();
    int lipidGrams = ((remainingKcal * lipidRatio) / 9).round();

    return {
      "proteins": proteinGrams,
      "carbs": carbGrams,
      "lipids": lipidGrams,
    };
  }
}

class DailyNutrition {
  int consumedCalories;
  int proteins;
  int carbs;
  int lipids;

  DailyNutrition({
    this.consumedCalories = 0,
    this.proteins = 0,
    this.carbs = 0,
    this.lipids = 0,
  });
}