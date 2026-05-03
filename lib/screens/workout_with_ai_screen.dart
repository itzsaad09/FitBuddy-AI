import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
  Timer? _timer;

  Uint8List? _processedImageBytes;
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
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          _startPoseDetection();
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _startPoseDetection() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_controller == null || !_controller!.value.isInitialized) return;
      if (_isProcessing) return;
      if (_backendUrl.isEmpty) return;

      if (mounted) {
        setState(() {
          _isProcessing = true;
        });
      }

      try {
        final XFile image = await _controller!.takePicture();
        final url = Uri.parse(_backendUrl);

        final request = http.MultipartRequest('POST', url);
        request.files.add(await http.MultipartFile.fromPath('image', image.path));

        final response = await request.send();
        if (response.statusCode == 200) {
          final respBody = await response.stream.bytesToString();
          final decoded = json.decode(respBody);
          final base64Image = decoded['image'];
          if (base64Image != null && mounted) {
            setState(() {
              _processedImageBytes = base64.decode(base64Image);
            });
          }
        }
      } catch (e) {
        debugPrint('Error sending image to backend: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI DETECTING JOINTS',
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
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_controller!),
                              if (_processedImageBytes != null)
                                Image.memory(
                                  _processedImageBytes!,
                                  fit: BoxFit.cover,
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
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        color: Colors.green,
                                        size: 10,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'LIVE POSE ACTIVE',
                                        style: TextStyle(
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
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(),
                        ),
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
                    SizedBox(width: 10),
                    Text(
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
