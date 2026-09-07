import 'dart:ui';

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

/// Player screen
/// Contains the player ui
///
/// Player ui can be standard player or gesture player
class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    printINFO("player");
    final size = MediaQuery.of(context).size;
    final PlayerController playerController = Get.find<PlayerController>();
    final settingsScreenController = Get.find<SettingsScreenController>();
    return Scaffold(
      /// SlidingUpPanel is used to create a panel that can slide up and down
      /// It is used to show the current queue panel in mobile
      body: Obx(
        () => SlidingUpPanel(
          boxShadow: const [],
          color: Colors.transparent,
          renderPanelSheet: false,
          minHeight: settingsScreenController.playerUi.value == 0
              ? 65 + Get.mediaQuery.padding.bottom
              : 0,
          maxHeight: size.height,
          isDraggable: !GetPlatform.isDesktop,
          controller: GetPlatform.isDesktop
              ? null
              : playerController.queuePanelController,

          /// this is the header of the collapsed panel
          /// contains the button ^ to open the queue panel
          collapsed: InkWell(
            onTap: () {
              /// queue open in end drawer in desktop
              if (GetPlatform.isDesktop) {
                playerController.homeScaffoldkey.currentState!.openEndDrawer();
              } else {
                playerController.queuePanelController.open();
              }
            },
            child: Container(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SizedBox(
                      height: 65,
                      child: Center(
                          child: Icon(
                        color: Theme.of(context).textTheme.titleMedium!.color?.withOpacity(0.7) ?? Colors.white70,
                        Icons.keyboard_arrow_up,
                        size: 36,
                      )),
                    ),
                  ],
                )),
          ),

          /// Panel for queue
          panelBuilder: (ScrollController sc, onReorderStart, onReorderEnd) {
            playerController.scrollController = sc;
            return Stack(
              children: [
                /// Stack first child
                /// UpNextQueue widget contains list of songs in queue
                UpNextQueue(
                  onReorderEnd: onReorderEnd,
                  onReorderStart: onReorderStart,
                ),

                /// Stack second child
                /// This contains the bottom bar with queue loop, shuffle, clear queue buttons
                /// and number of songs in queue
                /// BackdropFilter is used to blur the background
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          boxShadow: const [
                            BoxShadow(blurRadius: 10, color: Colors.black45, offset: Offset(0, -2))
                          ],
                          color: Theme.of(context).cardColor.withOpacity(0.85),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                        ),
                        height: 64 + Get.mediaQuery.padding.bottom,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              /// number of songs in queue
                              Obx(
                                () => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    "${playerController.currentQueue.length} ${"songs".tr}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall!
                                        .copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .color),
                                  ),
                                ),
                              ),

                              /// queue loop button
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  playerController.toggleQueueLoopMode();
                                },
                                child: Obx(
                                  () {
                                    final isEnabled = playerController.isQueueLoopModeEnabled.value;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: 36,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: isEnabled
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isEnabled
                                              ? Colors.transparent
                                              : Colors.white.withOpacity(0.12),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "queueLoop".tr,
                                          style: TextStyle(
                                            color: isEnabled ? Colors.white : Colors.white70,
                                            fontSize: 13,
                                            fontWeight: isEnabled ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              /// queue shuffle button
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  if (playerController
                                      .isShuffleModeEnabled.isTrue) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        snackbar(context,
                                            "queueShufflingDeniedMsg".tr,
                                            size: SanckBarSize.BIG));
                                    return;
                                  }
                                  playerController.shuffleQueue();
                                },
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Center(
                                      child: Icon(Icons.shuffle_rounded,
                                          color: Colors.white, size: 20)),
                                ),
                              ),

                              /// clear queue button
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  playerController.clearQueue();
                                },
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Center(
                                      child: Icon(Icons.playlist_remove_rounded,
                                          color: Colors.white, size: 20)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },

          /// show player ui based on selected player ui in settings
          /// Gesture player is only applicable for mobile
          body: settingsScreenController.playerUi.value == 0
              ? const StandardPlayer()
              : const ModernPlayer(),
        ),
      ),
    );
  }
}
