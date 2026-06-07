import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/signup_screen.dart'; // Assure-toi que le fichier s'appelle bien signup_screen.dart
import 'package:firebase_auth/firebase_auth.dart'; // Pour le type User
import 'screens/home_screen.dart';                // Pour HomeScreen
import 'screens/login_screen.dart';               // Pour LoginScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase initialisé avec succès !");
    }
  } catch (e) {
    debugPrint("Firebase est déjà initialisé : $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LiftLog',
      theme: ThemeData.dark(),
      // On utilise un StreamBuilder pour vérifier la connexion automatiquement
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Pendant que l'app vérifie le statut (chargement)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF13171C),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Si l'utilisateur est connecté (le snapshot contient des données User)
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          // Si personne n'est connecté, on renvoie vers le Login
          return const LoginScreen(); 
        },
      ),
    );
  }
}
