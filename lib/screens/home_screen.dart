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
  // Liste vide au départ
  List<WorkoutSession> _allSessions = [];
  
  // Booléen pour gérer le chargement au démarrage
  bool _isLoading = true;

  int _selectedSessionIndex = 0;
  int _currentTabRowIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  List<WorkoutSession> _defaultSessions() {
    return [
      WorkoutSession(name: "Push Day", exercises: [
        Exercise.createTarget(name: "Développé Couché", targetSets: 3, targetReps: 10, targetWeight: 80)
      ]),
    ];
  }

  // Fonction pour charger les séances
  Future<void> _loadSavedSessions() async {
    List<WorkoutSession> loadedSessions = _defaultSessions();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? sessionsJson = prefs.getString('saved_workout_sessions');

      if (sessionsJson != null && sessionsJson.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(sessionsJson);
        if (decoded is List) {
          loadedSessions = decoded
              .whereType<Map<String, dynamic>>()
              .map(WorkoutSession.fromJson)
              .toList();
        } else {
          await prefs.remove('saved_workout_sessions');
        }
      }
    } catch (_) {
      loadedSessions = _defaultSessions();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _allSessions = loadedSessions;
      _isLoading = false; // Le chargement est terminé
    });
  }

  // Fonction pour SAUVEGARDER les séances
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_allSessions.map((e) => e.toJson()).toList());
    await prefs.setString('saved_workout_sessions', encoded);
  }

  // 🗑️ Fonction pour supprimer une séance avec pop-up de confirmation
  void _deleteSessionDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le programme ?'),
        content: Text('Es-tu sûr de vouloir supprimer définitivement "${_allSessions[index].name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _allSessions.removeAt(index);
                
                // Sécurité : si on supprime la séance active ou qu'on dépasse la taille de la liste
                if (_selectedSessionIndex >= _allSessions.length) {
                  _selectedSessionIndex = _allSessions.isNotEmpty ? _allSessions.length - 1 : 0;
                }
              });
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
        title: const Text('Créer une nouvelle séance'),
        content: TextField(controller: titleController, decoration: const InputDecoration(labelText: "Nom")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  _allSessions.add(WorkoutSession(name: titleController.text, exercises: []));
                  _selectedSessionIndex = _allSessions.length - 1;
                  _currentTabRowIndex = 1; 
                });
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
    // Affiche le chargement uniquement si on n'a pas encore lu la base de données
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Détermine le nom de la séance (Sécurité si la liste est complètement vide)
    final String nextSessionName = _allSessions.isNotEmpty 
        ? _allSessions[_selectedSessionIndex].name 
        : "Aucun programme";

    final List<Widget> tabs = [
      SessionsTab(
        sessions: _allSessions,
        onLaunchSession: (session) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutScreen(
                session: session,
                onSessionUpdated: _saveSessions,
                isEditing: false,
              ),
            ),
          );
        },
        onEditSession: (session) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutScreen(
                session: session,
                onSessionUpdated: _saveSessions,
                isEditing: true,
              ),
            ),
          );
        },
        onDeleteSession: _deleteSessionDialog, // 👈 C'EST ICI QUE ÇA MANQUAIT !
        onCreateSession: _showCreateSessionDialog,
      ),
      DashboardTab(
        nextSessionName: nextSessionName,
        onStartSession: () {
          // Sécurité pour ne rien lancer si tout est supprimé
          if (_allSessions.isNotEmpty) {
            final currentSession = _allSessions[_selectedSessionIndex];
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutScreen(
                  session: currentSession,
                  onSessionUpdated: _saveSessions,
                  isEditing: false,
                ),
              ),
            );
          } else {
            // Petit message si l'utilisateur essaie de lancer sans avoir de séance
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Crée d'abord une séance dans l'onglet 'Séances' !"))
            );
          }
        },
      ),
      const KcalTab(),
    ];

    return Scaffold(
      body: tabs[_currentTabRowIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabRowIndex,
        onTap: (index) => setState(() => _currentTabRowIndex = index),
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Séances'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Kcal'),
        ],
      ),
    );
  }
}