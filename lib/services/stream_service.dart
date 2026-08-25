import 'dart:io';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  static Future<StreamProvider> fetch(String videoId,
      {String title = "", String artist = ""}) async {
    print("STREAM_FETCH: Starting stream fetch for $videoId (Title: $title)");

    // 1. YouTubeExplode Direct Manifest Fetch (Instant / Zero Delay)
    final yt = YoutubeExplode();
    try {
      final res = await yt.videos.streamsClient.getManifest(videoId);
      final audio = res.audioOnly;
      if (audio.isNotEmpty) {
        print("STREAM_FETCH: Instant success with YouTubeExplode");
        return StreamProvider(
            playable: true,
            statusMSG: "OK",
            audioFormats: audio
                .map((e) => Audio(
                    itag: e.tag,
                    audioCodec:
                        e.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
                    bitrate: e.bitrate.bitsPerSecond,
                    duration: 0,
                    loudnessDb: 0.0,
                    url: e.url.toString(),
                    size: e.size.totalBytes))
                .toList());
      }
    } catch (e) {
      print("STREAM_FETCH YouTubeExplode error, trying fallbacks: $e");
    } finally {
      yt.close();
    }

    // 2. Fallback: If we have song title/artist, search JioSaavn
    if (title.isNotEmpty) {
      final saavnMirrors = [
        "https://saavn.me/api/search/songs",
        "https://jiosaavn-api-private.vercel.app/api/search/songs",
        "https://saavn.dev/api/search/songs",
      ];

      for (final mirror in saavnMirrors) {
        try {
          final dio = Dio();
          final searchQuery = "$title $artist".trim();
          final saavnRes = await dio.get(
            mirror,
            queryParameters: {"query": searchQuery, "limit": 5},
            options: Options(
              receiveTimeout: const Duration(seconds: 2),
              sendTimeout: const Duration(seconds: 2),
            ),
          );
          if (saavnRes.statusCode == 200 && saavnRes.data != null) {
            final dataMap = saavnRes.data is Map ? saavnRes.data : {};
            final songs = (dataMap["data"]?["results"] as List? ??
                dataMap["results"] as List? ??
                []);
            if (songs.isNotEmpty) {
              final downloadUrls = songs.first["downloadUrl"] as List? ??
                  songs.first["media_url"] as List? ??
                  [];
              if (downloadUrls.isNotEmpty) {
                dynamic targetUrl;
                if (downloadUrls.first is Map) {
                  targetUrl = (downloadUrls.lastWhere(
                        (u) =>
                            u["quality"] == "320kbps" ||
                            u["quality"] == "160kbps",
                        orElse: () => downloadUrls.last,
                      ))["url"]
                      ?.toString();
                } else {
                  targetUrl = downloadUrls.last.toString();
                }

                if (targetUrl != null && targetUrl.isNotEmpty) {
                  print("STREAM_FETCH: Resolved via JioSaavn fallback ($mirror)");
                  return StreamProvider(
                    playable: true,
                    statusMSG: "OK",
                    audioFormats: [
                      Audio(
                        itag: 140,
                        audioCodec: Codec.mp4a,
                        bitrate: 320000,
                        duration: 0,
                        loudnessDb: 0.0,
                        url: targetUrl,
                        size: 0,
                      )
                    ],
                  );
                }
              }
            }
          }
        } catch (e) {
          continue;
        }
      }
    }

    // 3. Fallback: Direct Cobalt audio stream resolution
    final directResolvers = [
      "https://co.wuk.sh",
      "https://api.cobalt.tools",
    ];

    for (final host in directResolvers) {
      try {
        final dio = Dio();
        final response = await dio.post(
          "$host/",
          data: {
            "url": "https://www.youtube.com/watch?v=$videoId",
            "downloadMode": "audio",
            "audioFormat": "mp3",
          },
          options: Options(
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/json",
            },
            receiveTimeout: const Duration(seconds: 3),
            sendTimeout: const Duration(seconds: 3),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final streamUrl = response.data["url"]?.toString();
          if (streamUrl != null && streamUrl.isNotEmpty) {
            print("STREAM_FETCH: Success via Cobalt fallback $host");
            return StreamProvider(
              playable: true,
              statusMSG: "OK",
              audioFormats: [
                Audio(
                  itag: 140,
                  audioCodec: Codec.mp4a,
                  bitrate: 320000,
                  duration: 0,
                  loudnessDb: 0.0,
                  url: streamUrl,
                  size: 0,
                )
              ],
            );
          }
        }
      } catch (_) {
        continue;
      }
    }

    return StreamProvider(
      playable: false,
      statusMSG: "Song is unplayable",
    );
  }

  Audio? get highestQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 140,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 249 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
