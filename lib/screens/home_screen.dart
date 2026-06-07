import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_model.dart';
import 'workout_screen.dart';
import 'sessions_tab.dart';
import 'kcal_tab.dart';
import 'dashboard_tab.dart';

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
  int _currentTabRowIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  Future<void> _loadSavedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('saved_workout_sessions');
    
    List<WorkoutSession> loadedSessions = [];
    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(sessionsJson);
        if (decoded is List) {
          loadedSessions = decoded.whereType<Map<String, dynamic>>().map(WorkoutSession.fromJson).toList();
        }
      } catch (_) { loadedSessions = []; }
    }
    
    if (!mounted) return;
    setState(() {
      _allSessions = loadedSessions;
      _isLoading = false;
    });
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_workout_sessions', jsonEncode(_allSessions.map((e) => e.toJson()).toList()));
  }

  void _deleteSessionDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${_allSessions[index].name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              setState(() => _allSessions.removeAt(index));
              _saveSessions();
              Navigator.pop(context);
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
        title: const Text('Créer une séance'),
        content: TextField(controller: titleController, decoration: const InputDecoration(labelText: "Nom")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() => _allSessions.add(WorkoutSession(name: titleController.text, exercises: [])));
                _saveSessions();
                Navigator.pop(context);
              }
            },
            child: const Text('Créer'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF13171C), body: Center(child: CircularProgressIndicator()));

    final List<Widget> tabs = [
      SessionsTab(
        sessions: _allSessions,
        onLaunchSession: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: s, onSessionUpdated: _saveSessions))),
        onEditSession: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: s, onSessionUpdated: _saveSessions, isEditing: true))),
        onDeleteSession: _deleteSessionDialog,
        onCreateSession: _showCreateSessionDialog,
      ),
      DashboardTab(
        nextSessionName: _allSessions.isNotEmpty ? _allSessions[_selectedSessionIndex].name : "Aucune",
        onStartSession: () {
           if (_allSessions.isNotEmpty) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen(session: _allSessions[_selectedSessionIndex], onSessionUpdated: _saveSessions)));
           }
        },
      ),
      const KcalTab(),
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
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Séances'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Kcal'),
        ],
      ),
    );
  }
}