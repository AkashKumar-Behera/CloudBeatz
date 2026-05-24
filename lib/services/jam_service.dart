import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/jam_session.dart';
import '../ui/player/player_controller.dart';
import '../ui/widgets/jam_bottom_sheet.dart';
import '../services/music_service.dart';
import '../utils/helper.dart';

class JamService extends GetxService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  final isInJam = false.obs;
  final isHost = false.obs;
  final activeSession = Rxn<JamSession>();
  final participants = <JamParticipant>[].obs;
  final incomingReaction = Rxn<Map<String, dynamic>>();
  final pendingJoinCode = RxnString();
  final myDisplayName = ''.obs;

  late final String myDeviceId;

  StreamSubscription? _sessionSubscription;
  StreamSubscription? _reactionsSubscription;

  @override
  void onInit() {
    super.onInit();
    myDeviceId = getOrCreateDeviceId();
    myDisplayName.value = getJamDisplayName();
  }

  void updateDisplayName(String name) {
    setJamDisplayName(name);
    myDisplayName.value = name;
  }


  String getOrCreateDeviceId() {
    final box = Hive.box("AppPrefs");
    String? deviceId = box.get('jamDeviceId');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      box.put('jamDeviceId', deviceId);
    }
    return deviceId;
  }

  Future<bool> createJam() async {
    try {
      final name = getJamDisplayName();
      if (name.isEmpty) return false;

      // Generate a random 4-digit code
      final code = (Random().nextInt(9000) + 1000).toString();
      final sessionRef = _db.ref('jams/$code');

      final hostParticipant = JamParticipant(
        deviceId: myDeviceId,
        name: name,
        joinedAt: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
      );

      final playerController = Get.find<PlayerController>();
      JamCurrentSong? currentSong;
      if (playerController.currentSong.value != null) {
        final mediaItem = playerController.currentSong.value!;
        currentSong = JamCurrentSong(
          videoId: mediaItem.id,
          title: mediaItem.title,
          artist: mediaItem.artist ?? '',
          thumbnail: mediaItem.artUri?.toString() ?? '',
          durationMs: mediaItem.duration?.inMilliseconds ?? 0,
          positionMs: playerController.progressBarStatus.value.current.inMilliseconds,
          isPlaying: playerController.buttonState.value == PlayButtonState.playing,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }

      final session = JamSession(
        code: code,
        hostId: myDeviceId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
        currentSong: currentSong,
        participants: {myDeviceId: hostParticipant},
      );

      await sessionRef.set(session.toMap());

      isInJam.value = true;
      isHost.value = true;
      activeSession.value = session;

      _startListening(code);
      return true;
    } catch (e) {
      printERROR("Failed to create jam: $e");
      return false;
    }
  }

  Future<bool> joinJam(String code) async {
    try {
      final name = getJamDisplayName();
      if (name.isEmpty) return false;

      final sessionRef = _db.ref('jams/$code');
      final snapshot = await sessionRef.get();

      if (!snapshot.exists) {
        Get.snackbar(
          "Jam not found", 
          "No active Jam session found with code $code",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return false;
      }

      final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final session = JamSession.fromMap(code, map);

      if (!session.isActive) {
        Get.snackbar(
          "Session Ended", 
          "This Jam session is no longer active",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return false;
      }

      final myParticipant = JamParticipant(
        deviceId: myDeviceId,
        name: name,
        joinedAt: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
      );

      await sessionRef.child('participants/$myDeviceId').set(myParticipant.toMap());

      isInJam.value = true;
      isHost.value = false;
      activeSession.value = session;

      _startListening(code);

      if (session.currentSong != null) {
        _syncWithHost(session.currentSong!);
      }

      return true;
    } catch (e) {
      printERROR("Failed to join jam: $e");
      return false;
    }
  }

  void _startListening(String code) {
    _sessionSubscription?.cancel();
    _reactionsSubscription?.cancel();

    _sessionSubscription = _db.ref('jams/$code').onValue.listen((event) {
      if (event.snapshot.value == null) {
        _handleSessionEnd();
        return;
      }

      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final session = JamSession.fromMap(code, map);

      if (!session.isActive) {
        _handleSessionEnd();
        return;
      }

      activeSession.value = session;
      participants.assignAll(session.participants.values.toList());

      if (!isHost.value && session.currentSong != null) {
        _syncWithHost(session.currentSong!);
      }
    });

    final joinTime = DateTime.now().millisecondsSinceEpoch;
    _reactionsSubscription = _db.ref('jams/$code/reactions')
        .orderByChild('timestamp')
        .startAt(joinTime)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value != null) {
        final reactionData = Map<String, dynamic>.from(event.snapshot.value as Map);
        incomingReaction.value = reactionData;
      }
    });
  }

  void _handleSessionEnd() {
    if (isInJam.value) {
      leaveJam(localOnly: true);
      Get.snackbar(
        "Jam Session Ended",
        "The Jam session has been ended by the host.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  bool _isSyncing = false;

  Future<void> _syncWithHost(JamCurrentSong hostSong) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final playerController = Get.find<PlayerController>();
      final currentLocalSong = playerController.currentSong.value;

      final isSameSong = currentLocalSong != null && currentLocalSong.id == hostSong.videoId;

      if (!isSameSong) {
        printINFO("Syncing song change to: ${hostSong.title}");
        final result = await Get.find<MusicServices>().getSongWithId(hostSong.videoId);
        if (result[0]) {
          final mediaItems = List<MediaItem>.from(result[1]);
          if (mediaItems.isNotEmpty) {
            await playerController.playPlayListSong(mediaItems, 0);
          }
        } else {
          printERROR("Failed to fetch song: ${hostSong.videoId}");
        }
      }

      final elapsed = DateTime.now().millisecondsSinceEpoch - hostSong.updatedAt;
      final targetPositionMs = hostSong.isPlaying ? hostSong.positionMs + elapsed : hostSong.positionMs;

      final currentPosMs = playerController.progressBarStatus.value.current.inMilliseconds;
      final currentIsPlaying = playerController.buttonState.value == PlayButtonState.playing;

      if (currentIsPlaying != hostSong.isPlaying) {
        if (hostSong.isPlaying) {
          playerController.play();
        } else {
          playerController.pause();
        }
      }

      if ((targetPositionMs - currentPosMs).abs() > 3000) {
        printINFO("Drift detected: ${(targetPositionMs - currentPosMs).abs()}ms. Seeking to $targetPositionMs...");
        playerController.seek(Duration(milliseconds: targetPositionMs));
      }
    } catch (e) {
      printERROR("Error during sync with host: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> pushSongUpdate({
    required String videoId,
    required String title,
    required String artist,
    required String thumbnail,
    required int durationMs,
    required int positionMs,
    required bool isPlaying,
  }) async {
    if (!isInJam.value || !isHost.value || activeSession.value == null) return;

    final code = activeSession.value!.code;
    final currentSong = JamCurrentSong(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnail: thumbnail,
      durationMs: durationMs,
      positionMs: positionMs,
      isPlaying: isPlaying,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await _db.ref('jams/$code/currentSong').set(currentSong.toMap());
    } catch (e) {
      printERROR("Failed to push song update: $e");
    }
  }

  Future<void> pushSongUpdateFromLocalPlayer() async {
    if (!isInJam.value || !isHost.value || activeSession.value == null) return;

    final playerController = Get.find<PlayerController>();
    final mediaItem = playerController.currentSong.value;
    if (mediaItem == null) return;

    await pushSongUpdate(
      videoId: mediaItem.id,
      title: mediaItem.title,
      artist: mediaItem.artist ?? '',
      thumbnail: mediaItem.artUri?.toString() ?? '',
      durationMs: mediaItem.duration?.inMilliseconds ?? 0,
      positionMs: playerController.progressBarStatus.value.current.inMilliseconds,
      isPlaying: playerController.buttonState.value == PlayButtonState.playing,
    );
  }

  Future<void> leaveJam({bool localOnly = false}) async {
    if (!isInJam.value) return;

    final code = activeSession.value?.code;

    _sessionSubscription?.cancel();
    _reactionsSubscription?.cancel();

    if (!localOnly && code != null) {
      try {
        if (isHost.value) {
          await _db.ref('jams/$code/isActive').set(false);
        } else {
          await _db.ref('jams/$code/participants/$myDeviceId').remove();
        }
      } catch (e) {
        printERROR("Error leaving jam node: $e");
      }
    }

    isInJam.value = false;
    isHost.value = false;
    activeSession.value = null;
    participants.clear();
  }

  Future<void> sendReaction(String emoji) async {
    if (!isInJam.value || activeSession.value == null) return;

    final code = activeSession.value!.code;
    final name = getJamDisplayName();

    final reactionRef = _db.ref('jams/$code/reactions').push();
    await reactionRef.set({
      'emoji': emoji,
      'from': name,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> joinJamFromDeepLink(String code) async {
    final name = getJamDisplayName();
    if (name.isEmpty) {
      pendingJoinCode.value = code;
      showJamBottomSheet();
    } else {
      final success = await joinJam(code);
      if (success) {
        showJamBottomSheet();
      }
    }
  }

  String getShareLink() {
    final code = activeSession.value?.code ?? '';
    return 'cloudbeatz://jam/$code';
  }

  void showJamBottomSheet() {
    Get.bottomSheet(
      const JamBottomSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
