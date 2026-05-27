import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../screens/Settings/settings_screen_controller.dart';
import '../utils/theme_controller.dart';
import '../player/player_controller.dart';
import '/models/artist.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';

class ImageWidget extends StatelessWidget {
  const ImageWidget({
    super.key,
    this.song,
    this.playlist,
    this.album,
    this.artist,
    required this.size,
    this.isPlayerArtImage = false,
  });
  final MediaItem? song;
  final Playlist? playlist;
  final Album? album;
  final bool isPlayerArtImage;
  final Artist? artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    String imageUrl = song != null
        ? song!.artUri.toString()
        : playlist != null
            ? playlist!.thumbnailUrl
            : album != null
                ? album!.thumbnailUrl
                : artist != null
                    ? artist!.thumbnailUrl
                    : "";
    // String cacheKey = song != null
    //     ? "${song!.id}_song"
    //     : playlist != null
    //         ? "${playlist!.playlistId}_playlist"
    //         : album != null
    //             ? "${album!.browseId}_album"
    //             : artist != null
    //                 ? "${artist!.browseId}_artist"
    //                 : "";

    /// only valid for offline songs
    final bool offlineAvailable =
        song != null && (song?.extras?["url"] ?? "").contains("file");

    Widget buildErrorWidget(BuildContext context) {
      return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: artist != null ? null : BorderRadius.circular(10),
          ),
          child: Image.asset(
              "assets/icons/${song != null ? "song" : artist != null ? "artist" : "album"}.png"));
    }

    Widget buildShimmer(BuildContext context) {
      return Shimmer.fromColors(
          baseColor: Colors.grey[500]!,
          highlightColor: Colors.grey[300]!,
          enabled: true,
          direction: ShimmerDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: artist != null ? null : BorderRadius.circular(10),
              color: Colors.white54,
            ),
          ));
    }

    Widget buildNetworkImage(BuildContext context, String url) {
      if (url.isEmpty) return buildErrorWidget(context);
      return CachedNetworkImage(
        height: size,
        width: size,
        memCacheHeight: (song != null && !isPlayerArtImage) ? 140 : null,
        imageUrl: url,
        fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) {
          if (isPlayerArtImage && song != null) {
            final sc = Get.find<SettingsScreenController>();
            if (sc.themeModetype.value == ThemeType.dynamic) {
              Future.delayed(
                const Duration(milliseconds: 60),
                () => Get.find<PlayerController>().extractAlbumColor(imageProvider, song!.id),
              );
            }
          }
          return Image(image: imageProvider, fit: BoxFit.cover);
        },
        errorWidget: (context, url, error) => buildErrorWidget(context),
        progressIndicatorBuilder: ((_, __, ___) => buildShimmer(context)),
      );
    }

    Widget buildFileImage(BuildContext context) {
      final file = File(
          "${Get.find<SettingsScreenController>().supportDirPath}/thumbnails/${song!.id}.png");
      return Image.file(
        file,
        height: size,
        width: size,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (isPlayerArtImage && frame != null) {
            final sc = Get.find<SettingsScreenController>();
            if (sc.themeModetype.value == ThemeType.dynamic) {
              final provider = FileImage(file);
              Future.delayed(
                const Duration(milliseconds: 60),
                () => Get.find<PlayerController>().extractAlbumColor(provider, song!.id),
              );
            }
          }
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          final artUrl = song?.artUri?.toString() ?? '';
          if (artUrl.isNotEmpty && !artUrl.startsWith('file')) {
            return buildNetworkImage(context, artUrl);
          }
          return buildErrorWidget(context);
        },
      );
    }

    return Container(
      height: size,
      width: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: artist != null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: artist != null ? null : BorderRadius.circular(5),
      ),
      child: offlineAvailable
          ? buildFileImage(context)
          : buildNetworkImage(context, imageUrl),
    );
  }
}
