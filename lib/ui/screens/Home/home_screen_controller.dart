import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'dart:async';

import '/models/media_Item_builder.dart';
import '/ui/player/player_controller.dart';
import '../../../utils/update_check_flag_file.dart';
import '../../../utils/helper.dart';
import '/models/album.dart';
import '/models/playlist.dart';
import '/models/quick_picks.dart';
import '/services/music_service.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/widgets/new_version_dialog.dart';

class HomeScreenController extends GetxController {
  final MusicServices _musicServices = Get.find<MusicServices>();
  final isContentFetched = false.obs;
  final tabIndex = 0.obs;
  final networkError = false.obs;
  final quickPicks = QuickPicks([]).obs;
  final middleContent = [].obs;
  final fixedContent = [].obs;
  final showVersionDialog = true.obs;
  //isHomeScreenOnTop var only useful if bottom nav enabled
  final isHomeSreenOnTop = true.obs;
  final List<ScrollController> contentScrollControllers = [];
  bool reverseAnimationtransiton = false;

  @override
  onInit() {
    super.onInit();
    loadContent();
    if (updateCheckFlag) _checkNewVersion();
  }

  /// Helper: convert raw list -> List<MediaItem>
  List<MediaItem> _toMediaItemList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<MediaItem>((e) {
      if (e is MediaItem) return e;
      if (e is Map) return MediaItemBuilder.fromJson(e);
      throw Exception("Unsupported MediaItem type: ${e.runtimeType}");
    }).toList();
  }

  /// Helper: convert dynamic list -> List<Playlist>
  List<Playlist> _toPlaylistList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<Playlist>((e) {
      if (e is Playlist) return e;
      if (e is Map) return Playlist.fromJson(e);
      throw Exception("Unsupported Playlist type: ${e.runtimeType}");
    }).whereType<Playlist>().toList();
  }

  /// Helper: convert dynamic list -> List<Album>
  List<Album> _toAlbumList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<Album>((e) {
      if (e is Album) return e;
      if (e is Map) return Album.fromJson(e);
      throw Exception("Unsupported Album type: ${e.runtimeType}");
    }).whereType<Album>().toList();
  }

  Future<void> loadContent() async {
    final box = Hive.box("AppPrefs");
    final isCachedHomeScreenDataEnabled =
        box.get("cacheHomeScreenData") ?? true;
    if (isCachedHomeScreenDataEnabled) {
      final loaded = await loadContentFromDb();

      if (loaded) {
        final currTimeSecsDiff = DateTime.now().millisecondsSinceEpoch -
            (box.get("homeScreenDataTime") ??
                DateTime.now().millisecondsSinceEpoch);
        if (currTimeSecsDiff / 1000 > 3600 * 8) {
          // silent refresh from network
          loadContentFromNetwork(silent: true);
        }
      } else {
        try {
          await loadContentFromNetwork();
        } catch (_) {
          // network failed; DB not present — keep state empty (or show fallback if you add one)
          networkError.value = true;
        }
      }
    } else {
      try {
        await loadContentFromNetwork();
      } catch (_) {
        networkError.value = true;
      }
    }
  }

  Future<bool> loadContentFromDb() async {
    final homeScreenData = await Hive.openBox("homeScreenData");
    if (homeScreenData.keys.isNotEmpty) {
      final String quickPicksType = homeScreenData.get("quickPicksType");
      final List quickPicksData = homeScreenData.get("quickPicks");
      final List middleContentData = homeScreenData.get("middleContent") ?? [];
      final List fixedContentData = homeScreenData.get("fixedContent") ?? [];
      quickPicks.value = QuickPicks(
          quickPicksData.map((e) => MediaItemBuilder.fromJson(e)).toList(),
          title: quickPicksType);
      middleContent.value = middleContentData
          .map((e) => e["type"] == "Album Content"
              ? AlbumContent.fromJson(e)
              : PlaylistContent.fromJson(e))
          .toList();
      fixedContent.value = fixedContentData
          .map((e) => e["type"] == "Album Content"
              ? AlbumContent.fromJson(e)
              : PlaylistContent.fromJson(e))
          .toList();
      isContentFetched.value = true;
      printINFO("Loaded from offline db");
      return true;
    } else {
      return false;
    }
  }

  /// Main network loader — now supports first-run QP behaviour:
  /// - If first run and user preference is BOLI, it will show QP immediately (effectiveContentType = QP)
  /// - Then, it schedules a deferred BOLI fetch after 5 seconds which replaces QP when available.
  Future<void> loadContentFromNetwork({bool silent = false}) async {
    final box = Hive.box("AppPrefs");
    final prefsBox = Hive.box("AppPrefs");
    final bool isFirstRun = (prefsBox.get("homeScreenDataTime") == null);
    String contentType = box.get("discoverContentType") ?? "QP";

    // If first run & discover pref is BOLI, defer BOLI and show QP first.
    final bool shouldDeferBoli = isFirstRun && contentType == "BOLI";
    final String effectiveContentType = shouldDeferBoli ? "QP" : contentType;

    networkError.value = false;
    try {
      List middleContentTemp = [];
      final homeContentListMap = await _musicServices.getHome(
          limit:
              Get.find<SettingsScreenController>().noOfHomeScreenContent.value);

      // Use effectiveContentType for immediate display logic
      if (effectiveContentType == "TR") {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Trending");
        if (index != -1 && index != 0) {
          final raw = homeContentListMap[index]["contents"];
          quickPicks.value = QuickPicks(_toMediaItemList(raw),
              title: "Trending");
        } else if (index == -1) {
          List charts = await _musicServices.getCharts();
          final con =
              charts.length == 4 ? charts.removeAt(3) : charts.removeAt(2);
          quickPicks.value =
              QuickPicks(_toMediaItemList(con["contents"]), title: con['title']);
          middleContentTemp.addAll(charts);
        }
      } else if (effectiveContentType == "TMV") {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Top music videos");
        if (index != -1 && index != 0) {
          final con = homeContentListMap.removeAt(index);
          quickPicks.value =
              QuickPicks(_toMediaItemList(con["contents"]), title: con["title"]);
        } else if (index == -1) {
          List charts = await _musicServices.getCharts();
          quickPicks.value = QuickPicks(
              _toMediaItemList(charts[0]["contents"]),
              title: charts[0]["title"]);
          middleContentTemp.addAll(charts.sublist(1));
        }
      } else if (effectiveContentType == "BOLI") {
        try {
          final songId = box.get("recentSongId");
          if (songId != null) {
            final rel = (await _musicServices.getContentRelatedToSong(
                songId, getContentHlCode()));

            // if we actually got some data from server
            if (rel.isNotEmpty) {
              final con = rel.removeAt(0);
              quickPicks.value = QuickPicks(_toMediaItemList(con["contents"]));
              middleContentTemp.addAll(rel);
            } else {
              // fallback to Quick Picks only for display
              print(
                  "⚠️ No BOLI content found, showing temporary QP content...");
              final homeFallback = await _musicServices.getHome(limit: 3);
              final fallbackCon = homeFallback.first;
              quickPicks.value = QuickPicks(
                _toMediaItemList(fallbackCon["contents"]),
                title: fallbackCon["title"],
              );
              middleContentTemp.addAll(homeFallback.skip(1));
            }
          } else {
            // If no song history exists, fallback directly
            print("⚠️ No recent song found, showing temporary QP content...");
            final homeFallback = await _musicServices.getHome(limit: 3);
            final fallbackCon = homeFallback.first;
            quickPicks.value = QuickPicks(
              _toMediaItemList(fallbackCon["contents"]),
              title: fallbackCon["title"],
            );
            middleContentTemp.addAll(homeFallback.skip(1));
          }
        } catch (e) {
          printERROR("BOLI fetch failed — showing temporary QP fallback.");
          try {
            final homeFallback = await _musicServices.getHome(limit: 3);
            final fallbackCon = homeFallback.first;
            quickPicks.value = QuickPicks(
              _toMediaItemList(fallbackCon["contents"]),
              title: fallbackCon["title"],
            );
            middleContentTemp.addAll(homeFallback.skip(1));
          } catch (_) {
            printERROR("Fallback also failed — no content available.");
          }
        }
      }

      // If nothing set yet for quick picks, try to find "Quick picks" section in homeContentListMap
      if (quickPicks.value.songList.isEmpty) {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Quick picks");
        if (index != -1) {
          final con = homeContentListMap.removeAt(index);
          quickPicks.value = QuickPicks(
            _toMediaItemList(con["contents"]),
            title: "Quick picks",
          );
        } else {
          // Safe fallback if API didn't include "Quick picks"
          print("Quick picks section not found in homeContentListMap");
        }
      }

      middleContent.value = _setContentList(middleContentTemp);
      fixedContent.value = _setContentList(homeContentListMap);

      isContentFetched.value = true;

      // set home content last update time
      cachedHomeScreenData(updateAll: true);
      await Hive.box("AppPrefs")
          .put("homeScreenDataTime", DateTime.now().millisecondsSinceEpoch);

      // If we deferred BOLI due to first run, fetch it after a short delay so QP visible immediately
      if (shouldDeferBoli) {
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            await changeDiscoverContent("BOLI");
            printINFO("Deferred BOLI loaded after first-run QP");
          } catch (e) {
            printERROR("Deferred BOLI fetch failed: $e");
          }
        });
      }
    } on NetworkError catch (r, e) {
      printERROR("Home Content not loaded due to ${r.message}");
      await Future.delayed(const Duration(seconds: 1));
      networkError.value = !silent;
      // do not rethrow — caller already handles fallback in loadContent
    }
  }

  /// Robust converter — accepts raw JSON content list and converts items into
  /// PlaylistContent / AlbumContent where appropriate.
  List _setContentList(List<dynamic> contents) {
    List contentTemp = [];

    for (var content in contents) {
      try {
        if (content == null) continue;
        final title = content["title"] ?? "Untitled";

        // Ensure we have a contents list
        if (!content.containsKey("contents") || content["contents"] is! List) {
          continue;
        }

        final rawList = List<dynamic>.from(content["contents"]);
        if (rawList.isEmpty) continue;

        final first = rawList.first;

        // If first is already a Playlist or Album object, handle directly
        if (first is Playlist) {
          final tmp = PlaylistContent(
              playlistList: rawList.whereType<Playlist>().toList(), title: title);
          if (tmp.playlistList.length >= 2) contentTemp.add(tmp);
          continue;
        } else if (first is Album) {
          final tmp = AlbumContent(
              albumList: rawList.whereType<Album>().toList(), title: title);
          if (tmp.albumList.length >= 2) contentTemp.add(tmp);
          continue;
        }

        // If first is a Map (raw JSON), use heuristics to decide conversion
        if (first is Map) {
          // If looks like playlist JSON
          final looksLikePlaylist = first.containsKey("playlistId") ||
              (first.containsKey("trackCount") || first.containsKey("owner")) ||
              (first.containsKey("id") && first.containsKey("owner"));

          final looksLikeAlbum = first.containsKey("albumId") ||
              (first.containsKey("artist") && first.containsKey("album")) ||
              first.containsKey("year");

          if (looksLikePlaylist) {
            final plList = _toPlaylistList(rawList);
            final tmp = PlaylistContent(playlistList: plList, title: title);
            if (tmp.playlistList.length >= 2) contentTemp.add(tmp);
            continue;
          }

          if (looksLikeAlbum) {
            final alList = _toAlbumList(rawList);
            final tmp = AlbumContent(albumList: alList, title: title);
            if (tmp.albumList.length >= 2) contentTemp.add(tmp);
            continue;
          }

          // fallback: try playlist then album
          final tryPl = _toPlaylistList(rawList);
          if (tryPl.length >= 2) {
            contentTemp.add(PlaylistContent(playlistList: tryPl, title: title));
            continue;
          }
          final tryAl = _toAlbumList(rawList);
          if (tryAl.length >= 2) {
            contentTemp.add(AlbumContent(albumList: tryAl, title: title));
            continue;
          }

          // unknown shape, skip gracefully
          print("Skipping section '$title' — unknown content shape or too few items");
        } else {
          // unsupported type
          print("Skipping section '$title' — unsupported item type: ${first.runtimeType}");
        }
      } catch (e, st) {
        print("Error processing home content item: $e\n$st");
        continue;
      }
    }
    return contentTemp;
  }

  Future<void> changeDiscoverContent(dynamic val, {String? songId}) async {
    QuickPicks? quickPicks_;
    if (val == 'QP') {
      final homeContentListMap = await _musicServices.getHome(limit: 3);
      final raw = homeContentListMap[0]["contents"];
      quickPicks_ = QuickPicks(_toMediaItemList(raw),
          title: homeContentListMap[0]["title"]);
    } else if (val == "TMV" || val == 'TR') {
      try {
        final charts = await _musicServices.getCharts();
        final index = val == "TMV"
            ? 0
            : charts.length == 4
                ? 3
                : 2;
        quickPicks_ = QuickPicks(
            _toMediaItemList(charts[index]["contents"]),
            title: charts[index]["title"]);
      } catch (e) {
        printERROR(
            "Seems ${val == "TMV" ? "Top music videos" : "Trending songs"} currently not available!");
      }
    } else {
      songId ??= Hive.box("AppPrefs").get("recentSongId");
      if (songId != null) {
        try {
          final value = await _musicServices.getContentRelatedToSong(
              songId, getContentHlCode());
          middleContent.value = _setContentList(value);
          if (value.isNotEmpty && (value[0]['title']).contains("like")) {
            quickPicks_ =
                QuickPicks(_toMediaItemList(value[0]["contents"]));
            Hive.box("AppPrefs").put("recentSongId", songId);
          }
          // ignore: empty_catches
        } catch (e) {}
      }
    }
    if (quickPicks_ == null) return;

    quickPicks.value = quickPicks_;

    // set home content last update time
    cachedHomeScreenData(updateQuickPicksNMiddleContent: true);
    await Hive.box("AppPrefs")
        .put("homeScreenDataTime", DateTime.now().millisecondsSinceEpoch);
  }

  String getContentHlCode() {
    const List<String> unsupportedLangIds = ["ia", "ga", "fj", "eo"];
    final userLangId =
        Get.find<SettingsScreenController>().currentAppLanguageCode.value;
    return unsupportedLangIds.contains(userLangId) ? "en" : userLangId;
  }

  void onSideBarTabSelected(int index) {
    reverseAnimationtransiton = index > tabIndex.value;
    tabIndex.value = index;
  }

  void onBottonBarTabSelected(int index) {
    reverseAnimationtransiton = index > tabIndex.value;
    tabIndex.value = index;
  }

  void _checkNewVersion() {
    showVersionDialog.value =
        Hive.box("AppPrefs").get("newVersionVisibility") ?? true;
    if (showVersionDialog.isTrue) {
      newVersionCheck(Get.find<SettingsScreenController>().currentVersion)
          .then((value) {
        if (value) {
          showDialog(
              context: Get.context!,
              builder: (context) => const NewVersionDialog());
        }
      });
    }
  }

  void onChangeVersionVisibility(bool val) {
    Hive.box("AppPrefs").put("newVersionVisibility", !val);
    showVersionDialog.value = !val;
  }

  ///This is used to minimized bottom navigation bar by setting [isHomeSreenOnTop.value] to `true` and set mini player height.
  ///
  ///and applicable/useful if bottom nav enabled
  void whenHomeScreenOnTop() {
    if (Get.find<SettingsScreenController>().isBottomNavBarEnabled.isTrue) {
      final currentRoute = getCurrentRouteName();
      final isHomeOnTop = currentRoute == '/homeScreen';
      final isResultScreenOnTop = currentRoute == '/searchResultScreen';
      final playerCon = Get.find<PlayerController>();

      isHomeSreenOnTop.value = isHomeOnTop;

      // Set miniplayer height accordingly
      if (!playerCon.initFlagForPlayer) {
        if (isHomeOnTop) {
          playerCon.playerPanelMinHeight.value = 75.0;
        } else {
          Future.delayed(
              isResultScreenOnTop
                  ? const Duration(milliseconds: 300)
                  : Duration.zero, () {
            playerCon.playerPanelMinHeight.value =
                75.0 + Get.mediaQuery.viewPadding.bottom;
          });
        }
      }
    }
  }

  Future<void> cachedHomeScreenData({
    bool updateAll = false,
    bool updateQuickPicksNMiddleContent = false,
  }) async {
    if (Get.find<SettingsScreenController>().cacheHomeScreenData.isFalse ||
        quickPicks.value.songList.isEmpty) {
      return;
    }

    final homeScreenData = Hive.box("homeScreenData");

    if (updateQuickPicksNMiddleContent) {
      await homeScreenData.putAll({
        "quickPicksType": quickPicks.value.title,
        "quickPicks": _getContentDataInJson(quickPicks.value.songList,
            isQuickPicks: true),
        "middleContent": _getContentDataInJson(middleContent.toList()),
      });
    } else if (updateAll) {
      await homeScreenData.putAll({
        "quickPicksType": quickPicks.value.title,
        "quickPicks": _getContentDataInJson(quickPicks.value.songList,
            isQuickPicks: true),
        "middleContent": _getContentDataInJson(middleContent.toList()),
        "fixedContent": _getContentDataInJson(fixedContent.toList())
      });
    }

    printINFO("Saved Homescreen data data");
  }

  List<Map<String, dynamic>> _getContentDataInJson(List content,
      {bool isQuickPicks = false}) {
    if (isQuickPicks) {
      return content.toList().map((e) => MediaItemBuilder.toJson(e)).toList();
    } else {
      return content.map((e) {
        if (e.runtimeType == AlbumContent) {
          return (e as AlbumContent).toJson();
        } else {
          return (e as PlaylistContent).toJson();
        }
      }).toList();
    }
  }

  void disposeDetachedScrollControllers({bool disposeAll = false}) {
    final scrollControllersCopy = contentScrollControllers.toList();
    for (final contoller in scrollControllersCopy) {
      if (!contoller.hasClients || disposeAll) {
        contentScrollControllers.remove(contoller);
        contoller.dispose();
      }
    }
  }

  @override
  void dispose() {
    disposeDetachedScrollControllers(disposeAll: true);
    super.dispose();
  }
}
