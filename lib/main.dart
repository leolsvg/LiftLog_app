import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // On importe le HomeScreen tout neuf

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(), // Point de départ mis à jour
    );
  }
}