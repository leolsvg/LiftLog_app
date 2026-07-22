import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_model.dart';
import 'barcode_scanner_screen.dart';

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(); 
  static const Duration _searchCacheTtl = Duration(hours: 12);
  
  List<FoodItem> _searchResults = [];
  FoodItem? _selectedFood;
  double _currentWeight = 100.0;
  bool _isLoading = false;

  List<Map<String, dynamic>> _savedCustomMeals = [];

  // --- Palette de couleurs GAIN (Or & Anthracite) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  // En-tête strict imposé par la charte d'utilisation de l'API Open Food Facts
  final Map<String, String> _apiHeaders = {
    'User-Agent': 'GAIN - Android - Version 1.1.0 - Contact: developer.leo.cherbourg@gmail.com',
    'Accept': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _loadCustomMeals();
    _weightController.text = _currentWeight.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final String? mealsJson = prefs.getString('saved_custom_meals');
    
    if (mealsJson != null) {
      List<dynamic> decoded = jsonDecode(mealsJson);
      setState(() {
        _savedCustomMeals = decoded.map((e) => e as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _saveCustomMeals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_custom_meals', jsonEncode(_savedCustomMeals));
  }

  String _cacheKeyForQuery(String query) {
    final normalized = query.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'food_search_cache_$normalized';
  }

  Future<List<FoodItem>?> _loadCachedSearchResults(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKeyForQuery(query));
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final timestamp = DateTime.tryParse(decoded['timestamp'] as String? ?? '');
    final items = decoded['items'];
    if (timestamp == null || DateTime.now().difference(timestamp) > _searchCacheTtl) {
      await prefs.remove(_cacheKeyForQuery(query));
      return null;
    }

    if (items is! List) return null;

    return items
        .whereType<Map<String, dynamic>>()
        .map(FoodItem.fromCacheJson)
        .toList();
  }

  Future<void> _saveCachedSearchResults(String query, List<FoodItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKeyForQuery(query),
      jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<List<FoodItem>> _fetchFoodsFromOpenFoodFacts(String query, {required String host}) async {
    final url = Uri.https(host, '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '25',
      'sort_by': 'unique_scans_n', // Trie par popularité réelle des scans pour remonter le basique en premier
      'fields': 'product_name_fr,product_name,nutriments,image_front_small_url,brands',
      'countries_tags': 'en:france', // Cible le catalogue français en priorité
    });

    final response = await http.get(url, headers: _apiHeaders).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final products = (data is Map<String, dynamic> ? data['products'] : null) as List<dynamic>?;
    if (products == null) {
      throw Exception('Réponse API invalide');
    }

    return products.map((p) => FoodItem.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<void> _searchByText(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedFood = null;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _selectedFood = null;
    });

    try {
      List<FoodItem> finalResults = [];

      // 1️⃣ Recherche locale prioritaire dans "Mes plats fréquents" avec tous les arguments requis
      final String normalizedQuery = query.toLowerCase().trim();
      final localMatches = _savedCustomMeals.where((meal) {
        final String mealName = (meal['name'] ?? '').toString().toLowerCase();
        return mealName.contains(normalizedQuery);
      }).toList();

      for (var meal in localMatches) {
        finalResults.add(
          FoodItem(
            name: "⭐️ ${meal['name']}",
            kcalPer100g: (meal['kcal'] as num? ?? 0).toDouble(),
            protPer100g: (meal['proteins'] as num? ?? 0).toDouble(),
            carbsPer100g: (meal['carbs'] as num? ?? 0).toDouble(),
            lipidsPer100g: (meal['lipids'] as num? ?? 0).toDouble(),
            imageUrl: null,
          ),
        );
      }

      // 2️⃣ Recherche dans le cache local (SharedPreferences)
      final cachedResults = await _loadCachedSearchResults(query);
      if (cachedResults != null && cachedResults.isNotEmpty) {
        finalResults.addAll(cachedResults);
        setState(() {
          _searchResults = finalResults;
        });
        return;
      }

      // 3️⃣ Requête distante avec l'API Open Food Facts
      List<FoodItem> apiResults;
      try {
        apiResults = await _fetchFoodsFromOpenFoodFacts(query, host: 'fr.openfoodfacts.org');
      } catch (_) {
        apiResults = await _fetchFoodsFromOpenFoodFacts(query, host: 'world.openfoodfacts.org');
      }

      finalResults.addAll(apiResults);

      setState(() {
        _searchResults = finalResults;
      });
      await _saveCachedSearchResults(query, apiResults);
    } catch (e) {
      _showError("Open Food Facts est temporairement indisponible.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanBarcode() async {
    var res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (res is String && res != '-1') {
      _searchByBarcode(res.trim());
    }
  }

  Future<void> _searchByBarcode(String barcode) async {
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      Map<String, dynamic>? product;

      for (final host in ['fr.openfoodfacts.org', 'world.openfoodfacts.org']) {
        try {
          final url = Uri.https(host, '/api/v0/product/$barcode.json');
          final response = await http.get(url, headers: _apiHeaders).timeout(const Duration(seconds: 10));

          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }

          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic> && data['status'] == 1) {
            product = data['product'] as Map<String, dynamic>;
            break;
          }
        } catch (_) {
          continue;
        }
      }

      if (product != null) {
        setState(() {
          _selectedFood = FoodItem.fromJson(product!);
          _currentWeight = 100.0;
          _weightController.text = "100";
        });
      } else {
        _showError("Produit introuvable dans Open Food Facts.");
      }
    } catch (e) {
      _showError("Open Food Facts est temporairement indisponible.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red[800]));
  }

  void _showCreateMealDialog() {
    final nameController = TextEditingController();
    final kcalController = TextEditingController();
    final protController = TextEditingController();
    final carbsController = TextEditingController();
    final lipidsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nouveau plat complet', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: "Nom du plat (ex: Bol Avoine)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kcalController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: "Calories totales (kcal)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
              TextField(
                controller: protController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: "Protéines (g)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: "Glucides (g)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
              TextField(
                controller: lipidsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: "Lipides (g)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Annuler', style: TextStyle(color: textMuted))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0),
            onPressed: () {
              if (nameController.text.isNotEmpty && kcalController.text.isNotEmpty) {
                setState(() {
                  _savedCustomMeals.add({
                    'name': nameController.text,
                    'kcal': int.tryParse(kcalController.text) ?? 0,
                    'proteins': int.tryParse(protController.text) ?? 0,
                    'carbs': int.tryParse(carbsController.text) ?? 0,
                    'lipids': int.tryParse(lipidsController.text) ?? 0,
                  });
                });
                _saveCustomMeals();
                Navigator.pop(context);
              } else {
                _showError("Veuillez entrer un nom et les calories.");
              }
            },
            child: const Text('Sauvegarder', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _deleteCustomMeal(int index) {
    setState(() {
      _savedCustomMeals.removeAt(index);
    });
    _saveCustomMeals();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> currentMacros = _selectedFood?.calculateMacros(_currentWeight) ?? {"kcal": 0, "proteins": 0, "carbs": 0, "lipids": 0};

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('AJOUTER UN ALIMENT', style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textMain, fontFamily: 'Inter'),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un aliment...',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _searchByText("");
                            },
                          )
                        : IconButton(
                            icon: Icon(Icons.search, color: accentGold, size: 20),
                            onPressed: () => _searchByText(_searchController.text),
                          ),
                    ),
                    onChanged: (val) => setState(() {}),
                    onSubmitted: _searchByText,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: Icon(Icons.qr_code_scanner_rounded, color: accentGold, size: 20),
                    onPressed: _scanBarcode,
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              Center(child: Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator(color: accentGold, strokeWidth: 2))),

            if (!_isLoading && _searchResults.isEmpty && _selectedFood == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Mes plats fréquents", style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  TextButton.icon(
                    onPressed: _showCreateMealDialog, 
                    icon: Icon(Icons.add, color: accentGold, size: 16), 
                    label: Text("Créer", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'))
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              if (_savedCustomMeals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Text("Aucun plat sauvegardé.\nCréez vos plats habituels pour les ajouter plus vite.", textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter')),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _savedCustomMeals.length,
                    itemBuilder: (context, index) {
                      final meal = _savedCustomMeals[index];
                      return Card(
                        color: cardColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 38, height: 38, 
                            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), 
                            child: Icon(Icons.restaurant_menu_rounded, color: accentGold, size: 18)
                          ),
                          title: Text(meal['name'], style: TextStyle(fontWeight: FontWeight.bold, color: textMain, fontSize: 15, fontFamily: 'Inter')),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text('${meal['kcal']} kcal  •  P: ${meal['proteins']}g  •  G: ${meal['carbs']}g  •  L: ${meal['lipids']}g', style: TextStyle(fontSize: 11, color: textMuted, fontFamily: 'Inter')),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.shade200, size: 18),
                            onPressed: () => _deleteCustomMeal(index),
                          ),
                          onTap: () => Navigator.pop(context, meal),
                        ),
                      );
                    },
                  ),
                ),
            ],

            if (!_isLoading && _selectedFood == null && _searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final food = _searchResults[index];
                    return Card(
                      color: cardColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 38, 
                          height: 38, 
                          decoration: BoxDecoration(
                            color: bgColor, 
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: food.imageUrl != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(food.imageUrl!, width: 38, height: 38, fit: BoxFit.cover))
                              : Icon(Icons.fastfood_rounded, color: textMuted, size: 16),
                        ),
                        title: Text(food.name, style: TextStyle(fontWeight: FontWeight.bold, color: textMain, fontSize: 14, fontFamily: 'Inter')),
                        subtitle: Text('${food.kcalPer100g.round()} kcal / 100g', style: TextStyle(fontSize: 12, color: textMuted, fontFamily: 'Inter')),
                        trailing: Icon(Icons.add_circle_outline_rounded, color: accentGold, size: 20),
                        onTap: () {
                          setState(() {
                            _selectedFood = food;
                            _currentWeight = 100.0;
                            _weightController.text = "100";
                            _searchResults = []; 
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

            if (_selectedFood != null) ...[
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accentGold.withValues(alpha: 0.3), width: 1.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(_selectedFood!.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'))),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                            onPressed: () => setState(() => _selectedFood = null),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Text('Quantité pesée :', style: TextStyle(fontSize: 13, color: textMuted, fontFamily: 'Inter')),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                              child: TextFormField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                onChanged: (val) {
                                  setState(() {
                                    _currentWeight = double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text('grammes', style: TextStyle(fontSize: 15, color: textMuted, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroCircle('Kcal', currentMacros['kcal']!, accentGold),
                  _buildMacroCircle('Prot', currentMacros['proteins']!, textMain),
                  _buildMacroCircle('Gluc', currentMacros['carbs']!, textMain),
                  _buildMacroCircle('Lip', currentMacros['lipids']!, textMain),
                ],
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold, 
                    foregroundColor: bgColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                  ),
                  onPressed: () {
                    Navigator.pop(context, {
                      'name': _selectedFood!.name,
                      'kcal': currentMacros['kcal'],
                      'proteins': currentMacros['proteins'],
                      'carbs': currentMacros['carbs'],
                      'lipids': currentMacros['lipids'],
                    });
                  },
                  child: const Text('Ajouter au journal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCircle(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            border: Border.all(color: color == textMain ? Colors.grey.shade800 : color, width: 2), 
            color: cardColor
          ),
          child: Center(child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textMain, fontFamily: 'Inter'))),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: textMuted, fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Inter')),
      ],
    );
  }
}