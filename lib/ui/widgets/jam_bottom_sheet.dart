import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/jam_service.dart';
import '../../utils/helper.dart';

class JamBottomSheetController extends GetxController {
  final jamService = Get.find<JamService>();
  final nameController = TextEditingController();
  final codeController = TextEditingController();

  // Bottom sheet states: 'name', 'menu', 'join', 'host_active', 'guest_active'
  final sheetState = 'menu'.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _determineState();
  }

  void _determineState() {
    final name = getJamDisplayName();
    if (name.isEmpty) {
      sheetState.value = 'name';
    } else if (jamService.isInJam.isTrue) {
      sheetState.value = jamService.isHost.isTrue ? 'host_active' : 'guest_active';
    } else if (jamService.pendingJoinCode.value != null) {
      // If there was a pending deep-link code, proceed to join
      codeController.text = jamService.pendingJoinCode.value!;
      sheetState.value = 'join';
    } else {
      sheetState.value = 'menu';
    }
  }

  void saveName() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar("Name required", "Please enter a display name to continue");
      return;
    }
    jamService.updateDisplayName(name);
    
    // Check if we had a pending deep link join code
    if (jamService.pendingJoinCode.value != null) {
      final code = jamService.pendingJoinCode.value!;
      jamService.pendingJoinCode.value = null;
      joinSession(code);
    } else {
      sheetState.value = 'menu';
    }
  }

  Future<void> createSession() async {
    isLoading.value = true;
    final success = await jamService.createJam();
    isLoading.value = false;
    if (success) {
      sheetState.value = 'host_active';
    }
  }

  Future<void> joinSession(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.length != 4 || int.tryParse(cleanCode) == null) {
      Get.snackbar("Invalid Code", "Please enter a 4-digit numeric code");
      return;
    }
    isLoading.value = true;
    final success = await jamService.joinJam(cleanCode);
    isLoading.value = false;
    if (success) {
      sheetState.value = 'guest_active';
    }
  }

  Future<void> leaveOrEndSession() async {
    isLoading.value = true;
    await jamService.leaveJam();
    isLoading.value = false;
    sheetState.value = 'menu';
  }

  void shareJam() {
    final link = jamService.getShareLink();
    final code = jamService.activeSession.value?.code ?? '';
    Clipboard.setData(ClipboardData(text: link));
    Get.snackbar("Copied to Clipboard", "Jam deep link copied! Share with friends.");
    if (!GetPlatform.isDesktop) {
      Share.share(
        "Join my collaborative music Jam session on CloudBeatz! 🎧\n\nCode: $code\nLink: $link",
        subject: "Join my CloudBeatz Jam!",
      );
    }
  }
}

class JamBottomSheet extends StatelessWidget {
  const JamBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(JamBottomSheetController());
    
    return Obx(() {
      // Direct UI state mapping
      if (controller.jamService.isInJam.isTrue) {
        if (controller.jamService.isHost.isTrue && controller.sheetState.value != 'host_active') {
          controller.sheetState.value = 'host_active';
        } else if (controller.jamService.isHost.isFalse && controller.sheetState.value != 'guest_active') {
          controller.sheetState.value = 'guest_active';
        }
      } else if (controller.sheetState.value == 'host_active' || controller.sheetState.value == 'guest_active') {
        controller.sheetState.value = 'menu';
      }

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.only(
          bottom: 16,
          top: 12,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull Handle
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (controller.isLoading.isTrue)
                  const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStateContent(context, controller),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStateContent(BuildContext context, JamBottomSheetController controller) {
    switch (controller.sheetState.value) {
      case 'name':
        return _buildNameInputState(context, controller);
      case 'menu':
        return _buildMenuState(context, controller);
      case 'join':
        return _buildJoinState(context, controller);
      case 'host_active':
      case 'guest_active':
        return _buildActiveState(context, controller);
      default:
        return _buildMenuState(context, controller);
    }
  }

  Widget _buildNameInputState(BuildContext context, JamBottomSheetController controller) {
    return Column(
      key: const ValueKey('name_state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Set your Jam Name 🎶",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter a display name so your friends know who you are.",
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller.nameController,
          maxLength: 15,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: "Vibe Master Akash",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withBlue(255)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton(
            onPressed: controller.saveName,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Next", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuState(BuildContext context, JamBottomSheetController controller) {
    final name = getJamDisplayName();
    return Column(
      key: const ValueKey('menu_state'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hey $name! 👋",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Ready to Jam with your friends?",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                controller.nameController.text = name;
                controller.sheetState.value = 'name';
              },
              tooltip: "Change Display Name",
            )
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _buildMenuCard(
                context,
                title: "Create a Jam",
                desc: "Start a group listening session and control playback.",
                icon: Icons.graphic_eq,
                isPrimary: true,
                onTap: controller.createSession,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMenuCard(
                context,
                title: "Join a Jam",
                desc: "Enter a 4-digit code to sync with your friend's session.",
                icon: Icons.group_add_outlined,
                isPrimary: false,
                onTap: () {
                  controller.sheetState.value = 'join';
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: isPrimary ? primaryColor.withOpacity(0.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? primaryColor.withOpacity(0.4) : Colors.grey.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              size: 32,
              color: isPrimary ? primaryColor : Colors.grey,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildJoinState(BuildContext context, JamBottomSheetController controller) {
    return Column(
      key: const ValueKey('join_state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () {
                controller.sheetState.value = 'menu';
              },
            ),
            const SizedBox(width: 8),
            Text(
              "Join a Jam 🎧",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Text(
                "Enter 4-Digit Jam Code",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: controller.codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 18),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "0000",
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onSubmitted: (val) {
                    // Enter key triggers connect
                    controller.joinSession(val);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withAlpha(180),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton.icon(
            onPressed: () => controller.joinSession(controller.codeController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.link_rounded, color: Colors.white),
            label: const Text(
              "Connect",
              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActiveState(BuildContext context, JamBottomSheetController controller) {
    final session = controller.jamService.activeSession.value;
    if (session == null) return const SizedBox.shrink();

    final isHost = controller.jamService.isHost.value;
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      key: const ValueKey('active_state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isHost ? "You're Hosting Jam" : "Syncing to Jam",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: controller.shareJam,
              tooltip: "Share Link",
            )
          ],
        ),
        const SizedBox(height: 20),
        
        // Huge spaced numeric Jam Code Container
        Center(
          child: Column(
            children: [
              Text(
                "Jam Code",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.25), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: session.code.split('').map((char) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        char,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.greenAccent),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Currently synced song (if any)
        if (session.currentSong != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: session.currentSong!.thumbnail,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.currentSong!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.currentSong!.artist,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  session.currentSong!.isPlaying ? Icons.play_arrow : Icons.pause,
                  color: primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Participants List
        Text(
          "Participants (${controller.jamService.participants.length})",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: controller.jamService.participants.length,
            itemBuilder: (context, index) {
              final participant = controller.jamService.participants[index];
              final isMe = participant.deviceId == controller.jamService.myDeviceId;
              final isHostParticipant = participant.deviceId == session.hostId;
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isHostParticipant ? Colors.amber.shade700 : primaryColor.withOpacity(0.2),
                  child: Text(
                    participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                    style: TextStyle(color: isHostParticipant ? Colors.black : primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  participant.name + (isMe ? " (You)" : ""),
                  style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                ),
                trailing: isHostParticipant
                    ? const Tooltip(
                        message: "Host",
                        child: Icon(Icons.star, color: Colors.amber),
                      )
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        
        // End or Leave button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: controller.leaveOrEndSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: isHost ? Colors.redAccent.withOpacity(0.1) : Theme.of(context).cardColor,
              foregroundColor: isHost ? Colors.redAccent : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: isHost ? const BorderSide(color: Colors.redAccent, width: 1.5) : BorderSide(color: Colors.grey.withOpacity(0.2)),
              elevation: 0,
            ),
            child: Text(
              isHost ? "End Jam Session" : "Leave Jam",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
