import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dio/dio.dart';

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
  final jamQueue = <MediaItem>[].obs;

  late final String myDeviceId;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _sfuDataChannel;
  String? _sfuSessionId;
  Timer? _sfuTickerTimer;
  final isSfuActive = false.obs;

  StreamSubscription? _sessionSubscription;
  StreamSubscription? _reactionsSubscription;
  StreamSubscription? _offsetSubscription;
  StreamSubscription? _queueSubscription;
  Timer? _heartbeatTimer;

  int _serverTimeOffset = 0;

  @override
  void onInit() {
    super.onInit();
    myDeviceId = getOrCreateDeviceId();
    myDisplayName.value = getJamDisplayName();
    _initTimeOffsetListener();
    
    // Auto reconnect on app startup after 1 second delay to ensure services are fully up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        _checkAndReconnect();
      });
    });
  }

  void _initTimeOffsetListener() {
    _offsetSubscription?.cancel();
    _offsetSubscription = _db.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _serverTimeOffset = (event.snapshot.value as num).toInt();
        printINFO("Firebase Server Offset updated: $_serverTimeOffset ms");
      }
    });
  }

  void _checkAndReconnect() async {
    final box = Hive.box("AppPrefs");
    final cachedCode = box.get('activeJamCode') as String?;
    final cachedRole = box.get('jamRole') as String?;

    if (cachedCode != null && cachedCode.isNotEmpty) {
      printINFO("App Prefs me active Jam session code mila: $cachedCode. Auto-reconnecting...");
      final sessionRef = _db.ref('jams/$cachedCode');
      final snapshot = await sessionRef.get();

      if (snapshot.exists) {
        final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final session = JamSession.fromMap(cachedCode, map);

        if (session.isActive) {
          if (cachedRole == 'host' && session.hostId == myDeviceId) {
            printINFO("Host role session re-activate ho rha hai.");
            isInJam.value = true;
            isHost.value = true;
            activeSession.value = session;
            _startListening(cachedCode);
            _startHeartbeat(cachedCode);
            pushSongUpdateFromLocalPlayer();
            pushQueueUpdate();
          } else {
            printINFO("Guest role auto-reconnecting to session: $cachedCode");
            final name = getJamDisplayName();
            final myParticipant = JamParticipant(
              deviceId: myDeviceId,
              name: name.isEmpty ? "Guest" : name,
              joinedAt: DateTime.now().millisecondsSinceEpoch,
              isActive: true,
              lastHeartbeat: DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
            );
            await sessionRef.child('participants/$myDeviceId').set(myParticipant.toMap());
            
            isInJam.value = true;
            isHost.value = false;
            activeSession.value = session;
            _startListening(cachedCode);
            _startHeartbeat(cachedCode);
          }
        } else {
          _clearCache();
        }
      } else {
        _clearCache();
      }
    }
  }

  void _saveCache(String code, String role) {
    final box = Hive.box("AppPrefs");
    box.put('activeJamCode', code);
    box.put('jamRole', role);
  }

  void _clearCache() {
    final box = Hive.box("AppPrefs");
    box.delete('activeJamCode');
    box.delete('jamRole');
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

      final code = (Random().nextInt(9000) + 1000).toString();
      final sessionRef = _db.ref('jams/$code');

      final hostParticipant = JamParticipant(
        deviceId: myDeviceId,
        name: name,
        joinedAt: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
        lastHeartbeat: DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
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
          updatedAt: DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
        );
      }

      final session = JamSession(
        code: code,
        hostId: myDeviceId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
        currentSong: currentSong,
        participants: {myDeviceId: hostParticipant},
        config: JamConfig(allowGuestPlayPause: false),
      );

      await sessionRef.set(session.toMap());
      await sessionRef.onDisconnect().remove();

      isInJam.value = true;
      isHost.value = true;
      activeSession.value = session;

      _saveCache(code, 'host');
      _startListening(code);
      _startHeartbeat(code);
      pushQueueUpdate();
      _initHostSFUSession(code);

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
        lastHeartbeat: DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
      );

      // Guests are saved explicitly, NO automatic background disconnect node deletion is set up
      await sessionRef.child('participants/$myDeviceId').set(myParticipant.toMap());

      isInJam.value = true;
      isHost.value = false;
      activeSession.value = session;

      _saveCache(code, 'guest');
      _startListening(code);
      _startHeartbeat(code);

      if (session.currentSong != null) {
        _syncWithHost(session.currentSong!);
      }

      return true;
    } catch (e) {
      printERROR("Failed to join jam: $e");
      return false;
    }
  }

  void _startHeartbeat(String code) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!isInJam.value) {
        timer.cancel();
        return;
      }
      try {
        final currentServerTime = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
        if (isHost.value) {
          // Clean inactive participants who missed heartbeat for more than 5 minutes
          final sessionRef = _db.ref('jams/$code');
          final snapshot = await sessionRef.child('participants').get();
          if (snapshot.exists) {
            final participantsMap = Map<dynamic, dynamic>.from(snapshot.value as Map);
            participantsMap.forEach((key, value) {
              final participantId = key.toString();
              if (participantId != myDeviceId) {
                final participantMap = Map<dynamic, dynamic>.from(value as Map);
                final lastHb = participantMap['lastHeartbeat'] as int? ?? 0;
                if (currentServerTime - lastHb > 300000) { // 5 minutes timeout
                  printINFO("Inactive guest auto-removed from session: $participantId");
                  sessionRef.child('participants/$participantId').remove();
                }
              }
            });
          }
        }
        
        // Guest/Host updates their heartbeat
        await _db.ref('jams/$code/participants/$myDeviceId/lastHeartbeat').set(currentServerTime);
      } catch (e) {
        printERROR("Heartbeat error: $e");
      }
    });
  }

  void _startListening(String code) {
    _sessionSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _queueSubscription?.cancel();

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

      if (!isHost.value) {
        final hostSfuId = map['sfuSessionId'] as String?;
        if (hostSfuId != null && hostSfuId.isNotEmpty && _sfuSessionId != hostSfuId) {
          _sfuSessionId = hostSfuId;
          _initGuestSFUSession(code, hostSfuId);
        }
      }

      if (!isHost.value && session.currentSong != null) {
        if (!isSfuActive.value) {
          _syncWithHost(session.currentSong!);
        }
      }
    });

    // Queue sync subscription
    _queueSubscription = _db.ref('jams/$code/queue').onValue.listen((event) {
      if (event.snapshot.value != null && !isHost.value) {
        final rawQueue = List<dynamic>.from(event.snapshot.value as List);
        final items = rawQueue.map((item) {
          final map = Map<dynamic, dynamic>.from(item as Map);
          return MediaItem(
            id: map['id'] as String? ?? '',
            title: map['title'] as String? ?? '',
            artist: map['artist'] as String? ?? '',
            artUri: Uri.tryParse(map['thumbnail'] as String? ?? ''),
            duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
          );
        }).toList();
        jamQueue.assignAll(items);
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

      // Precise calculation leveraging our Server Clock Timing Offset
      final currentServerTime = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
      final elapsed = currentServerTime - hostSong.updatedAt;
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

      // We lower sync drift correction tolerance from 3000ms down to 800ms for high-precision
      if ((targetPositionMs - currentPosMs).abs() > 800) {
        printINFO("Precise drift detected: ${(targetPositionMs - currentPosMs).abs()}ms. Auto adjusting to $targetPositionMs...");
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
      updatedAt: DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
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

  Future<void> pushQueueUpdate() async {
    if (!isInJam.value || !isHost.value || activeSession.value == null) return;

    final code = activeSession.value!.code;
    final playerController = Get.find<PlayerController>();
    final rawQueue = playerController.currentQueue.take(10).map((mediaItem) => {
      'id': mediaItem.id,
      'title': mediaItem.title,
      'artist': mediaItem.artist ?? '',
      'thumbnail': mediaItem.artUri?.toString() ?? '',
      'durationMs': mediaItem.duration?.inMilliseconds ?? 0,
    }).toList();

    try {
      await _db.ref('jams/$code/queue').set(rawQueue);
    } catch (e) {
      printERROR("Failed to push queue update: $e");
    }
  }

  Future<void> updateConfig(JamConfig config) async {
    if (!isInJam.value || !isHost.value || activeSession.value == null) return;
    final code = activeSession.value!.code;
    try {
      await _db.ref('jams/$code/config').set(config.toMap());
    } catch (e) {
      printERROR("Failed to update config: $e");
    }
  }

  Future<void> leaveJam({bool localOnly = false}) async {
    if (!isInJam.value) return;

    final code = activeSession.value?.code;

    _heartbeatTimer?.cancel();
    _sessionSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _queueSubscription?.cancel();

    if (!localOnly && code != null) {
      try {
        if (isHost.value) {
          await _db.ref('jams/$code').onDisconnect().cancel();
          await _db.ref('jams/$code').remove();
        } else {
          await _db.ref('jams/$code/participants/$myDeviceId').onDisconnect().cancel();
          await _db.ref('jams/$code/participants/$myDeviceId').remove();
        }
      } catch (e) {
        printERROR("Error leaving jam node: $e");
      }
    }

    _stopSfu();
    _clearCache();
    isInJam.value = false;
    isHost.value = false;
    activeSession.value = null;
    participants.clear();
    jamQueue.clear();
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

    if (isSfuActive.value) {
      _broadcastSfuMessage({
        'type': 'reaction',
        'emoji': emoji,
        'from': name,
      });
    }
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
    if (GetPlatform.isDesktop) {
      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: SizedBox(
            width: 520,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: const JamBottomSheet(),
            ),
          ),
        ),
        barrierDismissible: true,
      ).whenComplete(() => Get.delete<JamBottomSheetController>(force: true));
    } else {
      Get.bottomSheet(
        const JamBottomSheet(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      ).whenComplete(() => Get.delete<JamBottomSheetController>(force: true));
    }
  }

  Future<Map<String, dynamic>> _fetchIceServers() async {
    try {
      final dio = Dio();
      final turnTokenId = "0eb61e5adcc1fd8d059b61007a1af9a4";
      final turnApiToken = "7904620e1c4f1eae5b1d14b3d6167d24cc6f8c0bf9c2b0006fd35dee8d5c49d7";
      final url = "https://rtc.live.cloudflare.com/v1/turn/keys/$turnTokenId/credentials/generate-ice-servers";
      
      final response = await dio.post(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer $turnApiToken",
            "Content-Type": "application/json",
          },
        ),
        data: {"ttl": 86400},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        printINFO("Successfully fetched Cloudflare ICE servers.");
        return data;
      } else {
        printERROR("Failed to fetch ICE servers: ${response.statusCode}");
      }
    } catch (e) {
      printERROR("Error fetching ICE servers: $e");
    }
    
    return {
      "iceServers": [
        {
          "urls": ["stun:stun.cloudflare.com:3478"]
        }
      ]
    };
  }

  Future<void> _initHostSFUSession(String roomCode) async {
    try {
      printINFO("Initializing Host WebRTC SFU Session...");
      final iceServersConfig = await _fetchIceServers();
      final rtcConfig = {
        'iceServers': iceServersConfig['iceServers'] ?? [{'urls': 'stun:stun.cloudflare.com:3478'}],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(rtcConfig);
      
      final dcInit = RTCDataChannelInit()..negotiated = false;
      _sfuDataChannel = await _peerConnection!.createDataChannel("jam-sync", dcInit);
      
      _sfuDataChannel!.onDataChannelState = (state) {
        printINFO("Host SFU DataChannel state changed: $state");
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          isSfuActive.value = true;
          _startSfuTicker();
        } else {
          isSfuActive.value = false;
          _sfuTickerTimer?.cancel();
        }
      };

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final dio = Dio();
      final appId = "ed0d7f61159c81af6bcf4d50cfce4d46";
      final apiToken = "7770fef0c07905db1b77b782920abbb8559595dd3fc411fc452e70d26406b69b";
      final url = "https://rtc.live.cloudflare.com/v1/apps/$appId/sessions/new";

      final sessionResponse = await dio.post(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer $apiToken",
            "Content-Type": "application/json",
          },
        ),
        data: {
          "sessionDescription": {
            "type": "offer",
            "sdp": offer.sdp,
          }
        },
      );

      if (sessionResponse.statusCode == 200 || sessionResponse.statusCode == 201) {
        final resData = sessionResponse.data;
        final hostSessionId = resData['sessionId'] as String;
        final answerSdp = resData['sessionDescription']['sdp'] as String;

        await _peerConnection!.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));
        _sfuSessionId = hostSessionId;

        final dcUrl = "https://rtc.live.cloudflare.com/v1/apps/$appId/sessions/$hostSessionId/datachannels/new";
        await dio.post(
          dcUrl,
          options: Options(
            headers: {
              "Authorization": "Bearer $apiToken",
              "Content-Type": "application/json",
            },
          ),
          data: {
            "dataChannels": [
              {
                "location": "local",
                "dataChannelName": "jam-sync",
              }
            ]
          },
        );

        await _db.ref('jams/$roomCode/sfuSessionId').set(hostSessionId);
        printINFO("Host SFU Session fully established with ID: $hostSessionId");
      } else {
        printERROR("Failed to create Host SFU Session: ${sessionResponse.statusCode}");
      }
    } catch (e) {
      printERROR("Error setting up Host SFU: $e");
      isSfuActive.value = false;
    }
  }

  Future<void> _initGuestSFUSession(String roomCode, String hostSfuSessionId) async {
    try {
      if (isSfuActive.value) return;
      printINFO("Initializing Guest WebRTC SFU Session pulling from Host ID: $hostSfuSessionId...");

      final iceServersConfig = await _fetchIceServers();
      final rtcConfig = {
        'iceServers': iceServersConfig['iceServers'] ?? [{'urls': 'stun:stun.cloudflare.com:3478'}],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(rtcConfig);

      final dummyDcInit = RTCDataChannelInit()..negotiated = false;
      await _peerConnection!.createDataChannel("dummy", dummyDcInit);

      _peerConnection!.onDataChannel = (channel) {
        printINFO("Guest received remote DataChannel: ${channel.label}");
        if (channel.label == "jam-sync") {
          _sfuDataChannel = channel;
          _sfuDataChannel!.onMessage = (data) {
            _handleSfuMessage(data.text);
          };
          _sfuDataChannel!.onDataChannelState = (state) {
            printINFO("Guest SFU DataChannel state changed: $state");
            if (state == RTCDataChannelState.RTCDataChannelOpen) {
              isSfuActive.value = true;
            } else {
              isSfuActive.value = false;
            }
          };
        }
      };

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final dio = Dio();
      final appId = "ed0d7f61159c81af6bcf4d50cfce4d46";
      final apiToken = "7770fef0c07905db1b77b782920abbb8559595dd3fc411fc452e70d26406b69b";

      final url = "https://rtc.live.cloudflare.com/v1/apps/$appId/sessions/new";
      final sessionResponse = await dio.post(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer $apiToken",
            "Content-Type": "application/json",
          },
        ),
        data: {
          "sessionDescription": {
            "type": "offer",
            "sdp": offer.sdp,
          }
        },
      );

      if (sessionResponse.statusCode == 200 || sessionResponse.statusCode == 201) {
        final resData = sessionResponse.data;
        final guestSessionId = resData['sessionId'] as String;
        final answerSdp = resData['sessionDescription']['sdp'] as String;

        await _peerConnection!.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));
        _sfuSessionId = guestSessionId;

        final pullUrl = "https://rtc.live.cloudflare.com/v1/apps/$appId/sessions/$guestSessionId/datachannels/new";
        final pullResponse = await dio.post(
          pullUrl,
          options: Options(
            headers: {
              "Authorization": "Bearer $apiToken",
              "Content-Type": "application/json",
            },
          ),
          data: {
            "dataChannels": [
              {
                "location": "remote",
                "sessionId": hostSfuSessionId,
                "dataChannelName": "jam-sync",
              }
            ]
          },
        );

        if (pullResponse.statusCode == 200 || pullResponse.statusCode == 201) {
          final pullData = pullResponse.data;
          String? renegotiateOfferSdp;
          
          if (pullData['sessionDescription'] != null) {
            renegotiateOfferSdp = pullData['sessionDescription']['sdp'] as String?;
          } else if (pullData['dataChannels'] != null && pullData['dataChannels'] is List && (pullData['dataChannels'] as List).isNotEmpty) {
            renegotiateOfferSdp = pullData['dataChannels'][0]['sessionDescription']?['sdp'] as String?;
          }
          
          if (renegotiateOfferSdp == null) {
            printERROR("Could not extract renegotiate SDP offer from Cloudflare response: $pullData");
            return;
          }

          await _peerConnection!.setRemoteDescription(RTCSessionDescription(renegotiateOfferSdp, 'offer'));
          final renegotiateAnswer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(renegotiateAnswer);

          final renegotiateUrl = "https://rtc.live.cloudflare.com/v1/apps/$appId/sessions/$guestSessionId/renegotiate";
          await dio.put(
            renegotiateUrl,
            options: Options(
              headers: {
                "Authorization": "Bearer $apiToken",
                "Content-Type": "application/json",
              },
            ),
            data: {
              "sessionDescription": {
                "type": "answer",
                "sdp": renegotiateAnswer.sdp,
              }
            },
          );

          printINFO("Guest SFU Renegotiation completed successfully!");
        } else {
          printERROR("Failed to pull Host SFU DataChannel: ${pullResponse.statusCode}");
        }
      } else {
        printERROR("Failed to create Guest SFU Session: ${sessionResponse.statusCode}");
      }
    } catch (e) {
      printERROR("Error setting up Guest SFU: $e");
      isSfuActive.value = false;
    }
  }

  void _broadcastSfuMessage(Map<String, dynamic> msg) {
    if (_sfuDataChannel != null && _sfuDataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        final text = jsonEncode(msg);
        _sfuDataChannel!.send(RTCDataChannelMessage(text));
      } catch (e) {
        printERROR("Failed to send SFU message: $e");
      }
    }
  }

  void _handleSfuMessage(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final type = map['type'] as String?;

      if (type == 'tick') {
        final positionMs = map['positionMs'] as int;
        final isPlaying = map['isPlaying'] as bool;
        final updatedAt = map['updatedAt'] as int;

        final playerController = Get.find<PlayerController>();
        final currentServerTime = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
        final elapsed = currentServerTime - updatedAt;
        final targetPositionMs = isPlaying ? positionMs + elapsed : positionMs;

        final currentPosMs = playerController.progressBarStatus.value.current.inMilliseconds;
        final currentIsPlaying = playerController.buttonState.value == PlayButtonState.playing;

        if (currentIsPlaying != isPlaying) {
          if (isPlaying) {
            playerController.play();
          } else {
            playerController.pause();
          }
        }

        if ((targetPositionMs - currentPosMs).abs() > 400) {
          printINFO("SFU Precise alignment: ${(targetPositionMs - currentPosMs).abs()}ms drift. Seeking...");
          playerController.seek(Duration(milliseconds: targetPositionMs));
        }
      } else if (type == 'play' || type == 'pause') {
        final videoId = map['videoId'] as String;
        final positionMs = map['positionMs'] as int;
        final isPlaying = map['isPlaying'] as bool;

        final hostSong = JamCurrentSong(
          videoId: videoId,
          title: map['title'] as String? ?? '',
          artist: map['artist'] as String? ?? '',
          thumbnail: map['thumbnail'] as String? ?? '',
          durationMs: map['durationMs'] as int? ?? 0,
          positionMs: positionMs,
          isPlaying: isPlaying,
          updatedAt: map['updatedAt'] as int? ?? (DateTime.now().millisecondsSinceEpoch + _serverTimeOffset),
        );

        _syncWithHost(hostSong);
      } else if (type == 'reaction') {
        final emoji = map['emoji'] as String;
        final from = map['from'] as String;
        incomingReaction.value = {
          'emoji': emoji,
          'from': from,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      }
    } catch (e) {
      printERROR("Error handling SFU message: $e");
    }
  }

  void _startSfuTicker() {
    _sfuTickerTimer?.cancel();
    _sfuTickerTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!isInJam.value || !isHost.value || !isSfuActive.value) {
        timer.cancel();
        return;
      }

      final playerController = Get.find<PlayerController>();
      final mediaItem = playerController.currentSong.value;
      if (mediaItem != null) {
        _broadcastSfuMessage({
          'type': 'tick',
          'positionMs': playerController.progressBarStatus.value.current.inMilliseconds,
          'isPlaying': playerController.buttonState.value == PlayButtonState.playing,
          'updatedAt': DateTime.now().millisecondsSinceEpoch + _serverTimeOffset,
        });
      }
    });
  }

  void _stopSfu() {
    _sfuTickerTimer?.cancel();
    _sfuDataChannel?.close();
    _peerConnection?.close();
    _sfuDataChannel = null;
    _peerConnection = null;
    isSfuActive.value = false;
    _sfuSessionId = null;
  }
}
