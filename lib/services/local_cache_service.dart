import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A small "cache-first" store for lists of posts (drops, flicks, …).
///
/// The pattern used across the app is:
///   1. On screen load, read whatever was cached last time and show it
///      immediately — no spinner, no network round-trip, and it works
///      with no connection at all.
///   2. Kick off a fresh fetch in the background. If it succeeds,
///      replace what's on screen and overwrite the cache. If it fails
///      (e.g. offline), just keep showing the cached posts instead of
///      an error screen.
///
/// This means a post's *data* (caption, media URLs, counts, etc.) is
/// never re-downloaded on every app open just to render the same
/// list — only when a fresh fetch actually succeeds does anything get
/// replaced. The underlying media (photos/videos) gets its own disk
/// cache too — see `cached_media.dart` — so previously-viewed media
/// keeps working offline as well.
class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const _prefix = 'rm_cache_';

  /// Persists a list of already-serialized maps (e.g. `Drop.toMap()`)
  /// under [key].
  Future<void> saveList(String key, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(items));
    } catch (_) {
      // Caching is a nice-to-have — never let a write failure surface
      // to the user.
    }
  }

  /// Reads back whatever was last saved under [key], or null if
  /// nothing's cached yet (or it failed to parse).
  Future<List<Map<String, dynamic>>?> loadList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Clears one cached key (used e.g. after deleting a post, so a
  /// stale copy of it can't reappear from cache).
  Future<void> clear(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }

  /// Clears every cached list — called on sign-out so the next
  /// account never sees a previous user's cached posts.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
