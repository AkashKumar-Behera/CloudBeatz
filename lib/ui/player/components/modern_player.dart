import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:squiggly_slider/slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '../../../ui/utils/theme_controller.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/loader.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../../widgets/rectangular_slider_thumb_shape.dart';
import '../player_controller.dart';
import 'backgroud_image.dart';
import 'lyrics_widget.dart';


/// Modern Player UI — v2
///
/// Features:
/// - Blurred ambient background with album-art extracted accent colors
/// - Large artwork card (r=24) that taps to reveal inline lyrics
/// - Lyrics overlay: Synced/Plain toggle switch + three-dots popup
/// - Inline lyrics text editor (popup)
/// - Pill play/pause + circular skip controls using extracted accent color
/// - SquigglySlider progress bar (toggleable via Settings)
/// - Footer: Loop, Shuffle, Favourite, Queue
class ModernPlayer extends StatelessWidget {
  const ModernPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController pc = Get.find<PlayerController>();
    final SettingsScreenController sc = Get.find<SettingsScreenController>();
    final size = MediaQuery.of(context).size;
    final bottomPad = Get.mediaQuery.padding.bottom;
    final double artSize = (size.width - 48).clamp(0.0, 360.0);

    return Stack(
      children: [
        // ── Blurred ambient background ─────────────────────────────────────
        BackgroudImage(
          key: Key("${pc.currentSong.value?.id}_modern_bg"),
          cacheHeight: 200,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 42.0, sigmaY: 42.0),
          child: Container(
            color: Colors.black.withOpacity(0.68),
          ),
        ),

        // ── Bottom gradient anchor ─────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: size.height * 0.50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ),

        // ── Main column ────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Obx(() {
            final showLyrics = pc.showLyricsflag.value;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: showLyrics
                  ? _buildLyricsLayout(context, pc, sc, bottomPad)
                  : _buildNormalLayout(context, pc, sc, bottomPad, artSize),
            );
          }),
        ),
      ],
    );
  }


  Widget _buildNormalLayout(BuildContext context, PlayerController pc,
      SettingsScreenController sc, double bottomPad, double artSize) {
    return Column(
      key: const ValueKey("normal_layout"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top header ───────────────────────────────────────────────
        _TopHeader(pc: pc),
        const SizedBox(height: 12),

        // ── Artwork ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Obx(() {
              final song = pc.currentSong.value;
              if (song == null) return const SizedBox.shrink();
              return _ArtworkCard(
                song: song,
                artSize: artSize,
                pc: pc,
              );
            }),
          ),
        ),

        const SizedBox(height: 20),

        // ── Song title & artist ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Obx(() {
              final song = pc.currentSong.value;
              return Column(
                children: [
                  Marquee(
                    delay: const Duration(milliseconds: 400),
                    duration: const Duration(seconds: 12),
                    id: "${song?.id}_modern_title",
                    child: Text(
                      song?.title ?? "—",
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    song?.artist ?? "—",
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }),
          ),
        ),

        const SizedBox(height: 24),

        // ── Primary Row: Pill Play/Pause + Circular Skip Next ────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Row(
              children: [
                Expanded(child: _PillPlayPauseButton(pc: pc)),
                const SizedBox(width: 16),
                _CircularSkipButton(
                  icon: Icons.skip_next_rounded,
                  onTap: () => pc.next(),
                  pc: pc,
                  size: 58,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Secondary Row: Circular Skip Prev + SquigglySlider ───────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CircularSkipButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: () => pc.prev(),
                  pc: pc,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SquigglyProgressBar(pc: pc, sc: sc),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),
        

        // ── Floating bottom dock ──────────────────────────────────────
        _buildBottomDock(context, pc, bottomPad),
      ],
    );
  }


  Widget _buildLyricsLayout(BuildContext context, PlayerController pc,
      SettingsScreenController sc, double bottomPad) {
    return Column(
      key: const ValueKey("lyrics_layout"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Lyrics header (small artwork, title, options) ─────────────
        _LyricsHeader(pc: pc),

        // ── Lyrics content ───────────────────────────────────────────
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: LyricsWidget(
              padding: EdgeInsets.zero,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Squiggly progress bar ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _SquigglyProgressBar(pc: pc, sc: sc),
        ),

        const SizedBox(height: 16),

        // ── Controls row ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircularSkipButton(
                icon: Icons.skip_previous_rounded,
                onTap: () => pc.prev(),
                pc: pc,
                size: 48,
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 140,
                child: _PillPlayPauseButton(pc: pc),
              ),
              const SizedBox(width: 24),
              _CircularSkipButton(
                icon: Icons.skip_next_rounded,
                onTap: () => pc.next(),
                pc: pc,
                size: 48,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),


        // ── Floating bottom dock ──────────────────────────────────────
        _buildBottomDock(context, pc, bottomPad),
      ],
    );
  }


  Widget _buildBottomDock(BuildContext context, PlayerController pc, double bottomPad) {
    return Padding(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        bottom: bottomPad > 0 ? bottomPad + 18 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Loop
                    Obx(() => _DockIconBtn(
                          icon: Icons.all_inclusive_rounded,
                          active: pc.isLoopModeEnabled.value,
                          onTap: pc.toggleLoopMode,
                        )),
                    // Shuffle
                    Obx(() => _DockIconBtn(
                          icon: Icons.shuffle_rounded,
                          active: pc.isShuffleModeEnabled.value,
                          onTap: pc.toggleShuffleMode,
                        )),
                    // Favourite
                    Obx(() => _DockIconBtn(
                          icon: pc.isCurrentSongFav.isFalse
                              ? Icons.favorite_border_rounded
                              : Icons.favorite_rounded,
                          active: pc.isCurrentSongFav.isTrue,
                          activeColor: Colors.redAccent,
                          onTap: pc.toggleFavourite,
                        )),
                    // Queue
                    _DockIconBtn(
                      icon: Icons.queue_music_rounded,
                      onTap: () {
                        if (GetPlatform.isDesktop) {
                          pc.homeScaffoldkey.currentState!
                              .openEndDrawer();
                        } else {
                          pc.queuePanelController.open();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _TopHeader extends StatelessWidget {
  final PlayerController pc;
  const _TopHeader({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 30),
            color: Theme.of(context).textTheme.titleMedium!.color,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: pc.playerPanelController.close,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 26),
            color: Theme.of(context).textTheme.titleMedium!.color,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              if (pc.currentSong.value == null) return;
              showModalBottomSheet(
                constraints: const BoxConstraints(maxWidth: 500),
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10.0))),
                isScrollControlled: true,
                context: pc.homeScaffoldkey.currentState!.context,
                barrierColor: Colors.transparent.withAlpha(100),
                builder: (context) => SongInfoBottomSheet(
                  pc.currentSong.value!,
                  calledFromPlayer: true,
                ),
              ).whenComplete(() => Get.delete<SongInfoController>());
            },
          ),
        ],
      ),
    );
  }
}

class _LyricsHeader extends StatelessWidget {
  final PlayerController pc;
  const _LyricsHeader({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 30),
            color: Theme.of(context).textTheme.titleMedium!.color,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: pc.playerPanelController.close,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => pc.showLyrics(),
              child: Row(
                children: [
                  Obx(() {
                    final song = pc.currentSong.value;
                    if (song == null) return const SizedBox.shrink();
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageWidget(
                          size: 48,
                          song: song,
                          isPlayerArtImage: false,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() {
                      final song = pc.currentSong.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song?.title ?? "—",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song?.artist ?? "—",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          _LyricsMenuButton(pc: pc),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARTWORK CARD (tappable thumbnail in normal layout)
// ─────────────────────────────────────────────────────────────────────────────
class _ArtworkCard extends StatelessWidget {
  final dynamic song;
  final double artSize;
  final PlayerController pc;

  const _ArtworkCard(
      {required this.song, required this.artSize, required this.pc});

  @override
  Widget build(BuildContext context) {
    final bool isOffline =
        (song?.extras?['url'] ?? '').contains('file');
    final settingsController = Get.find<SettingsScreenController>();

    return GestureDetector(
      onTap: () => pc.showLyrics(),
      onLongPress: () {
        if (song == null) return;
        showModalBottomSheet(
          constraints: const BoxConstraints(maxWidth: 500),
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10.0))),
          isScrollControlled: true,
          context: pc.homeScaffoldkey.currentState!.context,
          barrierColor: Colors.transparent.withAlpha(100),
          builder: (context) => SongInfoBottomSheet(
            song,
            calledFromPlayer: true,
          ),
        ).whenComplete(() => Get.delete<SongInfoController>());
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(115),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: artSize,
            height: artSize,
            child: isOffline
                ? ImageWidget(size: artSize, song: song, isPlayerArtImage: true)
                : CachedNetworkImage(
                    imageUrl: song.artUri.toString(),
                    cacheKey: "${song.id}_song",
                    memCacheHeight: 400,
                    fit: BoxFit.cover,
                    imageBuilder: (context, imageProvider) {
                      // Extract accent color when image loads
                      if (settingsController.themeModetype.value ==
                          ThemeType.dynamic) {
                        Future.delayed(
                          const Duration(milliseconds: 60),
                          () => pc.extractAlbumColor(
                              imageProvider, song.id),
                        );
                      }
                      return Image(image: imageProvider, fit: BoxFit.cover);
                    },
                    errorWidget: (c, u, e) => ImageWidget(
                        size: artSize,
                        song: song,
                        isPlayerArtImage: true),
                    progressIndicatorBuilder: (_, __, ___) =>
                        const LoadingIndicator(),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LYRICS THREE-DOTS POPUP MENU
// ─────────────────────────────────────────────────────────────────────────────
class _LyricsMenuButton extends StatelessWidget {
  final PlayerController pc;
  const _LyricsMenuButton({required this.pc});

  @override
  Widget build(BuildContext context) {
    // Read mode synchronously at build time so selection icon shows correctly
    return Obx(() {
      final mode = pc.lyricsMode.value;
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded,
            color: Colors.white70, size: 24),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'synced',
            child: Row(children: [
              Icon(Icons.sync_rounded,
                  size: 18,
                  color: mode == 0
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color),
              const SizedBox(width: 8),
              Text("showSyncedLyrics".tr,
                  style: TextStyle(
                      color: mode == 0
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: mode == 0 ? FontWeight.bold : FontWeight.normal)),
              if (mode == 0) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.white)
              ],
            ]),
          ),
          PopupMenuItem(
            value: 'plain',
            child: Row(children: [
              Icon(Icons.text_fields_rounded,
                  size: 18,
                  color: mode == 1
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color),
              const SizedBox(width: 8),
              Text("showPlainLyrics".tr,
                  style: TextStyle(
                      color: mode == 1
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: mode == 1 ? FontWeight.bold : FontWeight.normal)),
              if (mode == 1) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.white)
              ],
            ]),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 18),
              const SizedBox(width: 8),
              Text("editLyrics".tr),
            ]),
          ),
          PopupMenuItem(
            value: 'timestamp',
            child: Row(children: [
              const Icon(Icons.timer_rounded, size: 18),
              const SizedBox(width: 8),
              Text("searchWithTimestamp".tr),
            ]),
          ),
          PopupMenuItem(
            value: 'search',
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18),
              const SizedBox(width: 8),
              Text("searchLyricsOnline".tr),
            ]),
          ),
          PopupMenuItem(
            value: 'search_timestamp',
            child: Row(children: [
              const Icon(Icons.manage_search_rounded, size: 18),
              const SizedBox(width: 8),
              Text("searchLyricsWithTimestamp".tr),
            ]),
          ),
          PopupMenuItem(
            value: 'fetch',
            child: Row(children: [
              const Icon(Icons.refresh_rounded, size: 18),
              const SizedBox(width: 8),
              Text("fetchLyricsAgain".tr),
            ]),
          ),
        ],
        onSelected: (val) async {
          switch (val) {
            case 'synced':
              pc.changeLyricsMode(0);
              break;
            case 'plain':
              pc.changeLyricsMode(1);
              break;
            case 'fetch':
              await pc.refetchLyrics();
              break;
            case 'search':
              final query =
                  '${pc.currentSong.value?.title ?? ''} ${pc.currentSong.value?.artist ?? ''} lyrics';
              await _launchLyricsSearch(query);
              break;
            case 'search_timestamp':
              final query = (pc.currentSong.value?.title ?? '').trim();
              await _launchLyricsSearch(query, useLyricsify: true);
              break;
            case 'edit':
              _showInlineEditor(context);
              break;
            case 'timestamp':
              _showTimestampEditor(context);
              break;
          }
        },
      );
    });
  }

  Future<void> _launchLyricsSearch(String query, {bool useLyricsify = false}) async {
    final uri = useLyricsify
        ? Uri.https('www.lyricsify.com', '/search', {'q': query})
        : Uri.https('www.google.com', '/search', {'q': query});
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(SnackBar(
        content: Text('Search: $query'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _showInlineEditor(BuildContext context) {
    final currentPlain = pc.lyrics['plainLyrics'] ?? '';
    final textController =
        TextEditingController(text: currentPlain == 'NA' ? '' : currentPlain);

    showModalBottomSheet(
      context: pc.homeScaffoldkey.currentState!.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LyricsInlineEditor(
        controller: textController,
        pc: pc,
      ),
    );
  }

  void _showTimestampEditor(BuildContext context) {
    final currentSynced = pc.lyrics['synced'] ?? '';
    final textController =
        TextEditingController(text: currentSynced == 'NA' ? '' : currentSynced);

    showModalBottomSheet(
      context: pc.homeScaffoldkey.currentState!.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LyricsInlineEditor(
        controller: textController,
        pc: pc,
        title: "searchWithTimestamp".tr,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE LYRICS EDITOR
// ─────────────────────────────────────────────────────────────────────────────
class LyricsInlineEditor extends StatelessWidget {
  final TextEditingController controller;
  final PlayerController pc;
  final String? title;

  const LyricsInlineEditor(
      {super.key, required this.controller, required this.pc, this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? 'editLyrics'.tr,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('cancel'.tr),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      final newText = controller.text.trim();
                      await pc.updateSongLyrics(newText);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text('save'.tr),
                  ),
                ],
              ),
            ),
            Container(
              constraints:
                  const BoxConstraints(minHeight: 180, maxHeight: 380),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: controller,
                maxLines: 15,
                minLines: 8,
                keyboardType: TextInputType.multiline,
                autofocus: true,
                style: const TextStyle(fontSize: 14, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'Paste or type lyrics here...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withAlpha(13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PILL PLAY / PAUSE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _PillPlayPauseButton extends StatefulWidget {
  final PlayerController pc;
  const _PillPlayPauseButton({required this.pc});

  @override
  State<_PillPlayPauseButton> createState() => _PillPlayPauseButtonState();
}

class _PillPlayPauseButtonState extends State<_PillPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<PlayerController>(builder: (controller) {
      final buttonState = controller.buttonState.value;
      final isPlaying = buttonState == PlayButtonState.playing;
      final isLoading = buttonState == PlayButtonState.loading;

      if (isPlaying) {
        _anim.forward();
      } else if (!isLoading) {
        _anim.reverse();
      }

      // Use extracted accent color if available, else theme primary
      final accentColor = controller.extractedAccentColor.value ??
          Theme.of(context).colorScheme.primary;
      final onAccent = accentColor.computeLuminance() > 0.35
          ? Colors.black87
          : Colors.white;

      return GestureDetector(
        onTap: () => isPlaying ? controller.pause() : controller.play(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 58,
          decoration: BoxDecoration(
            color: accentColor,
            // Animate: full pill when paused, rounded rect when playing
            borderRadius: BorderRadius.circular(isPlaying ? 14 : 32),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(102),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const LoadingIndicator(dimension: 24)
                : AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _anim,
                    color: onAccent,
                    size: 32,
                  ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCULAR SKIP BUTTON (uses extracted accent as subtle tint)
// ─────────────────────────────────────────────────────────────────────────────
class _CircularSkipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final PlayerController pc;
  final double size;

  const _CircularSkipButton({
    required this.icon,
    required this.onTap,
    required this.pc,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final accentColor = pc.extractedAccentColor.value ??
          Theme.of(context).textTheme.titleLarge!.color!.withAlpha(26);
      final bgColor = pc.extractedAccentColor.value != null
          ? accentColor.withAlpha(51) // 20% opacity tint
          : Colors.white.withAlpha(20);

      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              color: Theme.of(context).textTheme.titleMedium!.color,
              size: size * 0.50,
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SQUIGGLY PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SquigglyProgressBar extends StatefulWidget {
  final PlayerController pc;
  final SettingsScreenController sc;
  const _SquigglyProgressBar({required this.pc, required this.sc});

  @override
  State<_SquigglyProgressBar> createState() => _SquigglyProgressBarState();
}

class _SquigglyProgressBarState extends State<_SquigglyProgressBar> {
  double? _dragValue;

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final wavyEnabled = widget.sc.squigglySliderEnabled.value;
      final amplitude = widget.sc.squigglyAmplitude.value;
      final wavelength = widget.sc.squigglyWavelength.value;
      final speed = widget.sc.squigglySpeed.value;
      return GetX<PlayerController>(builder: (controller) {
        final playing = controller.buttonState.value == PlayButtonState.playing;
        final maxMs =
            controller.progressBarStatus.value.total.inMilliseconds.toDouble();
        final curMs =
            controller.progressBarStatus.value.current.inMilliseconds.toDouble();
        final maxVal = maxMs > 0 ? maxMs : 1.0;
        final curVal = curMs.clamp(0.0, maxVal);

        final displayVal = (_dragValue ?? curVal).clamp(0.0, maxVal);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape:
                    const RectangularSliderThumbShape(width: 4.0, height: 14.0, radius: 2.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withAlpha(35),
                thumbColor: Colors.white,
              ),
              child: SquigglySlider(
                key: ValueKey('${wavyEnabled}_${playing}_${amplitude}_${wavelength}_${speed}'),
                value: displayVal,
                min: 0.0,
                max: maxVal,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withAlpha(35),
                thumbColor: Colors.white,
                squiggleAmplitude: (wavyEnabled && playing && _dragValue == null)
                    ? amplitude * (displayVal / (maxVal * 0.05).clamp(1000.0, 5000.0)).clamp(0.0, 1.0)
                    : 0.0,
                squiggleWavelength: wavelength,
                squiggleSpeed: (wavyEnabled && playing && _dragValue == null) ? speed : 0.0,
                onChanged: (v) {
                  setState(() {
                    _dragValue = v;
                  });
                },
                onChangeEnd: (v) {
                  controller.seek(Duration(milliseconds: v.toInt()));
                  setState(() {
                    _dragValue = null;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(_dragValue != null 
                        ? Duration(milliseconds: _dragValue!.toInt()) 
                        : controller.progressBarStatus.value.current),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontSize: 11),
                  ),
                  Text(
                    _fmt(controller.progressBarStatus.value.total),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        );
      });
    });
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// DOCK ICON BUTTON  (used inside the floating glassmorphic bottom dock)
// ─────────────────────────────────────────────────────────────────────────────
class _DockIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  const _DockIconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Obx(() {
          final accent = pc.extractedAccentColor.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(6),
            decoration: active
                ? BoxDecoration(
                    color: (activeColor ?? accent ?? Colors.white)
                        .withAlpha(30),
                    shape: BoxShape.circle,
                  )
                : null,
            child: Icon(
              icon,
              size: 22,
              color: active
                  ? (activeColor ?? accent ?? Colors.white)
                  : Colors.white.withAlpha(140),
            ),
          );
        }),
      ),
    );
  }
}
