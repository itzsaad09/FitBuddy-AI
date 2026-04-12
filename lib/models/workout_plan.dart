import 'package:fitbuddy_ai/models/exercise.dart';

class WorkoutPlanResponse {
  final bool success;
  final WorkoutData data;
  final DateTime generatedAt;

  WorkoutPlanResponse({
    required this.success,
    required this.data,
    required this.generatedAt,
  });

  factory WorkoutPlanResponse.fromJson(Map<String, dynamic> json) {
    return WorkoutPlanResponse(
      success: json['success'] ?? false,
      data: WorkoutData.fromJson(json['data']),
      generatedAt: DateTime.parse(json['generated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.toJson(),
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

class WorkoutData {
  final List<DailyWorkout> plan;
  final int totalWeeklyMinutes;
  final String targetMuscle;

  WorkoutData({
    required this.plan,
    required this.totalWeeklyMinutes,
    required this.targetMuscle,
  });

  factory WorkoutData.fromJson(Map<String, dynamic> json) {
    return WorkoutData(
      plan: (json['plan'] as List)
          .map((i) => DailyWorkout.fromJson(i))
          .toList(),
      totalWeeklyMinutes: json['total_weekly_minutes'] ?? 0,
      targetMuscle: json['target_muscle'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan.map((i) => i.toJson()).toList(),
      'total_weekly_minutes': totalWeeklyMinutes,
      'target_muscle': targetMuscle,
    };
  }
}

class DailyWorkout {
  final int day;
  final String dayName;
  final String dailyFocus;
  final List<PlannedExercise> exercises;

  DailyWorkout({
    required this.day,
    required this.dayName,
    required this.dailyFocus,
    required this.exercises,
  });

  factory DailyWorkout.fromJson(Map<String, dynamic> json) {
    return DailyWorkout(
      day: json['day'] ?? 0,
      dayName: json['day_name'] ?? '',
      dailyFocus: json['daily_focus'] ?? '',
      exercises: (json['exercises'] as List)
          .map((i) => PlannedExercise.fromJson(i))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'day_name': dayName,
      'daily_focus': dailyFocus,
      'exercises': exercises.map((i) => i.toJson()).toList(),
    };
  }
}

class PlannedExercise {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final String reps;
  final int restSeconds;
  final String formCue;
  final Exercise details;

  PlannedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.formCue,
    required this.details,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseId: json['exercise_id'] ?? '',
      exerciseName: json['exercise_name'] ?? '',
      sets: json['sets'] ?? 0,
      reps: json['reps'] ?? '',
      restSeconds: json['rest_seconds'] ?? 0,
      formCue: json['form_cue'] ?? '',
      details: Exercise.fromJson(json['details']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'sets': sets,
      'reps': reps,
      'rest_seconds': restSeconds,
      'form_cue': formCue,
      'details': details.toJson(),
    };
  }
}
