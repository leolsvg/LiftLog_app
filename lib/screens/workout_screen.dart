import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_model.dart';

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

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<bool> _isExpandedList = [];

  // --- Palette de couleurs LiftLog ---
  final Color bgColor = const Color(0xFF13171C);
  final Color cardColor = const Color(0xFF1F252D);
  final Color accentCyan = const Color(0xFF38B6FF);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);

  final List<String> _exerciseCatalog = [
    "Développé Couché", "Développé Incliné Haltères", "Écartés Poulie", 
    "Curl Biceps Haltères", "Curl Marteau", "Tractions", "Rowing Barre", 
    "Tirage Poitrine", "Extensions Triceps", "Développé Militaire", 
    "Élévations Latérales", "Squat", "Presse à Cuisses", "Leg Extension", "Crunchs"
  ];

  final List<String> _cardioCatalog = [
    "Course à pied", "Vélo", "Natation", "Rameur", "Corde à sauter", "Elliptique"
  ];

  @override
  void initState() {
    super.initState();
    
    if (!widget.isEditing) {
      for (var exercise in widget.session.exercises) {
        for (var set in exercise.sets) {
          set.isCompleted = false;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSessionUpdated());
    }

    _isExpandedList = List.generate(widget.session.exercises.length, (index) => true);
  }

  Future<void> _finishWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    List<String> completedDates = prefs.getStringList('completed_workouts') ?? [];

    if (!completedDates.contains(dateString)) {
      completedDates.add(dateString);
      await prefs.setStringList('completed_workouts', completedDates);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Séance validée ! 💪 Beau travail.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
      );
      Navigator.pop(context);
    }
  }

  IconData _getExerciseIcon(String name, bool isCardio) {
    if (!isCardio) return Icons.fitness_center;
    if (name.toLowerCase().contains("vélo")) return Icons.directions_bike;
    if (name.toLowerCase().contains("course") || name.toLowerCase().contains("tapis")) return Icons.directions_run;
    if (name.toLowerCase().contains("natation")) return Icons.pool;
    if (name.toLowerCase().contains("rameur")) return Icons.rowing;
    return Icons.timer;
  }

  // ➕ POP-UP DE CRÉATION (Interface simplifiée : 1 seul exercice secondaire max)
  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final alternativeController = TextEditingController(); 
    
    final setsController = TextEditingController(text: "3");
    final repsController = TextEditingController(text: "10");
    final weightController = TextEditingController(text: "60");

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
              title: Text('Ajouter une activité', style: TextStyle(color: textMain)),
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
                            selectedColor: accentCyan.withOpacity(0.2),
                            labelStyle: TextStyle(color: !isCardioSelected ? accentCyan : textMuted, fontWeight: FontWeight.bold),
                            onSelected: (val) => setDialogState(() => isCardioSelected = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Cardio'),
                            selected: isCardioSelected,
                            selectedColor: accentCyan.withOpacity(0.2),
                            labelStyle: TextStyle(color: isCardioSelected ? accentCyan : textMuted, fontWeight: FontWeight.bold),
                            onSelected: (val) => setDialogState(() => isCardioSelected = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                        List<String> catalog = isCardioSelected ? _cardioCatalog : _exerciseCatalog;
                        return catalog.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) => nameController.text = selection,
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        textEditingController.addListener(() => nameController.text = textEditingController.text);
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: TextStyle(color: textMain),
                          decoration: InputDecoration(
                            labelText: isCardioSelected ? "Exercice principal" : "Exercice principal", 
                            labelStyle: TextStyle(color: textMuted),
                            suffixIcon: Icon(Icons.search, size: 20, color: textMuted)
                          ),
                        );
                      },
                    ),

                    if (!isCardioSelected) ...[
                      TextField(controller: setsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Séries", labelStyle: TextStyle(color: textMuted))),
                      TextField(controller: repsController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Répétitions", labelStyle: TextStyle(color: textMuted))),
                      TextField(controller: weightController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Poids de départ (kg)", labelStyle: TextStyle(color: textMuted))),
                      const SizedBox(height: 16),
                      // Option claire pour l'alternative directe
                      TextField(
                        controller: alternativeController, 
                        style: TextStyle(color: textMain), 
                        decoration: InputDecoration(
                          labelText: "Exercice secondaire (Optionnel)", 
                          labelStyle: TextStyle(color: accentCyan.withOpacity(0.8)),
                          hintText: "Ex: Développé Couché Haltères",
                          hintStyle: TextStyle(color: textMuted.withOpacity(0.3), fontSize: 13),
                        ),
                      ),
                    ] else ...[
                      TextField(controller: durationController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Objectif Temps (min)", labelStyle: TextStyle(color: textMuted))),
                      TextField(controller: distanceController, keyboardType: TextInputType.number, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Objectif Distance (km)", labelStyle: TextStyle(color: textMuted))),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentCyan, foregroundColor: bgColor),
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
                          targetWeight: int.tryParse(weightController.text) ?? 60,
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

  @override
  Widget build(BuildContext context) {
    final session = widget.session; 

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(session.name, style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Column(
        children: [
          if (session.exercises.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.isEditing 
                    ? 'Aucune activité.\nConfigure ton programme en bas !'
                    : 'Séance vide.\nOuvre le mode "Modifier" (crayon) pour ajouter des exercices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 15),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: session.exercises.length,
                itemBuilder: (context, exIndex) {
                  final exercise = session.exercises[exIndex];
                  final bool isExpanded = _isExpandedList[exIndex];
                  
                  final int completedSets = exercise.sets.where((s) => s.isCompleted).length;
                  final int totalSets = exercise.sets.length;
                  final bool allDone = totalSets > 0 && completedSets == totalSets && !widget.isEditing;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: allDone ? accentCyan : Colors.transparent, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        // EN-TÊTE DE L'EXERCICE
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isExpandedList[exIndex] = !_isExpandedList[exIndex];
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(_getExerciseIcon(exercise.name, exercise.isCardio), color: allDone ? accentCyan : textMuted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold, 
                                          color: allDone ? accentCyan : textMain,
                                          decoration: allDone ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      
                                      // 🔄 LE BADGE ALTERNATIF RAPIDE : Propre, discret, compréhensible
                                      if (exercise.alternatives.isNotEmpty && !widget.isEditing && !allDone)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6.0),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                // On intervertit l'exercice principal et l'alternative d'un seul coup
                                                final temp = exercise.name;
                                                exercise.name = exercise.alternatives.first;
                                                exercise.alternatives[0] = temp;
                                              });
                                              widget.onSessionUpdated();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: accentCyan.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: accentCyan.withOpacity(0.3), width: 1),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.swap_horiz, size: 14, color: accentCyan),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Remplacer par : ${exercise.alternatives.first}",
                                                    style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
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
                                    allDone ? 'FAIT ✅' : '$completedSets/$totalSets',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: allDone ? accentCyan : Colors.orangeAccent.shade200
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                if (widget.isEditing)
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.redAccent.shade200),
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
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                                    color: textMuted
                                  )
                              ],
                            ),
                          ),
                        ),
                        
                        // CONTENU DE L'EXERCICE
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(height: 1, color: Colors.grey.shade800),
                                const SizedBox(height: 12),
                                
                                Row(
                                  children: [
                                    Expanded(flex: 1, child: Text(exercise.isCardio ? 'TOUR' : 'SÉRIE', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text(exercise.isCardio ? 'TEMPS (MIN)' : (widget.isEditing ? 'POIDS CIBLE' : 'POIDS (KG)'), style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text(exercise.isCardio ? 'DISTANCE (KM)' : (widget.isEditing ? 'REPS CIBLE' : 'REPS'), style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold))),
                                    if (!widget.isEditing)
                                      Expanded(flex: 1, child: Text('FAIT', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: exercise.sets.length,
                                  itemBuilder: (context, setIndex) {
                                    final currentSet = exercise.sets[setIndex];
                                    final bool isSetDone = currentSet.isCompleted && !widget.isEditing;

                                    return AnimatedOpacity(
                                      duration: const Duration(milliseconds: 300),
                                      opacity: isSetDone ? 0.3 : 1.0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 1, 
                                              child: Text('${setIndex + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMuted))
                                            ),
                                            
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                height: 40,
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                                                child: TextFormField(
                                                  initialValue: exercise.isCardio ? currentSet.duration.toString() : currentSet.weight.toString(),
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
                                                  decoration: const InputDecoration(border: InputBorder.none),
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
                                                height: 40,
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                                                child: TextFormField(
                                                  initialValue: exercise.isCardio ? currentSet.distance.toString() : currentSet.reps.toString(),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
                                                  decoration: const InputDecoration(border: InputBorder.none),
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
                                                  icon: Icon(
                                                    isSetDone ? Icons.check_box : Icons.check_box_outline_blank,
                                                    color: isSetDone ? accentCyan : textMuted,
                                                    size: 32,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      currentSet.isCompleted = !currentSet.isCompleted;
                                                      
                                                      bool nowAllDone = exercise.sets.every((s) => s.isCompleted);
                                                      if (nowAllDone) {
                                                        Future.delayed(const Duration(milliseconds: 400), () {
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
                                
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        exercise.sets.add(WorkoutSet(
                                          weight: exercise.sets.isNotEmpty ? exercise.sets.last.weight : 60,
                                          reps: exercise.sets.isNotEmpty ? exercise.sets.last.reps : 10,
                                          duration: exercise.sets.isNotEmpty ? exercise.sets.last.duration : 30,
                                          distance: exercise.sets.isNotEmpty ? exercise.sets.last.distance : 5.0,
                                        ));
                                      });
                                      widget.onSessionUpdated();
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_circle, size: 20, color: textMuted),
                                        const SizedBox(width: 6),
                                        Text(exercise.isCardio ? 'Ajouter un tour' : 'Ajouter une série', style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.bold)),
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

          if (widget.isEditing)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _showAddExerciseDialog,
                  icon: Icon(Icons.add, size: 24, color: bgColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  label: Text('Ajouter une Activité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: bgColor)),
                ),
              ),
            ),

          if (!widget.isEditing && session.exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _finishWorkout,
                  icon: const Icon(Icons.emoji_events, size: 28, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  label: const Text('TERMINER LA SÉANCE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}