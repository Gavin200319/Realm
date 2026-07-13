/// A single Drop returned from the `nearby_drops` RPC.
///
/// If [isUnlocked] is false, [caption] and [mediaUrl] will be null —
/// the server never sends locked content to the client at all, so
/// there's nothing to accidentally leak in the UI layer.
class Drop {
  final String id;
  final String creatorId;
  final String creatorUsername;
  final String? caption;
  final String? mediaUrl;
  final int unlockRadiusM;
  final double distanceM;
  final double? dropLat;
  final double? dropLng;
  final bool isUnlocked;
  final DateTime createdAt;

  const Drop({
    required this.id,
    required this.creatorId,
    required this.creatorUsername,
    required this.caption,
    required this.mediaUrl,
    required this.unlockRadiusM,
    required this.distanceM,
    this.dropLat,
    this.dropLng,
    required this.isUnlocked,
    required this.createdAt,
  });

  factory Drop.fromMap(Map<String, dynamic> map) {
    return Drop(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      creatorUsername: map['creator_username'] as String? ?? 'unknown',
      caption: map['caption'] as String?,
      mediaUrl: map['media_url'] as String?,
      unlockRadiusM: (map['unlock_radius_m'] as num).toInt(),
      distanceM: (map['distance_m'] as num).toDouble(),
      dropLat: (map['drop_lat'] as num?)?.toDouble(),
      dropLng: (map['drop_lng'] as num?)?.toDouble(),
      isUnlocked: map['is_unlocked'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get distanceLabel {
    if (distanceM < 1000) {
      return '${distanceM.round()}m away';
    }
    return '${(distanceM / 1000).toStringAsFixed(1)}km away';
  }

  bool get isWithinUnlockRange => distanceM <= unlockRadiusM;
}
