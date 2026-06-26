import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'kcal_tab.dart';

class EvolutionTab extends StatefulWidget {
  const EvolutionTab({super.key});

  @override
  State<EvolutionTab> createState() => _EvolutionTabState();
}

class _EvolutionTabState extends State<EvolutionTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;

  List<dynamic> _measurements = [];
  List<dynamic> _photos = [];

  // --- Palette de couleurs GAIN (Or & Anthracite) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEvolutionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvolutionData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final measurementsData = await _supabase
          .from('user_measurements')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false);

      final photosData = await _supabase
          .from('user_progress_photos')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false);

      setState(() {
        _measurements = measurementsData;
        _photos = photosData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur Évolution : $e");
      setState(() => _isLoading = false);
    }
  }

  void _showAddMeasurementsDialog() {
    final waistController = TextEditingController();
    final chestController = TextEditingController();
    final armLeftController = TextEditingController();
    final armRightController = TextEditingController();
    final thighLeftController = TextEditingController();
    final thighRightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Nouvelles mensurations", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: waistController, 
                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                style: TextStyle(color: textMain), 
                decoration: InputDecoration(
                  labelText: "Tour de taille (cm)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
              TextField(
                controller: chestController, 
                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                style: TextStyle(color: textMain), 
                decoration: InputDecoration(
                  labelText: "Tour de poitrine (cm)", 
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: armLeftController, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      style: TextStyle(color: textMain), 
                      decoration: InputDecoration(
                        labelText: "Bras G (cm)", 
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: armRightController, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      style: TextStyle(color: textMain), 
                      decoration: InputDecoration(
                        labelText: "Bras D (cm)", 
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: thighLeftController, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      style: TextStyle(color: textMain), 
                      decoration: InputDecoration(
                        labelText: "Cuisse G (cm)", 
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: thighRightController, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      style: TextStyle(color: textMain), 
                      decoration: InputDecoration(
                        labelText: "Cuisse D (cm)", 
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("Annuler", style: TextStyle(color: textMuted, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGold, 
              foregroundColor: bgColor, 
              elevation: 0, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final user = _supabase.auth.currentUser;
              if (user == null) return;

              // 1. Capture des instances d'UI avant le gap asynchrone
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await _supabase.from('user_measurements').insert({
                  'user_id': user.id,
                  'date': DateTime.now().toIso8601String().substring(0, 10),
                  'waist': double.tryParse(waistController.text),
                  'chest': double.tryParse(chestController.text),
                  'arm_left': double.tryParse(armLeftController.text),
                  'arm_right': double.tryParse(armRightController.text),
                  'thigh_left': double.tryParse(thighLeftController.text),
                  'thigh_right': double.tryParse(thighRightController.text),
                });
                
                // 2. Vérification moderne du BuildContext
                if (!context.mounted) return;
                
                // 3. Utilisation de la référence locale capturée pour fermer le dialogue
                navigator.pop();
                _loadEvolutionData();
                
                messenger.showSnackBar(
                  const SnackBar(content: Text('Mensurations enregistrées ! 📐'), backgroundColor: Colors.green),
                );
              } catch (e) {
                debugPrint("Erreur ajout mensurations : $e");
                if (!context.mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Erreur lors de l\'enregistrement'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          )
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (image == null) return;
    setState(() => _isLoading = true);

    try {
      final file = File(image.path);
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('progress-photos').upload(fileName, file);

      await _supabase.from('user_progress_photos').insert({
        'user_id': user.id,
        'storage_path': fileName,
        'type': 'Global',
      });

      _loadEvolutionData();
    } catch (e) {
      debugPrint("Erreur upload photo : $e");
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getSignedUrl(String path) async {
    try {
      return await _supabase.storage.from('progress-photos').createSignedUrl(path, 3600);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: const Color(0xFF1E1E1E),
          child: SafeArea(
            child: TabBar(
              controller: _tabController,
              indicatorColor: accentGold,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: accentGold,
              unselectedLabelColor: textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.local_fire_department_outlined, size: 22)),
                Tab(icon: Icon(Icons.straighten, size: 22)),
                Tab(icon: Icon(Icons.camera_alt_outlined, size: 22)),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2))
          : TabBarView(
              controller: _tabController,
              children: [
                const KcalTab(),
                _buildMeasurementsTab(),
                _buildPhotosTab(),
              ],
            ),
    );
  }

  Widget _buildMeasurementsTab() {
    if (_measurements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.straighten, size: 32, color: textMuted.withValues(alpha:0.3)),
            const SizedBox(height: 12),
            Text("Aucun relevé", style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter')),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cardColor, foregroundColor: accentGold, elevation: 0),
              onPressed: _showAddMeasurementsDialog, 
              child: const Text("Prendre mes mesures", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentGold,
        foregroundColor: bgColor,
        elevation: 2,
        onPressed: _showAddMeasurementsDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _measurements.length,
        itemBuilder: (context, index) {
          final item = _measurements[index];
          final DateTime rawDate = DateTime.parse(item['date']);
          final String formattedDate = DateFormat('dd MMM yyyy', 'fr_FR').format(rawDate);

          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedDate, style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMeasurementStat("Taille", "${item['waist'] ?? '--'} cm"),
                      _buildMeasurementStat("Pecs", "${item['chest'] ?? '--'} cm"),
                      _buildMeasurementStat("Bras", "${item['arm_left'] ?? '--'}/${item['arm_right'] ?? '--'}"),
                      _buildMeasurementStat("Cuisses", "${item['thigh_left'] ?? '--'}/${item['thigh_right'] ?? '--'}"),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeasurementStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textMuted, fontSize: 10, fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter')),
      ],
    );
  }

  Widget _buildPhotosTab() {
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 32, color: textMuted.withValues(alpha:0.3)),
            const SizedBox(height: 12),
            Text("Aucune photo", style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Inter')),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: cardColor, foregroundColor: accentGold, elevation: 0),
              onPressed: _pickAndUploadPhoto, 
              icon: const Icon(Icons.add_a_photo, size: 16), 
              label: const Text("Prendre une photo", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );
    }

    Map<String, List<dynamic>> groupedPhotos = {};
    for (var photo in _photos) {
      if (photo['date'] == null) continue;
      final DateTime rawDate = DateTime.parse(photo['date']);
      final String monthKey = DateFormat('MMMM yyyy', 'fr_FR').format(rawDate);
      
      if (!groupedPhotos.containsKey(monthKey)) {
        groupedPhotos[monthKey] = [];
      }
      groupedPhotos[monthKey]!.add(photo);
    }

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentGold,
        foregroundColor: bgColor,
        elevation: 2,
        onPressed: _pickAndUploadPhoto,
        child: const Icon(Icons.add_a_photo),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedPhotos.keys.length,
        itemBuilder: (context, index) {
          String monthTitle = groupedPhotos.keys.elementAt(index);
          List<dynamic> photosInMonth = groupedPhotos[monthTitle]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 2.0),
                child: Text(
                  monthTitle.toUpperCase(),
                  style: TextStyle(
                    color: accentGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), 
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: photosInMonth.length,
                itemBuilder: (context, pIndex) {
                  final photo = photosInMonth[pIndex];
                  final DateTime photoDate = DateTime.parse(photo['date'] ?? DateTime.now().toIso8601String());
                  final String displayDay = DateFormat('dd MMM', 'fr_FR').format(photoDate);

                  return Container(
                    decoration: BoxDecoration(
                      color: cardColor, 
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FutureBuilder<String>(
                            future: _getSignedUrl(photo['storage_path']),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 1.5));
                              }
                              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                return Image.network(snapshot.data!, fit: BoxFit.cover);
                              }
                              return Icon(Icons.broken_image, color: textMuted);
                            },
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha:0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                displayDay,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16), 
            ],
          );
        },
      ),
    );
  }
}