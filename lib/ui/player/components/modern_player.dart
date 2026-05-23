import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:squiggly_slider/slider.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '../../widgets/image_widget.dart';
import '../../widgets/loader.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'backgroud_image.dart';

/// Modern Player UI
///
/// A premium, minimalist player layout featuring:
/// - Large blurred ambient background
/// - Bold centered artwork card with soft rounded corners
/// - Centered song title + artist subtitle
/// - Primary row: wide accent pill play/pause + circular skip next
/// - Secondary row: circular skip previous + expanded squiggly progress bar
/// - Minimalist footer: loop, queue, more options
class ModernPlayer extends StatelessWidget {
  const ModernPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    final bottomPad = Get.mediaQuery.padding.bottom;

    // Artwork size: fill width but leave room for controls
    final double artSize = (size.width - 48).clamp(0.0, 360.0);

    return Stack(
      children: [
        // ── Background: blurred dynamic album art ──────────────────────────
        BackgroudImage(
          key: Key("${playerController.currentSong.value?.id}_modern_bg"),
          cacheHeight: 200,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.78),
            ),
          ),
        ),

        // ── Gradient fade at bottom to anchor controls ─────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: size.height * 0.55,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.0),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ),

        // ── Main scrollable content ────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Top header bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Collapse button
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        size: 30,
                        color: Theme.of(context).textTheme.titleMedium!.color,
                      ),
                      onPressed: playerController.playerPanelController.close,
                    ),

                    // Playing from label
                    Expanded(
                      child: Obx(() => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                playerController.playinfrom.value.typeString,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '"${playerController.playinfrom.value.nameString}"',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          )),
                    ),

                    // More options
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 26,
                        color: Theme.of(context).textTheme.titleMedium!.color,
                      ),
                      onPressed: () {
                        if (playerController.currentSong.value == null) return;
                        showModalBottomSheet(
                          constraints: const BoxConstraints(maxWidth: 500),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(10.0)),
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

              // ── Artwork card ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Obx(() {
                    final song = playerController.currentSong.value;
                    if (song == null) return const SizedBox.shrink();
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ImageWidget(
                          size: artSize,
                          song: song,
                          isPlayerArtImage: true,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 20),

              // ── Song Title & Artist ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Obx(() {
                    final song = playerController.currentSong.value;
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
                                .copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Marquee(
                          delay: const Duration(milliseconds: 400),
                          duration: const Duration(seconds: 12),
                          id: "${song?.id}_modern_artist",
                          child: Text(
                            song?.artist ?? "—",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 28),

              // ── Primary Controls Row: Pill Play/Pause + Circular Next ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Row(
                    children: [
                      // Wide pill-shaped Play/Pause button
                      Expanded(
                        child: _PillPlayPauseButton(
                            playerController: playerController),
                      ),
                      const SizedBox(width: 16),
                      // Circular Skip Next button
                      _CircularControlButton(
                        icon: Icons.skip_next_rounded,
                        onTap: () => playerController.next(),
                        size: 58,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Secondary Row: Circular Prev + Squiggly Seek Bar ────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Circular Skip Previous button
                          _CircularControlButton(
                            icon: Icons.skip_previous_rounded,
                            onTap: () => playerController.prev(),
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          // Expanded squiggly progress bar
                          Expanded(
                            child: _SquigglyProgressBar(
                                playerController: playerController),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer Action Bar ────────────────────────────────────────
              SizedBox(height: bottomPad > 0 ? 12 : 20),
              Padding(
                padding: EdgeInsets.only(
                    left: 28,
                    right: 28,
                    bottom: bottomPad > 0 ? bottomPad : 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Loop mode toggle
                      Obx(() => IconButton(
                            onPressed: playerController.toggleLoopMode,
                            icon: Icon(
                              Icons.all_inclusive_rounded,
                              color: playerController.isLoopModeEnabled.value
                                  ? Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .color
                                  : Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .color!
                                      .withOpacity(0.30),
                              size: 24,
                            ),
                          )),

                      // Shuffle mode toggle
                      Obx(() => IconButton(
                            onPressed: playerController.toggleShuffleMode,
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color:
                                  playerController.isShuffleModeEnabled.value
                                      ? Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .color
                                      : Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .color!
                                          .withOpacity(0.30),
                              size: 24,
                            ),
                          )),

                      // Favourite toggle
                      Obx(() => IconButton(
                            onPressed: playerController.toggleFavourite,
                            icon: Icon(
                              playerController.isCurrentSongFav.isFalse
                                  ? Icons.favorite_border_rounded
                                  : Icons.favorite_rounded,
                              color: playerController.isCurrentSongFav.isTrue
                                  ? Colors.redAccent
                                  : Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .color!
                                      .withOpacity(0.55),
                              size: 24,
                            ),
                          )),

                      // Queue trigger
                      IconButton(
                        onPressed: () {
                          if (GetPlatform.isDesktop) {
                            playerController.homeScaffoldkey.currentState!
                                .openEndDrawer();
                          } else {
                            playerController.queuePanelController.open();
                          }
                        },
                        icon: Icon(
                          Icons.playlist_play_rounded,
                          color: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .color!
                              .withOpacity(0.55),
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Pill-shaped Play / Pause button ─────────────────────────────────────────
class _PillPlayPauseButton extends StatefulWidget {
  final PlayerController playerController;
  const _PillPlayPauseButton({required this.playerController});

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

      final accentColor = Theme.of(context).colorScheme.primary;
      final onAccentColor = Theme.of(context).colorScheme.onPrimary;

      return GestureDetector(
        onTap: () => isPlaying ? controller.pause() : controller.play(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.40),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const LoadingIndicator(
                    dimension: 24,
                  )
                : AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _anim,
                    color: onAccentColor,
                    size: 32,
                  ),
          ),
        ),
      );
    });
  }
}

// ── Circular control button (Skip Prev / Skip Next) ──────────────────────────
class _CircularControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CircularControlButton({
    required this.icon,
    required this.onTap,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).textTheme.titleLarge!.color!.withOpacity(0.10),
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
  }
}

// ── Squiggly progress seek bar with time labels ──────────────────────────────
class _SquigglyProgressBar extends StatelessWidget {
  final PlayerController playerController;
  const _SquigglyProgressBar({required this.playerController});

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return GetX<PlayerController>(builder: (controller) {
      final isPlaying =
          controller.buttonState.value == PlayButtonState.playing;
      final maxMs = controller.progressBarStatus.value.total.inMilliseconds
          .toDouble();
      final curMs = controller.progressBarStatus.value.current.inMilliseconds
          .toDouble();
      final maxVal = maxMs > 0 ? maxMs : 1.0;
      final curVal = curMs.clamp(0.0, maxVal);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: SquigglySlider(
              value: curVal,
              min: 0.0,
              max: maxVal,
              activeColor:
                  Theme.of(context).sliderTheme.activeTrackColor,
              inactiveColor:
                  Theme.of(context).sliderTheme.inactiveTrackColor,
              thumbColor: Theme.of(context).sliderTheme.thumbColor,
              squiggleAmplitude: isPlaying ? 4.0 : 0.0,
              squiggleWavelength: 5.0,
              squiggleSpeed: isPlaying ? 0.06 : 0.0,
              onChanged: (v) {
                controller.seek(Duration(milliseconds: v.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(controller.progressBarStatus.value.current),
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
  }
}
