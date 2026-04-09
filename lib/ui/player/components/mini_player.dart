import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/ui/screens/Settings/settings_screen_controller.dart';
import 'package:ionicons/ionicons.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/ui/widgets/lyrics_dialog.dart';
import '/ui/widgets/song_info_dialog.dart';
import '/ui/player/player_controller.dart';
import '../../widgets/add_to_playlist.dart';
import '../../widgets/sleep_timer_bottom_sheet.dart';
import '../../widgets/song_download_btn.dart';
import '../../widgets/image_widget.dart';
import 'animated_play_button.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 800;
    final bottomNavEnabled =
        Get.find<SettingsScreenController>().isBottomNavBarEnabled.isTrue;

    return Obx(() {
      return Visibility(
        visible: playerController.isPlayerpanelTopVisible.value,
        child: AnimatedOpacity(
          opacity: playerController.playerPaneOpacity.value,
          duration: Duration.zero,
          child: Container(
            height: playerController.playerPanelMinHeight.value,
            width: size.width,
            color: Theme.of(context).bottomSheetTheme.backgroundColor,
            child: Center(
              child: Column(
                children: [
                  // ---------- CUSTOM FULL-WIDTH PROGRESS BAR ON TOP ----------
                  // This is the modified progress UI: one full-width bar across top of mini player.
                  // Left side = played (lighter), Right side = remaining (darker), vertical divider shows current pos.
                  GetX<PlayerController>(builder: (controller) {
                    final status = controller.progressBarStatus.value;
                    final total = status.total;
                    final current = status.current;
                    // protect against zero or null
                    final totalMs =
                        (total.inMilliseconds <= 0) ? 1 : total.inMilliseconds;
                    final currentMs =
                        current.inMilliseconds.clamp(0, totalMs).toInt();
                    final fraction = currentMs / totalMs;

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        // Seek to tapped position
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(details.globalPosition);
                        final width = box.size.width;
                        final dx = local.dx.clamp(0.0, width);
                        final tappedFraction = dx / width;
                        final seekMs = (tappedFraction * totalMs).toInt();
                        controller.seek(Duration(milliseconds: seekMs));
                      },
                      onHorizontalDragUpdate: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(details.globalPosition);
                        final width = box.size.width;
                        final dx = local.dx.clamp(0.0, width);
                        final draggedFraction = dx / width;
                        final seekMs = (draggedFraction * totalMs).toInt();
                        controller.seek(Duration(milliseconds: seekMs));
                      },
                      child: LayoutBuilder(builder: (context, constraints) {
                        const double barHeight = 5.0;
                        final width = constraints.maxWidth;
                        final playedWidth =
                            (width * fraction).clamp(0.0, width);
                        final theme = Theme.of(context);
                        final playedColor =
                            theme.progressIndicatorTheme.color ??
                                theme.colorScheme.primary;
                        final remainingColor = theme
                                .sliderTheme.inactiveTrackColor ??
                            theme.colorScheme.surface.withValues(alpha: 0.5);

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 0.0),
                          color: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // background remaining bar
                              Container(
                                height: barHeight,
                                width: width,
                                decoration: BoxDecoration(
                                  color: remainingColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // played bar (animated)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: barHeight,
                                width: playedWidth,
                                decoration: BoxDecoration(
                                  color: playedColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // vertical divider / current position indicator
                              Positioned(
                                left: (playedWidth - 1).clamp(0.0, width - 1),
                                child: Container(
                                  height: barHeight + 6,
                                  width: 2,
                                  decoration: BoxDecoration(
                                    color: theme.textTheme.titleMedium?.color ??
                                        Colors.white,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                              // small draggable thumb (optional) - visually subtle
                              Positioned(
                                left: (playedWidth - 6).clamp(0.0, width - 12),
                                child: Container(
                                  height: 12,
                                  width: 12,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 3,
                                          offset: Offset(0, 1))
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      }),
                    );
                  }),
                  // ---------- END custom progress bar ----------
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 17.0, vertical: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            playerController.currentSong.value != null
                                ? ImageWidget(
                                    size: 50,
                                    song: playerController.currentSong.value!,
                                  )
                                : const SizedBox(
                                    height: 50,
                                    width: 50,
                                  ),
                          ],
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragEnd: (DragEndDetails details) {
                              if (details.primaryVelocity! < 0) {
                                playerController.next();
                              } else if (details.primaryVelocity! > 0) {
                                playerController.prev();
                              }
                            },
                            onTap: () {
                              playerController.playerPanelController.open();
                            },
                            child: ColoredBox(
                              color: Colors.transparent,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    child: Text(
                                      playerController.currentSong.value != null
                                          ? playerController
                                              .currentSong.value!.title
                                          : "",
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 20,
                                    child: Marquee(
                                      id: "${playerController.currentSong.value}_mini",
                                      delay: const Duration(milliseconds: 300),
                                      duration: const Duration(seconds: 5),
                                      child: Text(
                                        playerController.currentSong.value !=
                                                null
                                            ? playerController
                                                .currentSong.value!.artist!
                                            : "",
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        //player control
                        SizedBox(
                          width: isWideScreen && !bottomNavEnabled ? 450 : 90,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (isWideScreen && !bottomNavEnabled)
                                Row(
                                  children: [
                                    IconButton(
                                        iconSize: 20,
                                        onPressed:
                                            playerController.toggleFavourite,
                                        icon: Obx(() => Icon(
                                              playerController
                                                      .isCurrentSongFav.isFalse
                                                  ? Icons.favorite_border
                                                  : Icons.favorite,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium!
                                                  .color,
                                            ))),
                                    IconButton(
                                        iconSize: 20,
                                        onPressed:
                                            playerController.toggleShuffleMode,
                                        icon: Obx(() => Icon(
                                              Ionicons.shuffle,
                                              color: playerController
                                                      .isShuffleModeEnabled
                                                      .value
                                                  ? Theme.of(context)
                                                      .textTheme
                                                      .titleLarge!
                                                      .color
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .titleLarge!
                                                      .color!
                                                      .withValues(alpha: 0.2),
                                            ))),
                                  ],
                                ),
                              if (isWideScreen && !bottomNavEnabled)
                                SizedBox(
                                    width: 40,
                                    child: InkWell(
                                      onTap: (playerController
                                                  .currentQueue.isEmpty ||
                                              (playerController
                                                      .currentQueue.first.id ==
                                                  playerController
                                                      .currentSong.value?.id))
                                          ? null
                                          : playerController.prev,
                                      child: Icon(
                                        Icons.skip_previous,
                                        color: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .color,
                                        size: 35,
                                      ),
                                    )),
                              isWideScreen && !bottomNavEnabled
                                  ? Container(
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      width: 58,
                                      height: 58,
                                      child: Center(
                                          child: AnimatedPlayButton(
                                        iconSize: isWideScreen ? 43 : 35,
                                      )))
                                  : SizedBox.square(
                                      dimension: 50,
                                      child: Center(
                                          child: AnimatedPlayButton(
                                        iconSize: isWideScreen ? 43 : 35,
                                      ))),
                              SizedBox(
                                  width: 40,
                                  child: Obx(() {
                                    final isLastSong =
                                        playerController.currentQueue.isEmpty ||
                                            (!(playerController
                                                        .isShuffleModeEnabled
                                                        .isTrue ||
                                                    playerController
                                                        .isQueueLoopModeEnabled
                                                        .isTrue) &&
                                                (playerController
                                                        .currentQueue.last.id ==
                                                    playerController.currentSong
                                                        .value?.id));
                                    return InkWell(
                                      onTap: isLastSong
                                          ? null
                                          : playerController.next,
                                      child: Icon(
                                        Icons.skip_next,
                                        color: isLastSong
                                            ? Theme.of(context)
                                                .textTheme
                                                .titleLarge!
                                                .color!
                                                .withValues(alpha: 0.2)
                                            : Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .color,
                                        size: 35,
                                      ),
                                    );
                                  })),
                              if (isWideScreen && !bottomNavEnabled)
                                Row(
                                  children: [
                                    IconButton(
                                        iconSize: 20,
                                        onPressed:
                                            playerController.toggleLoopMode,
                                        icon: Icon(
                                          Icons.all_inclusive,
                                          color: playerController
                                                  .isLoopModeEnabled.value
                                              ? Theme.of(context)
                                                  .textTheme
                                                  .titleLarge!
                                                  .color
                                              : Theme.of(context)
                                                  .textTheme
                                                  .titleLarge!
                                                  .color!
                                                  .withValues(alpha: 0.2),
                                        )),
                                    IconButton(
                                        iconSize: 20,
                                        onPressed: () {
                                          playerController.showLyrics();
                                          showDialog(
                                                  builder: (context) =>
                                                      const LyricsDialog(),
                                                  context: context)
                                              .whenComplete(() {
                                            playerController
                                                    .isDesktopLyricsDialogOpen =
                                                false;
                                            playerController
                                                .showLyricsflag.value = false;
                                          });
                                          playerController
                                              .isDesktopLyricsDialogOpen = true;
                                        },
                                        icon: Icon(Icons.lyrics_outlined,
                                            color: Theme.of(context)
                                                .textTheme
                                                .titleLarge!
                                                .color)),
                                  ],
                                ),
                              if (isWideScreen && !bottomNavEnabled)
                                const SizedBox(
                                  width: 20,
                                )
                            ],
                          ),
                        ),
                        if (isWideScreen && !bottomNavEnabled)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: size.width < 1004 ? 0 : 30.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(
                                        right: 20, left: 10),
                                    height: 20,
                                    width: (size.width > 860) ? 220 : 180,
                                    child: Obx(() {
                                      final volume =
                                          playerController.volume.value;
                                      return Row(
                                        children: [
                                          SizedBox(
                                              width: 20,
                                              child: InkWell(
                                                onTap: playerController.mute,
                                                child: Icon(
                                                  volume == 0
                                                      ? Icons.volume_off
                                                      : volume > 0 &&
                                                              volume < 50
                                                          ? Icons.volume_down
                                                          : Icons.volume_up,
                                                  size: 20,
                                                ),
                                              )),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 2,
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                        enabledThumbRadius:
                                                            6.0),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                        overlayRadius: 10.0),
                                              ),
                                              child: Slider(
                                                value: playerController
                                                        .volume.value /
                                                    100,
                                                onChanged: (value) {
                                                  playerController.setVolume(
                                                      (value * 100).toInt());
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                  SizedBox(
                                    height: 40,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            playerController
                                                .homeScaffoldkey.currentState!
                                                .openEndDrawer();
                                          },
                                          icon: const Icon(Icons.queue_music),
                                        ),
                                        if (size.width > 860)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 10.0),
                                            child: IconButton(
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 500),
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    10.0)),
                                                  ),
                                                  isScrollControlled: true,
                                                  context: playerController
                                                      .homeScaffoldkey
                                                      .currentState!
                                                      .context,
                                                  barrierColor: Colors
                                                      .transparent
                                                      .withAlpha(100),
                                                  builder: (context) =>
                                                      const SleepTimerBottomSheet(),
                                                );
                                              },
                                              icon: Icon(playerController
                                                      .isSleepTimerActive.isTrue
                                                  ? Icons.timer
                                                  : Icons.timer_outlined),
                                            ),
                                          ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        const SongDownloadButton(
                                          calledFromPlayer: true,
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            final currentSong = playerController
                                                .currentSong.value;
                                            if (currentSong != null) {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AddToPlaylist(
                                                        [currentSong]),
                                              ).whenComplete(() => Get.delete<
                                                  AddToPlaylistController>());
                                            }
                                          },
                                          icon: const Icon(Icons.playlist_add),
                                        ),
                                        if (size.width > 965)
                                          IconButton(
                                            onPressed: () {
                                              final currentSong =
                                                  playerController
                                                      .currentSong.value;
                                              if (currentSong != null) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      SongInfoDialog(
                                                    song: currentSong,
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.info,
                                                size: 22),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
