# CloudBeatz - System Context & Deep Audit Report

> **Last Updated:** September 2026  
> **Status:** Deep Audit Completed (Ready for Systematic Fixes)  
> **Repository:** `CloudBeatz` (Flutter Music Streaming & Offline Player)  
> **Supported Platforms:** Android, iOS, Windows, macOS, Linux

---

## 1. Project Overview & Architecture Context

### Tech Stack
- **Framework:** Flutter (Channel stable / Dart 3.x)
- **State Management:** GetX (`GetxController`, `Get.find()`, `Get.put()`)
- **Audio Engine:** `just_audio` + `audio_service` (`BaseAudioHandler`)
- **Local Storage:** Hive (`SongDownloads`, `Playlists`, `Favorites`, `SearchHistory`, `SettingsBox`)
- **Backend / Sources:**
  - YouTube Explode Dart (`youtube_explode_dart`)
  - Direct JioSaavn API (`saavn.dev` / `saavn.me` / direct API calls)
  - Piped / Invidious API
  - Synced Lyrics (LRCLIB API)
  - Local Device Audio Scanner (`on_audio_query`)

---

## 2. Deep Audit Findings Across Platforms & Features

---

### Category A: Core Audio Streaming & Fallback Breakdown (Multiplatform)

#### 1. Dead Fallback Streaming Mirrors in `StreamService`
- **Location:** `lib/services/stream_service.dart` (`_fetchSaavnStream`, `_fetchFromCobalt`, `_fetchPipedStream`)
- **Issue:**
  - `saavn.dev` and `saavn.me` endpoints are completely down (DNS lookup failed `11001`).
  - `jiosaavn-api-private.vercel.app` throws 402/404.
  - Cobalt endpoints (`api.cobalt.tools`, `co.wuk.sh`) return HTTP 400 bad requests.
  - When YouTube temporarily blocks or rate-limits a client IP (`RequestLimitExceededException` or 403), the fallback pipeline fails completely, falsely marking playable songs as "unplayable".
- **Impact:** Certain tracks (like YouTube Music tracks or Saavn regional tracks) fail to play or take 10+ seconds before timing out.
- **Fix:** Replace dead endpoints with direct JioSaavn public endpoints (`jiosaavn.com/api.php?__call=search.getResults...`) with decrypted media URLs and reliable public Piped API mirrors (`pipedapi.kavin.rocks`, `api.piped.private.coffee`).

#### 2. Missing Direct Dependency in `pubspec.yaml`
- **Location:** `pubspec.yaml`, `lib/main.dart`, `lib/services/audio_handler.dart`
- **Issue:**
  - `package:audio_session/audio_session.dart` is imported and used directly, but NOT declared under `dependencies:` in `pubspec.yaml` (it is currently pulled transitively by `just_audio`).
- **Impact:** Vulnerable to build breaks whenever `just_audio` updates or locks dependencies.
- **Fix:** Add `audio_session: ^0.1.21` directly to `pubspec.yaml`.

#### 3. Search Results Pushed to Queue Missing Accurate Durations
- **Location:** `lib/ui/screens/search_results/search_results_controller.dart` & `lib/services/audio_handler.dart`
- **Issue:** YouTube search results often omit exact duration in metadata until the stream is resolved. If a user rapidly skips songs in queue, `audio_handler.dart` experiences duration race conditions between `MediaItem` update and audio player duration stream.
- **Fix:** Ensure `audio_handler.dart` dynamically updates the current `MediaItem` duration as soon as `_player.durationStream` emits a non-null duration.

---

### Category B: Android-Specific Issues

#### 1. Null Assertion Crash on `openEqualizer`
- **Location:** `lib/services/audio_handler.dart` (Line 816)
- **Issue:**
  ```dart
  EqualizerService.openEqualizer(_player.androidAudioSessionId!);
  ```
  Calling `_player.androidAudioSessionId!` throws a runtime null assertion failure if playback hasn't started yet or audio session hasn't been initialized by Android OS.
- **Impact:** App crash when user opens Equalizer settings before starting playback.
- **Fix:** Add null check `if (_player.androidAudioSessionId != null)` and prompt user to start playback first if null.

#### 2. Deprecated Storage Permissions for Android 13+ (SDK 33+)
- **Location:** `lib/services/downloader.dart`, `android/app/src/main/AndroidManifest.xml`
- **Issue:** Still relying exclusively on `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE`. On Android 13+, these permissions are ignored by the OS; `READ_MEDIA_AUDIO` is required to scan local songs.
- **Fix:** Request `Permission.audio` on Android 13+ and fallback to `Permission.storage` on Android 12 and below.

#### 3. Unsafe Scaffold Context Lookups in Dialogs & Bottom Sheets
- **Location:** `lib/ui/screens/home/home_screen.dart`, `lib/ui/screens/player/player_controller.dart`
- **Issue:** Multiple sheets use `pc.homeScaffoldkey.currentState!.context` without verifying `currentState != null`.
- **Impact:** Can throw red screen error during quick tab navigation while dialog is opening.
- **Fix:** Use `Get.context` or safely guard with `if (pc.homeScaffoldkey.currentState != null)`.

---

### Category C: iOS-Specific Issues

#### 1. Incompatible Audio Codec (WebM/Opus) on AVPlayer
- **Location:** `lib/services/downloader.dart`, `lib/services/stream_service.dart`
- **Issue:**
  - YouTube Explode streams contain WebM/Opus audio (`itag: 251`), which iOS native `AVPlayer` cannot decode natively.
  - While Android and Windows (via mpv/ffmpeg) play Opus smoothly, iOS fails silently or stalls on Opus streams.
- **Impact:** Selected songs do not play or throw codec errors on iOS devices.
- **Fix:** For iOS platform (`Platform.isIOS`), filter streams to strictly prefer MP4A/AAC (`itag: 140`, `itag: 139`).

#### 2. Broken Sandbox File Paths for Local Downloads Across App Updates
- **Location:** `lib/services/downloader.dart`
- **Issue:** iOS assigns a new UUID container path to the app bundle directory after every app update/reinstall. If absolute file paths (`/var/mobile/Containers/Data/Application/{UUID}/Documents/...`) are stored in Hive `SongDownloads`, all previously downloaded songs become unreachable ("File not found") after an app update.
- **Fix:** Store relative file paths in Hive (e.g. `downloads/song_id.m4a`) and resolve dynamically at runtime using `(await getApplicationDocumentsDirectory()).path`.

#### 3. iOS Background Audio Playback & Lock Screen Controls
- **Location:** `ios/Runner/Info.plist`
- **Check:** Ensure `UIBackgroundModes` contains `audio` and proper remote control event forwarding is maintained in `AppDelegate.swift`.

---

### Category D: Windows / Desktop-Specific Issues

#### 1. SlidingUpPanel vs MiniPlayer Layout Collision
- **Location:** `lib/ui/screens/home/home.dart`, `lib/ui/screens/player/mini_player.dart`, `lib/ui/widgets/sliding_up_panel.dart`
- **Issue:**
  - On desktop (width > 800px), `mini_player.dart` shows extended desktop controls (volume slider, shuffle, repeat, queue buttons) which take ~450px width.
  - When `isPanelOpen` transitions or queue is expanded, `SlidingUpPanel` overlay can intercept mouse scroll and click events on the bottom edge of desktop screens.
  - In `home.dart`, `minHeight` for the panel is set to `105px`, but when switching routes, `home_screen_controller.dart` dynamically sets it to `75.0px`, causing layout jerks on Windows resize.
- **Fix:** Harmonize desktop mini-player heights and ensure hit-testing doesn't capture clicks outside the visible panel bounds.

#### 2. Jarvis IPC Service Hardcoded Port Conflict
- **Location:** `lib/services/jarvis_ipc_service.dart`
- **Issue:** Binds to `HttpServer.bind(InternetAddress.loopbackIPv4, 8082)`. If port 8082 is in use by any other Windows service, `JarvisIpcService` fails silently or causes an unhandled SocketException.
- **Fix:** Wrap in try-catch with graceful fallback or dynamic port assignment.

#### 3. Desktop Taskbar & Media Key Sync
- **Location:** `lib/services/windows_audio_service.dart`
- **Check:** SMTC (System Media Transport Controls) integration works, but timeline scrubbing on Windows taskbar sometimes sends out-of-sync seek events if duration is null.

---

### Category E: UI & Feature Collisions

#### 1. BottomNavBar vs SideNavBar Tab Index Desynchronization
- **Location:** `lib/ui/screens/settings/settings_screen_controller.dart` (Lines 189-195) & `lib/ui/widgets/bottom_nav_bar.dart`
- **Issue:**
  - Bottom Navigation has 4 tabs: `[0: Home, 1: Search, 2: Library (Combined), 3: Settings]`
  - Side Navigation (Desktop/Tablet) has 6 tabs: `[0: Home, 1: Songs, 2: Playlists, 3: Albums, 4: Artists, 5: Settings]`
  - When switching between BottomNav and SideNav in settings, or resizing the window across 720px, the selected tab index remains pointing to an invalid or different tab (e.g., Tab 3 in BottomNav is Settings, but in SideNav Tab 3 is Albums).
- **Fix:** Map tab categories to an enum (`AppTab.home`, `AppTab.search`, etc.) rather than raw integer indices.

#### 2. Inverted Selection Color in `SortWidget`
- **Location:** `lib/ui/widgets/sort_widget.dart` (Line 337)
- **Issue:**
  ```dart
  color: isSelected == null || isSelected == true
      ? Theme.of(Get.context!).textTheme.bodySmall!.color
      : Theme.of(Get.context!).colorScheme.secondary;
  ```
  Selected sort items receive a muted/gray `bodySmall` color, while unselected items receive the vibrant `secondary` accent color. This confuses users as the active filter looks inactive.
- **Fix:** Invert the ternary operator so `isSelected == true` gets `colorScheme.secondary`.

#### 3. Null Safety Exception in `SongDownloadButton`
- **Location:** `lib/ui/widgets/song_download_btn.dart` (Line 36)
- **Issue:**
  ```dart
  Hive.box("SongDownloads").containsKey(song!.id)
  ```
  If `song_` is passed as null or song metadata is still loading, it triggers a null assertion crash.
- **Fix:** Null check `song?.id != null ? Hive.box("SongDownloads").containsKey(song!.id) : false`.

---

## 3. Systematic Action Plan (Priority Ordered)

| Priority | Task Description | Target Files | Status |
|---|---|---|---|
| **P0** | Fix previous track audio bleeding (1-2s delay) & seekbar reset race | `lib/services/audio_handler.dart`, `lib/ui/player/player_controller.dart` | ✅ Completed |
| **P0** | Instant playback acceleration (reusable client, in-memory cache, background prefetch) | `lib/services/stream_service.dart`, `lib/services/audio_handler.dart` | ✅ Completed |
| **P0** | Declare `audio_session` directly in `pubspec.yaml` | `pubspec.yaml` | ✅ Completed |
| **P0** | Fix dead streaming fallbacks (clean up dead mirrors, fast timeouts) | `lib/services/stream_service.dart` | ✅ Completed |
| **P1** | Fix Android Equalizer crash (`androidAudioSessionId` null check) | `lib/services/audio_handler.dart` | ✅ Completed |
| **P1** | Fix iOS WebM/Opus audio playback failure (enforce AAC for iOS) | `lib/services/stream_service.dart`, `downloader.dart` | ✅ Completed |
| **P1** | Fix `SongDownloadButton` & `SortWidget` UI logic bugs | `lib/ui/widgets/song_download_btn.dart`, `sort_widget.dart` | ✅ Completed |
| **P2** | Fix BottomNav vs SideNav tab index desynchronization | `lib/ui/screens/settings/settings_screen_controller.dart` | Next |
| **P2** | Fix iOS sandbox download paths (use relative paths) | `lib/services/downloader.dart` | Next |
| **P2** | Windows MiniPlayer & SlidingUpPanel height & touch stabilization | `lib/ui/screens/home/home.dart`, `mini_player.dart` | Next |
| **P3** | Fix Jarvis IPC port binding collision | `lib/services/jarvis_ipc_service.dart` | Next |
