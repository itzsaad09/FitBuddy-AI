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
      version: 1,
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
}
