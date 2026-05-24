import 'package:squiggly_slider/slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:widget_marquee/widget_marquee.dart';

import '/ui/player/components/animated_play_button.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '../../widgets/rectangular_slider_thumb_shape.dart';
import '../player_controller.dart';

class PlayerControlWidget extends StatefulWidget {
  const PlayerControlWidget({super.key});

  @override
  State<PlayerControlWidget> createState() => _PlayerControlWidgetState();
}

class _PlayerControlWidgetState extends State<PlayerControlWidget> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.transparent
                      ],
                    ).createShader(
                        Rect.fromLTWH(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Obx(() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Marquee(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(seconds: 10),
                          id: "${playerController.currentSong.value}_title",
                          child: Text(
                            playerController.currentSong.value != null
                                ? playerController.currentSong.value!.title
                                : "NA",
                            textAlign: TextAlign.start,
                            style: Theme.of(context).textTheme.labelMedium!,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Marquee(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(seconds: 10),
                          id: "${playerController.currentSong.value}_subtitle",
                          child: Text(
                            playerController.currentSong.value != null
                                ? playerController.currentSong.value!.artist!
                                : "NA",
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      ],
                    );
                  }),
                ),
              ),
              SizedBox(
                width: 45,
                child: IconButton(
                    onPressed: playerController.toggleFavourite,
                    icon: Obx(() => Icon(
                          playerController.isCurrentSongFav.isFalse
                              ? Icons.favorite_border
                              : Icons.favorite,
                          color: Theme.of(context).textTheme.titleMedium!.color,
                        ))),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          GetX<PlayerController>(builder: (controller) {
            final isPlaying = controller.buttonState.value == PlayButtonState.playing;
            final maxMs = controller.progressBarStatus.value.total.inMilliseconds.toDouble();
            final currentMs = controller.progressBarStatus.value.current.inMilliseconds.toDouble();
            final maxVal = maxMs > 0 ? maxMs : 1.0;
            final currentVal = currentMs.clamp(0.0, maxVal);

            final displayVal = (_dragValue ?? currentVal).clamp(0.0, maxVal);

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
                     return SliderTheme(
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
                         squiggleAmplitude: (wavyEnabled && isPlaying && _dragValue == null) ? amplitude : 0.0,
                         squiggleWavelength: wavelength,
                         squiggleSpeed: (wavyEnabled && isPlaying && _dragValue == null) ? speed : 0.0,
                         onChanged: (value) {
                           setState(() {
                             _dragValue = value;
                           });
                         },
                         onChangeEnd: (value) {
                           controller.seek(Duration(milliseconds: value.toInt()));
                           setState(() {
                             _dragValue = null;
                           });
                         },
                       ),
                     );
                   }),
                 ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_dragValue != null
                            ? Duration(milliseconds: _dragValue!.toInt())
                            : controller.progressBarStatus.value.current),
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 12),
                      ),
                      Text(
                        _formatDuration(controller.progressBarStatus.value.total),
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: playerController.toggleShuffleMode,
                  icon: Obx(() => Icon(
                        Icons.shuffle,
                        color: playerController.isShuffleModeEnabled.value
                            ? Theme.of(context).textTheme.titleLarge!.color
                            : Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .color!
                                .withOpacity(0.2),
                      ))),
              _previousButton(playerController, context),
              const CircleAvatar(radius: 35, child: AnimatedPlayButton(key: Key("playButton"),)),
              _nextButton(playerController, context),
              Obx(() {
                return IconButton(
                    onPressed: playerController.toggleLoopMode,
                    icon: Icon(
                      Icons.all_inclusive,
                      color: playerController.isLoopModeEnabled.value
                          ? Theme.of(context).textTheme.titleLarge!.color
                          : Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .color!
                              .withOpacity(0.2),
                    ));
              }),
            ],
          ),
        ]);
  }


  Widget _previousButton(
      PlayerController playerController, BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.skip_previous,
        color: Theme.of(context).textTheme.titleMedium!.color,
      ),
      iconSize: 30,
      onPressed: playerController.prev,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${twoDigits(seconds)}";
  }
}

Widget _nextButton(PlayerController playerController, BuildContext context) {
  return Obx(() {
    final isLastSong = playerController.currentQueue.isEmpty ||
        (!(playerController.isShuffleModeEnabled.isTrue ||
                playerController.isQueueLoopModeEnabled.isTrue) &&
            (playerController.currentQueue.last.id ==
                playerController.currentSong.value?.id));
    return IconButton(
        icon: Icon(
          Icons.skip_next,
          color: isLastSong
              ? Theme.of(context).textTheme.titleLarge!.color!.withOpacity(0.2)
              : Theme.of(context).textTheme.titleMedium!.color,
        ),
        iconSize: 30,
        onPressed: isLastSong ? null : playerController.next);
  });
}
