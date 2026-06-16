import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';    
import 'screens/login_screen.dart';   
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // Initialisation de Supabase
  await Supabase.initialize(
    url: 'https://nrmogmelctormagxyady.supabase.co', 
    anonKey: 'sb_publishable_TE9Nnew2r_TAyT3vAM3_-g_1nqCuU_q',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  Session? _session;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initAuth() async {
    // 1. Récupérer la session actuelle si elle existe déjà en cache au démarrage
    final initialSession = supabase.auth.currentSession;
    
    // 2. Écouter activement les changements (parfait pour intercepter le retour du OAuth Google)
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      debugPrint("🔄 Changement d'état Auth Supabase : ${data.event}");
      if (mounted) {
        setState(() {
          // On force la lecture directe de la session fraîche présente dans le client Supabase
          _session = supabase.auth.currentSession;
          _initialized = true;
        });
      }
    }, onError: (error) {
      debugPrint("❌ Erreur Auth Supabase: $error");
      if (mounted) {
        setState(() => _initialized = true);
      }
    });

    // 3. Mettre à jour l'UI avec la session de départ
    if (mounted) {
      setState(() {
        _session = initialSession;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LiftLog',
      theme: ThemeData.dark(),
      home: !_initialized
          ? const Scaffold(
              backgroundColor: Color(0xFF13171C),
              body: Center(child: CircularProgressIndicator()),
            )
          : _session != null
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}