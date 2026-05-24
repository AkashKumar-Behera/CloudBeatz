import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';

import '../../widgets/loader.dart';
import '../player_controller.dart';

class LyricsWidget extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  const LyricsWidget({super.key, required this.padding});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    return Obx(
      () => playerController.isLyricsLoading.isTrue
          ? const Center(
              child: LoadingIndicator(),
            )
          : playerController.lyricsMode.toInt() == 1
              ? _PlainLyricsView(
                  playerController: playerController,
                  padding: padding,
                )
              : _SyncedLyricsView(playerController: playerController),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAIN LYRICS
// ─────────────────────────────────────────────────────────────────────────────
class _PlainLyricsView extends StatelessWidget {
  final PlayerController playerController;
  final EdgeInsetsGeometry padding;
  const _PlainLyricsView(
      {required this.playerController, required this.padding});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Obx(
        () {
          final isNA = playerController.lyrics["plainLyrics"] == "NA";
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextSelectionTheme(
                data: Theme.of(context).textSelectionTheme,
                child: SelectableText(
                  isNA ? "lyricsNotAvailable".tr : playerController.lyrics["plainLyrics"],
                  textAlign: TextAlign.left,
                  style: playerController.isDesktopLyricsDialogOpen
                      ? Theme.of(context).textTheme.titleMedium!
                      : Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            height: 1.7,
                          ),
                ),
              ),
              if (!isNA) ...[
                const SizedBox(height: 35),
                Center(
                  child: Text(
                    "Lyrics synchronized by Akash ✨",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.35),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ]
            ],
          );
        }
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYNCED LYRICS — Scrollable Apple Music / Spotify style view
// ─────────────────────────────────────────────────────────────────────────────
class _SyncedLyricsView extends StatefulWidget {
  final PlayerController playerController;

  const _SyncedLyricsView({required this.playerController});

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastIdx = -1;
  double _lastViewportHeight = 0.0;
  String _lastRawSynced = '';
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<LyricsLineModel> _parseLines(String rawLyrics) {
    if (rawLyrics.isEmpty) return [];
    final originalLines = LyricsModelBuilder.create()
        .bindLyricToMain(rawLyrics)
        .getModel()
        .lyrics;

    if (originalLines.isEmpty) return [];

    final List<LyricsLineModel> processedLines = [];

    // Check if there is an intro break before the first lyric line starts
    final firstStart = originalLines.first.startTime ?? 0;
    if (firstStart > 4000) {
      processedLines.add(LyricsLineModel()
        ..startTime = 0
        ..endTime = firstStart
        ..mainText = "• • •");
    }

    for (int i = 0; i < originalLines.length; i++) {
      processedLines.add(originalLines[i]);

      if (i < originalLines.length - 1) {
        final currentEnd =
            originalLines[i].endTime ?? originalLines[i].startTime ?? 0;
        final nextStart = originalLines[i + 1].startTime ?? 0;
        final gap = nextStart - currentEnd;

        if (gap > 4500) {
          processedLines.add(LyricsLineModel()
            ..startTime = currentEnd
            ..endTime = nextStart
            ..mainText = "• • •");
        }
      }
    }

    return processedLines;
  }

  int _getCurrentLineIndex(List<LyricsLineModel> lines, int posMs) {
    for (int i = 0; i < lines.length; i++) {
      final start = lines[i].startTime ?? 0;
      final end = lines[i].endTime ?? 0;
      if (posMs >= start && posMs < end) return i;
    }
    if (lines.isNotEmpty) {
      final last = lines.last;
      if (posMs >= (last.startTime ?? 0)) return lines.length - 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final viewportHeight = constraints.maxHeight;

      return Obx(() {
        final rawSynced = widget.playerController.lyrics['synced']?.toString() ?? '';
        final posMs = widget.playerController.progressBarStatus.value.current.inMilliseconds;

        if (rawSynced.isEmpty) {
          return Center(
            child: Text(
              "syncedLyricsNotAvailable".tr,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: Colors.white70),
            ),
          );
        }

        final lines = _parseLines(rawSynced);
        if (lines.isEmpty) {
          return Center(
            child: Text(
              "syncedLyricsNotAvailable".tr,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: Colors.white70),
            ),
          );
        }

        final currentIdx = _getCurrentLineIndex(lines, posMs);

        // Check if we need to scroll/center the active line
        final bool lyricsChanged = rawSynced != _lastRawSynced;
        final bool indexChanged = currentIdx != _lastIdx;
        final bool heightChanged = (viewportHeight - _lastViewportHeight).abs() > 1.0;

        if (lyricsChanged) {
          _itemKeys.clear();
        }

        if (lyricsChanged || indexChanged || heightChanged) {
          _lastIdx = currentIdx;
          _lastRawSynced = rawSynced;
          _lastViewportHeight = viewportHeight;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final context = _itemKeys[currentIdx]?.currentContext;
              if (context != null) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                );
              } else {
                // Fallback estimate scroll if context not resolved
                const double estimateLineHeight = 70.0;
                final double target = currentIdx * estimateLineHeight;
                _scrollController.animateTo(
                  target.clamp(0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                );
              }
            }
          });
        }

        const double estimateLineHeight = 70.0;

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            vertical: (viewportHeight / 2 - 35).clamp(0.0, viewportHeight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...List.generate(lines.length, (index) {
                final line = lines[index];
                final isCurrent = index == currentIdx;
                final difference = (index - currentIdx).abs();

                final double fontSize;
                final double opacity;
                final FontWeight fontWeight;

                if (isCurrent) {
                  fontSize = 28;
                  opacity = 1.0;
                  fontWeight = FontWeight.w800;
                } else if (difference == 1) {
                  fontSize = 20;
                  opacity = 0.50;
                  fontWeight = FontWeight.w600;
                } else {
                  fontSize = 18;
                  opacity = 0.28;
                  fontWeight = FontWeight.w500;
                }

                final text = line.mainText ?? '';
                if (text.isEmpty) return const SizedBox.shrink();

                final key = _itemKeys.putIfAbsent(index, () => GlobalKey());

                final bool isInstrumental = text == "• • •";

                Widget contentWidget;
                if (isInstrumental) {
                  contentWidget = Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: estimateLineHeight),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _PulsingDots(isActive: isCurrent),
                  );
                } else if (isCurrent) {
                  contentWidget = Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: estimateLineHeight),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _ActiveGlowText(
                      text: text,
                      startTime: line.startTime ?? 0,
                      endTime: line.endTime ?? 0,
                      playerController: widget.playerController,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
                  );
                } else {
                  contentWidget = AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    opacity: opacity,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        color: Colors.white,
                        height: 1.5,
                        letterSpacing: 0.0,
                      ),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: estimateLineHeight),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          text,
                          textAlign: TextAlign.left,
                          maxLines: null,
                        ),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  key: key,
                  onTap: () {
                    if (line.startTime != null) {
                      widget.playerController.seek(Duration(milliseconds: line.startTime!));
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: contentWidget,
                );
              }),
              const SizedBox(height: 35),
              Center(
                child: Text(
                  "Lyrics synchronized by Akash ✨",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.35),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      });
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULSING DOTS (Apple-style interlude indicator)
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingDots extends StatefulWidget {
  final bool isActive;
  const _PulsingDots({required this.isActive});

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_PulsingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.isActive ? 1.0 : 0.28;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double scale = 1.0;
              double dotOpacity = 0.3;

              if (widget.isActive) {
                final progress = _controller.value;
                final phase = (progress - (index * 0.22)) % 1.0;
                if (phase < 0.5) {
                  final sinVal = sin(phase * pi * 2);
                  scale = 1.0 + (sinVal * 0.28);
                  dotOpacity = 0.3 + (sinVal * 0.7);
                }
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(dotOpacity.clamp(0.0, 1.0)),
                ),
                transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                transformAlignment: Alignment.center,
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE GLOW TEXT (Apple-style left-to-right text sweep)
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveGlowText extends StatefulWidget {
  final String text;
  final int startTime;
  final int endTime;
  final PlayerController playerController;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double height;

  const _ActiveGlowText({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.playerController,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
    required this.height,
  });

  @override
  State<_ActiveGlowText> createState() => _ActiveGlowTextState();
}

class _ActiveGlowTextState extends State<_ActiveGlowText>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late StreamSubscription _positionSubscription;

  @override
  void initState() {
    super.initState();
    final durationMs = widget.endTime - widget.startTime;
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs > 0 ? durationMs : 1000),
    );

    _syncAnimation();

    _positionSubscription = AudioService.position.listen((_) {
      _syncAnimation();
    });
  }

  void _syncAnimation() {
    if (!mounted) return;
    final pc = widget.playerController;
    final isPlaying = pc.buttonState.value == PlayButtonState.playing;
    final currentMs = pc.progressBarStatus.value.current.inMilliseconds;

    final elapsed = currentMs - widget.startTime;
    final duration = widget.endTime - widget.startTime;

    if (duration <= 0) return;

    final double progress = (elapsed / duration).clamp(0.0, 1.0);

    _animController.value = progress;

    if (isPlaying && currentMs >= widget.startTime && currentMs < widget.endTime) {
      final remainingMs = widget.endTime - currentMs;
      _animController.animateTo(
        1.0,
        duration: Duration(milliseconds: remainingMs),
        curve: Curves.linear,
      );
    } else {
      _animController.stop();
    }
  }

  @override
  void didUpdateWidget(_ActiveGlowText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime || oldWidget.endTime != widget.endTime) {
      final durationMs = widget.endTime - widget.startTime;
      _animController.duration = Duration(milliseconds: durationMs > 0 ? durationMs : 1000);
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _positionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const SizedBox.shrink();

    final List<int> wordLengths = words.map((w) => w.length).toList();
    final int totalChars = wordLengths.fold(0, (sum, len) => sum + len);

    final List<double> wordStartFractions = [];
    final List<double> wordEndFractions = [];

    double currentFraction = 0.0;
    for (int i = 0; i < words.length; i++) {
      wordStartFractions.add(currentFraction);
      final double weight = totalChars > 0 ? (wordLengths[i] / totalChars) : (1.0 / words.length);
      currentFraction += weight;
      wordEndFractions.add(currentFraction.clamp(0.0, 1.0));
    }

    final TextStyle textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      letterSpacing: widget.letterSpacing,
      height: widget.height,
      color: Colors.white,
      shadows: [
        Shadow(
          blurRadius: 12.0,
          color: Colors.white.withOpacity(0.42),
          offset: Offset.zero,
        ),
        Shadow(
          blurRadius: 3.0,
          color: Colors.white.withOpacity(0.25),
          offset: Offset.zero,
        ),
      ],
    );

    final TextStyle dimmedStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      letterSpacing: widget.letterSpacing,
      height: widget.height,
      color: Colors.white.withOpacity(0.26),
      shadows: const [],
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final progress = _animController.value;

        return Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: widget.fontSize * 0.24,
          runSpacing: widget.fontSize * 0.12,
          children: List.generate(words.length, (index) {
            final startFrac = wordStartFractions[index];
            final endFrac = wordEndFractions[index];

            if (progress >= endFrac) {
              return Text(
                words[index],
                style: textStyle,
              );
            } else if (progress <= startFrac) {
              return Text(
                words[index],
                style: dimmedStyle,
              );
            } else {
              final double wordProgress = (progress - startFrac) / (endFrac - startFrac);
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0.26),
                    ],
                    stops: [
                      wordProgress,
                      (wordProgress + 0.15).clamp(0.0, 1.0),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds);
                },
                child: Text(
                  words[index],
                  style: textStyle,
                ),
              );
            }
          }),
        );
      },
    );
  }
}
