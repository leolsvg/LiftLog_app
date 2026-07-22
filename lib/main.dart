import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';    
import 'screens/login_screen.dart';   
import 'package:intl/date_symbol_data_local.dart';

StreamSubscription<Uri>? _oauthLinkSubscription;

Future<void> _handleOAuthDeepLink() async {
  final appLinks = AppLinks();

  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
    }
  } catch (e) {
    debugPrint('❌ Erreur de traitement du deep link OAuth : $e');
  }

  _oauthLinkSubscription ??= appLinks.uriLinkStream.listen((uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e) {
      debugPrint('❌ Erreur de traitement du deep link OAuth en temps réel : $e');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await Supabase.initialize(
    url: 'https://nrmogmelctormagxyady.supabase.co',
    publishableKey: 'sb_publishable_TE9Nnew2r_TAyT3vAM3_-g_1nqCuU_q',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await _handleOAuthDeepLink();

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
        fontFamily: 'Inter',
      ),
      home: const AuthGate(),
    );
  }
}

// 🛡️ COMPOSANT D'AIGUILLAGE SECURISE
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
    // Initialisation synchrone du user actuel
    final initialSession = supabase.auth.currentSession;
    _currentUserId = initialSession?.user.id;

    // Écoute fluide des événements d'authentification
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      debugPrint("🔄 [GAIN Auth] Changement d'état détecté : ${data.event}");
      
      final newUserId = data.session?.user.id;

      // Déclenche le passage à l'accueil sur SIGNED_IN ou si l'ID change
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

    // Stabilisation immédiate au boot
    Future.delayed(Duration.zero, () {
      if (mounted && !_initialized) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF191919),
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: Color(0xFFC7AA0C), strokeWidth: 2), // Aligné sur ton accentGold
          ),
        ),
      );
    }

    return _currentUserId != null ? const HomeScreen() : const LoginScreen();
  }
}