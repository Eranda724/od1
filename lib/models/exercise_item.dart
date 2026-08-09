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
  final String? description; // Optional legacy single description
  final Map<String, String>? descriptions; // Localized descriptions
  final String icon; // Legacy emoji icon
  final String? labelImage; // New custom label image
  final String unit;
  final int defaultReps;
  final int defaultTimer; // Admin-configured exercise duration (in seconds)
  final int defaultDays; // Admin-configured number of days

  /// All media assets admin uploaded for this exercise.
  /// Stored in Firestore as  exercises/{id}/mediaItems  (array of maps).
  final List<ExerciseMedia> mediaItems;

  ExerciseItem({
    required this.id,
    required this.name,
    this.description,
    this.descriptions,
    required this.icon,
    this.labelImage,
    required this.unit,
    this.defaultReps = 0,
    this.defaultTimer = 0,
    this.defaultDays = 0,
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

    Map<String, String>? parsedDescriptions;
    if (data['descriptions'] != null) {
      parsedDescriptions = Map<String, String>.from(data['descriptions']);
    }

    return ExerciseItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] as String?,
      descriptions: parsedDescriptions,
      icon: data['icon'] ?? '💪',
      labelImage: data['labelImage'] as String?,
      unit: data['unit'] ?? 'reps',
      defaultReps: (data['defaultReps'] as num?)?.toInt() ?? 0,
      defaultTimer: (data['defaultTimer'] as num?)?.toInt() ?? 0,
      defaultDays: (data['defaultDays'] as num?)?.toInt() ?? 0,
      mediaItems: items,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (description != null) 'description': description,
        if (descriptions != null) 'descriptions': descriptions,
        'icon': icon,
        if (labelImage != null) 'labelImage': labelImage,
        'unit': unit,
        'defaultReps': defaultReps,
        'defaultTimer': defaultTimer,
        'defaultDays': defaultDays,
        'mediaItems': mediaItems.map((m) => m.toMap()).toList(),
      };
}