class FoodItem {
  final String name;
  final double kcalPer100g;
  final double protPer100g;
  final double carbsPer100g;
  final double lipidsPer100g;
  final String? imageUrl;

  FoodItem({
    required this.name,
    required this.kcalPer100g,
    required this.protPer100g,
    required this.carbsPer100g,
    required this.lipidsPer100g,
    this.imageUrl,
  });

  // Convertit l'objet Dart en Map pour Firestore
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'kcal': kcalPer100g,
        'prot': protPer100g,
        'carbs': carbsPer100g,
        'lipids': lipidsPer100g,
        'imageUrl': imageUrl,
      };

  // Crée l'objet Dart depuis une Map Firestore
  factory FoodItem.fromFirestore(Map<String, dynamic> data) {
    return FoodItem(
      name: data['name'] ?? 'Produit inconnu',
      kcalPer100g: (data['kcal'] ?? 0.0).toDouble(),
      protPer100g: (data['prot'] ?? 0.0).toDouble(),
      carbsPer100g: (data['carbs'] ?? 0.0).toDouble(),
      lipidsPer100g: (data['lipids'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, int> calculateMacros(double weightInGrams) {
    double multiplier = weightInGrams / 100;
    return {
      "kcal": (kcalPer100g * multiplier).round(),
      "proteins": (protPer100g * multiplier).round(),
      "carbs": (carbsPer100g * multiplier).round(),
      "lipids": (lipidsPer100g * multiplier).round(),
    };
  }

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

  factory FoodItem.fromJson(Map<String, dynamic> json) {

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    if (json.containsKey('product_name_fr') || json.containsKey('product_name')) {
      // Open Food Facts product JSON
      final nutr = json['nutriments'] ?? {};
      return FoodItem(
        name: json['product_name_fr'] ?? json['product_name'] ?? 'Produit inconnu',
        kcalPer100g: parseDouble(nutr['energy-kcal_100g']),
        protPer100g: parseDouble(nutr['proteins_100g']),
        carbsPer100g: parseDouble(nutr['carbohydrates_100g']),
        lipidsPer100g: parseDouble(nutr['fat_100g']),
        imageUrl: json['image_front_small_url'] ?? json['image_url'],
      );
    }

    // Fallback when reading from cache
    return FoodItem(
      name: json['name'] ?? 'Produit inconnu',
      kcalPer100g: parseDouble(json['kcalPer100g']),
      protPer100g: parseDouble(json['protPer100g']),
      carbsPer100g: parseDouble(json['carbsPer100g']),
      lipidsPer100g: parseDouble(json['lipidsPer100g']),
      imageUrl: json['imageUrl'],
    );
  }

  factory FoodItem.fromCacheJson(Map<String, dynamic> json) => FoodItem.fromJson(json);
}