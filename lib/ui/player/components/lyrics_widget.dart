import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:get/get.dart';

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
        () => TextSelectionTheme(
          data: Theme.of(context).textSelectionTheme,
          child: SelectableText(
            playerController.lyrics["plainLyrics"] == "NA"
                ? "lyricsNotAvailable".tr
                : playerController.lyrics["plainLyrics"],
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
    return LyricsModelBuilder.create()
        .bindLyricToMain(rawLyrics)
        .getModel()
        .lyrics;
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
            children: List.generate(lines.length, (index) {
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

              return GestureDetector(
                key: key,
                onTap: () {
                  if (line.startTime != null) {
                    widget.playerController.seek(Duration(milliseconds: line.startTime!));
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  opacity: opacity,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: Colors.white,
                      height: isCurrent ? 1.3 : 1.5,
                      letterSpacing: isCurrent ? -0.3 : 0.0,
                    ),
                    child: Container(
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
                ),
              );
            }),
          ),
        );
      });
    });
  }
}
