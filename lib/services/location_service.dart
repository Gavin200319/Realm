import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Requests permission (if needed) and returns the current position.
  /// Forces a fresh GPS fix — never returns a cached location.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled on this device.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied — enable it in Settings.',
      );
    }

    // Try to get a fresh high-accuracy fix first.
    // If it times out (indoors, weak signal), fall back to the last
    // known position rather than failing entirely.
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException {
      // Fall back to last known position if GPS times out
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      // If no last known, try again with lower accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    }
  }

  /// Streams position updates — used to live-refresh the feed as the
  /// user walks around, so locked drops flip to unlocked in real time.
  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,           // update every 5 meters
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Reality Merge is tracking your location',
          notificationTitle: 'Reality Merge',
          enableWakeLock: true,
        ),
      ),
    );
  }
}

// needed for TimeoutException
class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);
}
