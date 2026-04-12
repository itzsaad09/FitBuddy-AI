import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fitbuddy_ai/models/exercise.dart';
import 'package:fitbuddy_ai/models/workout_plan.dart';
import 'package:fitbuddy_ai/services/database_service.dart';

class ApiService {
  final DatabaseService _db = DatabaseService();
  String? get geminiKey {
    final key = dotenv.env['API_KEY'];
    if (key == null || key == 'YOUR_API_KEY_HERE' || key.isEmpty) return null;
    return key;
  }

  // Cache for CSV exercises
  List<Exercise>? _cachedCsvExercises;

  Future<List<Exercise>> fetchExercisesByBodyPart(
    String bodyPart, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final results = await _loadExercisesFromCsv();
      final filtered = results
          .where(
            (e) =>
                e.bodyPart.toLowerCase().trim() ==
                bodyPart.toLowerCase().trim(),
          )
          .toList();

      debugPrint(
        'Loaded ${results.length} total, filtered ${filtered.length} for $bodyPart',
      );

      if (filtered.isNotEmpty) {
        final start = offset.clamp(0, filtered.length);
        final end = (offset + limit).clamp(0, filtered.length);
        return filtered.sublist(start, end);
      }
      return [];
    } catch (e) {
      debugPrint('Error loading exercises for $bodyPart: $e');
      return [];
    }
  }

  Future<List<Exercise>> _loadExercisesFromCsv() async {
    if (_cachedCsvExercises != null) return _cachedCsvExercises!;

    try {
      String csvString = await rootBundle.loadString('assets/exercises.csv');

      // Strip UTF-8 BOM if present (common issue in Linux builds/CI)
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      debugPrint('CSV loaded. Bytes: ${csvString.length}');
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
      );

      if (rows.isEmpty) return [];

      final headers = rows.first
          .map((e) => e.toString().toLowerCase().trim().replaceAll('"', ''))
          .toList();
      final List<Exercise> exercises = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final Map<String, dynamic> mapped = {};
        for (int j = 0; j < headers.length; j++) {
          if (j < row.length) {
            String value = row[j].toString().trim();
            // Remove literal outer quotes if the parser didn't strip them
            if (value.startsWith('"') && value.endsWith('"')) {
              value = value.substring(1, value.length - 1);
            }
            mapped[headers[j]] = value;
          }
        }
        exercises.add(Exercise.fromJson(mapped));
      }

      _cachedCsvExercises = exercises;
      return exercises;
    } catch (e) {
      debugPrint('Error loading exercises from CSV: $e');
      return [];
    }
  }

  Future<Exercise> fetchExerciseById(String id) async {
    try {
      final List<Exercise> allExercises = await _loadExercisesFromCsv();
      return allExercises.firstWhere((e) => e.id == id);
    } catch (e) {
      throw Exception('Exercise not found locally: $id');
    }
  }

  Future<WorkoutPlanResponse> generateWorkoutPlanWithAI({
    required String instruction,
  }) async {
    if (geminiKey == null) {
      throw Exception('Gemini API key is missing. Add GEMINI_API_KEY to .env');
    }

    try {
      final List<Exercise> allExercises = await _loadExercisesFromCsv();
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiKey!,
      );

      // Compact list of available exercises to keep tokens efficient
      final exercisesListStr = allExercises
          .map((e) => 'ID: ${e.id}, Name: ${e.name}, Muscle: ${e.target}')
          .join('\n');

      final prompt =
          '''
You are an expert professional fitness trainer and workout programmer. Create a highly customized 7-day workout plan based on the client's specific physical profile and target goals.

CLIENT PROFILE:
- USER INSTRUCTION: $instruction
(Note: The instruction should contain the user's Age, Weight, and Height. If they are missing, please use reasonable defaults for a healthy adult but prioritize any specific goals mentioned.)

AVAILABLE EXERCISES (You MUST strictly use ONLY these exercise IDs and names):
$exercisesListStr

INSTRUCTIONS:
1. Identify the Target Muscle, Goal, and any Profile Data (Age, Height, Weight) from the USER INSTRUCTION.
2. Create a 7-day workout plan (Monday to Sunday) focused on that goal.
3. Factor in the client's age, weight, and height (if provided) to determine the appropriate volume (sets/reps) and rest periods.
4. ONLY select exercises from the provided AVAILABLE EXERCISES list.
5. For each exercise, specify:
   - exercise_id (exact match from the list)
   - exercise_name (exact match from the list)
   - sets (number of sets, usually 3-5)
   - reps (string, e.g., "8-12" for hypertrophy)
   - rest_seconds (number)
   - form_cue (string, one brief tip)
6. Implement progressive overload as the week progresses.

RESPONSE FORMAT (STRICT JSON ONLY, no other text or markdown wrapping):
{
  "client_summary": {
    "target_muscle": "...",
    "profile": "Based on provided or assumed metrics"
  },
  "plan": [
    {
      "day": 1,
      "day_name": "Monday",
      "daily_focus": "e.g., Heavy Compound or Rest",
      "exercises": [
        {
          "exercise_id": "0001",
          "exercise_name": "Example Exercise",
          "sets": 4,
          "reps": "8-10",
          "rest_seconds": 90,
          "form_cue": "Control the eccentric portion"
        }
      ]
    }
  ]
}
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final text = response.text;

      if (text == null) throw Exception('No response from AI');

      // Clean the response (remove markdown code blocks if present)
      String cleanJson = text;
      if (text.contains('```json')) {
        cleanJson = text.split('```json')[1].split('```')[0];
      } else if (text.contains('```')) {
        cleanJson = text.split('```')[1].split('```')[0];
      }
      cleanJson = cleanJson.trim();

      final Map<String, dynamic> decoded = json.decode(cleanJson);

      // Build the final response with full exercise details
      final List<DailyWorkout> dailyWorkouts = [];
      for (var day in decoded['plan']) {
        final List<PlannedExercise> plannedExercises = [];
        for (var ex in day['exercises']) {
          final String exId = ex['exercise_id'].toString().padLeft(4, '0');
          // Find exercise details in local list
          final Exercise details = allExercises.firstWhere(
            (e) => e.id == exId,
            orElse: () => Exercise(
              id: exId,
              name: ex['exercise_name'],
              bodyPart: 'General',
              target: 'Misc',
              equipment: 'None',
              gifUrl: '',
              instructions: [],
            ),
          );

          plannedExercises.add(
            PlannedExercise(
              exerciseId: exId,
              exerciseName: ex['exercise_name'],
              sets: ex['sets'] is int
                  ? ex['sets']
                  : int.tryParse(ex['sets'].toString()) ?? 3,
              reps: ex['reps'].toString(),
              restSeconds: ex['rest_seconds'] is int
                  ? ex['rest_seconds']
                  : int.tryParse(ex['rest_seconds'].toString()) ?? 60,
              formCue: ex['form_cue'] ?? '',
              details: details,
            ),
          );
        }

        dailyWorkouts.add(
          DailyWorkout(
            day: day['day'],
            dayName: day['day_name'],
            dailyFocus: day['daily_focus'] ?? '',
            exercises: plannedExercises,
          ),
        );
      }

      final finalResponse = WorkoutPlanResponse(
        success: true,
        generatedAt: DateTime.now(),
        data: WorkoutData(
          plan: dailyWorkouts,
          totalWeeklyMinutes: dailyWorkouts.length * 60, // Estimate
          targetMuscle:
              decoded['client_summary']['target_muscle'] ?? 'Personalized',
        ),
      );

      // Persist to local storage
      await _db.saveWorkoutPlan(finalResponse);

      return finalResponse;
    } catch (e) {
      debugPrint('AI generation failed: $e');
      throw Exception('Failed to generate plan: $e');
    }
  }
}
