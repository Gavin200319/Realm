enum DropVisibility { public, private }
enum DropMediaType { photo, video, document }

class Drop {
  final String id;
  final String creatorId;
  final String creatorUsername;
  final String? caption;
  final String? mediaUrl;
  final DropMediaType? mediaType;
  final DropVisibility visibility;
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
    required this.mediaType,
    required this.visibility,
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
      mediaType: _parseMediaType(map['media_type'] as String?),
      visibility: (map['visibility'] as String?) == 'private'
          ? DropVisibility.private
          : DropVisibility.public,
      unlockRadiusM: (map['unlock_radius_m'] as num).toInt(),
      distanceM: (map['distance_m'] as num).toDouble(),
      dropLat: (map['drop_lat'] as num?)?.toDouble(),
      dropLng: (map['drop_lng'] as num?)?.toDouble(),
      isUnlocked: map['is_unlocked'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static DropMediaType? _parseMediaType(String? raw) {
    switch (raw) {
      case 'photo': return DropMediaType.photo;
      case 'video': return DropMediaType.video;
      case 'document': return DropMediaType.document;
      default: return null;
    }
  }

  String get distanceLabel {
    if (distanceM < 1000) return '${distanceM.round()}m away';
    return '${(distanceM / 1000).toStringAsFixed(1)}km away';
  }

  bool get isWithinUnlockRange => distanceM <= unlockRadiusM;
  bool get isPrivate => visibility == DropVisibility.private;
}
