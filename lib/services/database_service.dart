import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:fitbuddy_ai/models/workout_plan.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database?> get database async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return null;
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'fitbuddyai.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_plans(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_muscle TEXT,
            plan_json TEXT,
            generated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE exercise_gifs(
            exercise_id TEXT PRIMARY KEY,
            gif_blob BLOB
          )
        ''');
        await db.execute('''
          CREATE TABLE workout_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exercise_name TEXT,
            reps INTEGER,
            completed_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE workout_history(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              exercise_name TEXT,
              reps INTEGER,
              completed_at TEXT
            )
          ''');
        }
      },
    );
  }

  // --- Workout Plan Persistence ---

  Future<void> saveWorkoutPlan(WorkoutPlanResponse plan) async {
    final db = await database;
    if (db == null) return;

    await db.insert('workout_plans', {
      'target_muscle': plan.data.targetMuscle,
      'plan_json': jsonEncode(plan.toJson()),
      'generated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<WorkoutPlanResponse?> getLatestWorkoutPlan() async {
    final db = await database;
    if (db == null) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'workout_plans',
      orderBy: 'generated_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final String jsonStr = maps.first['plan_json'];
    return WorkoutPlanResponse.fromJson(jsonDecode(jsonStr));
  }

  // --- GIF Caching ---

  Future<void> saveGif(String exerciseId, Uint8List gifBlob) async {
    final db = await database;
    if (db == null) return;

    await db.insert('exercise_gifs', {
      'exercise_id': exerciseId,
      'gif_blob': gifBlob,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Uint8List?> getGif(String exerciseId) async {
    final db = await database;
    if (db == null) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'exercise_gifs',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );

    if (maps.isEmpty) return null;
    return maps.first['gif_blob'] as Uint8List;
  }

  // --- Workout History & Weekly Tracking ---

  Future<void> saveWorkoutSession(String exerciseName, int reps) async {
    final db = await database;
    if (db == null) return;

    await db.insert('workout_history', {
      'exercise_name': exerciseName,
      'reps': reps,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getWorkoutHistory() async {
    final db = await database;
    if (db == null) return [];

    return await db.query(
      'workout_history',
      orderBy: 'completed_at DESC',
    );
  }

  Future<Map<String, int>> getWeeklyProgressSummary() async {
    final db = await database;
    if (db == null) return {};

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    
    final List<Map<String, dynamic>> results = await db.query(
      'workout_history',
      where: 'completed_at >= ?',
      whereArgs: [sevenDaysAgo],
    );

    final Map<String, int> summary = {};
    for (final row in results) {
      final name = row['exercise_name'] as String;
      final reps = row['reps'] as int;
      summary[name] = (summary[name] ?? 0) + reps;
    }
    return summary;
  }

  // --- Data Portability (Backup Export & Import) ---

  Future<String> exportDatabaseToJson() async {
    final db = await database;
    if (db == null) return '{}';

    final List<Map<String, dynamic>> plans = await db.query('workout_plans');
    final List<Map<String, dynamic>> history = await db.query('workout_history');

    final backup = {
      'version': 2,
      'workout_plans': plans,
      'workout_history': history,
      'exported_at': DateTime.now().toIso8601String(),
    };

    return jsonEncode(backup);
  }

  Future<void> importDatabaseFromJson(String jsonString) async {
    final db = await database;
    if (db == null) return;

    final Map<String, dynamic> backup = jsonDecode(jsonString);
    final List<dynamic> plans = backup['workout_plans'] ?? [];
    final List<dynamic> history = backup['workout_history'] ?? [];

    await db.transaction((txn) async {
      // Clear existing records
      await txn.delete('workout_plans');
      await txn.delete('workout_history');

      // Restore plans
      for (final plan in plans) {
        await txn.insert('workout_plans', Map<String, dynamic>.from(plan), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Restore history
      for (final session in history) {
        await txn.insert('workout_history', Map<String, dynamic>.from(session));
      }
    });
  }
}
