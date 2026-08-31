import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized image bank.
///
/// Images are managed by the admin via the "Image Bank" screen in the Admin
/// Panel. The admin can enable/disable images and upload new ones.  The app
/// pulls the active pool from Firestore at runtime and falls back to the
/// bundled defaults if Firestore is unreachable.
///
/// HOW TO ADD DEFAULT IMAGES (developer):
///   1. Drop the file into `assets/images/`
///   2. Register it in `pubspec.yaml` under `flutter: assets:`
///   3. Add the path to the relevant list in `admin_celebration_assets_screen.dart`
///      under `kDefaultXxxImages`.
///
class ImageBank {
  ImageBank._();

  static final _rng = math.Random();

  // ── FIRESTORE ─────────────────────────────────────────────────────────────

  static const String _collection = 'app_config';
  static const String _document = 'image_bank';

  static DocumentReference get _docRef =>
      FirebaseFirestore.instance.collection(_collection).doc(_document);

  // ── HARD-CODED FALLBACKS (mirrors admin_celebration_assets_screen.dart) ──

  static const List<String> _fallbackCelebrationImages = [
    'assets/images/p1.png',
    'assets/images/p2.png',
    'assets/images/p3.png',
    'assets/images/p4.png',
    'assets/images/p5.png',
    'assets/images/p6.png',
    'assets/images/p7.png',
  ];

  static const List<String> _fallbackExerciseCongrats = [
    'assets/images/login.png',
    'assets/images/register.png',
    'assets/images/streak.png',
    'assets/images/p1.png',
    'assets/images/p2.png',
    'assets/images/p3.png',
    'assets/images/p4.png',
    'assets/images/p5.png',
    'assets/images/p6.png',
    'assets/images/p7.png',
    'assets/images/congrads_po1.png',
    'assets/images/congrads_po2.png',
    'assets/images/congrads_po3.png',
  ];

  static const List<String> _fallbackDailySummary = [
    'assets/images/login.png',
    'assets/images/register.png',
    'assets/images/streak.png',
    'assets/images/p1.png',
    'assets/images/p2.png',
    'assets/images/p3.png',
    'assets/images/p4.png',
    'assets/images/p5.png',
    'assets/images/p6.png',
    'assets/images/p7.png',
    'assets/images/fire-congrads.png',
    'assets/images/congrads_po1.png',
    'assets/images/congrads_po2.png',
    'assets/images/congrads_po3.png',
  ];

  static const List<String> _fallbackStreakCharacter = [
    'assets/images/login.png',
    'assets/images/register.png',
    'assets/images/streak.png',
    'assets/images/p1.png',
    'assets/images/p2.png',
    'assets/images/p3.png',
    'assets/images/p4.png',
    'assets/images/p5.png',
    'assets/images/p6.png',
    'assets/images/p7.png',
    'assets/images/congrads_po1.png',
    'assets/images/congrads_po2.png',
    'assets/images/congrads_po3.png',
  ];

  // ── CACHED POOLS (refreshed each time Firestore is read) ─────────────────

  static List<String>? _celebrationImages;
  static List<String>? _exerciseCongrats;
  static List<String>? _dailySummary;
  static List<String>? _streakCharacter;

  static final _updatesController = StreamController<void>.broadcast();
  static Stream<void> get onUpdates => _updatesController.stream;

  /// Call once (e.g. from main or app startup) to warm the caches and listen for live updates.
  /// Screens that call `random*()` will always get the most up-to-date active pool.
  static Future<void> initialize() async {
    try {
      // 1. Await initial fetch so startup is fully warmed
      final snap = await _docRef.get();
      _updateCaches(snap);

      // 2. Listen for live changes from the admin panel
      _docRef.snapshots().listen(_updateCaches);
    } catch (_) {
      // Firestore unavailable — keep/use fallbacks.
    }
  }

  static void _updateCaches(DocumentSnapshot snap) {
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>? ?? {};
    _celebrationImages = _parse(data, 'celebration_images', _fallbackCelebrationImages);
    _exerciseCongrats = _parse(data, 'exercise_congrats', _fallbackExerciseCongrats);
    _dailySummary     = _parse(data, 'daily_summary',     _fallbackDailySummary);
    _streakCharacter  = _parse(data, 'streak_character',  _fallbackStreakCharacter);
    
    _updatesController.add(null);
  }

  static List<String> _parse(
    Map<String, dynamic> data,
    String field,
    List<String> fallback,
  ) {
    final raw = data[field] as List<dynamic>?;
    if (raw == null || raw.isEmpty) return fallback;
    final enabled = raw
        .whereType<Map<String, dynamic>>()
        .where((e) => e['enabled'] == true)
        .map((e) => e['url'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return enabled.isEmpty ? fallback : enabled;
  }

  // ── PUBLIC API ────────────────────────────────────────────────────────────

  /// Random image for the **Exercise Congratulation** screen.
  static String randomExerciseCongrats() {
    final pool = _exerciseCongrats ?? _fallbackExerciseCongrats;
    return pool[_rng.nextInt(pool.length)];
  }

  /// Random image for the **Daily Summary / Personal Greetings** screen.
  static String randomDailySummary() {
    final pool = _dailySummary ?? _fallbackDailySummary;
    return pool[_rng.nextInt(pool.length)];
  }

  /// Random image for the **Streak Card** character (personal + friend streak).
  static String randomStreakCharacter() {
    final pool = _streakCharacter ?? _fallbackStreakCharacter;
    return pool[_rng.nextInt(pool.length)];
  }
}
