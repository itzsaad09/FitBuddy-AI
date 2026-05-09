import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
    _loadUrl();
    _initializeCamera();
    WakelockPlus.enable(); // Keep screen on
  }

  void _loadUrl() {
    String url = dotenv.env['BACKEND'] ?? dotenv.env['BACKEND_URL'] ?? '';
    if (url.isNotEmpty) {
      if (!url.startsWith('http')) url = 'https://$url';
      if (!url.endsWith('/detect')) {
        url = url.endsWith('/') ? '${url}detect' : '$url/detect';
      }
    }
    _backendUrl = url;
    print('DEBUG: Target Backend URL is: "$_backendUrl"');
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
          ResolutionPreset.medium, // Changed to medium for better AI detection
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          print('DEBUG: Camera initialized. Starting loop...');
          _processFrameLoop();
        }
      }
    } catch (e) {
      print('DEBUG: Camera error: $e');
    }
  }

  Future<void> _processFrameLoop() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      print('DEBUG: Loop aborted - controller not ready');
      return;
    }
    if (_isProcessing) return;
    
    if (_backendUrl.isEmpty) {
      print('DEBUG: Error - Backend URL is empty! Check your .env file.');
      Future.delayed(const Duration(seconds: 2), _processFrameLoop);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      print('DEBUG: 1. Capturing picture...');
      final XFile image = await _controller!.takePicture();
      print('DEBUG: 2. Picture saved at ${image.path}. Sending to backend...');

      final url = Uri.parse(_backendUrl);
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      print('DEBUG: 3. Request sent. Waiting for Python response...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      print('DEBUG: 4. Received Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final landmarks = decoded['landmarks'];
        
        if (landmarks != null) {
          print('DEBUG: SUCCESS! Received ${landmarks.length} landmarks.');
          if (mounted) {
            setState(() {
              _landmarks = landmarks;
            });
          }
        } else {
          print('DEBUG: Error - Backend returned 200 but no "landmarks" key found.');
        }
      } else {
        print('DEBUG: Backend error: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Network/Request failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // Wait a bit before next attempt to prevent overwhelming the server
        Future.delayed(const Duration(milliseconds: 100), _processFrameLoop);
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Allow screen to sleep again
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI LIVE TRACKING',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
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
                            if (_landmarks != null && _landmarks!.isNotEmpty)
                              CustomPaint(
                                painter: LandmarkPainter(_landmarks!),
                              ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: _isProcessing ? Colors.orange : Colors.green, size: 10),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isProcessing ? 'AI THINKING...' : 'LIVE TRACKING',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('RETURN TO WORKOUT'),
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
    final paint = Paint()..color = Colors.greenAccent..strokeWidth = 4.0..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = Colors.red..style = PaintingStyle.fill;

    void drawLine(int i1, int i2) {
      if (i1 < landmarks.length && i2 < landmarks.length) {
        final lm1 = landmarks[i1]; final lm2 = landmarks[i2];
        canvas.drawLine(
          Offset(size.width - (lm1['x'] * size.width), lm1['y'] * size.height),
          Offset(size.width - (lm2['x'] * size.width), lm2['y'] * size.height),
          paint,
        );
      }
    }

    drawLine(11, 12); drawLine(11, 13); drawLine(13, 15); drawLine(12, 14); drawLine(14, 16);
    drawLine(11, 23); drawLine(12, 24); drawLine(23, 24); drawLine(23, 25); drawLine(25, 27);
    drawLine(24, 26); drawLine(26, 28);

    for (var lm in landmarks) {
      canvas.drawCircle(Offset(size.width - (lm['x'] * size.width), lm['y'] * size.height), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
