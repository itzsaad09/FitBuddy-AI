import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fitbuddy_ai/models/user_profile.dart';
import 'package:fitbuddy_ai/screens/main_screen.dart';

class SetupScreen extends StatefulWidget {
  final bool isEditing;
  const SetupScreen({super.key, this.isEditing = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    _heightController = TextEditingController(
      text: widget.isEditing ? profile.height.toString() : '',
    );
    _ageController = TextEditingController(
      text: widget.isEditing ? profile.age.toString() : '',
    );
    _weightController = TextEditingController(
      text: widget.isEditing ? profile.weight.toString() : '',
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      await Provider.of<UserProfileProvider>(
        context,
        listen: false,
      ).updateProfile(
        height: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        weight: double.parse(_weightController.text),
      );

      if (mounted) {
        if (widget.isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // Elegant Slate Background
          Positioned.fill(
            child: Container(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          // Subtle Ambient Glow
          Positioned(
            top: -150,
            right: -50,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: isDark ? 0.03 : 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isEditing ? 'PROFILE' : 'WELCOME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isEditing ? 'Refine Metrics' : 'FitBuddyAI',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'High-performance tracking for your journey.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: isDark ? 0.4 : 0.6),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 64),
                    _buildGlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildInput(
                              label: 'Height',
                              suffix: 'cm',
                              controller: _heightController,
                            ),
                            const SizedBox(height: 40),
                            _buildInput(
                              label: 'Age',
                              suffix: 'yr',
                              controller: _ageController,
                              isInteger: true,
                            ),
                            const SizedBox(height: 40),
                            _buildInput(
                              label: 'Weight',
                              suffix: 'kg',
                              controller: _weightController,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 64),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isEditing ? 'UPDATE PROFILE' : 'GET STARTED',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    if (widget.isEditing)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'DISCARD CHANGES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: isDark ? 0.3 : 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(40),
      child: child,
    );
  }

  Widget _buildInput({
    required String label,
    required String suffix,
    required TextEditingController controller,
    bool isInteger = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.7),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'REQUIRED';
            if (double.tryParse(value) == null) return 'INVALID';
            return null;
          },
        ),
      ],
    );
  }
}
