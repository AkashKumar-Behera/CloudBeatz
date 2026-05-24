import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_widget.dart';
import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'backgroud_image.dart';
import 'lyrics_widget.dart';
import 'lyrics_switch.dart';
import 'player_control.dart';

/// Standard player widget — Spotify-style vertical PageView layout
///
/// Page 0: Album art + player controls
/// Page 1: Full-screen scrollable lyrics (swipe up from Page 0)
class StandardPlayer extends StatefulWidget {
  const StandardPlayer({super.key});

  @override
  State<StandardPlayer> createState() => _StandardPlayerState();
}

class _StandardPlayerState extends State<StandardPlayer> {
  late final PageController _pageController;
  // 0 = player page, 1 = lyrics page
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = (_pageController.page ?? 0).round();
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLyrics() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToPlayer() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final PlayerController playerController = Get.find<PlayerController>();
    final topPad = Get.mediaQuery.padding.top;
    final bottomPad = Get.mediaQuery.padding.bottom;

    double playerArtImageSize = size.width - 60;
    final spaceAvailableForArtImage =
        size.height - (70 + bottomPad + 330);
    playerArtImageSize = playerArtImageSize > spaceAvailableForArtImage
        ? spaceAvailableForArtImage
        : playerArtImageSize;

    return Stack(
      children: [
        // ── Blurred ambient background ────────────────────────────────────
        BackgroudImage(
          key: Key("${playerController.currentSong.value?.id}_background"),
          cacheHeight: 200,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.80),
                ),
              ),
              // Bottom gradient fade
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 65 + bottomPad + 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.4),
                        Theme.of(context).primaryColor.withOpacity(0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, 0.5, 0.8, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── PageView — vertical swipe between player & lyrics ─────────────
        if (!context.isLandscape)
          PageView(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            children: [
              // ── PAGE 0: Album Art + Controls ───────────────────────────
              _PlayerPage(
                playerController: playerController,
                playerArtImageSize: playerArtImageSize,
                bottomPad: bottomPad,
                topPad: topPad,
                size: size,
                onSwipeUpHintTap: _goToLyrics,
              ),
              // ── PAGE 1: Full-screen Lyrics ─────────────────────────────
              _LyricsPage(
                playerController: playerController,
                bottomPad: bottomPad,
                topPad: topPad,
                onSwipeDownTap: _goToPlayer,
              ),
            ],
          ),

        // ── Landscape: original row layout ───────────────────────────────
        if (context.isLandscape)
          Padding(
            padding: const EdgeInsets.only(left: 25, right: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: size.width * .45,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 90.0, top: 40),
                    child: Center(
                      child: _AlbumArtWidget(
                        playerController: playerController,
                        playerArtImageSize: size.width * .29,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: size.width * .48,
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: 10.0, right: 10, bottom: bottomPad),
                    child: const PlayerControlWidget(),
                  ),
                ),
              ],
            ),
          ),

        // ── Fixed header: minimize + more dots ───────────────────────────
        if (!(context.isLandscape && GetPlatform.isMobile))
          _PlayerHeader(
            playerController: playerController,
            topPad: topPad,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 0 — Album Art + Controls
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerPage extends StatelessWidget {
  final PlayerController playerController;
  final double playerArtImageSize;
  final double bottomPad;
  final double topPad;
  final Size size;
  final VoidCallback onSwipeUpHintTap;

  const _PlayerPage({
    required this.playerController,
    required this.playerArtImageSize,
    required this.bottomPad,
    required this.topPad,
    required this.size,
    required this.onSwipeUpHintTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top padding (below header)
        SizedBox(height: topPad + (size.height < 750 ? 90 : 110)),

        // Album art (no lyrics overlay here — lyrics are now page 2)
        _AlbumArtWidget(
          playerController: playerController,
          playerArtImageSize: playerArtImageSize,
        ),

        const Spacer(),

        // Player controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const PlayerControlWidget(),
          ),
        ),

        // ── Swipe-up hint → lyrics ────────────────────────────────────
        GestureDetector(
          onTap: onSwipeUpHintTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              top: 18,
              bottom: 28 + bottomPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 18,
                  color: Colors.white.withOpacity(0.45),
                ),
                const SizedBox(height: 4),
                Text(
                  'lyrics'.tr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 1 — Full-screen Lyrics
// ─────────────────────────────────────────────────────────────────────────────
class _LyricsPage extends StatelessWidget {
  final PlayerController playerController;
  final double bottomPad;
  final double topPad;
  final VoidCallback onSwipeDownTap;

  const _LyricsPage({
    required this.playerController,
    required this.bottomPad,
    required this.topPad,
    required this.onSwipeDownTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Lyrics page header ─────────────────────────────────────────────
        SizedBox(height: topPad + 64),

        // Swipe-down hint pill
        Center(
          child: GestureDetector(
            onTap: onSwipeDownTap,
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // Song name + lyrics toggle row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Song title + artist
              Expanded(
                child: Obx(() {
                  final song = playerController.currentSong.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium!
                            .copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song?.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(width: 12),
              // Synced / Plain toggle
              const LyricsSwitch(alwaysVisible: true),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── LyricsWidget — takes all remaining space ───────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 24, right: 24, bottom: bottomPad + 24),
            child: LyricsWidget(
              padding: const EdgeInsets.symmetric(vertical: 60),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Album art widget (no lyrics overlay — separate from albumart_lyrics.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _AlbumArtWidget extends StatelessWidget {
  final PlayerController playerController;
  final double playerArtImageSize;

  const _AlbumArtWidget({
    required this.playerController,
    required this.playerArtImageSize,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => playerController.currentSong.value != null
          ? GestureDetector(
              onLongPress: () {
                showModalBottomSheet(
                  constraints: const BoxConstraints(maxWidth: 500),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10.0)),
                  ),
                  isScrollControlled: true,
                  context:
                      playerController.homeScaffoldkey.currentState!.context,
                  barrierColor: Colors.transparent.withAlpha(100),
                  builder: (context) => SongInfoBottomSheet(
                    playerController.currentSong.value!,
                    calledFromPlayer: true,
                  ),
                ).whenComplete(() => Get.delete<SongInfoController>());
              },
              onHorizontalDragEnd: (DragEndDetails details) {
                if (details.primaryVelocity! < 0) {
                  playerController.next();
                } else if (details.primaryVelocity! > 0) {
                  playerController.prev();
                }
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: ImageWidget(
                    size: playerArtImageSize,
                    song: playerController.currentSong.value!,
                    isPlayerArtImage: true,
                  ),
                ),
              ),
            )
          : SizedBox(height: playerArtImageSize),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed header — minimize + more-dots (overlays both pages)
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerHeader extends StatelessWidget {
  final PlayerController playerController;
  final double topPad;

  const _PlayerHeader({
    required this.playerController,
    required this.topPad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPad + 20, left: 10, right: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minimize
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            onPressed: playerController.playerPanelController.close,
          ),
          const Spacer(),
          // More options
          IconButton(
            icon: const Icon(Icons.more_vert, size: 25),
            onPressed: () {
              showModalBottomSheet(
                constraints: const BoxConstraints(maxWidth: 500),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10.0)),
                ),
                isScrollControlled: true,
                context:
                    playerController.homeScaffoldkey.currentState!.context,
                barrierColor: Colors.transparent.withAlpha(100),
                builder: (context) => SongInfoBottomSheet(
                  playerController.currentSong.value!,
                  calledFromPlayer: true,
                ),
              ).whenComplete(() => Get.delete<SongInfoController>());
            },
          ),
        ],
      ),
    );
  }
}
