import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WorkoutWithAiScreen extends StatefulWidget {
  const WorkoutWithAiScreen({super.key});

  @override
  State<WorkoutWithAiScreen> createState() => _WorkoutWithAiScreenState();
}

class _WorkoutWithAiScreenState extends State<WorkoutWithAiScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  List<dynamic>? _landmarks;
  String _backendUrl = '';

  @override
  void initState() {
    super.initState();
    String url = dotenv.env['BACKEND'] ?? dotenv.env['BACKEND_URL'] ?? '';
    if (url.isNotEmpty && !url.endsWith('/detect')) {
      url = url.endsWith('/') ? '${url}detect' : '$url/detect';
    }
    _backendUrl = url;
    _initializeCamera();
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
          ResolutionPreset.low, // 'low' is much faster and reduces lag significantly
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          _processFrameLoop();
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _processFrameLoop() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;
    if (_backendUrl.isEmpty) {
      Future.delayed(const Duration(seconds: 1), _processFrameLoop);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final url = Uri.parse(_backendUrl);

      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send().timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final respBody = await response.stream.bytesToString();
        final decoded = json.decode(respBody);
        final landmarks = decoded['landmarks'];
        
        if (landmarks != null && mounted) {
          debugPrint('Received ${landmarks.length} landmarks from Python');
          setState(() {
            _landmarks = landmarks;
          });
        }
      } else {
        debugPrint('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Python Backend network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // Faster loop for smoother tracking
        Future.delayed(const Duration(milliseconds: 10), _processFrameLoop);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI LIVE TRACKING',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isCameraInitialized && _controller != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            
                            // Improved Landmark Overlay
                            if (_landmarks != null && _landmarks!.isNotEmpty)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: LandmarkPainter(_landmarks!),
                                ),
                              ),

                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: _isProcessing ? Colors.orange : Colors.green,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isProcessing ? 'AI THINKING...' : 'LIVE TRACKING',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'RETURN TO WORKOUT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  final List<dynamic> landmarks;

  LandmarkPainter(this.landmarks);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    void drawLine(int i1, int i2) {
      if (i1 < landmarks.length && i2 < landmarks.length) {
        final lm1 = landmarks[i1];
        final lm2 = landmarks[i2];
        
        // Ensure values are within 0-1 range
        double x1 = (lm1['x'] as num).toDouble();
        double y1 = (lm1['y'] as num).toDouble();
        double x2 = (lm2['x'] as num).toDouble();
        double y2 = (lm2['y'] as num).toDouble();

        canvas.drawLine(
          Offset(size.width - (x1 * size.width), y1 * size.height),
          Offset(size.width - (x2 * size.width), y2 * size.height),
          paint,
        );
      }
    }

    // Connect standard joints
    drawLine(11, 12); // Shoulders
    drawLine(11, 13); drawLine(13, 15); // Left Arm
    drawLine(12, 14); drawLine(14, 16); // Right Arm
    drawLine(11, 23); drawLine(12, 24); // Torso Side
    drawLine(23, 24); // Hips
    drawLine(23, 25); drawLine(25, 27); // Left Leg
    drawLine(24, 26); drawLine(26, 28); // Right Leg

    // Draw all points
    for (var lm in landmarks) {
      double x = (lm['x'] as num).toDouble();
      double y = (lm['y'] as num).toDouble();
      canvas.drawCircle(
        Offset(size.width - (x * size.width), y * size.height),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
