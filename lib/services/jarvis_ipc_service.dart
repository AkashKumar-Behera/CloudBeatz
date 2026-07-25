import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/services/music_service.dart';
import 'package:harmonymusic/ui/player/player_controller.dart';

class JarvisIpcService {
  static HttpServer? _server;

  static Future<void> start({int port = 8082}) async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      print("[JARVIS-IPC] Listening on localhost:$port");

      _server!.listen((HttpRequest request) async {
        final response = request.response;
        // CORS Headers
        response.headers.add("Access-Control-Allow-Origin", "*");
        response.headers.add("Access-Control-Allow-Methods", "GET, OPTIONS");
        response.headers.add("Access-Control-Allow-Headers", "*");

        if (request.method == 'OPTIONS') {
          response.statusCode = HttpStatus.ok;
          await response.close();
          return;
        }

        final path = request.uri.path;
        final params = request.uri.queryParameters;

        try {
          if (path == '/play') {
            final audioHandler = Get.find<AudioHandler>();
            await audioHandler.play();
            response.write(jsonEncode({"result": "success", "message": "playback resumed"}));
          } 
          else if (path == '/pause') {
            final audioHandler = Get.find<AudioHandler>();
            await audioHandler.pause();
            response.write(jsonEncode({"result": "success", "message": "playback paused"}));
          } 
          else if (path == '/next') {
            final audioHandler = Get.find<AudioHandler>();
            await audioHandler.skipToNext();
            response.write(jsonEncode({"result": "success", "message": "skipped to next"}));
          } 
          else if (path == '/prev') {
            final audioHandler = Get.find<AudioHandler>();
            await audioHandler.skipToPrevious();
            response.write(jsonEncode({"result": "success", "message": "skipped to previous"}));
          } 
          else if (path == '/volume') {
            final levelStr = params['level'];
            if (levelStr != null) {
              final level = double.tryParse(levelStr);
              if (level != null && level >= 0.0 && level <= 1.0) {
                final playerController = Get.find<PlayerController>();
                await playerController.setVolume((level * 100).toInt());
              }
            }
            response.write(jsonEncode({"result": "success"}));
          } 
          else if (path == '/search_play') {
            final query = params['query'];
            if (query != null && query.isNotEmpty) {
              final musicServices = Get.find<MusicServices>();
              final results = await musicServices.search(query, filter: 'songs');
              if (results.containsKey('Songs') && results['Songs'].isNotEmpty) {
                final song = results['Songs'][0] as MediaItem;
                final playerController = Get.find<PlayerController>();
                await playerController.pushSongToQueue(song);
                response.write(jsonEncode({
                  "result": "success", 
                  "message": "playing song: ${song.title} by ${song.artist}",
                  "title": song.title,
                  "artist": song.artist
                }));
              } else {
                response.statusCode = HttpStatus.notFound;
                response.write(jsonEncode({"result": "error", "message": "song not found"}));
              }
            } else {
              response.statusCode = HttpStatus.badRequest;
              response.write(jsonEncode({"result": "error", "message": "query param required"}));
            }
          } 
          else if (path == '/status') {
            final playerController = Get.find<PlayerController>();
            final currentSong = playerController.currentSong.value;
            final isPlaying = playerController.buttonState.value == PlayButtonState.playing;
            
            response.write(jsonEncode({
              "result": "success",
              "title": currentSong?.title ?? "None",
              "artist": currentSong?.artist ?? "None",
              "status": isPlaying ? "playing" : "paused",
              "volume": playerController.volume.value / 100.0
            }));
          } 
          else {
            response.statusCode = HttpStatus.notFound;
            response.write(jsonEncode({"result": "error", "message": "not found"}));
          }
        } catch (e) {
          response.statusCode = HttpStatus.internalServerError;
          response.write(jsonEncode({"result": "error", "message": e.toString()}));
        } finally {
          await response.close();
        }
      });
    } catch (e) {
      print("[JARVIS-IPC] Error starting server: $e");
    }
  }

  static void stop() {
    _server?.close();
    _server = null;
  }
}
