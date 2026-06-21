// A single media asset (image or video) attached to an exercise.
class ExerciseMedia {
  final String url;
  final bool isVideo;

  const ExerciseMedia({required this.url, required this.isVideo});

  factory ExerciseMedia.fromMap(Map<String, dynamic> map) {
    return ExerciseMedia(
      url: map['url'] as String? ?? '',
      isVideo: map['isVideo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'url': url, 'isVideo': isVideo};
}

class ExerciseItem {
  final String id;
  final String name;
  final String? description; // Optional description added by admin
  final String icon;
  final String unit;
  final int defaultReps;
  final int defaultTimer; // Admin-configured exercise duration (in seconds)
  /// All media assets admin uploaded for this exercise.
  /// Stored in Firestore as  exercises/{id}/mediaItems  (array of maps).
  final List<ExerciseMedia> mediaItems;

  ExerciseItem({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.unit,
    this.defaultReps = 0,
    this.defaultTimer = 0,
    this.mediaItems = const [],
  });

  factory ExerciseItem.fromMap(String id, Map<String, dynamic> data) {
    // Parse mediaItems array if present, else fall back to legacy single mediaUrl
    final rawList = data['mediaItems'];
    List<ExerciseMedia> items = [];
    if (rawList is List) {
      items = rawList
          .whereType<Map>()
          .map((m) => ExerciseMedia.fromMap(Map<String, dynamic>.from(m)))
          .where((m) => m.url.isNotEmpty)
          .toList();
    }

    // Legacy single-media support: if no mediaItems array but mediaUrl exists
    if (items.isEmpty) {
      final url = data['mediaUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        items = [
          ExerciseMedia(
            url: url,
            isVideo: data['isVideo'] as bool? ?? false,
          ),
        ];
      }
    }

    return ExerciseItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] as String?,
      icon: data['icon'] ?? '💪',
      unit: data['unit'] ?? 'reps',
      defaultReps: (data['defaultReps'] as num?)?.toInt() ?? 0,
      defaultTimer: (data['defaultTimer'] as num?)?.toInt() ?? 0,
      mediaItems: items,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (description != null) 'description': description,
        'icon': icon,
        'unit': unit,
        'defaultReps': defaultReps,
        'defaultTimer': defaultTimer,
        'mediaItems': mediaItems.map((m) => m.toMap()).toList(),
      };
}