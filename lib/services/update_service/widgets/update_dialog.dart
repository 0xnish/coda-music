import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:Coda/services/update_service/models/update_info.dart';
import 'package:Coda/services/update_service/update_service.dart';

import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog(this.info, {super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  bool _cancelled = false;
  int _received = 0;
  int? _total;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _cancelled = false;
      _error = null;
      _received = 0;
      _total = null;
    });

    final installer = await UpdateService.downloadInstaller(
      url: widget.info.downloadUrl,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _received = received;
          _total = total;
        });
      },
      stopRequested: () => _cancelled,
    );

    if (!mounted) return;

    if (_cancelled) {
      setState(() => _downloading = false);
      return;
    }

    if (installer == null) {
      setState(() {
        _downloading = false;
        _error = 'Download failed. Check your connection and try again.';
      });
      return;
    }

    Navigator.pop(context);
    await UpdateService.installAndExit(installer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTotal = _total != null && _total! > 0;
    final progress = hasTotal ? _received / _total! : 0.0;

    return AlertDialog(
      backgroundColor: const Color(0xFFF0F4FF),
      title: const Text('Update Available', style: TextStyle(color: Color(0xFF1A1A2E))),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version ${widget.info.version}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF3A3A5C),
                ),
              ),
              const SizedBox(height: 12),
              if (_downloading) ...[
                LinearProgressIndicator(value: _total == null ? null : progress),
                const SizedBox(height: 8),
                Text(
                  hasTotal
                      ? 'Downloading... ${(_received / 1048576).toStringAsFixed(1)} / ${(_total! / 1048576).toStringAsFixed(1)} MB'
                      : 'Downloading...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF3A3A5C),
                  ),
                ),
              ] else if (_error != null) ...[
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB00020),
                  ),
                ),
              ] else ...[
                MarkdownBody(
                  data: widget.info.body.isNotEmpty
                      ? widget.info.body
                      : '_No changelog provided._',
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF3A3A5C),
                    ),
                    h1: theme.textTheme.titleLarge,
                    h2: theme.textTheme.titleMedium,
                    h3: theme.textTheme.titleSmall,
                    blockquoteDecoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onTapLink: (text, href, title) async {
                    if (href == null) return;
                    final uri = Uri.parse(href);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_downloading) {
              _cancelled = true;
            }
            Navigator.pop(context);
          },
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF5A5A7A))),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4A6CF7),
            foregroundColor: Colors.white,
          ),
          onPressed: _downloading ? null : _downloadAndInstall,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
