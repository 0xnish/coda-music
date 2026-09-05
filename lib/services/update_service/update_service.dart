import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:Coda/services/settings_manager.dart';
import 'package:Coda/services/update_service/models/update_info.dart';
import 'package:Coda/services/update_service/widgets/update_checking.dart';
import 'package:Coda/services/update_service/widgets/update_dialog.dart';
import 'package:Coda/services/update_service/widgets/update_download_dialog.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:Coda/services/bottom_message.dart';

class UpdateService {
  static const String owner = '0xnish';
  static const String repo = 'coda-music';

  static final ValueNotifier<Widget?> modalHost = ValueNotifier<Widget?>(null);

  static void showUpdateModal(Widget Function() builder) {
    modalHost.value = builder();
  }

  static void closeUpdateModal() {
    modalHost.value = null;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(package.version.split('+').first);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final Uri uri = Uri.parse(
        'https://raw.githubusercontent.com/0xnish/coda-music/main/desktop_update.json?t=$timestamp',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String remoteVersionString = data['version']?.toString() ?? '1.0.0';
      
      Version remoteVersion;
      try {
        remoteVersion = Version.parse(remoteVersionString);
      } catch (e) {
        final parts = remoteVersionString.split('.');
        if (parts.length == 2) {
          remoteVersion = Version.parse('$remoteVersionString.0');
        } else if (parts.length == 1) {
           remoteVersion = Version.parse('$remoteVersionString.0.0');
        } else {
           return null;
        }
      }

      if (remoteVersion > currentVersion) {
        final downloadUrl = await _resolveInstallerUrl();
        return UpdateInfo(
          version: remoteVersion,
          name: 'New Update Available',
          body: 'A new version of Coda Music is available.',
          publishedAt: '',
          downloadUrl: downloadUrl,
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String> _resolveInstallerUrl() async {
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              'https://api.github.com/repos/$owner/$repo/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return defaultDownloadUrl;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('setup.exe')) {
          final url = asset['browser_download_url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
      return defaultDownloadUrl;
    } catch (_) {
      return defaultDownloadUrl;
    } finally {
      client.close();
    }
  }

  static String get defaultDownloadUrl =>
      'https://github.com/$owner/$repo/releases/latest';

  static Future<File?> downloadInstaller({
    required String url,
    required void Function(int received, int? total) onProgress,
    bool Function()? stopRequested,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamed = await client.send(request);
      if (streamed.statusCode != 200) return null;
      final total = streamed.contentLength;
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}coda-music-update-setup.exe',
      );
      final sink = file.openSync(mode: FileMode.write);
      var received = 0;
      await for (final chunk in streamed.stream) {
        if (stopRequested?.call() ?? false) {
          sink.closeSync();
          return null;
        }
        sink.writeFromSync(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      sink.closeSync();
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<void> installAndExit(File installer) async {
    try {
      await Process.start(installer.path, const []);
    } catch (_) {}
    exit(0);
  }

  static Future<void> autoCheck(BuildContext context) async {
    final update = await checkForUpdate();
    if (update == null || !context.mounted) return;

    await showUpdateDialog(context, update);
  }

  static void downloadUpdate() {
    showUpdateModal(
      () => UpdateDownloadDialog(onClosed: closeUpdateModal),
    );
  }

  static Future<void> checkFromSettings(BuildContext context) async {
    showUpdateModal(() => const UpdateCheckingDialog());

    final update = await checkForUpdate();

    if (!context.mounted) return;

    if (update == null) {
      closeUpdateModal();
      GetIt.I<SettingsManager>().hasUpdate = false;
      BottomMessage.showText(context, 'You are already on the latest version');
      return;
    }

    GetIt.I<SettingsManager>().hasUpdate = true;

    showUpdateModal(
      () => AlertDialog(
        backgroundColor: const Color(0xFFF7F9FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update,
                      color: Color(0xFF4A6CF7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update available',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version ${update.version}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3A3A5C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'A new version of Coda Music is ready to download.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3A3A5C),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        actions: [
          TextButton(
            onPressed: closeUpdateModal,
            child: const Text(
              'Not now',
              style: TextStyle(
                color: Color(0xFF3A3A5C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              closeUpdateModal();
              downloadUpdate();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  static Future<void> manualCheck(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => const UpdateCheckingDialog(),
    );

    final update = await checkForUpdate();

    if (!context.mounted) return;
    Navigator.pop(context);

    if (update != null) {
      await showUpdateDialog(context, update);
    } else {
      BottomMessage.showText(context, 'You are already on the latest version');
    }
  }

  static Future<void> showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
  ) {
    return showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => UpdateDialog(info),
    );
  }
}
