import 'package:flutter/material.dart';
import 'package:fitbuddy_ai/models/exercise.dart';
import 'package:fitbuddy_ai/services/api_service.dart';
import 'package:fitbuddy_ai/widgets/cached_gif.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fitbuddy_ai/screens/workout_with_ai_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final ApiService _apiService = ApiService();
  late Exercise _currentExercise;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _currentExercise = widget.exercise;
    // If the passed exercise is a "shallow" object (no instructions), fetch more details
    if (_currentExercise.instructions.isEmpty) {
      _fetchFullDetails();
    }
  }

  Future<void> _fetchFullDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final fullExercise = await _apiService.fetchExerciseById(
        _currentExercise.id,
      );
      if (mounted) {
        setState(() {
          _currentExercise = fullExercise;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'exercise_gif_${_currentExercise.id}',
                    child: CachedGif(
                      exerciseId: _currentExercise.id,
                      gifUrl: _currentExercise.gifUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Gradient Overlay for text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.2),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.6, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentExercise.target.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _capitalizeEachWord(_currentExercise.name),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ElegantTag(text: _currentExercise.bodyPart),
                      _ElegantTag(text: _currentExercise.equipment),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Technique',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoadingDetails)
                    ...List.generate(
                      4,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Shimmer.fromColors(
                          baseColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          highlightColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 14,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 14,
                                      width: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_currentExercise.instructions.isEmpty)
                    Text(
                      'No specific instructions available.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  else
                    ..._buildInstructions(
                      context,
                      _currentExercise.instructions,
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutWithAiScreen(
                    targetMuscle: _currentExercise.target,
                    exerciseName: _currentExercise.name,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18),
                SizedBox(width: 10),
                Text(
                  'START WORKOUT WITH AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  List<Widget> _buildInstructions(
    BuildContext context,
    List<String> instructions,
  ) {
    return instructions.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final text = entry.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: 32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 1,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _ElegantTag extends StatelessWidget {
  final String text;

  const _ElegantTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
