import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nutrition_model.dart';
import '../models/workout_model.dart';

class DatabaseService {
  final String uid;
  DatabaseService({required this.uid});

  final CollectionReference userCollection = FirebaseFirestore.instance.collection('users');

  // Enregistrer ou mettre à jour le profil utilisateur
  Future updateUserProfile(UserProfile profile) async {
    return await userCollection.doc(uid).set(profile.toFirestore(), SetOptions(merge: true));
  }

  // Enregistrer une séance de sport
  Future addWorkoutSession(WorkoutSession session) async {
    return await userCollection.doc(uid).collection('workouts').add(session.toFirestore());
  }
}