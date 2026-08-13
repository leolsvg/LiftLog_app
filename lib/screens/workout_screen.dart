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

class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<bool> _isExpandedList = [];

  Timer? _restTimer;
  int _totalRestSeconds = 90;
  int _currentRestSeconds = 0;
  AnimationController? _progressController;
  late DateTime _startTime;
  Timer? _elapsedTicker;

  static const List<int> _restPresets = [60, 90, 120, 180];

  // Signatures de style GAIN - Or & Anthracite sobre unifié
  final Color bgColor = const Color(0xFF191919);
  final Color cardColor = const Color(0xFF242424);
  final Color accentGold = const Color(0xFFC7AA0C);
  final Color textMain = Colors.white;
  final Color textMuted = const Color(0xFFA0AAB5);
  final Color textHint = const Color(0xFF333333);

  List<Map<String, dynamic>> _dynamicExerciseCatalog = [];
  List<Map<String, dynamic>> _dynamicCardioCatalog = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now(); 
    _initializeExerciseCatalog(); 
    
    if (!widget.isEditing) {
      _restoreSessionState();
      _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }

    _isExpandedList = List.generate(widget.session.exercises.length, (index) => true);

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalRestSeconds),
    );

    _loadDefaultRestSeconds();
  }

  Future<void> _loadDefaultRestSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('gain_default_rest_seconds');
    if (saved != null && mounted) {
      setState(() {
        _totalRestSeconds = saved;
        _progressController?.duration = Duration(seconds: _totalRestSeconds);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _elapsedTicker?.cancel();
    _progressController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveSessionState();
    } else if (state == AppLifecycleState.resumed && !widget.isEditing) {
      _restoreRestTimerOnResume();
    }
  }

  Future<void> _saveSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gain_session_start_time', _startTime.toIso8601String());
    
    if (_currentRestSeconds > 0) {
      final endTime = DateTime.now().add(Duration(seconds: _currentRestSeconds));
      await prefs.setString('gain_timer_end_time', endTime.toIso8601String());
      await prefs.setInt('gain_timer_total_seconds', _totalRestSeconds);
    } else {
      await prefs.remove('gain_timer_end_time');
    }
  }

  Future<void> _restoreSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStart = prefs.getString('gain_session_start_time');
    
    if (savedStart != null) {
      setState(() {
        _startTime = DateTime.parse(savedStart);
      });
    } else {
      for (var exercise in widget.session.exercises) {
        for (var set in exercise.sets) {
          set.isCompleted = false;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSessionUpdated());
    }
    _restoreRestTimerOnResume();
  }

  Future<void> _restoreRestTimerOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEndTime = prefs.getString('gain_timer_end_time');
    final savedTotal = prefs.getInt('gain_timer_total_seconds') ?? 90;

    if (savedEndTime != null) {
      final endTime = DateTime.parse(savedEndTime);
      final remainingSeconds = endTime.difference(DateTime.now()).inSeconds;

      if (remainingSeconds > 0) {
        setState(() {
          _totalRestSeconds = savedTotal;
          _currentRestSeconds = remainingSeconds;
        });
        _resumeRestTimer();
      } else {
        _clearSavedTimer();
      }
    }
  }

  void _resumeRestTimer() {
    _restTimer?.cancel();
    _progressController?.duration = Duration(seconds: _totalRestSeconds);
    _progressController?.value = 1.0 - (_currentRestSeconds / _totalRestSeconds);
    _progressController!.forward();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 1) {
        setState(() {
          _currentRestSeconds--;
        });
      } else {
        _stopRestTimer();
        _clearSavedTimer();
        _showChronoDoneSnackbar();
      }
    });
  }

  Future<void> _clearSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gain_timer_end_time');
  }

  Future<void> _clearAllSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gain_session_start_time');
    await prefs.remove('gain_timer_end_time');
  }

  void _showChronoDoneSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Chrono terminé 🦾", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: Colors.white)),
        backgroundColor: accentGold,
        duration: const Duration(seconds: 2),
      ),
    );
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
          {'user_id': user.id, 'name': 'Développé Couché (Barre)', 'category': 'Pectoraux'},
          {'user_id': user.id, 'name': 'Développé Incliné (Haltères)', 'category': 'Pectoraux'},
          {'user_id': user.id, 'name': 'Tractions (Poids de corps)', 'category': 'Dos'},
          {'user_id': user.id, 'name': 'Rowing Barre', 'category': 'Dos'},
          {'user_id': user.id, 'name': 'Squat Barre', 'category': 'Jambes'},
          {'user_id': user.id, 'name': 'Presse à cuisses', 'category': 'Jambes'},
          {'user_id': user.id, 'name': 'Développé Militaire', 'category': 'Épaules'},
          {'user_id': user.id, 'name': 'Élévations Latérales', 'category': 'Épaules'},
          {'user_id': user.id, 'name': 'Curl Biceps (Haltères)', 'category': 'Bras'},
          {'user_id': user.id, 'name': 'Extension Triceps (Poulie)', 'category': 'Bras'},
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

  void _startRestTimer([int? presetSeconds]) {
    _restTimer?.cancel();
    setState(() {
      if (presetSeconds != null) _totalRestSeconds = presetSeconds;
      _currentRestSeconds = _totalRestSeconds;
    });

    _progressController?.duration = Duration(seconds: _totalRestSeconds);
    _progressController?.reset();
    _progressController!.forward();

    _saveSessionState();
    if (presetSeconds != null) _saveDefaultRestSeconds(presetSeconds);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 1) {
        setState(() {
          _currentRestSeconds--;
        });
      } else {
        _stopRestTimer();
        _clearSavedTimer();
        _showChronoDoneSnackbar();
      }
    });
  }

  Future<void> _saveDefaultRestSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gain_default_rest_seconds', seconds);
  }

  void _adjustRestTime(int amountSeconds) {
    if (_currentRestSeconds <= 0) return;

    setState(() {
      _currentRestSeconds = (_currentRestSeconds + amountSeconds).clamp(0, 600);
      _totalRestSeconds = (_totalRestSeconds + amountSeconds).clamp(30, 600);
      
      if (_currentRestSeconds == 0) {
        _stopRestTimer();
        _clearSavedTimer();
        return;
      }

      _progressController?.duration = Duration(seconds: _totalRestSeconds);
      double newValue = 1.0 - (_currentRestSeconds / _totalRestSeconds);
      _progressController?.value = newValue.clamp(0.0, 1.0);
      _progressController!.forward();
    });
    _saveSessionState();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _progressController?.stop();
    // 🕒 On conserve _totalRestSeconds (durée préférée) plutôt que de la réinitialiser,
    // pour que le prochain repos reparte sur la même durée.
    setState(() {
      _currentRestSeconds = 0;
    });
    _clearSavedTimer();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  void _showNoteDialog(String title, String currentNote, Function(String) onSave) {
    final controller = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: textMain, fontFamily: 'Inter', fontSize: 14),
          decoration: InputDecoration(
            hintText: "Ressentis, blessures, objectifs...",
            hintStyle: TextStyle(color: textMuted.withValues(alpha:0.5)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0),
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      'notes': widget.session.notes,
    }).select().single();

    final workoutId = workoutResponse['id'];

    for (var exercise in widget.session.exercises) {
      final completedSets = exercise.sets.where((s) => s.isCompleted).toList();
      if (completedSets.isEmpty) continue; 

      final exerciseResponse = await supabase.from('workout_exercises').insert({
        'workout_id': workoutId,
        'exercise_name': exercise.name,
        'notes': exercise.notes,
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

    int completedSets = 0;
    double totalVolumeKg = 0;
    for (var exercise in widget.session.exercises) {
      for (var set in exercise.sets.where((s) => s.isCompleted)) {
        completedSets++;
        if (!exercise.isCardio) totalVolumeKg += set.weight * set.reps;
      }
    }
    final sessionDurationMinutes = DateTime.now().difference(_startTime).inMinutes;

    try {
      await _saveWorkoutToSupabase();
      await _clearAllSessionState();

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      List<String> completedDates = prefs.getStringList('completed_workouts') ?? [];
      if (!completedDates.contains(dateString)) {
        completedDates.add(dateString);
        await prefs.setStringList('completed_workouts', completedDates);
      }

      if (mounted) {
        Navigator.pop(context); // ferme le loader
        await _showSessionSummaryDialog(
          completedSets: completedSets,
          totalVolumeKg: totalVolumeKg,
          durationMinutes: sessionDurationMinutes == 0 ? 1 : sessionDurationMinutes,
        );
        if (mounted) Navigator.pop(context); // retour à la liste des programmes
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur cloud : $e", style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red[900],
          )
        );
      }
    }
  }

  Future<void> _showSessionSummaryDialog({
    required int completedSets,
    required double totalVolumeKg,
    required int durationMinutes,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: accentGold, size: 22),
            const SizedBox(width: 10),
            Text('Séance terminée', style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
          ],
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _summaryStat('$durationMinutes min', 'Durée'),
            _summaryStat('$completedSets', 'Séries'),
            _summaryStat('${totalVolumeKg.round()} kg', 'Volume'),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: bgColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Terminer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: accentGold, fontSize: 19, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: textMuted, fontSize: 11, fontFamily: 'Inter')),
      ],
    );
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
                      TextField(controller: setsController, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Séries", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                      TextField(controller: repsController, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, onSubmitted: (_) => FocusScope.of(context).unfocus(), style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Répétitions", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: alternativeController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        style: TextStyle(color: textMain),
                        decoration: InputDecoration(
                          labelText: "Exercice secondaire (Optionnel)",
                          labelStyle: TextStyle(color: textMuted),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
                        ),
                      ),
                    ] else ...[
                      TextField(controller: durationController, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Objectif Temps (min)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
                      TextField(controller: distanceController, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, onSubmitted: (_) => FocusScope.of(context).unfocus(), style: TextStyle(color: textMain), decoration: InputDecoration(labelText: "Objectif Distance (km)", labelStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)))),
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

  void _showRenameSessionDialog(WorkoutSession session) {
    final controller = TextEditingController(text: session.name);

    void submit() {
      final trimmed = controller.text.trim();
      if (trimmed.isNotEmpty) {
        setState(() => session.name = trimmed);
        widget.onSessionUpdated();
      }
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Renommer le programme', style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          style: TextStyle(color: textMain, fontFamily: 'Inter'),
          decoration: InputDecoration(
            labelText: 'Nom du programme',
            labelStyle: TextStyle(color: textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentGold)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: bgColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: submit,
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    final int totalSetsCount = session.exercises.fold(0, (sum, e) => sum + e.sets.length);
    final int completedSetsCount = session.exercises.fold(0, (sum, e) => sum + e.sets.where((s) => s.isCompleted).length);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: widget.isEditing
            ? InkWell(
                onTap: () => _showRenameSessionDialog(session),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        session.name.toUpperCase(),
                        style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 18, letterSpacing: 1.0),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.edit_rounded, size: 15, color: accentGold),
                  ],
                ),
              )
            : Text(
                session.name.toUpperCase(),
                style: TextStyle(color: textMain, fontFamily: 'TheSeason', fontSize: 18, letterSpacing: 1.0),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Column(
        children: [
          if (!widget.isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(DateTime.now().difference(_startTime).inSeconds),
                    style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                  const SizedBox(width: 18),
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '$completedSetsCount / $totalSetsCount séries',
                    style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                  const Spacer(),
                  if (totalSetsCount > 0)
                    SizedBox(
                      width: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: completedSetsCount / totalSetsCount,
                          backgroundColor: cardColor,
                          valueColor: AlwaysStoppedAnimation<Color>(accentGold),
                          minHeight: 4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (!widget.isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: InkWell(
                onTap: () => _showNoteDialog(
                  "Note globale de séance",
                  session.notes ?? "",
                  (val) {
                    setState(() => session.notes = val.isNotEmpty ? val : null);
                    widget.onSessionUpdated();
                  }
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha:0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: session.notes != null ? accentGold.withValues(alpha:0.3) : Colors.grey.shade900),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notes_rounded, color: session.notes != null ? accentGold : textMuted, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          session.notes ?? "Ajouter une note générale à cette séance...",
                          style: TextStyle(
                            color: session.notes != null ? textMain : textMuted.withValues(alpha:0.6),
                            fontSize: 12,
                            fontStyle: session.notes != null ? FontStyle.normal : FontStyle.italic,
                            fontFamily: 'Inter'
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (session.notes != null)
                        Icon(Icons.edit_rounded, color: accentGold, size: 12),
                    ],
                  ),
                ),
              ),
            ),

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
              // 🖐️ REORDERABLE LIST VIEW POUR RÉORDONNER LES EXERCICES
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: session.exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final exercise = session.exercises.removeAt(oldIndex);
                    session.exercises.insert(newIndex, exercise);

                    final expandedState = _isExpandedList.removeAt(oldIndex);
                    _isExpandedList.insert(newIndex, expandedState);
                  });
                  widget.onSessionUpdated();
                },
                itemBuilder: (context, exIndex) {
                  final exercise = session.exercises[exIndex];
                  final bool isExpanded = _isExpandedList[exIndex];
                  
                  final int completedSets = exercise.sets.where((s) => s.isCompleted).length;
                  final int totalSets = exercise.sets.length;
                  final bool allDone = totalSets > 0 && completedSets == totalSets && !widget.isEditing;

                  return Card(
                    // 🔑 Clé unique requise par ReorderableListView
                    key: ValueKey('exercise_${exercise.name}_$exIndex'),
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    color: cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: allDone ? accentGold.withValues(alpha:0.4) : Colors.transparent, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isExpandedList[exIndex] = !_isExpandedList[exIndex]),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // 🖐️ Poignée de glissement (Drag Handle)
                                ReorderableDragStartListener(
                                  index: exIndex,
                                  child: Container(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: textMuted.withValues(alpha: 0.4),
                                      size: 20,
                                    ),
                                  ),
                                ),
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
                                IconButton(
                                  icon: Icon(
                                    exercise.notes != null && exercise.notes!.isNotEmpty 
                                        ? Icons.sticky_note_2_rounded 
                                        : Icons.note_add_outlined,
                                    size: 18,
                                    color: exercise.notes != null && exercise.notes!.isNotEmpty ? accentGold : textMuted.withValues(alpha:0.4),
                                  ),
                                  onPressed: () => _showNoteDialog(
                                    "Note pour ${exercise.name}",
                                    exercise.notes ?? "",
                                    (val) {
                                      setState(() => exercise.notes = val.isNotEmpty ? val : null);
                                      widget.onSessionUpdated();
                                    }
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (!widget.isEditing)
                                  Text(
                                    allDone ? 'FAIT' : '$completedSets / $totalSets',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      color: allDone ? accentGold : textMuted
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
                        if (exercise.notes != null && exercise.notes!.isNotEmpty && !isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                            child: Text(
                              "📝 ${exercise.notes}",
                              style: TextStyle(color: textMuted, fontSize: 11, fontStyle: FontStyle.italic, fontFamily: 'Inter'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(height: 1, color: Colors.grey.shade900),
                                if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    "Note : ${exercise.notes}",
                                    style: TextStyle(color: textMuted.withValues(alpha:0.8), fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Inter'),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(flex: 1, child: Text(exercise.isCardio ? 'TOUR' : 'SÉRIE', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                                    Expanded(flex: 2, child: Text(exercise.isCardio ? 'MINUTES' : (widget.isEditing ? 'REPS CIBLE' : 'REPS'), style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                                    Expanded(flex: 2, child: Text(exercise.isCardio ? 'DISTANCE (KM)' : (widget.isEditing ? 'POIDS CIBLE' : 'KG'), style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                                    if (!exercise.isCardio)
                                      Expanded(flex: 1, child: Text('RIR', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold, fontFamily: 'Inter'), textAlign: TextAlign.center)),
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
                                                height: 38,
                                                margin: const EdgeInsets.only(right: 10),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                alignment: Alignment.center,
                                                child: TextFormField(
                                                  initialValue: exercise.isCardio ? currentSet.duration.toString() : currentSet.reps.toString(),
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  textInputAction: TextInputAction.done,
                                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                  ),
                                                  onChanged: (val) {
                                                    if (exercise.isCardio) {
                                                      currentSet.duration = int.tryParse(val) ?? currentSet.duration;
                                                    } else {
                                                      currentSet.reps = int.tryParse(val) ?? currentSet.reps;
                                                    }
                                                    widget.onSessionUpdated();
                                                  },
                                                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                height: 38,
                                                margin: const EdgeInsets.only(right: 10),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                alignment: Alignment.center,
                                                child: TextFormField(
                                                  initialValue: exercise.isCardio ? currentSet.distance.toString() : currentSet.weight.toString(),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  textAlign: TextAlign.center,
                                                  textInputAction: TextInputAction.done,
                                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                  ),
                                                  onChanged: (val) {
                                                    if (exercise.isCardio) {
                                                      currentSet.distance = double.tryParse(val) ?? currentSet.distance;
                                                    } else {
                                                      currentSet.weight = int.tryParse(val) ?? currentSet.weight;
                                                    }
                                                    widget.onSessionUpdated();
                                                  },
                                                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                                                ),
                                              ),
                                            ),
                                            if (!exercise.isCardio)
                                              Expanded(
                                                flex: 1,
                                                child: Align(
                                                  alignment: Alignment.center,
                                                  child: DropdownButtonHideUnderline(
                                                    child: DropdownButton<int>(
                                                      dropdownColor: cardColor,
                                                      value: currentSet.rir,
                                                      hint: Text("-", style: TextStyle(color: textHint, fontSize: 14, fontWeight: FontWeight.bold)),
                                                      icon: const SizedBox.shrink(),
                                                      style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter'),
                                                      onChanged: (int? newValue) {
                                                        setState(() {
                                                          currentSet.rir = newValue;
                                                        });
                                                        widget.onSessionUpdated();
                                                        _saveSessionState();
                                                      },
                                                      items: [0, 1, 2, 3, 4].map<DropdownMenuItem<int>>((int value) {
                                                        return DropdownMenuItem<int>(
                                                          value: value,
                                                          child: Text(value == 0 ? "0" : "$value"),
                                                        );
                                                      }).toList(),
                                                    ),
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
                                        Text(exercise.isCardio ? 'Tour' : 'Série', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
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
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border(top: BorderSide(color: Colors.grey.shade900)),
                  ),
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
                      Row(
                        children: [
                          for (final preset in _restPresets) ...[
                            InkWell(
                              onTap: () => _startRestTimer(preset),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _totalRestSeconds == preset ? accentGold.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _totalRestSeconds == preset ? accentGold.withValues(alpha: 0.4) : Colors.grey.shade800),
                                ),
                                child: Text(
                                  "${preset}s",
                                  style: TextStyle(
                                    color: _totalRestSeconds == preset ? accentGold : textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
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
                child: ElevatedButton(
                  onPressed: _finishWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: bgColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('TERMINER LA SÉANCE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontFamily: 'Inter')),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}