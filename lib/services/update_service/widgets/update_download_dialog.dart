import 'package:flutter/material.dart';
import 'package:Coda/services/update_service/update_service.dart';

class UpdateDownloadDialog extends StatefulWidget {
  const UpdateDownloadDialog({super.key, this.onClosed});

  final VoidCallback? onClosed;

  @override
  State<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<UpdateDownloadDialog> {
  static const _accent = Color(0xFF4A6CF7);
  static const _title = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF3A3A5C);
  static const _errorColor = Color(0xFFB00020);

  bool _cancelled = false;
  int _received = 0;
  int? _total;
  String? _error;
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final update = await UpdateService.checkForUpdate();
    if (update == null) {
      if (!mounted) return;
      setState(() {
        _error = 'No update found';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _versionLabel = update.version.toString();
      });
    }

    final installer = await UpdateService.downloadInstaller(
      url: update.downloadUrl,
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

    if (_cancelled) return;

    if (installer == null) {
      setState(() {
        _error = 'Download failed. Check your connection and retry.';
      });
      return;
    }

    _close();
    await UpdateService.installAndExit(installer);
  }

  void _close() {
    if (widget.onClosed != null) {
      widget.onClosed!();
    } else if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTotal = _total != null && _total! > 0;
    final progress = hasTotal ? _received / _total! : 0.0;
    final failed = _error != null;

    return AlertDialog(
      backgroundColor: const Color(0xFFF7F9FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      content: SizedBox(
        width: 310,
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
                    color: failed
                        ? const Color(0xFFFDA4AF)
                        : const Color(0xFFDDE6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    failed ? Icons.error_outline : Icons.cloud_download,
                    color: failed ? _errorColor : _accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        failed ? 'Update failed' : 'Downloading update',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _versionLabel != null
                            ? 'Version $_versionLabel'
                            : 'Preparing...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (failed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF3C4CB),
                    width: 1,
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _errorColor,
                    height: 1.4,
                  ),
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: hasTotal ? progress : null,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFDDE4F5),
                  color: _accent,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    hasTotal
                        ? '${(_received / 1048576).toStringAsFixed(1)} / ${(_total! / 1048576).toStringAsFixed(1)} MB'
                        : 'Contacting server...',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const Spacer(),
                  if (hasTotal)
                    Text(
                      '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE4E9F6),
            foregroundColor: const Color(0xFF3A3A5C),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            _cancelled = true;
            _close();
          },
          child: Text(
            failed ? 'Close' : 'Cancel',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

