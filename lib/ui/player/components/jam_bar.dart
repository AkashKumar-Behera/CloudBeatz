import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import '../../../services/jam_service.dart';

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent,
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            ),
          ),
        );
      },
    );
  }
}

class JamBar extends StatelessWidget {
  const JamBar({super.key});

  @override
  Widget build(BuildContext context) {
    final jamService = Get.find<JamService>();
    final primaryColor = Theme.of(context).primaryColor;
    
    return Obx(() {
      final session = jamService.activeSession.value;
      if (session == null) return const SizedBox.shrink();

      return Container(
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Status and Code
            const PulsingDot(),
            const SizedBox(width: 10),
            Text(
              "Jam ${session.code}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${jamService.participants.length} listeners",
                style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            
            // Emoji Buttons
            _buildEmojiButton("🔥", jamService),
            _buildEmojiButton("❤️", jamService),
            _buildEmojiButton("😮", jamService),
            
            const SizedBox(width: 4),
            VerticalDivider(color: Colors.white.withOpacity(0.15), indent: 14, endIndent: 14),
            const SizedBox(width: 4),
            
            // Share button
            IconButton(
              icon: Icon(Icons.share_outlined, size: 20, color: Colors.white.withOpacity(0.8)),
              onPressed: () {
                final link = jamService.getShareLink();
                Clipboard.setData(ClipboardData(text: link));
                Get.snackbar("Copied to Clipboard", "Jam deep link copied! Share with friends.");
                Share.share(
                  "Join my collaborative music Jam session on CloudBeatz! 🎧\n\nCode: ${session.code}\nLink: $link",
                  subject: "Join my CloudBeatz Jam!",
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Share Link",
            ),
          ],
        ),
      );
    });
  }

  Widget _buildEmojiButton(String emoji, JamService jamService) {
    return GestureDetector(
      onTap: () => jamService.sendReaction(emoji),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
