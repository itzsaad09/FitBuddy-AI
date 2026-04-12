import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fitbuddy_ai/services/database_service.dart';
import 'package:shimmer/shimmer.dart';

class CachedGif extends StatefulWidget {
  final String exerciseId;
  final String gifUrl;
  final BoxFit fit;

  const CachedGif({
    super.key,
    required this.exerciseId,
    required this.gifUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<CachedGif> createState() => _CachedGifState();
}

class _CachedGifState extends State<CachedGif> {
  final DatabaseService _db = DatabaseService();
  Uint8List? _gifData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGif();
  }

  Future<void> _loadGif() async {
    // On Web, don't use the binary cache logic, let the browser handle it.
    if (kIsWeb) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // 1. Try to load from local cache
      final localData = await _db.getGif(widget.exerciseId);

      if (localData != null && localData.isNotEmpty) {
        if (mounted) {
          setState(() {
            _gifData = localData;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. If not in DB, download from URL
      final response = await http.get(Uri.parse(widget.gifUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        // Save to DB for next time (mobile only)
        await _db.saveGif(widget.exerciseId, bytes);

        if (mounted) {
          setState(() {
            _gifData = bytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error caching GIF: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        highlightColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        child: Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // 1. Use memory image if cached
    if (_gifData != null) {
      return Image.memory(_gifData!, fit: widget.fit, gaplessPlayback: true);
    }

    // 2. Fallback to network image (always used on Web, or if cache failed on mobile)
    return Image.network(
      widget.gifUrl,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Shimmer.fromColors(
          baseColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          highlightColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          child: Container(
            color: Colors.white,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }
}
