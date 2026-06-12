import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fitbuddy_ai/services/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class ProgressReportScreen extends StatefulWidget {
  const ProgressReportScreen({super.key});

  @override
  State<ProgressReportScreen> createState() => _ProgressReportScreenState();
}

class _ProgressReportScreenState extends State<ProgressReportScreen> {
  final DatabaseService _db = DatabaseService();
  Map<String, int> _weeklySummary = {};
  List<Map<String, dynamic>> _historyLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final summary = await _db.getWeeklyProgressSummary();
    final history = await _db.getWorkoutHistory();
    if (mounted) {
      setState(() {
        _weeklySummary = summary;
        _historyLogs = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportBackup() async {
    try {
      final jsonBackup = await _db.exportDatabaseToJson();
      
      // Get temporary directory to write the file to
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/fitbuddy_backup.json');
      await tempFile.writeAsString(jsonBackup);
      
      // Trigger the native share-sheet
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'FitBuddy AI Backup - Workout Logs & Plans',
        ),
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup export window closed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export file: $e')),
      );
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        // User cancelled picker
        return;
      }

      final file = File(result.files.single.path!);
      final jsonContent = await file.readAsString();

      // Validate JSON content before importing
      final Map<String, dynamic> parsed = jsonDecode(jsonContent);
      if (!parsed.containsKey('workout_plans') || !parsed.containsKey('workout_history')) {
        throw const FormatException('Invalid backup file schema.');
      }

      await _db.importDatabaseFromJson(jsonContent);
      
      if (!mounted) return;
      _loadReportData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file imported and restored successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import backup file: $e')),
      );
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    int totalWeeklyReps = _weeklySummary.values.fold(0, (sum, val) => sum + val);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'PROGRESS PROFILE',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 4),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  // --- Weekly Reps Header card ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WEEKLY ANALYTICS SUMMARY',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$totalWeeklyReps REPS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const Text(
                              'Completed across the past 7 days',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- Backup and Portability Card ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATA PORTABILITY & BACKUP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _exportBackup,
                                    icon: const Icon(Icons.share_rounded, size: 18),
                                    label: const Text('EXPORT BACKUP FILE'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _importBackup,
                                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                                    label: const Text('RESTORE FILE'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.textTheme.bodyLarge?.color,
                                      side: BorderSide(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- Weekly Reps By Exercise Header ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                      child: Text(
                        'EXERCISE SPECIFIC PROGRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),

                  if (_weeklySummary.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: Text(
                            'No workouts completed in the last 7 days. Complete an AI workout to see progress!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final key = _weeklySummary.keys.toList()[index];
                          final val = _weeklySummary[key]!;
                          // Simple mock max ceiling reps for visualization
                          final double progress = (val / 100.0).clamp(0.05, 1.0);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        key.toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '$val reps',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _weeklySummary.length,
                      ),
                    ),

                  // --- Completed History Logs ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                      child: Text(
                        'CHRONOLOGICAL HISTORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),

                  if (_historyLogs.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: Text(
                            'No logged workouts found.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final log = _historyLogs[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.check_circle_outline_rounded, color: colorScheme.primary, size: 20),
                            ),
                            title: Text(
                              log['exercise_name'].toString().toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            subtitle: Text(
                              _formatDate(log['completed_at']),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Text(
                              '${log['reps']} REPS',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          );
                        },
                        childCount: _historyLogs.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }
}
