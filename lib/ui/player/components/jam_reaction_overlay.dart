import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/jam_service.dart';

class JamReactionOverlay extends StatefulWidget {
  const JamReactionOverlay({super.key});

  @override
  State<JamReactionOverlay> createState() => _JamReactionOverlayState();
}

class _JamReactionOverlayState extends State<JamReactionOverlay> {
  final _jamService = Get.find<JamService>();
  final List<_ReactionItem> _reactions = [];
  final _random = Random();
  Worker? _reactionWorker;

  @override
  void initState() {
    super.initState();
    _reactionWorker = ever(_jamService.incomingReaction, (reaction) {
      if (reaction != null) {
        final emoji = reaction['emoji'] as String? ?? '🔥';
        final from = reaction['from'] as String? ?? '';
        _spawnReaction(emoji, from);
      }
    });
  }

  void _spawnReaction(String emoji, String from) {
    if (!mounted) return;
    
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final item = _ReactionItem(
      id: id,
      emoji: emoji,
      from: from,
      startX: 0.25 + _random.nextDouble() * 0.5, // 25% to 75% screen width
      wobbleSpeed: 2 + _random.nextDouble() * 3,
      wobbleAmount: 12 + _random.nextDouble() * 18,
    );
    
    setState(() {
      _reactions.add(item);
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _reactions.removeWhere((r) => r.id == id);
        });
      }
    });
  }

  @override
  void dispose() {
    _reactionWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _reactions.map((item) {
          return _ReactionAnimation(
            key: ValueKey(item.id),
            item: item,
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionItem {
  final String id;
  final String emoji;
  final String from;
  final double startX;
  final double wobbleSpeed;
  final double wobbleAmount;

  _ReactionItem({
    required this.id,
    required this.emoji,
    required this.from,
    required this.startX,
    required this.wobbleSpeed,
    required this.wobbleAmount,
  });
}

class _ReactionAnimation extends StatefulWidget {
  final _ReactionItem item;
  const _ReactionAnimation({required this.item, super.key});

  @override
  State<_ReactionAnimation> createState() => _ReactionAnimationState();
}

class _ReactionAnimationState extends State<_ReactionAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _translateY = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _wobble = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = Theme.of(context).primaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double yPos = size.height * 0.7 - (_translateY.value * size.height * 0.45);
        final double wobbleOffset = sin(_wobble.value * widget.item.wobbleSpeed * pi) * widget.item.wobbleAmount;
        final double xPos = (widget.item.startX * size.width) + wobbleOffset;

        return Positioned(
          left: xPos,
          top: yPos,
          child: Opacity(
            opacity: _opacity.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item.emoji,
                  style: const TextStyle(fontSize: 36),
                ),
                if (widget.item.from.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withOpacity(0.3), width: 0.5),
                    ),
                    child: Text(
                      widget.item.from,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
