import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/image_widget.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'albumart_lyrics.dart';
import 'backgroud_image.dart';
import 'lyrics_switch.dart';
import 'lyrics_widget.dart';
import 'player_control.dart';

/// Standard player widget
///
/// Normal mode  → classic layout with album art + controls
/// Lyrics mode  → modern-player-style: small thumbnail top-left, full LyricsWidget in center
class StandardPlayer extends StatelessWidget {
  const StandardPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final PlayerController playerController = Get.find<PlayerController>();

    double playerArtImageSize = size.width - 60;
    final spaceAvailableForArtImage =
        size.height - (70 + Get.mediaQuery.padding.bottom + 330);
    playerArtImageSize = playerArtImageSize > spaceAvailableForArtImage
        ? spaceAvailableForArtImage
        : playerArtImageSize;

    return Stack(
      children: [
        /// Background blurred album art
        BackgroudImage(
          key: Key("${playerController.currentSong.value?.id}_background"),
          cacheHeight: 200,
        ),

        /// Blur + tint overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.8),
                  ),
                ),
              ),
              // Bottom gradient
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 65 + Get.mediaQuery.padding.bottom + 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.4),
                        Theme.of(context).primaryColor.withOpacity(0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, 0.5, 0.8, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        /// Main content — switches between normal and lyrics layouts
        Padding(
          padding: const EdgeInsets.only(left: 25, right: 25),
          child: (context.isLandscape)
              // ── Landscape: classic side-by-side ──────────────────────────
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: size.width * .45,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 90.0),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: AlbumArtNLyrics(
                              playerArtImageSize: size.width * .29,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: size.width * .48,
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: 10.0,
                            right: 10,
                            bottom: Get.mediaQuery.padding.bottom),
                        child: const PlayerControlWidget(),
                      ),
                    ),
                  ],
                )
              // ── Portrait: animated switch between normal ↔ lyrics ────────
              : Obx(() {
                  final showLyrics = playerController.showLyricsflag.value;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: showLyrics
                        ? _StandardLyricsLayout(
                            key: const ValueKey('std_lyrics'),
                            playerController: playerController,
                          )
                        : _StandardNormalLayout(
                            key: const ValueKey('std_normal'),
                            playerController: playerController,
                            playerArtImageSize: playerArtImageSize,
                            size: size,
                          ),
                  );
                }),
        ),

        /// Fixed header — minimize + more-dots (overlays both layouts)
        if (!(context.isLandscape && GetPlatform.isMobile))
          Padding(
            padding: EdgeInsets.only(
                top: Get.mediaQuery.padding.top + 20, left: 10, right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Minimize button
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                  onPressed: playerController.playerPanelController.close,
                ),
                const Spacer(),
                /// More options
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 25),
                  onPressed: () {
                    showModalBottomSheet(
                      constraints: const BoxConstraints(maxWidth: 500),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(10.0)),
                      ),
                      isScrollControlled: true,
                      context: playerController
                          .homeScaffoldkey.currentState!.context,
                      barrierColor: Colors.transparent.withAlpha(100),
                      builder: (context) => SongInfoBottomSheet(
                        playerController.currentSong.value!,
                        calledFromPlayer: true,
                      ),
                    ).whenComplete(() => Get.delete<SongInfoController>());
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NORMAL LAYOUT — classic album art + controls (original standard player)
// ─────────────────────────────────────────────────────────────────────────────
class _StandardNormalLayout extends StatelessWidget {
  final PlayerController playerController;
  final double playerArtImageSize;
  final Size size;

  const _StandardNormalLayout({
    super.key,
    required this.playerController,
    required this.playerArtImageSize,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// Top padding — shifts based on screen height
        Obx(
          () => playerController.showLyricsflag.value
              ? SizedBox(height: size.height < 750 ? 60 : 90)
              : SizedBox(height: size.height < 750 ? 110 : 140),
        ),

        /// LyricsSwitch + AlbumArtNLyrics
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LyricsSwitch(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: AlbumArtNLyrics(playerArtImageSize: playerArtImageSize),
            ),
          ],
        ),

        const Expanded(child: SizedBox()),

        /// Player controls
        Padding(
          padding: EdgeInsets.only(
              bottom: 80 + Get.mediaQuery.padding.bottom),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const PlayerControlWidget(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LYRICS LAYOUT — Modern-player style: small thumb top-left + full lyrics
// ─────────────────────────────────────────────────────────────────────────────
class _StandardLyricsLayout extends StatelessWidget {
  final PlayerController playerController;

  const _StandardLyricsLayout({
    super.key,
    required this.playerController,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = Get.mediaQuery.padding.bottom;
    final topPad = Get.mediaQuery.padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Space below the fixed header row (minimize + more-dots overlay)
        SizedBox(height: topPad + 64),

        // ── Lyrics header: small thumbnail + song info + menu ─────────────
        _StdLyricsHeader(pc: playerController),

        // ── Full LyricsWidget ─────────────────────────────────────────────
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: LyricsWidget(padding: EdgeInsets.zero),
          ),
        ),

        const SizedBox(height: 8),

        // ── Progress bar ──────────────────────────────────────────────────
        const _StdProgressBar(),

        const SizedBox(height: 12),

        // ── Controls row ──────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad + 12 : 24),
          child: const _StdLyricsControls(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LYRICS HEADER — small thumbnail + title + artist + menu button
// ─────────────────────────────────────────────────────────────────────────────
class _StdLyricsHeader extends StatelessWidget {
  final PlayerController pc;
  const _StdLyricsHeader({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        children: [
          // Small 48px thumbnail — tap to go back to normal layout
          GestureDetector(
            onTap: () => pc.showLyrics(),
            child: Obx(() {
              final song = pc.currentSong.value;
              if (song == null) return const SizedBox.shrink();
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
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
          ),
          const SizedBox(width: 12),

          // Song title + artist
          Expanded(
            child: Obx(() {
              final song = pc.currentSong.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song?.title ?? '—',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song?.artist ?? '—',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }),
          ),

          // Three-dots lyrics menu (same as modern player)
          _StdLyricsMenuButton(pc: pc),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LYRICS MENU BUTTON — identical to modern player's _LyricsMenuButton
// ─────────────────────────────────────────────────────────────────────────────
class _StdLyricsMenuButton extends StatelessWidget {
  final PlayerController pc;
  const _StdLyricsMenuButton({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = pc.lyricsMode.value;
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded,
            color: Colors.white70, size: 22),
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
              Text('showSyncedLyrics'.tr,
                  style: TextStyle(
                      color: mode == 0
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight:
                          mode == 0 ? FontWeight.bold : FontWeight.normal)),
              if (mode == 0) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.white),
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
              Text('showPlainLyrics'.tr,
                  style: TextStyle(
                      color: mode == 1
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight:
                          mode == 1 ? FontWeight.bold : FontWeight.normal)),
              if (mode == 1) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.white),
              ],
            ]),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'search',
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18),
              const SizedBox(width: 8),
              Text('searchLyricsOnline'.tr),
            ]),
          ),
          PopupMenuItem(
            value: 'search_timestamp',
            child: Row(children: [
              const Icon(Icons.manage_search_rounded, size: 18),
              const SizedBox(width: 8),
              Text('searchLyricsWithTimestamp'.tr),
            ]),
          ),
          PopupMenuItem(
            value: 'fetch',
            child: Row(children: [
              const Icon(Icons.refresh_rounded, size: 18),
              const SizedBox(width: 8),
              Text('fetchLyricsAgain'.tr),
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
              final q =
                  '${pc.currentSong.value?.title ?? ''} ${pc.currentSong.value?.artist ?? ''} lyrics';
              await _launchUrl(Uri.https('www.google.com', '/search', {'q': q}));
              break;
            case 'search_timestamp':
              final q = (pc.currentSong.value?.title ?? '').trim();
              await _launchUrl(
                  Uri.https('www.lyricsify.com', '/search', {'q': q}));
              break;
          }
        },
      );
    });
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR (reuses PlayerControlWidget's slider style)
// ─────────────────────────────────────────────────────────────────────────────
class _StdProgressBar extends StatefulWidget {
  const _StdProgressBar();

  @override
  State<_StdProgressBar> createState() => _StdProgressBarState();
}

class _StdProgressBarState extends State<_StdProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return GetX<PlayerController>(builder: (controller) {
      final maxMs =
          controller.progressBarStatus.value.total.inMilliseconds.toDouble();
      final currentMs =
          controller.progressBarStatus.value.current.inMilliseconds.toDouble();
      final maxVal = maxMs > 0 ? maxMs : 1.0;
      final displayVal = (_dragValue ?? currentMs).clamp(0.0, maxVal);

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withAlpha(35),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: displayVal,
                min: 0.0,
                max: maxVal,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withAlpha(35),
                thumbColor: Colors.white,
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  controller.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
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
                      .copyWith(fontSize: 12),
                ),
                Text(
                  _fmt(controller.progressBarStatus.value.total),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLS ROW (prev + play/pause + next) — used in lyrics mode
// ─────────────────────────────────────────────────────────────────────────────
class _StdLyricsControls extends StatelessWidget {
  const _StdLyricsControls();

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        Obx(() => IconButton(
              onPressed: pc.toggleShuffleMode,
              icon: Icon(
                Icons.shuffle,
                color: pc.isShuffleModeEnabled.value
                    ? Theme.of(context).textTheme.titleLarge!.color
                    : Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .color!
                        .withOpacity(0.2),
              ),
            )),
        // Previous
        IconButton(
          icon: Icon(Icons.skip_previous,
              color: Theme.of(context).textTheme.titleMedium!.color),
          iconSize: 30,
          onPressed: pc.prev,
        ),
        // Play / Pause
        Obx(() {
          final isPlaying =
              pc.buttonState.value == PlayButtonState.playing;
          return CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.15),
            child: IconButton(
              iconSize: 30,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              onPressed: isPlaying ? pc.pause : pc.play,
            ),
          );
        }),
        // Next
        Obx(() {
          final isLast = pc.currentQueue.isEmpty ||
              (!(pc.isShuffleModeEnabled.isTrue ||
                      pc.isQueueLoopModeEnabled.isTrue) &&
                  pc.currentQueue.last.id == pc.currentSong.value?.id);
          return IconButton(
            icon: Icon(
              Icons.skip_next,
              color: isLast
                  ? Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .color!
                      .withOpacity(0.2)
                  : Theme.of(context).textTheme.titleMedium!.color,
            ),
            iconSize: 30,
            onPressed: isLast ? null : pc.next,
          );
        }),
        // Loop
        Obx(() => IconButton(
              onPressed: pc.toggleLoopMode,
              icon: Icon(
                Icons.all_inclusive,
                color: pc.isLoopModeEnabled.value
                    ? Theme.of(context).textTheme.titleLarge!.color
                    : Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .color!
                        .withOpacity(0.2),
              ),
            )),
      ],
    );
  }
}
