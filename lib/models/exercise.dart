import 'dart:convert';

class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String target;
  final String equipment;
  final String gifUrl;
  final List<String> instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.target,
    required this.equipment,
    required this.gifUrl,
    required this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // Merge 'details', 'data', 'info', 'exercise', 'attributes', 'item', 'result' if they exist
    final Map<String, dynamic> data = {...json};
    for (final key in [
      'details',
      'data',
      'info',
      'exercise',
      'attributes',
      'item',
      'result',
      'body',
    ]) {
      if (json[key] is Map<String, dynamic>) {
        data.addAll(json[key]);
      }
    }

    String rawGifUrl =
        (data['gifUrl'] ??
                data['gifurl'] ??
                data['gif_url'] ??
                data['gif'] ??
                data['animation'] ??
                data['videoUrl'] ??
                data['image'] ??
                data['imageUrl'] ??
                '')
            .toString();

    // Check if the URL is valid
    bool isValidUrl(String url) =>
        url.isNotEmpty &&
        (url.startsWith('http') ||
            url.contains('.com') ||
            url.contains('.net'));

    // Search for any key that might hold the URL if standard ones are missing
    if (!isValidUrl(rawGifUrl)) {
      data.forEach((key, value) {
        final k = key.toLowerCase();
        if ((k.contains('gif') ||
                k.contains('anim') ||
                k.contains('img') ||
                k.contains('url')) &&
            value is String &&
            isValidUrl(value)) {
          rawGifUrl = value;
        }
      });
    }

    // Advanced ID-based fallback logic
    if (!isValidUrl(rawGifUrl)) {
      final String? gid =
          (data['gifid'] ??
                  data['gifId'] ??
                  data['gifID'] ??
                  data['gif_id'] ??
                  data['exercise_id'] ??
                  data['id'] ??
                  data['eid'])
              ?.toString();

      if (gid != null && gid.isNotEmpty) {
        // Use a 4-digit padded ID for standard mirrors
        final String cleanId = gid.padLeft(4, '0');

        // Try the GitHub-based mirror as primary fallback due to CloudFront lookup issues
        rawGifUrl =
            "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$cleanId/0.gif";
      }
    }

    // Sanitize Cloudinary MP4 urls to be image compatible
    if (rawGifUrl.contains('f_mp4')) {
      rawGifUrl = rawGifUrl.replaceAll('f_mp4', 'f_auto');
    }

    // Robust instruction mapping
    List<String> instructions = [];
    final dynamic rawInstructions =
        data['instructions'] ??
        data['instructionslist'] ??
        data['instructions_list'] ??
        data['instruction_list'] ??
        data['instruction'] ??
        data['steps'] ??
        data['step'] ??
        data['guide'] ??
        data['desc'] ??
        data['benefits'] ??
        data['benefit'] ??
        data['technique'] ??
        data['howTo'] ??
        data['description'] ??
        data['instructionsList'];

    if (rawInstructions is List) {
      instructions = rawInstructions.map((e) => e.toString()).toList();
    } else if (rawInstructions is String && rawInstructions.isNotEmpty) {
      // Handle cases where it might be a double-encoded JSON string
      if (rawInstructions.trim().startsWith('[') &&
          rawInstructions.trim().endsWith(']')) {
        try {
          final decoded = jsonDecode(rawInstructions);
          if (decoded is List) {
            instructions = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      if (instructions.isEmpty) {
        // Some APIs use |, ;, or natural steps as separators
        String text = rawInstructions;
        if (RegExp(r'^\d+[\.\)]').hasMatch(text)) {
          instructions = text
              .split(RegExp(r'\s*\d+[\.\)]\s+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          final List<String> parts = text.contains('|')
              ? text.split('|')
              : (text.contains(';') ? text.split(';') : text.split('\n'));

          instructions = parts
              .where((s) => s.trim().length > 2)
              .map((s) => s.trim())
              .toList();
        }
      }
    }

    return Exercise(
      id: (data['id'] ?? data['exercise_id'] ?? data['exerciseId'] ?? '')
          .toString(),
      name:
          (data['name'] ?? data['exercise_name'] ?? data['exerciseName'] ?? '')
              .toString(),
      bodyPart:
          (data['bodyPart'] ??
                  data['bodypart'] ??
                  data['body_part'] ??
                  data['region'] ??
                  '')
              .toString(),
      target:
          (data['target'] ??
                  data['target_muscle'] ??
                  data['targetMuscle'] ??
                  '')
              .toString(),
      equipment: (data['equipment'] ?? data['equipment_type'] ?? '').toString(),
      gifUrl: rawGifUrl,
      instructions: instructions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bodyPart': bodyPart,
      'target': target,
      'equipment': equipment,
      'gifUrl': gifUrl,
      'instructions': instructions,
    };
  }
}
