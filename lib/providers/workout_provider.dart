import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy_ai/models/workout_plan.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutPlanResponse? _weeklyPlan;
  bool _isLoading = false;

  WorkoutPlanResponse? get weeklyPlan => _weeklyPlan;
  bool get isLoading => _isLoading;

  WorkoutProvider() {
    _loadSavedPlan();
  }

  Future<void> _loadSavedPlan() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? planJson = prefs.getString('saved_weekly_plan');

      if (planJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(planJson);
        _weeklyPlan = WorkoutPlanResponse.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('Error loading saved workout plan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWeeklyPlan(WorkoutPlanResponse plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String planJson = jsonEncode(plan.toJson());
      await prefs.setString('saved_weekly_plan', planJson);

      _weeklyPlan = plan;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving workout plan: $e');
    }
  }

  Future<void> clearPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_weekly_plan');
      _weeklyPlan = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing workout plan: $e');
    }
  }
}
