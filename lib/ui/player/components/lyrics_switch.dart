import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/ui/utils/theme_controller.dart';
import 'package:toggle_switch/toggle_switch.dart';

import '../player_controller.dart';

/// Synced / Plain lyrics toggle.
///
/// When [alwaysVisible] is true (used on the lyrics page) the switch is shown
/// unconditionally.  When false (legacy behaviour) it only shows while
/// [PlayerController.showLyricsflag] is active.
class LyricsSwitch extends StatelessWidget {
  const LyricsSwitch({super.key, this.alwaysVisible = false});

  final bool alwaysVisible;

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();

    Widget toggle = ToggleSwitch(
      minWidth: 90.0,
      cornerRadius: 20.0,
      activeBgColors: [
        [Theme.of(context).primaryColor.withLightness(0.4)],
        [Theme.of(context).primaryColor.withLightness(0.4)],
      ],
      activeFgColor: Colors.white,
      inactiveBgColor: Theme.of(context).colorScheme.secondary,
      inactiveFgColor: Colors.white,
      initialLabelIndex: playerController.lyricsMode.value,
      totalSwitches: 2,
      labels: ['synced'.tr, 'plain'.tr],
      radiusStyle: true,
      onToggle: playerController.changeLyricsMode,
    );

    if (alwaysVisible) return toggle;

    return Obx(
      () => playerController.showLyricsflag.value
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: toggle,
            )
          : const SizedBox.shrink(),
    );
  }
}
