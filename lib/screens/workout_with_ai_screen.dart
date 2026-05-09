import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WorkoutWithAiScreen extends StatefulWidget {
  const WorkoutWithAiScreen({super.key});

  @override
  State<WorkoutWithAiScreen> createState() => _WorkoutWithAiScreenState();
}

class _WorkoutWithAiScreenState extends State<WorkoutWithAiScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  List<dynamic> _targetLandmarks = [];
  List<Map<String, dynamic>> _currentLandmarks = []; 
  late Ticker _ticker;
  
  String _localUrl = '';
  String _remoteUrl = '';
  String _currentActiveUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUrls();
    _initializeCamera();
    _initializeSmoothing();
    WakelockPlus.enable();
  }

  void _loadUrls() {
    String local = dotenv.env['LOCAL_BACKEND_URL'] ?? '';
    String remote = dotenv.env['BACKEND'] ?? '';

    String format(String u) {
      if (u.isEmpty) return '';
      if (!u.startsWith('http')) u = 'https://$u';
      if (!u.endsWith('/detect')) {
        u = u.endsWith('/') ? '${u}detect' : '$u/detect';
      }
      return u;
    }

    _localUrl = format(local);
    _remoteUrl = format(remote);
    _currentActiveUrl = _localUrl.isNotEmpty ? _localUrl : _remoteUrl;
  }

  void _initializeSmoothing() {
    _ticker = createTicker((elapsed) {
      if (_targetLandmarks.isEmpty) return;
      if (_currentLandmarks.isEmpty || _currentLandmarks.length != _targetLandmarks.length) {
        _currentLandmarks = _targetLandmarks.map((m) => Map<String, dynamic>.from(m)).toList();
      } else {
        for (int i = 0; i < _targetLandmarks.length; i++) {
          final target = _targetLandmarks[i];
          final current = _currentLandmarks[i];
          current['x'] += ((target['x'] as num).toDouble() - (current['x'] as num).toDouble()) * 0.25;
          current['y'] += ((target['y'] as num).toDouble() - (current['y'] as num).toDouble()) * 0.25;
          current['v'] = (target['v'] as num).toDouble();
        }
      }
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final CameraDescription selectedCamera = _cameras!.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
          _startProcessingLoop();
        }
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  Future<void> _startProcessingLoop() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;
    if (_currentActiveUrl.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final XFile image = await _controller!.takePicture();
      final request = http.MultipartRequest('POST', Uri.parse(_currentActiveUrl));
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 3));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final landmarks = decoded['landmarks'];
        if (mounted && landmarks != null) {
          _targetLandmarks = landmarks;
        }
      } else if (_currentActiveUrl == _localUrl && _remoteUrl.isNotEmpty) {
        _fallbackToRemote();
      }
    } catch (e) {
      if (_currentActiveUrl == _localUrl && _remoteUrl.isNotEmpty) {
        _fallbackToRemote();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _startProcessingLoop();
      }
    }
  }

  void _fallbackToRemote() {
    setState(() { _currentActiveUrl = _remoteUrl; });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ticker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'SMOOTH AI WORKOUT',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isCameraInitialized && _controller != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Camera View with Correct Fill
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: CameraPreview(_controller!),
                              ),
                            ),

                            // 2. AI Overlay aligned to the FittedBox
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: CustomPaint(
                                  painter: PosePainter(
                                    landmarks: _currentLandmarks,
                                    isFrontCamera: _controller!.description.lensDirection == CameraLensDirection.front,
                                  ),
                                ),
                              ),
                            ),
                            
                            // 3. UI Overlays (Badges)
                            Positioned(
                              top: 20,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 0.5),
                                ),
                                child: Text(
                                  _currentActiveUrl == _localUrl ? 'LOCAL: LOW LATENCY' : 'REMOTE: CLOUD AI',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                  ),
                  child: const Text('FINISH WORKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Map<String, dynamic>> landmarks;
  final bool isFrontCamera;

  PosePainter({required this.landmarks, required this.isFrontCamera});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final paintJoint = Paint()..color = Colors.cyanAccent.withOpacity(0.9)..strokeWidth = 6..strokeCap = StrokeCap.round;
    final paintLine = Paint()..color = Colors.greenAccent.withOpacity(0.7)..strokeWidth = 4..strokeCap = StrokeCap.round;

    Offset? getPos(int index) {
      if (index >= landmarks.length) return null;
      final lm = landmarks[index];
      if ((lm['v'] as num).toDouble() < 0.3) return null;

      double x = (lm['x'] as num).toDouble();
      double y = (lm['y'] as num).toDouble();
      
      // Mirroring for front camera
      if (isFrontCamera) x = 1.0 - x;

      return Offset(x * size.width, y * size.height);
    }

    final connections = [
      [11, 12], [11, 13], [13, 15], [12, 14], [14, 16],
      [11, 23], [12, 24], [23, 24], [23, 25], [25, 27], [24, 26], [26, 28],
    ];

    for (final conn in connections) {
      final p1 = getPos(conn[0]);
      final p2 = getPos(conn[1]);
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paintLine);
    }

    for (int i = 0; i < landmarks.length; i++) {
      final pos = getPos(i);
      if (pos != null) canvas.drawCircle(pos, 4, paintJoint);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
