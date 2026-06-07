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
  static const Duration _searchCacheTtl = Duration(hours: 12);
  
  List<FoodItem> _searchResults = [];
  FoodItem? _selectedFood;
  double _currentWeight = 100.0;
  bool _isLoading = false;

  // 🆕 NOUVEAU : Liste pour stocker les plats complets de l'utilisateur
  List<Map<String, dynamic>> _savedCustomMeals = [];

  // --- Palette de couleurs LiftLog (Thème sombre) ---
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  @override
  void initState() {
    super.initState();
    _loadCustomMeals(); // On charge les plats au démarrage de la page
  }

  // 🔄 CHARGEMENT DES PLATS SAUVEGARDÉS
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

  // 💾 SAUVEGARDE DES PLATS
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
      'page_size': '20',
      'sort_by': 'popularity',
      'fields': 'product_name_fr,product_name,nutriments,image_front_small_url',
    });

    final response = await http.get(url).timeout(const Duration(seconds: 10));
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

  // 🌍 1. RECHERCHE PAR TEXTE
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
      final cachedResults = await _loadCachedSearchResults(query);
      if (cachedResults != null && cachedResults.isNotEmpty) {
        setState(() {
          _searchResults = cachedResults;
        });
        return;
      }

      List<FoodItem> results;
      try {
        results = await _fetchFoodsFromOpenFoodFacts(query, host: 'world.openfoodfacts.org');
      } catch (_) {
        results = await _fetchFoodsFromOpenFoodFacts(query, host: 'fr.openfoodfacts.org');
      }

      setState(() {
        _searchResults = results;
      });
      await _saveCachedSearchResults(query, results);
    } catch (e) {
      _showError("Open Food Facts est temporairement indisponible.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 📷 2. OUVERTURE DE LA CAMÉRA
  Future<void> _scanBarcode() async {
    var res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (res is String && res != '-1') {
      _searchByBarcode(res);
    }
  }

  // 🌍 3. RECHERCHE PAR CODE BARRES
  Future<void> _searchByBarcode(String barcode) async {
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      Map<String, dynamic>? product;

      for (final host in ['world.openfoodfacts.org', 'fr.openfoodfacts.org']) {
        try {
          final url = Uri.https(host, '/api/v0/product/$barcode.json');
          final response = await http.get(url).timeout(const Duration(seconds: 10));

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

  // 🛠️ 4. DIALOGUE POUR CRÉER UN PLAT COMPLET
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
        title: Text('Nouveau plat complet', style: TextStyle(color: textMain)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(labelText: "Nom du plat (ex: Bol Avoine)", labelStyle: TextStyle(color: textMuted)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kcalController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(labelText: "Calories totales (kcal)", labelStyle: TextStyle(color: textMuted), icon: const Icon(Icons.local_fire_department, color: Colors.orange)),
              ),
              TextField(
                controller: protController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(labelText: "Protéines (g)", labelStyle: TextStyle(color: textMuted), icon: Icon(Icons.fitness_center, color: Colors.redAccent.shade200)),
              ),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(labelText: "Glucides (g)", labelStyle: TextStyle(color: textMuted), icon: Icon(Icons.grain, color: Colors.greenAccent.shade400)),
              ),
              TextField(
                controller: lipidsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(labelText: "Lipides (g)", labelStyle: TextStyle(color: textMuted), icon: Icon(Icons.water_drop, color: Colors.orangeAccent.shade200)),
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
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
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

  // 🗑️ SUPPRIMER UN PLAT SAUVEGARDÉ
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
        title: Text('Ajouter un aliment', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BARRE DE RECHERCHE & BOUTON SCAN
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(
                      hintText: 'Ex: Poulet, Pâtes...',
                      hintStyle: TextStyle(color: textMuted),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _searchByText(""); // Réinitialise la vue
                            },
                          )
                        : IconButton(
                            icon: Icon(Icons.search, color: accentCyan),
                            onPressed: () => _searchByText(_searchController.text),
                          ),
                    ),
                    onChanged: (val) {
                      setState(() {}); // Met à jour l'icône de la croix
                    },
                    onSubmitted: _searchByText,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(color: accentCyan, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.barcode_reader, color: Colors.white),
                    onPressed: _scanBarcode,
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),

            // CHARGEMENT
            if (_isLoading)
              Center(child: Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator(color: accentCyan))),

            // 🆕 AFFICHAGE DES PLATS SAUVEGARDÉS (Si on ne cherche rien et qu'on n'a pas sélectionné de produit)
            if (!_isLoading && _searchResults.isEmpty && _selectedFood == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Mes plats fréquents", style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showCreateMealDialog, 
                    icon: Icon(Icons.add, color: accentCyan, size: 20), 
                    label: Text("Créer", style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold))
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              if (_savedCustomMeals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Text("Aucun plat sauvegardé.\nCréez vos plats habituels pour les ajouter plus vite !", textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 45, height: 45, 
                            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), 
                            child: Icon(Icons.restaurant, color: accentCyan)
                          ),
                          title: Text(meal['name'], style: TextStyle(fontWeight: FontWeight.bold, color: textMain, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('${meal['kcal']} kcal  •  P: ${meal['proteins']}g  •  G: ${meal['carbs']}g  •  L: ${meal['lipids']}g', style: TextStyle(fontSize: 12, color: textMuted)),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent.shade200),
                            onPressed: () => _deleteCustomMeal(index),
                          ),
                          onTap: () {
                            // On ajoute directement ce plat au journal en fermant l'écran !
                            Navigator.pop(context, meal);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],

            // RÉSULTATS DE RECHERCHE OPEN FOOD FACTS
            if (!_isLoading && _selectedFood == null && _searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final food = _searchResults[index];
                    return Card(
                      color: cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: food.imageUrl != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(food.imageUrl!, width: 40, height: 40, fit: BoxFit.cover))
                            : Container(width: 40, height: 40, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.fastfood, color: textMuted)),
                        title: Text(food.name, style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                        subtitle: Text('${food.kcalPer100g.round()} kcal / 100g', style: TextStyle(fontSize: 13, color: textMuted)),
                        trailing: Icon(Icons.add_circle_outline, color: accentCyan),
                        onTap: () {
                          setState(() {
                            _selectedFood = food;
                            _searchResults = []; 
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

            // ALIMENT SÉLECTIONNÉ (Prêt à peser)
            if (_selectedFood != null) ...[
              Card(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accentCyan, width: 1.5)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(_selectedFood!.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textMain))),
                          IconButton(
                            icon: Icon(Icons.close, color: textMuted),
                            onPressed: () => setState(() => _selectedFood = null),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      Text('Quantité pesée :', style: TextStyle(fontSize: 14, color: textMuted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _currentWeight.toStringAsFixed(0)),
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: bgColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _currentWeight = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 15),
                          Text('grammes', style: TextStyle(fontSize: 18, color: textMuted, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroCircle('Kcal', currentMacros['kcal']!, accentCyan),
                  _buildMacroCircle('Prot', currentMacros['proteins']!, Colors.redAccent.shade200),
                  _buildMacroCircle('Gluc', currentMacros['carbs']!, Colors.greenAccent.shade400),
                  _buildMacroCircle('Lip', currentMacros['lipids']!, Colors.orangeAccent.shade200),
                ],
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentCyan, 
                    foregroundColor: bgColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
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
                  child: const Text('Ajouter au journal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
          width: 65,
          height: 65,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3), color: cardColor),
          child: Center(child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textMain))),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}