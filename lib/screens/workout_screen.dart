import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_model.dart';
import 'exercise_progress_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final WorkoutSession session;
  final VoidCallback onSessionUpdated;
  final bool isEditing; 

  const WorkoutScreen({
    super.key, 
    required this.session,
    required this.onSessionUpdated,
    this.isEditing = false, 
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  List<bool> _isExpandedList = [];

  Timer? _restTimer;
  int _totalRestSeconds = 90; 
  int _currentRestSeconds = 0;
  AnimationController? _progressController;
  late DateTime _startTime;

  // Signatures de style GAIN - Or & Anthracite unifié
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  List<Map<String, dynamic>> _dynamicExerciseCatalog = [];
  List<Map<String, dynamic>> _dynamicCardioCatalog = [];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now(); 
    _initializeExerciseCatalog(); 
    
    if (!widget.isEditing) {
      for (var exercise in widget.session.exercises) {
        for (var set in exercise.sets) {
          set.isCompleted = false;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSessionUpdated());
    }

    _isExpandedList = List.generate(widget.session.exercises.length, (index) => true);

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalRestSeconds),
    );
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _progressController?.dispose();
    super.dispose();
  }

  Future<void> _initializeExerciseCatalog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await Supabase.instance.client
          .from('exercises')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      if (existing.isEmpty) {
        final List<Map<String, dynamic>> defaultExercises = [
          {'user_id': user.id, 'name': 'Développé Couché (Barre)', 'category': 'Pectoraux (Faisceau moyen)'},
          {'user_id': user.id, 'name': 'Développé Incliné (Haltères)', 'category': 'Pectoraux (Faisceau supérieur)'},
          {'user_id': user.id, 'name': 'Écarté à la poulie', 'category': 'Pectoraux (Portion basse)'},
          {'user_id': user.id, 'name': 'Tractions (Poids de corps)', 'category': 'Grand Dorsal'},
          {'user_id': user.id, 'name': 'Rowing Barre', 'category': 'Grand Dorsal & Trapèzes'},
          {'user_id': user.id, 'name': 'Tirage Vertical (Poulie)', 'category': 'Grand Dorsal'},
          {'user_id': user.id, 'name': 'Squat Gobelet / Barre', 'category': 'Quadriceps & Fessiers'},
          {'user_id': user.id, 'name': 'Presse à cuisses', 'category': 'Quadriceps'},
          {'user_id': user.id, 'name': 'Leg Curl (Ischios)', 'category': 'Ischio-jambiers'},
          {'user_id': user.id, 'name': 'Développé Militaire', 'category': 'Deltoïde Antérieur'},
          {'user_id': user.id, 'name': 'Élévations Latérales', 'category': 'Deltoïde Latéral'},
          {'user_id': user.id, 'name': 'Curl Biceps (Haltères)', 'category': 'Biceps (Global)'},
          {'user_id': user.id, 'name': 'Extension Triceps (Poulie)', 'category': 'Triceps (Chef latéral)'},
          {'user_id': user.id, 'name': 'Crunch au sol', 'category': 'Grand Droit de l\'Abdomen'},
          {'user_id': user.id, 'name': 'Course à pied', 'category': 'Cardio'},
          {'user_id': user.id, 'name': 'Vélo', 'category': 'Cardio'},
        ];
        await Supabase.instance.client.from('exercises').insert(defaultExercises);
      }
    } catch (e) {
      debugPrint("Erreur injection catalogue : $e");
    }
    _loadCatalogFromSupabase();
  }

  Future<void> _loadCatalogFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final List<dynamic> data = await Supabase.instance.client
          .from('exercises')
          .select('name, category')
          .or('user_id.eq.${user.id},user_id.is.null');

      final List<Map<String, dynamic>> muscu = [];
      final List<Map<String, dynamic>> cardio = [];

      for (var row in data) {
        final exerciseData = row as Map<String, dynamic>;
        final category = exerciseData['category'] as String? ?? 'Autre';

        if (category.toLowerCase() == 'cardio') {
          cardio.add(exerciseData);
        } else {
          muscu.add(exerciseData);
        }
      }

      if (mounted) {
        setState(() {
          _dynamicExerciseCatalog = muscu;
          _dynamicCardioCatalog = cardio;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement catalogue : $e");
    }
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _currentRestSeconds = _totalRestSeconds;
    });

    _progressController?.duration = Duration(seconds: _totalRestSeconds);
    _progressController?.reset();
    _progressController!.forward(); 

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 1) {
        setState(() {
          _currentRestSeconds--;
        });
      } else {
        _stopRestTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Chrono terminé. À la suite 🦾", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: Colors.white)),
            backgroundColor: accentGold,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _adjustRestTime(int amountSeconds) {
    if (_currentRestSeconds <= 0) return;

    setState(() {
      _currentRestSeconds = (_currentRestSeconds + amountSeconds).clamp(0, 600);
      _totalRestSeconds = (_totalRestSeconds + amountSeconds).clamp(30, 600);
      
      if (_currentRestSeconds == 0) {
        _stopRestTimer();
        return;
      }

      _progressController?.duration = Duration(seconds: _totalRestSeconds);
      double newValue = 1.0 - (_currentRestSeconds / _totalRestSeconds);
      _progressController?.value = newValue.clamp(0.0, 1.0);
      _progressController!.forward();
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _progressController?.stop();
    setState(() {
      _currentRestSeconds = 0;
      _totalRestSeconds = 90;
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  Future<void> _saveWorkoutToSupabase() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return; 

    final sessionDuration = DateTime.now().difference(_startTime).inMinutes;

    final workoutResponse = await supabase.from('workouts').insert({
      'user_id': user.id,
      'name': widget.session.name,
      'duration_minutes': sessionDuration == 0 ? 1 : sessionDuration,
    }).select().single();

    final workoutId = workoutResponse['id'];

    for (var exercise in widget.session.exercises) {
      final completedSets = exercise.sets.where((s) => s.isCompleted).toList();
      if (completedSets.isEmpty) continue; 

      final exerciseResponse = await supabase.from('workout_exercises').insert({
        'workout_id': workoutId,
        'exercise_name': exercise.name,
      }).select().single();

      final exerciseId = exerciseResponse['id'];

      int order = 1;
      for (var set in completedSets) {
        await supabase.from('exercise_sets').insert({
          'exercise_id': exerciseId,
          'weight': exercise.isCardio ? set.duration.toString() : set.weight.toString(),
          'reps': exercise.isCardio ? (set.distance * 1000).toInt() : set.reps, 
          'set_order': order,
        });
        order++;
      }
    }
  }

  Future<void> _finishWorkout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2)),
    );

    try {
      await _saveWorkoutToSupabase();

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      List<String> completedDates = prefs.getStringList('completed_workouts') ?? [];
      if (!completedDates.contains(dateString)) {
        completedDates.add(dateString);
        await prefs.setStringList('completed_workouts', completedDates);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Séance validée et enregistrée ! 💪", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            backgroundColor: const Color(0xFF1E211A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: accentGold, width: 0.5)),
          )
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur cloud : $e", style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade900,
          )
        );
      }
    }
  }

  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final alternativeController = TextEditingController(); 
    final setsController = TextEditingController(text: "3");
    final repsController = TextEditingController(text: "10");
    final durationController = TextEditingController(text: "30");
    final distanceController = TextEditingController(text: "5.0");

    bool isCardioSelected = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Ajouter une activité', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Musculation'),
                            selected: !isCardioSelected,
                            selectedColor: accentGold.withValues(alpha:0.15),
                            backgroundColor: bgColor,
                            labelStyle: TextStyle(color: !isCardioSelected ? accentGold : textMuted, fontWeight: FontWeight.bold, fontSize: 13),
                            onSelected: (val) => setDialogState(() => isCardioSelected = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Cardio'),
                            selected: isCardioSelected,
                            selectedColor: accentGold.withValues(alpha:0.15),
                            backgroundColor: bgColor,
                            labelStyle: TextStyle(color: isCardioSelected ? accentGold : textMuted, fontWeight: FontWeight.bold, fontSize: 13),
                            onSelected: (val) => setDialogState(() => isCardioSelected = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (option) => option['name'] ?? '',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        List<Map<String, dynamic>> catalog = isCardioSelected ? _dynamicCardioCatalog : _dynamicExerciseCatalog;
                        return catalog.where((option) => (option['name'] as String).toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (Map<String, dynamic> selection) {
                        nameController.text = selection['name'] ?? '';
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        textEditingController.addListener(() => nameController.text = textEditingController.text);
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: TextStyle(color: textMain),
                          decoration: InputDecoration(
                            labelText: "Exercice principal", 
                            labelStyle: TextStyle(color: textMuted),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: cardColor,
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.72,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(option['name'] ?? '', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                                      subtitle: Text(option['category'] ?? '', style: TextStyle(color: textMuted, fontSize: 10)),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    if (!isCardioSelected) ...[
                      TextField(controller: setsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Séries", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                      TextField(controller: repsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Répétitions", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: alternativeController, 
                        style: TextStyle(color: textMain), 
                        decoration: InputDecoration(
                          labelText: "Exercice secondaire (Optionnel)", 
                          labelStyle: TextStyle(color: textMuted),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                        ),
                      ),
                    ] else ...[
                      TextField(controller: durationController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Objectif Temps (min)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                      TextField(controller: distanceController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Objectif Distance (km)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0),
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      List<String> alts = alternativeController.text.trim().isNotEmpty 
                          ? [alternativeController.text.trim()] 
                          : [];

                      setState(() {
                        widget.session.exercises.add(Exercise.createTarget(
                          name: nameController.text,
                          isCardio: isCardioSelected,
                          alternatives: alts, 
                          targetSets: isCardioSelected ? 1 : (int.tryParse(setsController.text) ?? 3),
                          targetReps: int.tryParse(repsController.text) ?? 10,
                          targetWeight: 0, 
                          targetDuration: int.tryParse(durationController.text) ?? 30,
                          targetDistance: double.tryParse(distanceController.text) ?? 5.0,
                        ));
                        _isExpandedList.add(true); 
                      });
                      widget.onSessionUpdated();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _swapExercise(Exercise exercise) {
    setState(() {
      final temp = exercise.name;
      exercise.name = exercise.alternatives.first;
      exercise.alternatives[0] = temp;
    });
    widget.onSessionUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session; 

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          session.name.toUpperCase(), 
          style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 18, letterSpacing: 1.0)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Column(
        children: [
          if (session.exercises.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.isEditing 
                    ? 'Aucune activité.\nConfigure ton programme en bas'
                    : 'Séance vide.\nOuvre le mode édition (crayon) pour rajouter tes mouvements.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Inter'),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: session.exercises.length,
                itemBuilder: (context, exIndex) {
                  final exercise = session.exercises[exIndex];
                  final bool isExpanded = _isExpandedList[exIndex];
                  
                  final int completedSets = exercise.sets.where((s) => s.isCompleted).length;
                  final int totalSets = exercise.sets.length;
                  final bool allDone = totalSets > 0 && completedSets == totalSets && !widget.isEditing;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    color: cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: allDone ? accentGold.withValues(alpha:0.4) : Colors.transparent, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isExpandedList[exIndex] = !_isExpandedList[exIndex]),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ExerciseProgressScreen(exerciseName: exercise.name),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          exercise.name,
                                          style: TextStyle(
                                            fontSize: 16, 
                                            fontWeight: FontWeight.bold, 
                                            fontFamily: 'Inter',
                                            color: allDone ? accentGold : textMain,
                                            decoration: allDone ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                      if (exercise.alternatives.isNotEmpty && !widget.isEditing && !allDone)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: InkWell(
                                            onTap: () => _swapExercise(exercise),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.grey.shade900),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.swap_horiz, size: 13, color: accentGold),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Remplacer : ${exercise.alternatives.first}",
                                                    style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!widget.isEditing)
                                  Text(
                                    allDone ? 'FAIT' : '$completedSets / $totalSets',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      color: allDone ? accentGold : Colors.orangeAccent.shade200
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                if (widget.isEditing)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent.shade200, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        session.exercises.removeAt(exIndex);
                                        _isExpandedList.removeAt(exIndex);
                                      });
                                      widget.onSessionUpdated();
                                    },
                                  )
                                else
                                  Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more, 
                                    color: textMuted,
                                    size: 20,
                                  )
                              ],
                            ),
                          ),
                        ),
                        
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(height: 1, color: Colors.grey.shade900),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(flex: 1, child: Text(exercise.isCardio ? 'TOUR' : 'SÉRIE', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                                    Expanded(flex: 2, child: Text(exercise.isCardio ? 'MINUTES' : (widget.isEditing ? 'POIDS CIBLE' : 'KG'), style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                                    Expanded(flex: 2, child: Text(exercise.isCardio ? 'DISTANCE (KM)' : (widget.isEditing ? 'REPS CIBLE' : 'REPS'), style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                                    if (!widget.isEditing)
                                      Expanded(flex: 1, child: Text('VALIDE', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'), textAlign: TextAlign.center)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: exercise.sets.length,
                                  itemBuilder: (context, setIndex) {
                                    final currentSet = exercise.sets[setIndex];
                                    final bool isSetDone = currentSet.isCompleted && !widget.isEditing;

                                    return AnimatedOpacity(
                                      duration: const Duration(milliseconds: 200),
                                      opacity: isSetDone ? 0.25 : 1.0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 1, 
                                              child: Text('${setIndex + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMuted, fontFamily: 'Inter'))
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                height: 36,
                                                margin: const EdgeInsets.only(right: 12),
                                                child: TextFormField(
                                                  initialValue: exercise.isCardio ? currentSet.duration.toString() : currentSet.weight.toString(),
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
                                                  decoration: InputDecoration(
                                                    border: InputBorder.none,
                                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade900)),
                                                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                                                  ),
                                                  onChanged: (val) {
                                                    if (exercise.isCardio) {
                                                      currentSet.duration = int.tryParse(val) ?? currentSet.duration;
                                                    } else {
                                                      currentSet.weight = int.tryParse(val) ?? currentSet.weight;
                                                    }
                                                    widget.onSessionUpdated();
                                                  },
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                height: 36,
                                                margin: const EdgeInsets.only(right: 12),
                                                child: TextFormField(
                                                  initialValue: exercise.isCardio ? currentSet.distance.toString() : currentSet.reps.toString(),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
                                                  decoration: InputDecoration(
                                                    border: InputBorder.none,
                                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade900)),
                                                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                                                  ),
                                                  onChanged: (val) {
                                                    if (exercise.isCardio) {
                                                      currentSet.distance = double.tryParse(val) ?? currentSet.distance;
                                                    } else {
                                                      currentSet.reps = int.tryParse(val) ?? currentSet.reps;
                                                    }
                                                    widget.onSessionUpdated();
                                                  },
                                                ),
                                              ),
                                            ),
                                            if (!widget.isEditing)
                                              Expanded(
                                                flex: 1,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  icon: Icon(
                                                    isSetDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                                    color: isSetDone ? accentGold : textMuted.withValues(alpha:0.5),
                                                    size: 24,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      currentSet.isCompleted = !currentSet.isCompleted;
                                                      if (currentSet.isCompleted) {
                                                        _startRestTimer();
                                                      }
                                                      bool nowAllDone = exercise.sets.every((s) => s.isCompleted);
                                                      if (nowAllDone) {
                                                        Future.delayed(const Duration(milliseconds: 300), () {
                                                          if (mounted) setState(() => _isExpandedList[exIndex] = false);
                                                        });
                                                      }
                                                    });
                                                    widget.onSessionUpdated();
                                                  },
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      exercise.sets.add(WorkoutSet(
                                        weight: exercise.sets.isNotEmpty ? exercise.sets.last.weight : 0,
                                        reps: exercise.sets.isNotEmpty ? exercise.sets.last.reps : 10,
                                        duration: exercise.sets.isNotEmpty ? exercise.sets.last.duration : 30,
                                        distance: exercise.sets.isNotEmpty ? exercise.sets.last.distance : 5.0,
                                      ));
                                    });
                                    widget.onSessionUpdated();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add, size: 14, color: textMuted),
                                        const SizedBox(width: 4),
                                        Text(exercise.isCardio ? 'Tour supplémentaire' : 'Série supplémentaire', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                      ],
                    ),
                  );
                },
              ),
            ),

          if (_currentRestSeconds > 0)
            AnimatedBuilder(
              animation: _progressController!,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFF161A20), 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hourglass_empty_rounded, color: accentGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(_currentRestSeconds),
                            style: TextStyle(color: textMain, fontWeight: FontWeight.w900, fontSize: 15, fontFamily: 'Inter', letterSpacing: 0.5),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => _adjustRestTime(-30),
                            child: Text("-30s", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _adjustRestTime(30),
                            child: Text("+30s", style: TextStyle(color: accentGold, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _stopRestTimer,
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: 1.0 - _progressController!.value,
                          backgroundColor: bgColor,
                          valueColor: AlwaysStoppedAnimation<Color>(accentGold),
                          minHeight: 2, 
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          if (widget.isEditing)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _showAddExerciseDialog,
                  icon: Icon(Icons.add_rounded, size: 18, color: bgColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  label: Text('Ajouter une activité', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: bgColor, fontFamily: 'Inter')),
                ),
              ),
            ),

          if (!widget.isEditing && session.exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _finishWorkout,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E211A), // Fond velours sombre
                    side: BorderSide(color: accentGold.withValues(alpha:0.5), width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('TERMINER LA SÉANCE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0, fontFamily: 'Inter')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}