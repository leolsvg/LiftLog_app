import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_model.dart';
import 'workout_screen.dart';
import 'sessions_tab.dart';
import 'dashboard_tab.dart';
import 'evolution_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Palette de couleurs GAIN (Or & Anthracite) ---
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  List<WorkoutSession> _allSessions = [];
  bool _isLoading = true;

  final int _selectedSessionIndex = 0;
  int _currentTabRowIndex = 1; // Par défaut sur le Dashboard (Accueil)

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  Future<void> _loadSavedSessions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('workout_templates')
          .select('name, exercises')
          .eq('user_id', user.id);

      List<WorkoutSession> loadedSessions = data.map((json) {
        return WorkoutSession(
          name: json['name'] ?? 'Programme',
          exercises: (json['exercises'] as List?)
                  ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
                  .toList() ?? [],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _allSessions = loadedSessions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur lors de la récupération cloud : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncSessionsToSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('workout_templates')
          .delete()
          .eq('user_id', user.id);

      if (_allSessions.isNotEmpty) {
        final templatesToInsert = _allSessions.map((session) => {
          'user_id': user.id,
          'name': session.name,
          'exercises': session.exercises.map((e) => e.toJson()).toList(),
        }).toList();

        await Supabase.instance.client.from('workout_templates').insert(templatesToInsert);
      }
    } catch (e) {
      debugPrint("Erreur de synchronisation cloud : $e");
    }
  }

  void _deleteSessionDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer la séance ?', style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
        content: Text('Supprimer définitivement "${_allSessions[index].name}" ?', style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted, fontFamily: 'Inter'))),
          ElevatedButton(
            onPressed: () async {
              setState(() => _allSessions.removeAt(index));
              Navigator.pop(context);
              await _syncSessionsToSupabase();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], elevation: 0),
            child: const Text('Supprimer', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showCreateSessionDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Créer une séance', style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
        content: TextField(
          controller: titleController, 
          style: TextStyle(color: textMain, fontFamily: 'Inter'),
          decoration: InputDecoration(
            labelText: "Nom de l'entraînement", 
            labelStyle: TextStyle(color: textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted, fontFamily: 'Inter'))),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                setState(() => _allSessions.add(WorkoutSession(name: titleController.text, exercises: [])));
                Navigator.pop(context);
                await _syncSessionsToSupabase();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0),
            child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2)));

    final List<Widget> tabs = [
      SessionsTab(
        sessions: _allSessions,
        onLaunchSession: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: s, onSessionUpdated: _syncSessionsToSupabase))),
        onEditSession: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: s, onSessionUpdated: _syncSessionsToSupabase, isEditing: true))),
        onDeleteSession: _deleteSessionDialog,
        onCreateSession: _showCreateSessionDialog, onReorderSessions: (int oldIndex, int newIndex) {  },
      ),
      DashboardTab(
        nextSessionName: _allSessions.isNotEmpty ? _allSessions[_selectedSessionIndex].name : "Aucune",
        onStartSession: () {
           if (_allSessions.isNotEmpty) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: _allSessions[_selectedSessionIndex], onSessionUpdated: _syncSessionsToSupabase)));
           }
        },
      ),
      const EvolutionTab(), 
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: tabs[_currentTabRowIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabRowIndex,
        onTap: (index) => setState(() => _currentTabRowIndex = index),
        backgroundColor: cardColor,
        selectedItemColor: accentGold,
        unselectedItemColor: textMuted.withValues(alpha:0.6),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Inter'),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontFamily: 'Inter'),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded, size: 22), label: 'Séances'),
          BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 22), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined, size: 22), label: 'Suivi'),
        ],
      ),
    );
  }
}