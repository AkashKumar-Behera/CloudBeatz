import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/player/player_controller.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/sleep_timer_bottom_sheet.dart';
import '../../widgets/songinfo_bottom_sheet.dart';

/// Album art widget — used by [StandardPlayer] in normal (non-lyrics) mode.
///
/// Tapping the art calls [PlayerController.showLyrics] which flips
/// [showLyricsflag] and causes the AnimatedSwitcher in StandardPlayer to
/// transition to the full-screen lyrics layout.
///
/// The old inline-lyrics overlay has been removed; lyrics are now a
/// separate full-screen layout handled by StandardPlayer itself.
class AlbumArtNLyrics extends StatelessWidget {
  const AlbumArtNLyrics({super.key, required this.playerArtImageSize});
  final double playerArtImageSize;

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    return Obx(() => playerController.currentSong.value != null
        ? Stack(
            children: [
              // Album art with tap / swipe / long-press gestures
              GestureDetector(
                onLongPress: () {
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
                onTap: () => playerController.showLyrics(),
                onHorizontalDragEnd: (DragEndDetails details) {
                  if (details.primaryVelocity! < 0) {
                    playerController.next();
                  } else if (details.primaryVelocity! > 0) {
                    playerController.prev();
                  }
                },
                child: ImageWidget(
                  size: playerArtImageSize,
                  song: playerController.currentSong.value!,
                  isPlayerArtImage: true,
                ),
              ),

              // Sleep timer badge (shown only when active)
              Obx(() => playerController.isSleepTimerActive.isTrue
                  ? SizedBox(
                      width: playerArtImageSize,
                      height: playerArtImageSize,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            height: 50,
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  width: 1.3, color: Colors.white),
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withAlpha(150),
                            ),
                            child: IconButton(
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
                                  builder: (context) =>
                                      const SleepTimerBottomSheet(),
                                );
                              },
                              icon: const Icon(Icons.timer,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          )
        : Container());
  }
}
