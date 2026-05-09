import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  Uint8List? _processedImageBytes;
  String _backendUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _initializeCamera();
    WakelockPlus.enable();
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
          _processFrameLoop();
        }
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _processFrameLoop() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;
    
    if (_backendUrl.isEmpty) {
      Future.delayed(const Duration(seconds: 2), _processFrameLoop);
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

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final base64Image = decoded['image'];
        
        if (base64Image != null && mounted) {
          setState(() {
            _processedImageBytes = base64.decode(base64Image);
          });
        }
      }
    } catch (e) {
      debugPrint('Network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        Future.delayed(const Duration(milliseconds: 10), _processFrameLoop);
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI WORKOUT REAL-TIME',
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
                            
                            // Display the processed "video" frame from Python
                            if (_processedImageBytes != null)
                              Image.memory(
                                _processedImageBytes!,
                                fit: BoxFit.cover,
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
                                    const Text(
                                      'PYTHON VIDEO LIVE',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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
