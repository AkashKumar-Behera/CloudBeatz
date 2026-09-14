import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/widgets/update_dialog.dart';
import '../utils/helper.dart';

class GithubAsset {
  final String name;
  final String downloadUrl;
  final int size;

  GithubAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      name: json['name'] ?? '',
      downloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
    );
  }
}

class GithubReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final String publishedAt;
  final List<GithubAsset> assets;

  GithubReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory GithubReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assetList = (json['assets'] as List? ?? [])
        .map((a) => GithubAsset.fromJson(a as Map<String, dynamic>))
        .toList();
    return GithubReleaseInfo(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      htmlUrl: json['html_url'] ?? 'https://cloudbeatz.web.app/',
      publishedAt: json['published_at'] ?? '',
      assets: assetList,
    );
  }

  String getPlatformDownloadUrl() {
    if (Platform.isWindows) {
      final exe = assets.firstWhereOrNull(
        (a) => a.name.toLowerCase().endsWith('.exe'),
      );
      if (exe != null) return exe.downloadUrl;
    } else if (Platform.isAndroid) {
      final arm64 = assets.firstWhereOrNull(
        (a) => a.name.contains('arm64-v8a') && a.name.endsWith('.apk'),
      );
      if (arm64 != null) return arm64.downloadUrl;
      final universal = assets.firstWhereOrNull(
        (a) => a.name.endsWith('.apk'),
      );
      if (universal != null) return universal.downloadUrl;
    } else if (Platform.isIOS) {
      final ipa = assets.firstWhereOrNull(
        (a) => a.name.toLowerCase().endsWith('.ipa'),
      );
      if (ipa != null) return ipa.downloadUrl;
    }
    return htmlUrl;
  }
}

class UpdateService {
  static const String repoApiUrl =
      "https://api.github.com/repos/AkashKumar-Behera/CloudBeatz/releases/latest";

  /// Compares two version strings (e.g. "v2.0.0" and "1.15.1"). Returns true if [remote] > [current].
  static bool isVersionNewer(String remote, String current) {
    try {
      final cleanRemote = remote.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');

      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (cParts.length < 3) {
        cParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Automatically called a few seconds after app launch.
  static Future<void> checkOnStartup() async {
    // Small delay to ensure UI has settled and app started smoothly
    await Future.delayed(const Duration(seconds: 4));
    await checkForUpdate(silentCheck: true);
  }

  /// Check for updates from GitHub Releases
  static Future<void> checkForUpdate({
    bool silentCheck = false,
    bool showToastIfLatest = false,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        repoApiUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
          headers: {"Accept": "application/vnd.github.v3+json"},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final release = GithubReleaseInfo.fromJson(response.data);
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVer = packageInfo.version;

        if (isVersionNewer(release.tagName, currentVer)) {
          final prefs = Hive.box("AppPrefs");
          final dismissedTag = prefs.get("dismissed_update_tag");

          // If silently checking on startup, don't re-prompt if user already dismissed this specific tag
          if (silentCheck && dismissedTag == release.tagName) {
            return;
          }

          final downloadUrl = release.getPlatformDownloadUrl();
          if (Get.context != null) {
            Get.dialog(
              UpdateDialog(
                releaseInfo: release,
                currentVersion: currentVer,
                downloadUrl: downloadUrl,
                onDismiss: () {
                  prefs.put("dismissed_update_tag", release.tagName);
                  Get.back();
                },
              ),
              barrierDismissible: true,
            );
          }
        } else if (showToastIfLatest) {
          Get.snackbar(
            "CloudBeatz is Up to Date",
            "You are using the latest version ($currentVer)",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF1E1735).withOpacity(0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.check_circle, color: Color(0xFF8263FF)),
          );
        }
      }
    } catch (e) {
      if (showToastIfLatest) {
        Get.snackbar(
          "Update Check Failed",
          "Could not check for updates. Please check your internet connection.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1E1735).withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          icon: const Icon(Icons.error_outline, color: Colors.orangeAccent),
        );
      }
      printERROR("Update check error: $e");
    }
  }

  /// Launch download URL in device browser
  static Future<void> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
