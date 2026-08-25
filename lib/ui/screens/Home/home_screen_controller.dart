import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

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

  Future<void> loadContent() async {
    final box = Hive.box("AppPrefs");
    final isCachedHomeScreenDataEnabled =
        box.get("cacheHomeScreenData") ?? true;
    if (isCachedHomeScreenDataEnabled) {
      final loaded = await loadContentFromDb();

      if (loaded) {
        // Load fresh content in background so home screen playlists always stay updated
        loadContentFromNetwork(silent: true);
      } else {
        loadContentFromNetwork();
      }
    } else {
      loadContentFromNetwork();
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

  Future<void> loadContentFromNetwork({bool silent = false}) async {
    final box = Hive.box("AppPrefs");
    String contentType = box.get("discoverContentType") ?? "QP";

    networkError.value = false;
    try {
      List middleContentTemp = [];
      final homeContentListMap = await _musicServices.getHome(
          limit:
              Get.find<SettingsScreenController>().noOfHomeScreenContent.value);
      if (contentType == "TR") {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Trending");
        if (index != -1 && index != 0) {
          quickPicks.value = QuickPicks(
              List<MediaItem>.from(homeContentListMap[index]["contents"]),
              title: "Trending");
        } else if (index == -1) {
          List charts = await _musicServices.getCharts(contentType);
          final index = charts.indexWhere((element) =>
              element['title'] ==
              (contentType == "TMV" ? "Top Music Videos" : "Trending"));
          if (index != -1) {
            quickPicks.value = QuickPicks(
                List<MediaItem>.from(charts[index]["contents"]),
                title: charts[index]['title']);
            middleContentTemp.addAll(charts);
          }
        }
      } else if (contentType == "TMV") {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Top music videos");
        if (index != -1 && index != 0) {
          final con = homeContentListMap.removeAt(index);
          quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
              title: con["title"]);
        } else if (index == -1) {
          List charts = await _musicServices.getCharts(contentType);
          final index = charts.indexWhere((element) =>
              element['title'] ==
              (contentType == "TMV" ? "Top Music Videos" : "Trending"));
          if (index != -1) {
            quickPicks.value = QuickPicks(
                List<MediaItem>.from(charts[index]["contents"]),
                title: charts[index]["title"]);
            middleContentTemp.addAll(charts);
          }
        }
      } else if (contentType == "BOLI") {
        try {
          String? songId = box.get("recentSongId");
          if (songId == null || songId.isEmpty || songId.contains("file")) {
            final songsBox = Hive.box("SongsUrlCache");
            if (songsBox.keys.isNotEmpty) {
              songId = songsBox.keys.last.toString();
            }
          }

          if (songId != null && songId.isNotEmpty && !songId.contains("file")) {
            final rel = (await _musicServices.getContentRelatedToSong(
                songId, getContentHlCode()));
            if (rel != null && rel.isNotEmpty) {
              final con = rel.removeAt(0);
              quickPicks.value =
                  QuickPicks(List<MediaItem>.from(con["contents"]), title: con["title"] ?? "discover");
              middleContentTemp.addAll(rel);
            }
          }
        } catch (e) {
          printERROR(
              "Seems Based on last interaction content error: $e");
        }
      }

      if (quickPicks.value.songList.isEmpty) {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Quick picks");
        if (index != -1) {
          final con = homeContentListMap.removeAt(index);
          quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
              title: "Quick picks");
        } else if (homeContentListMap.isNotEmpty) {
          final fallbackIndex = homeContentListMap.indexWhere((element) =>
              element['contents'] != null &&
              element['contents'].isNotEmpty &&
              element['contents'][0].runtimeType == MediaItem);
          if (fallbackIndex != -1) {
            final con = homeContentListMap.removeAt(fallbackIndex);
            quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
                title: con["title"] ?? "Quick picks");
          } else {
            // Ultimate fallback to trending charts
            try {
              List charts = await _musicServices.getCharts("QP");
              final chartIndex = charts.indexWhere((element) =>
                  element['title'] == "Trending" || element['title'] == "Top Music Videos");
              if (chartIndex != -1) {
                quickPicks.value = QuickPicks(
                    List<MediaItem>.from(charts[chartIndex]["contents"]),
                    title: charts[chartIndex]['title']);
                middleContentTemp.addAll(charts);
              }
            } catch (e) {
              printERROR("Error loading trending fallback: $e");
            }
          }
        }
      }

      final limit = Get.find<SettingsScreenController>().noOfHomeScreenContent.value;
      final totalMiddle = _setContentList(middleContentTemp);
      final totalFixed = _setContentList(homeContentListMap);
      
      final combined = [...totalMiddle, ...totalFixed];
      if (combined.length > limit) {
        middleContent.value = combined.sublist(0, limit);
        fixedContent.value = [];
      } else {
        middleContent.value = totalMiddle;
        fixedContent.value = totalFixed;
      }

      isContentFetched.value = true;

      // set home content last update time
      cachedHomeScreenData(updateAll: true);
      await Hive.box("AppPrefs")
          .put("homeScreenDataTime", DateTime.now().millisecondsSinceEpoch);
      // ignore: unused_catch_stack
    } on NetworkError catch (r, e) {
      printERROR("Home Content not loaded due to ${r.message}");
      await Future.delayed(const Duration(seconds: 1));
      networkError.value = !silent;
    }
  }

  List _setContentList(
    List<dynamic> contents,
  ) {
    List contentTemp = [];
    for (var content in contents) {
      final subContents = content["contents"] as List<dynamic>? ?? [];
      if (subContents.isEmpty) continue;
      
      final firstItem = subContents.first;
      if (firstItem is Playlist) {
        final tmp = PlaylistContent(
            playlistList: subContents.whereType<Playlist>().toList(),
            title: content["title"] ?? "Playlists");
        if (tmp.playlistList.isNotEmpty) {
          contentTemp.add(tmp);
        }
      } else if (firstItem is Album) {
        final tmp = AlbumContent(
            albumList: subContents.whereType<Album>().toList(),
            title: content["title"] ?? "Albums");
        if (tmp.albumList.isNotEmpty) {
          contentTemp.add(tmp);
        }
      } else if (firstItem is MediaItem) {
        final playlists = subContents.whereType<MediaItem>().map((e) {
          return Playlist(
            title: e.title,
            playlistId: e.extras?['playlistId'] ?? e.id,
            thumbnailUrl: e.artUri?.toString() ?? Playlist.thumbPlaceholderUrl,
            description: e.artist ?? "Playlist",
          );
        }).toList();
        if (playlists.isNotEmpty) {
          contentTemp.add(PlaylistContent(
            playlistList: playlists,
            title: content["title"] ?? "Recommended",
          ));
        }
      }
    }
    return contentTemp;
  }

  Future<void> changeDiscoverContent(dynamic val, {String? songId}) async {
    QuickPicks? quickPicks_;
    if (val == 'QP') {
      final homeContentListMap = await _musicServices.getHome(limit: 3);
      quickPicks_ = QuickPicks(
          List<MediaItem>.from(homeContentListMap[0]["contents"]),
          title: homeContentListMap[0]["title"]);
    } else if (val == "TMV" || val == 'TR') {
      try {
        final charts = await _musicServices.getCharts(val);
        final index = charts.indexWhere((element) =>
            element['title'] ==
            (val == "TMV" ? "Top Music Videos" : "Trending"));
        quickPicks_ = QuickPicks(
            List<MediaItem>.from(charts[index]["contents"]),
            title: charts[index]["title"]);
      } catch (e) {
        printERROR(
            "Seems ${val == "TMV" ? "Top music videos" : "Trending songs"} currently not available!");
      }
    } else {
      songId ??= Hive.box("AppPrefs").get("recentSongId");
      printINFO("BOLI: Fetching related content for songId: $songId");
      if (songId != null) {
        try {
          final value = await _musicServices.getContentRelatedToSong(
              songId, getContentHlCode());
          printINFO("BOLI: Received related content: ${value?.length} items");
          if (value != null && value.isNotEmpty) {
            final rel = List.from(value);
            final firstSection = rel.removeAt(0);
            quickPicks_ =
                QuickPicks(List<MediaItem>.from(firstSection["contents"]), title: firstSection["title"] ?? "discover");
            
            final limit = Get.find<SettingsScreenController>().noOfHomeScreenContent.value;
            final boliSections = _setContentList(rel);
            
            // If BOLI didn't return album sections, search artist albums for the current song
            if (boliSections.whereType<AlbumContent>().isEmpty && quickPicks_.songList.isNotEmpty) {
              try {
                final artistName = quickPicks_.songList.first.artist?.split(',')[0].trim() ?? "";
                if (artistName.isNotEmpty) {
                  final albumSearch = await _musicServices.search(artistName, filter: "albums", limit: 10);
                  if (albumSearch.containsKey("Albums") && (albumSearch["Albums"] as List).isNotEmpty) {
                    boliSections.insert(0, AlbumContent(
                      title: "$artistName Albums",
                      albumList: List<Album>.from(albumSearch["Albums"]),
                    ));
                  }
                }
              } catch (e) {
                printERROR("Error fetching artist albums for BOLI: $e");
              }
            }

            // If BOLI related sections are fewer than limit, supplement with Home playlists
            if (boliSections.length < limit) {
              final homeContentListMap = await _musicServices.getHome(limit: limit);
              final homeSections = _setContentList(homeContentListMap);
              final combined = [...boliSections, ...homeSections];
              middleContent.value = combined.take(limit).toList();
            } else {
              middleContent.value = boliSections.take(limit).toList();
            }
            fixedContent.value = [];
            Hive.box("AppPrefs").put("recentSongId", songId);
          } else {
            printERROR("BOLI: value is empty or null from getContentRelatedToSong");
          }
        } catch (e, st) {
          printERROR("BOLI Error: $e \n $st");
        }
      } else {
        printERROR("BOLI: songId is NULL in AppPrefs!");
      }
    }
    if (quickPicks_ != null) {
      quickPicks.value = quickPicks_;
      cachedHomeScreenData(updateQuickPicksNMiddleContent: true);
      await Hive.box("AppPrefs")
          .put("homeScreenDataTime", DateTime.now().millisecondsSinceEpoch);
    }
  }

  void updateHomeWithSearchResults(Map<String, dynamic> searchResult) {
    try {
      final List<dynamic> newSections = [];
      if (searchResult.containsKey("Albums") && (searchResult["Albums"] as List).isNotEmpty) {
        newSections.add({
          "title": "Albums",
          "contents": searchResult["Albums"],
        });
      }
      if (searchResult.containsKey("Featured playlists") && (searchResult["Featured playlists"] as List).isNotEmpty) {
        newSections.add({
          "title": "Featured playlists",
          "contents": searchResult["Featured playlists"],
        });
      }
      if (searchResult.containsKey("Community playlists") && (searchResult["Community playlists"] as List).isNotEmpty) {
        newSections.add({
          "title": "Community playlists",
          "contents": searchResult["Community playlists"],
        });
      }

      if (newSections.isNotEmpty) {
        final limit = Get.find<SettingsScreenController>().noOfHomeScreenContent.value;
        final formattedSections = _setContentList(newSections);
        final currentSections = middleContent.toList();
        
        // Put the searched Albums & Playlists at the top of Home Screen
        final List combined = [...formattedSections];
        for (var sec in currentSections) {
          if (!combined.any((e) => e.title == sec.title)) {
            combined.add(sec);
          }
        }
        middleContent.value = combined.take(limit).toList();
        fixedContent.value = [];
        cachedHomeScreenData(updateQuickPicksNMiddleContent: true);
      }
    } catch (e) {
      printERROR("updateHomeWithSearchResults error: $e");
    }
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
