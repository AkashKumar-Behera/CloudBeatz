class JamSession {
  final String code;
  final String hostId;
  final int createdAt;
  final bool isActive;
  final JamCurrentSong? currentSong;
  final Map<String, JamParticipant> participants;
  final JamConfig config;

  JamSession({
    required this.code,
    required this.hostId,
    required this.createdAt,
    required this.isActive,
    this.currentSong,
    required this.participants,
    required this.config,
  });

  factory JamSession.fromMap(String code, Map<dynamic, dynamic> map) {
    final participantsMap = map['participants'] as Map<dynamic, dynamic>? ?? {};
    final parsedParticipants = participantsMap.map(
      (key, value) => MapEntry(
        key.toString(),
        JamParticipant.fromMap(key.toString(), Map<dynamic, dynamic>.from(value)),
      ),
    );

    return JamSession(
      code: code,
      hostId: map['hostId'] as String? ?? '',
      createdAt: map['createdAt'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? false,
      currentSong: map['currentSong'] != null
          ? JamCurrentSong.fromMap(Map<dynamic, dynamic>.from(map['currentSong']))
          : null,
      participants: parsedParticipants,
      config: map['config'] != null
          ? JamConfig.fromMap(Map<dynamic, dynamic>.from(map['config']))
          : JamConfig(allowGuestPlayPause: false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'createdAt': createdAt,
      'isActive': isActive,
      'currentSong': currentSong?.toMap(),
      'participants': participants.map((key, value) => MapEntry(key, value.toMap())),
      'config': config.toMap(),
    };
  }
}

class JamConfig {
  final bool allowGuestPlayPause;

  JamConfig({required this.allowGuestPlayPause});

  factory JamConfig.fromMap(Map<dynamic, dynamic> map) {
    return JamConfig(
      allowGuestPlayPause: map['allowGuestPlayPause'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowGuestPlayPause': allowGuestPlayPause,
    };
  }
}

class JamCurrentSong {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final int durationMs;
  final int positionMs;
  final bool isPlaying;
  final int updatedAt;

  JamCurrentSong({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.durationMs,
    required this.positionMs,
    required this.isPlaying,
    required this.updatedAt,
  });

  factory JamCurrentSong.fromMap(Map<dynamic, dynamic> map) {
    return JamCurrentSong(
      videoId: map['videoId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      thumbnail: map['thumbnail'] as String? ?? '',
      durationMs: map['durationMs'] as int? ?? 0,
      positionMs: map['positionMs'] as int? ?? 0,
      isPlaying: map['isPlaying'] as bool? ?? false,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'artist': artist,
      'thumbnail': thumbnail,
      'durationMs': durationMs,
      'positionMs': positionMs,
      'isPlaying': isPlaying,
      'updatedAt': updatedAt,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JamCurrentSong &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          title == other.title &&
          artist == other.artist &&
          thumbnail == other.thumbnail &&
          durationMs == other.durationMs &&
          positionMs == other.positionMs &&
          isPlaying == other.isPlaying &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      videoId.hashCode ^
      title.hashCode ^
      artist.hashCode ^
      thumbnail.hashCode ^
      durationMs.hashCode ^
      positionMs.hashCode ^
      isPlaying.hashCode ^
      updatedAt.hashCode;
}

class JamParticipant {
  final String deviceId;
  final String name;
  final int joinedAt;
  final bool isActive;
  final int lastHeartbeat;

  JamParticipant({
    required this.deviceId,
    required this.name,
    required this.joinedAt,
    required this.isActive,
    required this.lastHeartbeat,
  });

  factory JamParticipant.fromMap(String deviceId, Map<dynamic, dynamic> map) {
    return JamParticipant(
      deviceId: deviceId,
      name: map['name'] as String? ?? '',
      joinedAt: map['joinedAt'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? false,
      lastHeartbeat: map['lastHeartbeat'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'joinedAt': joinedAt,
      'isActive': isActive,
      'lastHeartbeat': lastHeartbeat,
    };
  }
}
