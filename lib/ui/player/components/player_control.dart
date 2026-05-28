import 'package:squiggly_slider/slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:widget_marquee/widget_marquee.dart';

import '/ui/player/components/animated_play_button.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '../../widgets/rectangular_slider_thumb_shape.dart';
import '../player_controller.dart';
import '../../../services/jam_service.dart';

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
    final JamService jamService = Get.find<JamService>();

    return Obx(() {
      final bool isGuest = jamService.isInJam.value && !jamService.isHost.value;
      final bool allowPlayPause = jamService.activeSession.value?.config.allowGuestPlayPause ?? false;

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
                    child: Column(
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
                    ),
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: AbsorbPointer(
                    absorbing: isGuest, // Guests cannot toggle favourite
                    child: IconButton(
                        onPressed: playerController.toggleFavourite,
                        icon: Icon(
                          playerController.isCurrentSongFav.isFalse
                              ? Icons.favorite_border
                              : Icons.favorite,
                          color: isGuest
                              ? Theme.of(context).textTheme.titleMedium!.color!.withOpacity(0.2)
                              : Theme.of(context).textTheme.titleMedium!.color,
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            Builder(builder: (context) {
              final isPlaying = playerController.buttonState.value == PlayButtonState.playing;
              final maxMs = playerController.progressBarStatus.value.total.inMilliseconds.toDouble();
              final currentMs = playerController.progressBarStatus.value.current.inMilliseconds.toDouble();
              final maxVal = maxMs > 0 ? maxMs : 1.0;
              final currentVal = currentMs.clamp(0.0, maxVal);

              final displayVal = (_dragValue ?? currentVal).clamp(0.0, maxVal);

              return Column(
                children: [
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4.0),
                     child: Builder(builder: (context) {
                        final sc = Get.find<SettingsScreenController>();
                        final wavyEnabled = sc.squigglySliderEnabled.value;
                        final amplitude = sc.squigglyAmplitude.value;
                        final wavelength = sc.squigglyWavelength.value;
                        final speed = sc.squigglySpeed.value;

                        final scaleDuration = (maxVal * 0.05).clamp(1000.0, 5000.0);
                        final startScale = (displayVal / scaleDuration).clamp(0.0, 1.0);
                        final currentAmplitude = (wavyEnabled && isPlaying && _dragValue == null)
                            ? amplitude * startScale
                            : 0.0;
                        final currentSpeed = (wavyEnabled && isPlaying && _dragValue == null) ? speed : 0.0;

                        return AbsorbPointer(
                          absorbing: isGuest, // Guests cannot seek the song progress bar
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              thumbShape:
                                  const RectangularSliderThumbShape(width: 4.0, height: 14.0, radius: 2.0),
                              overlayShape:
                                  const RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: isGuest ? Colors.white.withAlpha(50) : Colors.white,
                              inactiveTrackColor: Colors.white.withAlpha(35),
                              thumbColor: isGuest ? Colors.transparent : Colors.white,
                            ),
                            child: SquigglySlider(
                              key: ValueKey('${wavyEnabled}_${isPlaying}_${amplitude}_${wavelength}_${speed}'),
                              value: displayVal,
                              min: 0.0,
                              max: maxVal,
                              activeColor: isGuest ? Colors.white.withAlpha(50) : Colors.white,
                              inactiveColor: Colors.white.withAlpha(35),
                              thumbColor: isGuest ? Colors.transparent : Colors.white,
                              squiggleAmplitude: currentAmplitude,
                              squiggleWavelength: wavelength,
                              squiggleSpeed: currentSpeed,
                              onChanged: (value) {
                                setState(() {
                                  _dragValue = value;
                                });
                              },
                              onChangeEnd: (value) {
                                playerController.seek(Duration(milliseconds: value.toInt()));
                                setState(() {
                                  _dragValue = null;
                                });
                              },
                            ),
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
                              : playerController.progressBarStatus.value.current),
                          style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 12),
                        ),
                        Text(
                          _formatDuration(playerController.progressBarStatus.value.total),
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
                AbsorbPointer(
                  absorbing: isGuest, // Guests cannot toggle shuffle
                  child: IconButton(
                      onPressed: playerController.toggleShuffleMode,
                      icon: Icon(
                        Icons.shuffle,
                        color: (!isGuest && playerController.isShuffleModeEnabled.value)
                            ? Theme.of(context).textTheme.titleLarge!.color
                            : Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .color!
                                .withOpacity(0.2),
                      )),
                ),
                AbsorbPointer(
                  absorbing: isGuest, // Guests cannot trigger previous song
                  child: _previousButton(playerController, context, isGuest),
                ),
                AbsorbPointer(
                  absorbing: isGuest && !allowPlayPause, // Guests can play/pause only if allowed by host config
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: (isGuest && !allowPlayPause)
                        ? Theme.of(context).disabledColor.withOpacity(0.3)
                        : null,
                    child: const AnimatedPlayButton(key: Key("playButton")),
                  ),
                ),
                AbsorbPointer(
                  absorbing: isGuest, // Guests cannot trigger next song
                  child: _nextButton(playerController, context, isGuest),
                ),
                AbsorbPointer(
                  absorbing: isGuest, // Guests cannot toggle loop
                  child: IconButton(
                      onPressed: playerController.toggleLoopMode,
                      icon: Icon(
                        Icons.all_inclusive,
                        color: (!isGuest && playerController.isLoopModeEnabled.value)
                            ? Theme.of(context).textTheme.titleLarge!.color
                            : Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .color!
                                .withOpacity(0.2),
                      )),
                ),
              ],
            ),
          ]);
    });
  }

  Widget _previousButton(
      PlayerController playerController, BuildContext context, bool isGuest) {
    return IconButton(
      icon: Icon(
        Icons.skip_previous,
        color: isGuest
            ? Theme.of(context).textTheme.titleMedium!.color!.withOpacity(0.2)
            : Theme.of(context).textTheme.titleMedium!.color,
      ),
      iconSize: 30,
      onPressed: isGuest ? null : playerController.prev,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${twoDigits(seconds)}";
  }
}

Widget _nextButton(PlayerController playerController, BuildContext context, bool isGuest) {
  final isLastSong = playerController.currentQueue.isEmpty ||
      (!(playerController.isShuffleModeEnabled.isTrue ||
              playerController.isQueueLoopModeEnabled.isTrue) &&
          (playerController.currentQueue.last.id ==
              playerController.currentSong.value?.id));
  return IconButton(
      icon: Icon(
        Icons.skip_next,
        color: (isLastSong || isGuest)
            ? Theme.of(context).textTheme.titleLarge!.color!.withOpacity(0.2)
            : Theme.of(context).textTheme.titleMedium!.color,
      ),
      iconSize: 30,
      onPressed: (isLastSong || isGuest) ? null : playerController.next);
}
