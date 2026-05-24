import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:squiggly_slider/slider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../screens/Settings/settings_screen_controller.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/rectangular_slider_thumb_shape.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'albumart_lyrics.dart';
import 'backgroud_image.dart';
import 'lyrics_switch.dart';
import 'lyrics_widget.dart';
import 'modern_player.dart';
import 'player_control.dart';

/// Standard player widget
///
/// Normal mode  → classic layout with album art + controls
/// Lyrics mode  → modern-player-style: small thumbnail + minimize in header, full LyricsWidget center
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
                  color: Theme.of(context).primaryColor.withAlpha(204),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 65 + Get.mediaQuery.padding.bottom + 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withAlpha(102),
                        Colors.transparent,
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
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: size.width * .45,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 90.0, top: 40),
                        child: Center(
                          child: AlbumArtNLyrics(
                            playerArtImageSize: size.width * .29,
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
              : Obx(() {
                  final showLyrics = playerController.showLyricsflag.value;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
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

        /// Fixed header — only shown in NORMAL mode (lyrics layout has its own header)
        if (!(context.isLandscape && GetPlatform.isMobile))
          Obx(() => playerController.showLyricsflag.isFalse
              ? Padding(
                  padding: EdgeInsets.only(
                      top: Get.mediaQuery.padding.top + 20,
                      left: 10,
                      right: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.keyboard_arrow_down, size: 28),
                        onPressed:
                            playerController.playerPanelController.close,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 25),
                        onPressed: () {
                          showModalBottomSheet(
                            constraints:
                                const BoxConstraints(maxWidth: 500),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.0)),
                            ),
                            isScrollControlled: true,
                            context: playerController
                                .homeScaffoldkey.currentState!.context,
                            barrierColor:
                                Colors.transparent.withAlpha(100),
                            builder: (context) => SongInfoBottomSheet(
                              playerController.currentSong.value!,
                              calledFromPlayer: true,
                            ),
                          ).whenComplete(
                              () => Get.delete<SongInfoController>());
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NORMAL LAYOUT — classic album art + controls
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
        SizedBox(height: size.height < 750 ? 110 : 140),

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
// LYRICS LAYOUT — small thumb + minimize in header, full LyricsWidget
// ─────────────────────────────────────────────────────────────────────────────
class _StandardLyricsLayout extends StatelessWidget {
  final PlayerController playerController;

  const _StandardLyricsLayout({
    super.key,
    required this.playerController,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = Get.mediaQuery.padding.top;
    final bottomPad = Get.mediaQuery.padding.bottom;
    // Fixed bottom section: progress(~30) + gap(8) + controls(~56) + bottom padding (80 + bottomPad)
    final bottomFixedH = 30.0 + 8.0 + 56.0 + 80.0 + bottomPad;
    // Fixed top section: status bar space + header row (~56)
    final topFixedH = (topPad + 8) + 56.0;

    return LayoutBuilder(builder: (context, constraints) {
      // Compute exact lyrics height so controls always stay on screen
      final lyricsH =
          (constraints.maxHeight - topFixedH - bottomFixedH - 20).clamp(80.0, double.infinity);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad + 8),

          _StdLyricsHeader(pc: playerController),

          // Constrained lyrics — never pushes controls off screen
          SizedBox(
            height: lyricsH,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LyricsWidget(padding: EdgeInsets.zero),
            ),
          ),

          const SizedBox(height: 4),

          const _StdProgressBar(),

          const SizedBox(height: 8),

          Padding(
            padding: EdgeInsets.only(
              bottom: 80.0 + bottomPad,
            ),
            child: const _StdLyricsControls(),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LYRICS HEADER — minimize button + small thumbnail + song info + menu
// ─────────────────────────────────────────────────────────────────────────────
class _StdLyricsHeader extends StatelessWidget {
  final PlayerController pc;
  const _StdLyricsHeader({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Minimize button (close player panel)
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 28,
              color: Theme.of(context).textTheme.titleMedium!.color,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: pc.playerPanelController.close,
          ),

          const SizedBox(width: 6),

          // Small 44px thumbnail — tap to return to normal layout
          GestureDetector(
            onTap: () => pc.showLyrics(),
            child: Obx(() {
              final song = pc.currentSong.value;
              if (song == null) return const SizedBox(width: 44, height: 44);
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageWidget(
                    size: 44,
                    song: song,
                    isPlayerArtImage: false,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(width: 10),

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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    song?.artist ?? '—',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }),
          ),

          // Three-dots lyrics menu
          _StdLyricsMenuButton(pc: pc),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LYRICS MENU BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _StdLyricsMenuButton extends StatelessWidget {
  final PlayerController pc;
  const _StdLyricsMenuButton({required this.pc});

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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = pc.lyricsMode.value;
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded,
            color: Colors.white70, size: 22),
        color: Theme.of(context).cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      fontWeight: mode == 0
                          ? FontWeight.bold
                          : FontWeight.normal)),
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
                      fontWeight: mode == 1
                          ? FontWeight.bold
                          : FontWeight.normal)),
              if (mode == 1) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.white),
              ],
            ]),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 18),
              const SizedBox(width: 8),
              Text('editLyrics'.tr),
            ]),
          ),
          PopupMenuItem(
            value: 'timestamp',
            child: Row(children: [
              const Icon(Icons.timer_rounded, size: 18),
              const SizedBox(width: 8),
              Text('searchWithTimestamp'.tr),
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
            case 'edit':
              _showInlineEditor(context);
              break;
            case 'timestamp':
              _showTimestampEditor(context);
              break;
            case 'fetch':
              await pc.refetchLyrics();
              break;
            case 'search':
              final q =
                  '${pc.currentSong.value?.title ?? ''} ${pc.currentSong.value?.artist ?? ''} lyrics';
              await _launch(
                  Uri.https('www.google.com', '/search', {'q': q}));
              break;
            case 'search_timestamp':
              final q = (pc.currentSong.value?.title ?? '').trim();
              await _launch(
                  Uri.https('www.lyricsify.com', '/search', {'q': q}));
              break;
          }
        },
      );
    });
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR — used in lyrics mode
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
    final sc = Get.find<SettingsScreenController>();
    return GetX<PlayerController>(builder: (controller) {
      final isPlaying = controller.buttonState.value == PlayButtonState.playing;
      final maxMs =
          controller.progressBarStatus.value.total.inMilliseconds.toDouble();
      final currentMs =
          controller.progressBarStatus.value.current.inMilliseconds.toDouble();
      final maxVal = maxMs > 0 ? maxMs : 1.0;
      final displayVal = (_dragValue ?? currentMs).clamp(0.0, maxVal);

      final wavyEnabled = sc.squigglySliderEnabled.value;
      final amplitude = sc.squigglyAmplitude.value;
      final wavelength = sc.squigglyWavelength.value;
      final speed = sc.squigglySpeed.value;

      // Scale down amplitude at the start of the song for a smooth transition from a straight line
      final scaleDuration = (maxVal * 0.05).clamp(1000.0, 5000.0);
      final startScale = (displayVal / scaleDuration).clamp(0.0, 1.0);
      final currentAmplitude = (wavyEnabled && isPlaying && _dragValue == null)
          ? amplitude * startScale
          : 0.0;
      final currentSpeed = (wavyEnabled && isPlaying && _dragValue == null) ? speed : 0.0;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SliderTheme(
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
                key: ValueKey('${wavyEnabled}_${isPlaying}_${amplitude}_${wavelength}_${speed}'),
                value: displayVal,
                min: 0.0,
                max: maxVal,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withAlpha(35),
                thumbColor: Colors.white,
                squiggleAmplitude: currentAmplitude,
                squiggleWavelength: wavelength,
                squiggleSpeed: currentSpeed,
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  controller.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
// CONTROLS ROW — shuffle + prev + animated play/pause + next + loop
// ─────────────────────────────────────────────────────────────────────────────
class _StdLyricsControls extends StatelessWidget {
  const _StdLyricsControls();

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final activeColor = Theme.of(context).textTheme.titleMedium!.color!;
    final inactiveColor = activeColor.withAlpha(51); // 0.2 opacity

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Shuffle
        Obx(() => IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: pc.toggleShuffleMode,
              icon: Icon(
                Icons.shuffle_rounded,
                size: 22,
                color: pc.isShuffleModeEnabled.value
                    ? activeColor
                    : inactiveColor,
              ),
            )),

        // Previous
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(Icons.skip_previous_rounded,
              size: 28, color: activeColor),
          onPressed: pc.prev,
        ),

        // Animated play / pause
        Obx(() {
          final isPlaying =
              pc.buttonState.value == PlayButtonState.playing;
          return GestureDetector(
            onTap: isPlaying ? pc.pause : pc.play,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                // Theme color with slight opacity for the button bg
                color: activeColor.withAlpha(40),
                borderRadius: BorderRadius.circular(
                  isPlaying ? 14 : 29, // smaller radius when playing
                ),
                border: Border.all(
                  color: activeColor.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 30,
                color: activeColor,
              ),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(Icons.skip_next_rounded,
                size: 28,
                color: isLast ? inactiveColor : activeColor),
            onPressed: isLast ? null : pc.next,
          );
        }),

        // Loop
        Obx(() => IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: pc.toggleLoopMode,
              icon: Icon(
                Icons.all_inclusive_rounded,
                size: 22,
                color: pc.isLoopModeEnabled.value
                    ? activeColor
                    : inactiveColor,
              ),
            )),
      ],
    );
  }
}
