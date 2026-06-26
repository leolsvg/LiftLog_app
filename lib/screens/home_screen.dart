import 'dart:convert'; 
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
  final Color bgColor = const Color(0xFF13171C);
  final Color accentCyan = const Color(0xFF38B6FF);

  List<WorkoutSession> _allSessions = [];
  bool _isLoading = true;

  int _selectedSessionIndex = 0;
  int _currentTabRowIndex = 1; // Par défaut sur l'Accueil

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
        backgroundColor: const Color(0xFF1F252D),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
        content: Text('Supprimer "${_allSessions[index].name}" ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              setState(() => _allSessions.removeAt(index));
              Navigator.pop(context);
              await _syncSessionsToSupabase();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            child: const Text('Supprimer'),
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
        backgroundColor: const Color(0xFF1F252D),
        title: const Text('Créer une séance', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: titleController, 
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "Nom", labelStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                setState(() => _allSessions.add(WorkoutSession(name: titleController.text, exercises: [])));
                Navigator.pop(context);
                await _syncSessionsToSupabase();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
            child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator(color: Color(0xFF38B6FF))));

    final List<Widget> tabs = [
      SessionsTab(
        sessions: _allSessions,
        onLaunchSession: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: s, onSessionUpdated: _syncSessionsToSupabase))),
        onEditSession: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: s, onSessionUpdated: _syncSessionsToSupabase, isEditing: true))),
        onDeleteSession: _deleteSessionDialog,
        onCreateSession: _showCreateSessionDialog,
      ),
      DashboardTab(
        nextSessionName: _allSessions.isNotEmpty ? _allSessions[_selectedSessionIndex].name : "Aucune",
        onStartSession: () {
           if (_allSessions.isNotEmpty) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: _allSessions[_selectedSessionIndex], onSessionUpdated: _syncSessionsToSupabase)));
           }
        },
      ),
      const EvolutionTab(), // Regroupe Calories, Mensurations et Photos
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: tabs[_currentTabRowIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabRowIndex,
        onTap: (index) => setState(() => _currentTabRowIndex = index),
        backgroundColor: const Color(0xFF1F252D),
        selectedItemColor: accentCyan,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Séances'),
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Suivi'),
        ],
      ),
    );
  }
}