import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '/ui/player/components/modern_player.dart';
import '/ui/player/components/standard_player.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '../../utils/helper.dart';
import '../widgets/snackbar.dart';
import '../widgets/up_next_queue.dart';
import '/ui/player/player_controller.dart';
import '../widgets/sliding_up_panel.dart';

/// Player screen — shows Standard or Modern player UI.
class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    printINFO("player");
    final size = MediaQuery.of(context).size;
    final PlayerController playerController = Get.find<PlayerController>();
    final settingsScreenController = Get.find<SettingsScreenController>();
    return Scaffold(
      body: Obx(
        () => SlidingUpPanel(
          boxShadow: const [],
          minHeight: settingsScreenController.playerUi.value == 0
              ? 65 + Get.mediaQuery.padding.bottom
              : 0,
          maxHeight: size.height,
          isDraggable: !GetPlatform.isDesktop,
          controller: GetPlatform.isDesktop
              ? null
              : playerController.queuePanelController,

          /// Collapsed state — arrow button to open queue panel
          collapsed: InkWell(
            onTap: () {
              if (GetPlatform.isDesktop) {
                playerController.homeScaffoldkey.currentState!.openEndDrawer();
              } else {
                playerController.queuePanelController.open();
              }
            },
            child: Container(
              color: Theme.of(context).primaryColor,
              child: Column(
                children: [
                  SizedBox(
                    height: 65,
                    child: Center(
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        size: 40,
                        color: Theme.of(context).textTheme.titleMedium!.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// Panel for queue — UpNextQueue + solid bottom control bar
          panelBuilder: (ScrollController sc, onReorderStart, onReorderEnd) {
            playerController.scrollController = sc;
            return Stack(
              children: [
                UpNextQueue(
                  onReorderEnd: onReorderEnd,
                  onReorderStart: onReorderStart,
                ),

                /// Bottom control bar — solid, no blur
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 60 + Get.mediaQuery.padding.bottom,
                    padding: const EdgeInsets.only(
                        top: 10, bottom: 10, left: 10, right: 10),
                    decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(blurRadius: 5, color: Colors.black54)
                      ],
                      color: Theme.of(context).primaryColor.withOpacity(0.92),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        /// song count
                        Obx(
                          () => Text(
                            "${playerController.currentQueue.length} ${"songs".tr}",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .color),
                          ),
                        ),

                        /// queue loop
                        InkWell(
                          onTap: playerController.toggleQueueLoopMode,
                          child: Obx(
                            () => Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15),
                              decoration: BoxDecoration(
                                color: playerController
                                        .isQueueLoopModeEnabled.isFalse
                                    ? Colors.white24
                                    : Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(child: Text("queueLoop".tr)),
                            ),
                          ),
                        ),

                        /// shuffle queue
                        InkWell(
                          onTap: () {
                            if (playerController.isShuffleModeEnabled.isTrue) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  snackbar(context,
                                      "queueShufflingDeniedMsg".tr,
                                      size: SanckBarSize.BIG));
                              return;
                            }
                            playerController.shuffleQueue();
                          },
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                                child:
                                    Icon(Icons.shuffle, color: Colors.black)),
                          ),
                        ),

                        /// clear queue
                        InkWell(
                          onTap: playerController.clearQueue,
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                                child: Icon(Icons.playlist_remove,
                                    color: Colors.black)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },

          /// Player UI — Standard or Modern based on settings
          body: settingsScreenController.playerUi.value == 0
              ? const StandardPlayer()
              : const ModernPlayer(),
        ),
      ),
    );
  }
}
