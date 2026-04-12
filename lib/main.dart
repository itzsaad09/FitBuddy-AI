import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:fitbuddy_ai/models/user_profile.dart';
import 'package:fitbuddy_ai/services/theme_service.dart';
import 'package:fitbuddy_ai/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: const FitBuddy_AI(),
    ),
  );
}

class FitBuddy_AI extends StatelessWidget {
  const FitBuddy_AI({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    // Elegant Crystal Slate Dark Theme
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B4D8),
        brightness: Brightness.dark,
        surface: const Color(0xFF0D1117),
        onSurface: Colors.white,
        primary: const Color(0xFF00B4D8),
        secondary: const Color(0xFFFF9F1C),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1121),
      cardTheme: CardThemeData(
        color: const Color(0xFF161B22).withValues(alpha: 0.8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white70),
        systemOverlayStyle:
            SystemUiOverlayStyle.light, // White icons for dark background
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w300,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
    );

    // Elegant Professional Light Theme (Refined for visibility)
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0077B6),
        brightness: Brightness.light,
        surface: Colors.white,
        onSurface: const Color(
          0xFF0F172A,
        ), // Darker slate for better text contrast
        primary: const Color(0xFF0077B6),
        secondary: const Color(
          0xFFE36414,
        ), // More energetic but professional orange
      ),
      scaffoldBackgroundColor: const Color(
        0xFFF1F5F9,
      ), // Slightly darker gray for better surface contrast
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        systemOverlayStyle:
            SystemUiOverlayStyle.dark, // Dark icons for light background
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w300,
          color: Color(0xFF0F172A),
          letterSpacing: 2,
        ),
      ),
    );

    return MaterialApp(
      title: 'FitBuddy AI',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeService.themeMode,
      home: const MainScreen(),
    );
  }
}
