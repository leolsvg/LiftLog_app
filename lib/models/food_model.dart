class FoodItem {
  final String name;
  final double kcalPer100g;
  final double protPer100g;
  final double carbsPer100g;
  final double lipidsPer100g;
  final String? imageUrl; // 🌟 Petit bonus : l'API nous donne souvent l'image du produit !

  FoodItem({
    required this.name,
    required this.kcalPer100g,
    required this.protPer100g,
    required this.carbsPer100g,
    required this.lipidsPer100g,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kcalPer100g': kcalPer100g,
      'protPer100g': protPer100g,
      'carbsPer100g': carbsPer100g,
      'lipidsPer100g': lipidsPer100g,
      'imageUrl': imageUrl,
    };
  }

  // Traducteur : Convertit les données brutes d'Open Food Facts en un objet FoodItem propre
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final nutriments = json['nutriments'] ?? {};
    
    // Fonction de sécurité car l'API peut renvoyer des entiers (10) ou des décimales (10.5)
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FoodItem(
      // Prend le nom français en priorité, sinon le nom générique
      name: json['product_name_fr'] ?? json['product_name'] ?? 'Produit inconnu',
      kcalPer100g: parseDouble(nutriments['energy-kcal_100g']),
      protPer100g: parseDouble(nutriments['proteins_100g']),
      carbsPer100g: parseDouble(nutriments['carbohydrates_100g']),
      lipidsPer100g: parseDouble(nutriments['fat_100g']),
      imageUrl: json['image_front_small_url'],
    );
  }

  factory FoodItem.fromCacheJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FoodItem(
      name: json['name'] as String? ?? 'Produit inconnu',
      kcalPer100g: parseDouble(json['kcalPer100g']),
      protPer100g: parseDouble(json['protPer100g']),
      carbsPer100g: parseDouble(json['carbsPer100g']),
      lipidsPer100g: parseDouble(json['lipidsPer100g']),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  // La fameuse règle de 3 pour ajuster selon l'assiette
  Map<String, int> calculateMacros(double weightInGrams) {
    double multiplier = weightInGrams / 100;
    return {
      "kcal": (kcalPer100g * multiplier).round(),
      "proteins": (protPer100g * multiplier).round(),
      "carbs": (carbsPer100g * multiplier).round(),
      "lipids": (lipidsPer100g * multiplier).round(),
    };
  }
}