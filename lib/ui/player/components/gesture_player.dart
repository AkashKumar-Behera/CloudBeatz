import 'dart:ui';

import 'package:squiggly_slider/slider.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/ui/player/components/backgroud_image.dart';

import 'package:widget_marquee/widget_marquee.dart';

import '../../widgets/songinfo_bottom_sheet.dart';
import '../../utils/theme_controller.dart';
import '../../screens/Settings/settings_screen_controller.dart';
import '../player_controller.dart';

class GesturePlayer extends StatelessWidget {
  const GesturePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    return Stack(
      children: [
        GestureDetector(
          /// Full screen Background image is acting as album art
          child: const BackgroudImage(),
          onHorizontalDragEnd: (DragEndDetails details) {
            if (details.primaryVelocity! < 0) {
              playerController.next();
            } else if (details.primaryVelocity! > 0) {
              playerController.prev();
            }
          },
          onDoubleTap: () {
            playerController.playPause();
          },
          onLongPress: () {
            showModalBottomSheet(
              constraints: const BoxConstraints(maxWidth: 500),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
              ),
              isScrollControlled: true,
              context: playerController.homeScaffoldkey.currentState!.context,
              barrierColor: Colors.transparent.withAlpha(100),
              builder: (context) => SongInfoBottomSheet(
                playerController.currentSong.value!,
                calledFromPlayer: true,
              ),
            ).whenComplete(() => Get.delete<SongInfoController>());
          },
        ),
        IgnorePointer(
          child: Align(
            child: Center(
              child: Obx(
                () => FadeTransition(
                  opacity: playerController.gesturePlayerStateAnimation!,
                  child: playerController.gesturePlayerVisibleState.value == 2
                      ? const SizedBox.shrink()
                      : Icon(
                          playerController.gesturePlayerVisibleState.value == 1
                              ? Icons.play_arrow
                              : Icons.pause,
                          size: 180,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: Get.mediaQuery.padding.bottom != 0
                    ? Get.mediaQuery.padding.bottom + 10
                    : 20,
                left: 20,
                right: 20),
            child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(maxWidth: 500),
              height: 142,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() {
                                    return Marquee(
                                      delay: const Duration(milliseconds: 300),
                                      duration: const Duration(seconds: 10),
                                      id: "${playerController.currentSong.value}_title",
                                      child: Text(
                                        playerController.currentSong.value !=
                                                null
                                            ? playerController
                                                .currentSong.value!.title
                                            : "NA",
                                        textAlign: TextAlign.start,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .complementaryColor),
                                      ),
                                    );
                                  }),
                                  const SizedBox(
                                    height: 7,
                                  ),
                                  GetX<PlayerController>(builder: (controller) {
                                    return Marquee(
                                      delay: const Duration(milliseconds: 300),
                                      duration: const Duration(seconds: 10),
                                      id: "${playerController.currentSong.value}_subtitle",
                                      child: Text(
                                        playerController.currentSong.value !=
                                                null
                                            ? controller
                                                .currentSong.value!.artist!
                                            : "NA",
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .complementaryColor,
                                                fontWeight: FontWeight.normal),
                                      ),
                                    );
                                  }),
                                ]),
                          ),
                          SizedBox(
                            width: 75,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                    splashRadius: 10,
                                    iconSize: 20,
                                    visualDensity: const VisualDensity(
                                        horizontal: -4, vertical: -4),
                                    onPressed: playerController.toggleFavourite,
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Obx(() {
                                      return IconButton(
                                          splashRadius: 10,
                                          visualDensity: const VisualDensity(
                                              horizontal: -4, vertical: -4),
                                          iconSize: 18,
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
                                                    .withOpacity(0.2),
                                          ));
                                    }),
                                    IconButton(
                                      iconSize: 18,
                                      splashRadius: 10,
                                      visualDensity: const VisualDensity(
                                          horizontal: -4, vertical: -4),
                                      onPressed:
                                          playerController.toggleShuffleMode,
                                      icon: Obx(
                                        () => Icon(
                                          Icons.shuffle,
                                          color: playerController
                                                  .isShuffleModeEnabled.value
                                              ? Theme.of(context)
                                                  .textTheme
                                                  .titleLarge!
                                                  .color
                                              : Theme.of(context)
                                                  .textTheme
                                                  .titleLarge!
                                                  .color!
                                                  .withOpacity(0.2),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      GetX<PlayerController>(builder: (controller) {
                        final isPlaying = controller.buttonState.value == PlayButtonState.playing;
                        final maxMs = controller.progressBarStatus.value.total.inMilliseconds.toDouble();
                        final currentMs = controller.progressBarStatus.value.current.inMilliseconds.toDouble();
                        final maxVal = maxMs > 0 ? maxMs : 1.0;
                        final currentVal = currentMs.clamp(0.0, maxVal);

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Obx(() {
                                  final sc = Get.find<SettingsScreenController>();
                                  final wavyEnabled = sc.squigglySliderEnabled.value;
                                  final amplitude = sc.squigglyAmplitude.value;
                                  final wavelength = sc.squigglyWavelength.value;
                                  final speed = sc.squigglySpeed.value;
                                  return SquigglySlider(
                                    key: ValueKey('${wavyEnabled}_${isPlaying}_${amplitude}_${wavelength}_${speed}'),
                                    value: currentVal,
                                    min: 0.0,
                                    max: maxVal,
                                    activeColor: Theme.of(context).sliderTheme.activeTrackColor,
                                    inactiveColor: Theme.of(context).sliderTheme.inactiveTrackColor,
                                    thumbColor: Theme.of(context).sliderTheme.thumbColor,
                                    squiggleAmplitude: wavyEnabled && isPlaying ? amplitude : 0.0,
                                    squiggleWavelength: wavelength,
                                    squiggleSpeed: wavyEnabled && isPlaying ? speed : 0.0,
                                    onChanged: (value) {
                                      controller.seek(Duration(milliseconds: value.toInt()));
                                    },
                                  );
                                }),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(controller.progressBarStatus.value.current),
                                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                        color: Theme.of(context).primaryColor.complementaryColor,
                                        fontSize: 11),
                                  ),
                                  Text(
                                    _formatDuration(controller.progressBarStatus.value.total),
                                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                        color: Theme.of(context).primaryColor.complementaryColor,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        // absorb pointer to prevent the next,prev gesture from being triggered when the user tries to switch app
        Align(
          alignment: Alignment.bottomCenter,
          child: AbsorbPointer(
            child: SizedBox(
              height: Get.mediaQuery.padding.bottom + 20,
              child: Container(),
            ),
          ),
        )
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${twoDigits(seconds)}";
  }
}
