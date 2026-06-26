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
    publishableKey: 'sb_publishable_TE9Nnew2r_TAyT3vAM3_-g_1nqCuU_q',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GAIN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF191919),
        fontFamily: 'Inter', // Ta police d'interface par défaut
      ),
      home: const AuthGate(), // 👈 L'aiguillage est géré ici de manière isolée
    );
  }
}

// 🛡️ COMPOSANT D'AIGUILLAGE LUXE ET SÉCURISÉ
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;
  String? _currentUserId;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    // On récupère la session actuelle de manière statique une première fois
    final initialSession = supabase.auth.currentSession;
    _currentUserId = initialSession?.user.id;

    // On écoute les changements uniques
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      debugPrint("🔄 [GAIN Auth] Changement d'état détecté : ${data.event}");
      final newUserId = data.session?.user.id;

      // 🌟 PROTECTION CRITIQUE : On ne reconstruit l'UI que si l'identité de l'utilisateur a VRAIMENT changé
      if (!_initialized || _currentUserId != newUserId) {
        if (mounted) {
          setState(() {
            _currentUserId = newUserId;
            _initialized = true;
          });
        }
      }
    }, onError: (error) {
      debugPrint("❌ Erreur Auth Supabase: $error");
      if (mounted) setState(() => _initialized = true);
    });

    // Stabilisation du démarrage initial
    Future.delayed(Duration.zero, () {
      if (mounted && !_initialized) {
        setState(() => _initialized = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement épuré haut de gamme
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF13171C),
        body: Center(
          child: SizedBox(
            width: 22,
            height: 24,
            child: CircularProgressIndicator(color: Color(0xFF38B6FF), strokeWidth: 2),
          ),
        ),
      );
    }

    // Si on a un ID utilisateur valide -> Accueil, sinon -> Écran de connexion
    return _currentUserId != null ? const HomeScreen() : const LoginScreen();
  }
}