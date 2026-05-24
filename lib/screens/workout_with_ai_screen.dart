import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class WorkoutWithAiScreen extends StatefulWidget {
  final String targetMuscle;
  final String exerciseName;
  const WorkoutWithAiScreen({
    super.key,
    this.targetMuscle = 'general',
    this.exerciseName = 'Workout',
  });

  @override
  State<WorkoutWithAiScreen> createState() => _WorkoutWithAiScreenState();
}

class _WorkoutWithAiScreenState extends State<WorkoutWithAiScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  List<dynamic> _targetLandmarks = [];
  List<Map<String, dynamic>> _currentLandmarks = [];
  late Ticker _ticker;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _currentFormStatus = 'WAITING...';

  String _localUrl = '';
  String _remoteUrl = '';
  String _currentActiveUrl = '';
  int _repCount = 0;
  String _lastState = 'UNKNOWN';
  String _guidanceTip = 'READY';

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
      if (u.startsWith('http://')) u = u.replaceFirst('http://', 'ws://');
      if (u.startsWith('https://')) u = u.replaceFirst('https://', 'wss://');
      if (!u.startsWith('ws')) u = 'ws://$u';
      if (!u.endsWith('/ws/detect')) {
        if (u.endsWith('/')) u = u.substring(0, u.length - 1);
        u = '$u/ws/detect';
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
      if (_currentLandmarks.isEmpty ||
          _currentLandmarks.length != _targetLandmarks.length) {
        _currentLandmarks = _targetLandmarks
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else {
        for (int i = 0; i < _targetLandmarks.length; i++) {
          final target = _targetLandmarks[i];
          final current = _currentLandmarks[i];
          current['x'] +=
              ((target['x'] as num).toDouble() -
                  (current['x'] as num).toDouble()) *
              0.25;
          current['y'] +=
              ((target['y'] as num).toDouble() -
                  (current['y'] as num).toDouble()) *
              0.25;
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
          _connectWebSocket();
          _sendFrame();
        }
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  void _connectWebSocket() {
    if (_currentActiveUrl.isEmpty) return;
    print('DEBUG: Connecting to AI: $_currentActiveUrl. Target: ${widget.targetMuscle}');

    try {
      final uri = Uri.parse(_currentActiveUrl).replace(
        queryParameters: {'target': widget.targetMuscle.toLowerCase()},
      );
      _channel = WebSocketChannel.connect(uri);

      // We set a flag to track if we've successfully received any message
      bool receivedData = false;

      // If we are connecting to LOCAL, set a timeout to fallback if no data comes back
      if (_currentActiveUrl == _localUrl) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !receivedData && _currentActiveUrl == _localUrl) {
            print('DEBUG: Local timeout. Switching to Remote.');
            _fallbackToRemote();
          }
        });
      }

      _channel!.stream.listen(
        (message) {
          if (!receivedData) {
            receivedData = true;
            _isConnected = true;
            print('DEBUG: AI Connected Successfully');
          }

          final decoded = json.decode(message);
          if (decoded['landmarks'] != null) {
            if (mounted) {
              setState(() {
                _targetLandmarks = decoded['landmarks'];
                
                final String rawClassification = (decoded['classification'] ?? '...').toString().toUpperCase();
                final String rawState = (decoded['state'] ?? 'UNKNOWN').toString().toUpperCase();
                
                // If it's a raw KNN classification (doesn't contain angle measurements)
                // and it doesn't match the current exercise name, sanitize it!
                if (!rawClassification.contains('ANGLE') && 
                    !rawClassification.contains('KNEE') && 
                    !rawClassification.contains('SHOULDER')) {
                  final String exNameLower = widget.exerciseName.toLowerCase();
                  final String classLower = rawClassification.toLowerCase();
                  
                  // Check if the predicted class matches the current exercise
                  bool matches = exNameLower.contains(classLower) || 
                                 classLower.contains(exNameLower) ||
                                 (classLower.replaceAll('_', '').contains(exNameLower.replaceAll(' ', '')));
                                 
                  if (!matches) {
                    if (rawState == 'BENT') {
                      _currentFormStatus = 'POSITION: DOWN';
                    } else if (rawState == 'STRAIGHT') {
                      _currentFormStatus = 'POSITION: UP';
                    } else if (rawState == 'MOVING') {
                      _currentFormStatus = 'IN MOTION...';
                    } else {
                      _currentFormStatus = 'TRACKING...';
                    }
                  } else {
                    _currentFormStatus = rawClassification.replaceAll('_', ' ');
                  }
                } else {
                  _currentFormStatus = rawClassification;
                }
                
                if (rawState == 'STRAIGHT' || rawState == 'BENT') {
                  if (rawState == 'STRAIGHT' && _lastState == 'BENT') {
                    _repCount++;
                    print("DEBUG: REP COUNTED: $_repCount");
                  }
                  _lastState = rawState;
                }
                
                _guidanceTip = (decoded['guidance'] ?? 'READY').toString().toUpperCase();
              });
              _sendFrame();
            }
          } else if (decoded['error'] != null) {
            _sendFrame();
          }
        },
        onDone: () {
          print('DEBUG: AI Connection Closed');
          _isConnected = false;
          _fallbackToRemote();
        },
        onError: (error) {
          print('DEBUG: AI Connection Error: $error');
          _isConnected = false;
          _fallbackToRemote();
        },
      );
    } catch (e) {
      print('DEBUG: Connection Exception: $e');
      _fallbackToRemote();
    }
  }

  Future<void> _sendFrame() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized)
      return;

    // Check if we have a channel, even if 'isConnected' isn't true yet
    // This allows the first frame to 'wake up' the backend
    if (_channel == null) {
      if (_currentActiveUrl.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), _sendFrame);
      }
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      Uint8List bytes = await image.readAsBytes();

      // Compress and downscale in memory (180px width is perfect for MediaPipe, reducing payload size by 98%)
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final img.Image resized = img.copyResize(decoded, width: 180);
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 50));
      }

      // Send if channel exists (optimistic connection)
      _channel!.sink.add(bytes);
    } catch (e) {
      debugPrint('Camera Loop Error: $e');
      Future.delayed(const Duration(milliseconds: 100), _sendFrame);
    }
  }

  bool _isSwitching = false;
  void _fallbackToRemote() {
    if (_isSwitching) return;
    if (_currentActiveUrl == _localUrl && _remoteUrl.isNotEmpty) {
      _isSwitching = true;
      print('DEBUG: Falling back to Remote Backend...');

      // Close old channel
      _channel?.sink.close();
      _isConnected = false;

      setState(() {
        _currentActiveUrl = _remoteUrl;
      });

      Future.delayed(const Duration(seconds: 1), () {
        _isSwitching = false;
        _connectWebSocket();
        _sendFrame();
      });
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ticker.dispose();
    _channel?.sink.close(status.goingAway);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.exerciseName.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isCameraInitialized && _controller != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            // Single FittedBox for perfect synchronization
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: Stack(
                                  children: [
                                    CameraPreview(_controller!),
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: PosePainter(
                                          landmarks: _currentLandmarks,
                                          isFrontCamera:
                                              _controller!
                                                  .description
                                                  .lensDirection ==
                                              CameraLensDirection.front,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Reps Counter Badge (Top Right)
                            Positioned(
                              top: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fitness_center_rounded,
                                      color: colorScheme.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'REPS: $_repCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 3. UI Overlays (Badges)
                            Positioned(
                              top: 20,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _currentActiveUrl == _localUrl
                                      ? 'LOCAL: LOW LATENCY'
                                      : 'REMOTE: CLOUD AI',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // 5. AI Guidance Coach Badge
                            Positioned(
                              bottom: 95,
                              left: 20,
                              right: 20,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _guidanceTip.contains('GOOD') || _guidanceTip.contains('GREAT')
                                          ? Colors.cyanAccent.withValues(alpha: 0.5)
                                          : Colors.amberAccent.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.campaign_rounded,
                                        color: _guidanceTip.contains('GOOD') || _guidanceTip.contains('GREAT')
                                            ? Colors.cyanAccent
                                            : Colors.amberAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          _guidanceTip,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 4. Form Correction Status Badge
                            Positioned(
                              bottom: 30,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _currentFormStatus.contains('BENT') ||
                                            _currentFormStatus.contains('STRAIGHT') ||
                                            _currentFormStatus.contains('UP') ||
                                            _currentFormStatus.contains('DOWN') ||
                                            _currentFormStatus.contains('GOOD') ||
                                            _currentFormStatus.contains('PERFECT')
                                        ? Colors.green.withValues(alpha: 0.8)
                                        : _currentFormStatus.contains('MOTION') ||
                                                _currentFormStatus == '...' ||
                                                _currentFormStatus == 'WAITING...'
                                            ? Colors.black54
                                            : Colors.red.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    _currentFormStatus,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                  ),
                  child: const Text(
                    'FINISH WORKOUT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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

    final paintJoint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.9)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final paintLine = Paint()
      ..color = Colors.greenAccent.withOpacity(0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

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
      [11, 12],
      [11, 13],
      [13, 15],
      [12, 14],
      [14, 16],
      [11, 23],
      [12, 24],
      [23, 24],
      [23, 25],
      [25, 27],
      [24, 26],
      [26, 28],
    ];

    for (final conn in connections) {
      final p1 = getPos(conn[0]);
      final p2 = getPos(conn[1]);
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paintLine);
    }

    // Only draw dots for major joints (Shoulders down to Ankles)
    // We skip indices 0-10 (Face) and 17-22 (Fingers/Hands)
    const jointIndices = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28];

    for (int i in jointIndices) {
      final pos = getPos(i);
      if (pos != null) canvas.drawCircle(pos, 4, paintJoint);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
