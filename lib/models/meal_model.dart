class CustomMeal {
  final String? id;
  final String name;
  final int kcal;
  final int prot;
  final int carbs;
  final int lipids;

  CustomMeal({
    this.id,
    required this.name,
    required this.kcal,
    required this.prot,
    required this.carbs,
    required this.lipids,
  });

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'name': name,
      'kcal': kcal,
      'prot': prot,
      'carbs': carbs,
      'lipids': lipids,
    };
  }

  factory CustomMeal.fromSupabase(Map<String, dynamic> map) {
    return CustomMeal(
      id: map['id'],
      name: map['name'],
      kcal: map['kcal'] ?? 0,
      prot: map['prot'] ?? 0,
      carbs: map['carbs'] ?? 0,
      lipids: map['lipids'] ?? 0,
    );
  }
}