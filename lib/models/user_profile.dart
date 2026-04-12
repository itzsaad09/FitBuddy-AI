import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileProvider extends ChangeNotifier {
  double _height = 0.0;
  int _age = 0;
  double _weight = 0.0;
  bool _isSetupComplete = false;

  double get height => _height;
  int get age => _age;
  double get weight => _weight;
  bool get isSetupComplete => _isSetupComplete;

  UserProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _height = prefs.getDouble('height') ?? 0.0;
    _age = prefs.getInt('age') ?? 0;
    _weight = prefs.getDouble('weight') ?? 0.0;
    _isSetupComplete = prefs.getBool('is_setup_complete') ?? false;
    notifyListeners();
  }

  Future<void> updateProfile({
    required double height,
    required int age,
    required double weight,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('height', height);
    await prefs.setInt('age', age);
    await prefs.setDouble('weight', weight);
    await prefs.setBool('is_setup_complete', true);

    _height = height;
    _age = age;
    _weight = weight;
    _isSetupComplete = true;
    notifyListeners();
  }
}
