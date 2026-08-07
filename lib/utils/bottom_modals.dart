import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:duration_picker/duration_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:Coda/utils/playlist_thumbnail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'package:Coda/services/import_service.dart';

import '../generated/l10n.dart';
import '../services/bottom_message.dart';
import '../services/download_manager.dart';
import '../services/library.dart';
import '../services/media_player.dart';
import '../services/settings_manager.dart';
import '../themes/colors.dart';
import '../themes/text_styles.dart';
import 'adaptive_widgets/adaptive_widgets.dart';
import 'format_duration.dart';
import '../utils/extensions.dart';

class Modals {
  static Future<T?> showGlassWindow<T>({
    required BuildContext context,
    required Widget child,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          ),
        );
      },
    );
  }

  static Future showTimerModal(BuildContext context) {
    return showGlassWindow(
      context: context,
      child: const _GlassWindow(
        title: "Sleep Timer",
        width: 400,
        height: 500,
        child: _TimerWindowContent(),
      ),
    );
  }

  static Future showCenterLoadingModal(BuildContext context, {String? title}) {
    return showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title ?? S.of(context).Progress),
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [LoadingIndicatorM3E()],
          ),
        );
      },
    );
  }

  static Future<String?> showTextField(
    BuildContext context, {
    String? title,
    String? hintText,
    String? doneText,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _textFieldBottomModal(context,
          title: title, hintText: hintText, doneText: doneText),
    );
  }

  static Future<T?> showSelection<T>(
      BuildContext context, List<SelectionItem> items) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _showSelection(context, items),
    );
  }

  static void showSongBottomModal(BuildContext context, Map song) {
    showGlassWindow(
      context: context,
      child: _GlassWindow(
        title: "Song Options",
        width: 400,
        height: 600,
        child: _SongWindowContent(song: song),
      ),
    );
  }

  static void showPlayerOptionsModal(
    BuildContext context,
    Map song, {
    Offset? buttonPosition,
    Size? buttonSize,
  }) {
    Offset position = buttonPosition ?? Offset.zero;
    Size size = buttonSize ?? Size.zero;

    if (buttonPosition == null) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        position = renderBox.localToGlobal(Offset.zero);
        size = renderBox.size;
      }
    }

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AppleMusicStylePopup(
          song: song,
          animation: animation,
          buttonPosition: position,
          buttonSize: size,
        );
      },
    );
  }

  static void showPlaylistBottomModal(BuildContext context, Map playlist) {
    showGlassWindow(
      context: context,
      child: _GlassWindow(
        title: "Playlist Options",
        width: 400,
        height: 600,
        child: _PlaylistWindowContent(playlist: playlist),
      ),
    );
  }

  static void showDownloadBottomModal(BuildContext context) {
    showModalBottomSheet(
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (context) => _downloadBottomModal(context),
    );
  }

  static void showDownloadDetailsBottomModal(
      BuildContext context, Map playlist) {
    showModalBottomSheet(
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (context) => _downloadDetailsBottomModal(context, playlist),
    );
  }

  static Future showArtistsBottomModal(BuildContext context, List artists,
      {String? leading, bool shouldPop = false}) {
    return showGlassWindow(
      context: context,
      child: _GlassWindow(
        title: S.of(context).Artists,
        width: 400,
        height: 500,
        child: _ArtistsWindowContent(artists: artists, leading: leading),
      ),
    );
  }

  static void showCreateplaylistModal(BuildContext context, {Map? item}) {
    showGlassWindow(
      context: context,
      child: _GlassWindow(
        title: S.of(context).Create_Playlist,
        width: 400,
        height: 300,
        child: _CreatePlaylistWindowContent(item: item),
      ),
    );
  }

  static void showImportplaylistModal(BuildContext context, {Map? item}) {
     showGlassWindow(
      context: context,
      child: _GlassWindow(
        title: S.of(context).Import_Playlist,
        width: 400,
        height: 300,
        child: _ImportPlaylistWindowContent(),
      ),
    );
  }

  static void showPlaylistRenameBottomModal(BuildContext context,
      {required String playlistId, String? name}) {
    showModalBottomSheet(
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (context) => _playlistRenameBottomModal(context,
          name: name, playlistId: playlistId),
    );
  }

  static void addToPlaylist(BuildContext context, Map item) {
    showGlassWindow(
      context: context,
      child: _GlassWindow(
        title: S.of(context).Add_To_Playlist,
        width: 400,
        height: 600,
        child: _AddToPlaylistContent(item: item),
      ),
    );
  }

  static Future<bool> showConfirmBottomModal(
    BuildContext context, {
    required String message,
    bool isDanger = false,
    String? doneText,
    String? cancelText,
  }) async {
    return await showModalBottomSheet(
            useRootNavigator: false,
            backgroundColor: Colors.transparent,
            useSafeArea: true,
            isScrollControlled: true,
            context: context,
            builder: (context) => _confirmBottomModal(context,
                message: message,
                isDanger: isDanger,
                doneText: doneText,
                cancelText: cancelText)) ??
        false;
  }

  static void showAccentSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _accentSelector(context),
    );
  }
}

BottomModalLayout _confirmBottomModal(
  BuildContext context, {
  required String message,
  bool isDanger = false,
  String? doneText,
  String? cancelText,
}) {
  return BottomModalLayout(
    title: Center(
      child: Text(
        S.of(context).Confirm,
        style: bigTextStyle(context),
      ),
    ),
    actions: [
      AdaptiveButton(
        onPressed: () {
          Navigator.pop(context, false);
        },
        child: Text(
          cancelText ?? S.of(context).No,
        ),
      ),
      const SizedBox(width: 16),
      AdaptiveFilledButton(
        onPressed: () {
          Navigator.pop(context, true);
        },
        color: isDanger ? Colors.red : Theme.of(context).colorScheme.primary,
        child: Text(
          doneText ?? S.of(context).Yes,
          style: TextStyle(color: isDanger ? Colors.white : null),
        ),
      )
    ],
    child: SingleChildScrollView(
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

BottomModalLayout _playlistRenameBottomModal(BuildContext context,
    {String? name, required String playlistId}) {
  TextEditingController controller = TextEditingController();
  controller.text = name ?? '';
  return BottomModalLayout(
      title: Center(
        child: Text(
          S.of(context).Rename_Playlist,
          style: mediumTextStyle(context),
        ),
      ),
      actions: [
        AdaptiveFilledButton(
          onPressed: () async {
            String text = controller.text;
            context
                .read<LibraryService>()
                .renamePlaylist(
                    playlistId: playlistId,
                    title: text.trim().isNotEmpty ? text : null)
                .then((String message) {
              Navigator.pop(context);
              BottomMessage.showText(context, message);
            });
          },
          child: Text(S.of(context).Rename),
        )
      ],
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              child: Column(
                children: [
                  AdaptiveTextField(
                    controller: controller,
                    fillColor: greyColor,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                    hintText: S.of(context).Playlist_Name,
                    prefix: const Icon(Icons.title),
                  ),
                ],
              ),
            )
          ],
        ),
      ));
}

BottomModalLayout _textFieldBottomModal(BuildContext context,
    {String? title, String? hintText, String? doneText}) {
  String? text;
  return BottomModalLayout(
    title: (title != null)
        ? Center(
            child: Text(
              title,
              style: mediumTextStyle(context),
            ),
          )
        : null,
    actions: [
      AdaptiveFilledButton(
        onPressed: () async {
          Navigator.pop(context, text);
        },
        child: Text(doneText ?? S.of(context).Done),
      )
    ],
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                AdaptiveTextField(
                  onChanged: (value) => text = value,
                  fillColor: greyColor,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                  hintText: hintText,
                  prefix: const Icon(Icons.title),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppleMusicStylePopup extends StatelessWidget {
  final Map song;
  final Animation<double> animation;
  final Offset buttonPosition;
  final Size buttonSize;

  const _AppleMusicStylePopup({
    required this.song,
    required this.animation,
    required this.buttonPosition,
    required this.buttonSize,
  });

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bool hasValidPosition =
        buttonPosition != Offset.zero && buttonSize != Size.zero;

    final double top =
        hasValidPosition ? buttonPosition.dy + buttonSize.height + 8 : 60;
    final double right = hasValidPosition
        ? (screenWidth - buttonPosition.dx - buttonSize.width)
            .clamp(16.0, (screenWidth - 216).clamp(16.0, screenWidth))
        : 16;

    return Stack(
      children: [
        Positioned(
          top: top.clamp(0, screenHeight - 300),
          right: right,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          if (!['DOWNLOADING', 'DOWNLOADED']
                              .contains(song['status']))
                            _menuItem(
                              context,
                              icon: AdaptiveIcons.download,
                              title: S.of(context).Download,
                              onTap: () {
                                Navigator.pop(context);
                                BottomMessage.showText(
                                    context, S.of(context).Download_Started);
                                GetIt.I<DownloadManager>().downloadSong(song);
                              },
                            ),
                          _menuItem(
                            context,
                            icon: AdaptiveIcons.library_add,
                            title: S.of(context).Add_To_Playlist,
                            onTap: () {
                              Navigator.pop(context);
                              Modals.addToPlaylist(context, song);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          if (song['artists'] != null)
                            _menuItem(
                              context,
                              icon: AdaptiveIcons.people,
                              title: S.of(context).Artists,
                              trailing: Icon(
                                AdaptiveIcons.chevron_right,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Modals.showArtistsBottomModal(
                                  context,
                                  song['artists'],
                                  leading: song['thumbnails']?.first['url'],
                                  shouldPop: true,
                                );
                              },
                            ),
                          if (song['album'] != null)
                            _menuItem(
                              context,
                              icon: AdaptiveIcons.album,
                              title: S.of(context).Album,
                              trailing: Icon(
                                Icons.chevron_right,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                context.go('/browse', extra: {
                                  'endpoint': song['album']['endpoint']
                                      .cast<String, dynamic>(),
                                });
                              },
                            ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

BottomModalLayout _showSelection(
    BuildContext context, List<SelectionItem> items) {
  return BottomModalLayout(
    title: Center(
      child: Text(
        "Select",
        style: mediumTextStyle(context),
      ),
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...items.map(
            (item) => AdaptiveListTile(
              dense: true,
              title: Text(item.title),
              onTap: () {
                Navigator.pop(context, item.data);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

BottomModalLayout _downloadBottomModal(BuildContext context) {
  return BottomModalLayout(
    title: AdaptiveListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(S.of(context).Downloads,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: greyColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          AdaptiveIcons.download,
          color: context.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Downloading),
            leading: Icon(AdaptiveIcons.downloading),
            onTap: () async {
              context.push('/saved/downloads_page/downloading_page');
              Navigator.pop(context);
            },
          ),
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Restore_Missing_Songs),
            leading: Icon(AdaptiveIcons.sync),
            onTap: () async {
              Navigator.pop(context);
              BottomMessage.showText(
                  context, S.of(context).Restoring_Missing_Songs);
              GetIt.I<DownloadManager>().restoreDownloads();
            },
          ),
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Delete_All_Songs),
            leading: Icon(AdaptiveIcons.delete),
            onTap: () async {
              bool shouldDelete = await Modals.showConfirmBottomModal(context,
                  message: S.of(context).Confirm_Delete_All_Message,
                  isDanger: true,
                  doneText: S.of(context).Yes,
                  cancelText: S.of(context).No);
              if (shouldDelete) {
                Navigator.pop(context);
                BottomMessage.showText(context, S.of(context).Deleting_Songs);
                List songs = Hive.box('DOWNLOADS').values.toList();
                for (var song in songs) {
                  await Hive.box('DOWNLOADS').delete(song['videoId']);
                  if (song.containsKey('path')) {
                    String path = song['path'];
                    try {
                      File(path).delete();
                    } catch (e) {
                    }
                  }
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}

BottomModalLayout _downloadDetailsBottomModal(
    BuildContext context, Map playlist) {
  return BottomModalLayout(
    title: AdaptiveListTile(
      contentPadding: EdgeInsets.zero,
      title:
          Text(playlist['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: (playlist['songs']?.length > 0)
          ? (playlist['type'] == "ALBUM")
              ? PlaylistThumbnail(
                  playslist: [playlist['songs'][0]], size: 50, radius: 8)
              : PlaylistThumbnail(
                  playslist: playlist['songs'], size: 50, radius: 8)
          : Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: greyColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.music_note_list,
                color: context.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
      subtitle: playlist['subtitle'] != null
          ? Text(playlist['subtitle'],
              maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Play_Next),
            leading: Icon(AdaptiveIcons.playlist_play),
            onTap: () async {
              Navigator.pop(context);
              await GetIt.I<MediaPlayer>().playNext(Map.from(playlist));
              GetIt.I<MediaPlayer>().player.play();
            },
          ),
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Add_To_Queue),
            leading: Icon(AdaptiveIcons.queue_add),
            onTap: () async {
              Navigator.pop(context);
              await GetIt.I<MediaPlayer>().addToQueue(Map.from(playlist));
            },
          ),
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Restore_Missing_Songs),
            leading: Icon(Icons.restore),
            onTap: () async {
              Navigator.pop(context);
              BottomMessage.showText(
                  context, S.of(context).Restoring_Missing_Songs);
              GetIt.I<DownloadManager>()
                  .restoreDownloads(songs: playlist['songs']);
            },
          ),
          AdaptiveListTile(
            dense: true,
            title: Text(S.of(context).Delete_All_Songs),
            leading: Icon(AdaptiveIcons.delete),
            onTap: () async {
              Modals.showConfirmBottomModal(
                context,
                message: S.of(context).Confirm_Delete_All_Message,
                isDanger: true,
              ).then(
                (bool confirm) async {
                  if (confirm) {
                    Navigator.pop(context);
                    BottomMessage.showText(
                        context, S.of(context).Deleting_Songs);
                    for (var song in playlist['songs']) {
                      await GetIt.I<DownloadManager>().deleteSong(
                        key: song['videoId'],
                        path: song['path'],
                        playlistId: playlist['id'],
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

BottomModalLayout _accentSelector(BuildContext context) {
  Color? accentColor = GetIt.I<SettingsManager>().accentColor;
  return BottomModalLayout(
    title: Center(
      child: Text('Select Color', style: mediumTextStyle(context)),
    ),
    actions: [
      AdaptiveButton(
        onPressed: () {
          Navigator.pop(context);
          GetIt.I<SettingsManager>().accentColor = null;
        },
        child: const Text('Reset'),
      ),
      AdaptiveFilledButton(
        child: Text(S.of(context).Done),
        onPressed: () => Navigator.pop(context),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorPicker(
          pickerColor: accentColor ?? Colors.white,
          onColorChanged: (color) {
            GetIt.I<SettingsManager>().accentColor = color;
          },
          labelTypes: const [],
          portraitOnly: true,
          colorPickerWidth: min(300, MediaQuery.of(context).size.width - 32),
          pickerAreaHeightPercent: 0.7,
          enableAlpha: false,
          displayThumbColor: false,
          paletteType: PaletteType.hueWheel,
        ),
      ],
    ),
  );
}

class BottomModalLayout extends StatelessWidget {
  const BottomModalLayout({
    required this.child,
    this.title,
    this.actions,
    super.key,
  });
  final Widget child;
  final Widget? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      constraints: const BoxConstraints(maxWidth: 600),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 0),
                      child: title!),
                child,
                if (actions != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SelectionItem<T> {
  final String title;
  final IconData? icon;
  final T data;

  SelectionItem({required this.title, this.icon, required this.data});
}

class _GlassWindow extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;
  final double height;

  const _GlassWindow({
    required this.title,
    required this.child,
    this.width = 500,
    this.height = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: width,
          height: height,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          hoverColor: Colors.white.withOpacity(0.1),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

class _AddToPlaylistContent extends StatelessWidget {
  final Map item;
  const _AddToPlaylistContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: AdaptiveFilledButton(
            onPressed: () {
              Navigator.pop(context);
              Modals.showCreateplaylistModal(context, item: item);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 20, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  S.of(context).Create_Playlist,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              ...context
                  .read<LibraryService>()
                  .userPlaylists
                  .map((key, playlist) {
                final bool isAlreadyIn = playlist['songs'].contains(item);
                return MapEntry(
                  key,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        hoverColor: Colors.white.withOpacity(0.05),
                        onTap: isAlreadyIn
                            ? null
                            : () async {
                                await context
                                    .read<LibraryService>()
                                    .addToPlaylist(item: item, key: key)
                                    .then((String message) {
                                  Navigator.pop(context);
                                  BottomMessage.showText(context, message);
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (playlist['thumbnails'] != null &&
                                        playlist['thumbnails'].isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: playlist['thumbnails']
                                            .first['url']
                                            .replaceAll('w540-h225', 'w60-h60'),
                                        height: 56,
                                        width: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        height: 56,
                                        width: 56,
                                        color: Colors.grey[900],
                                        child: const Icon(Icons.music_note,
                                            color: Colors.white),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${playlist['songs']?.length ?? 0} songs',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAlreadyIn)
                                Icon(Icons.check_circle,
                                    color: Theme.of(context).primaryColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).values,
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtistsWindowContent extends StatelessWidget {
  final List artists;
  final String? leading;

  const _ArtistsWindowContent({required this.artists, this.leading});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: Colors.white.withOpacity(0.05),
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.go(
                  '/browse',
                  extra: {
                    'endpoint': artist['endpoint'].cast<String, dynamic>(),
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: leading != null
                          ? CachedNetworkImageProvider(leading!)
                          : null,
                      backgroundColor: Colors.grey[900],
                      child: leading == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      artist['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withOpacity(0.3)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimerWindowContent extends StatefulWidget {
  const _TimerWindowContent();

  @override
  State<_TimerWindowContent> createState() => _TimerWindowContentState();
}

class _TimerWindowContentState extends State<_TimerWindowContent> {
  @override
  Widget build(BuildContext context) {
    final mediaPlayer = context.watch<MediaPlayer>();
    final currentTimer = mediaPlayer.timerDuration.value;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentTimer != null) ...[
            const Text(
              "Timer Active",
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatDuration(currentTimer),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 24),
            AdaptiveFilledButton(
              onPressed: () {
                mediaPlayer.cancelTimer();
              },
              color: Colors.red.withOpacity(0.2),
              child:
                  const Text("Stop Timer", style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),
          ],
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildPreset(const Duration(minutes: 15), "15 min"),
                _buildPreset(const Duration(minutes: 30), "30 min"),
                _buildPreset(const Duration(minutes: 45), "45 min"),
                _buildPreset(const Duration(hours: 1), "1 hr"),
                _buildPreset(const Duration(hours: 2), "2 hrs"),
                _buildPreset(
                    null, "Custom"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreset(Duration? duration, String label) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        hoverColor: Colors.white.withOpacity(0.1),
        onTap: () {
          if (duration != null) {
            context.read<MediaPlayer>().setTimer(duration);
            Navigator.pop(context);
          } else {
            showDurationPicker(
              context: context,
              initialTime: const Duration(minutes: 30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF3A3A3F),
              ),
            ).then((d) {
              if (d != null) {
                context.read<MediaPlayer>().setTimer(d);
                Navigator.pop(context);
              }
            });
          }
        },
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SongWindowContent extends StatelessWidget {
  final Map song;
  const _SongWindowContent({required this.song});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song['thumbnails'].first['url'],
                height: 60,
                width: song['type'] == 'VIDEO' ? 100 : 60,
                fit: BoxFit.cover,
errorWidget: (context, url, error) => const Icon(Icons.music_note),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song['title'],
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (song['subtitle'] != null)
                    Text(
                      song['subtitle'],
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),

        _buildAction(
          context,
          icon: AdaptiveIcons.playlist_play,
          title: S.of(context).Play_Next,
          onTap: () async {
            Navigator.pop(context);
            await GetIt.I<MediaPlayer>().playNext(Map.from(song));
          },
        ),
        _buildAction(
          context,
          icon: AdaptiveIcons.queue_add,
          title: S.of(context).Add_To_Queue,
          onTap: () async {
            Navigator.pop(context);
            await GetIt.I<MediaPlayer>().addToQueue(Map.from(song));
          },
        ),
        ValueListenableBuilder(
          valueListenable: Hive.box('FAVOURITES').listenable(),
          builder: (context, value, child) {
            Map? item = value.get(song['videoId']);
            return _buildAction(
              context,
              icon: item == null
                  ? AdaptiveIcons.heart
                  : AdaptiveIcons.heart_fill,
              title: item == null
                  ? S.of(context).Add_To_Favourites
                  : S.of(context).Remove_From_Favourites,
              onTap: () async {
                Navigator.pop(context);
                if (item == null) {
                  await Hive.box('FAVOURITES').put(
                    song['videoId'],
                    {
                      ...song,
                      'createdAt': DateTime.now().millisecondsSinceEpoch
                    },
                  );
                } else {
                  await value.delete(song['videoId']);
                }
              },
            );
          },
        ),
        if (!['DOWNLOADING', 'DOWNLOADED'].contains(song['status']))
        _buildAction(
          context,
          icon: AdaptiveIcons.download,
          title: S.of(context).Download,
          onTap: () {
            Navigator.pop(context);
            BottomMessage.showText(context, S.of(context).Download_Started);
            GetIt.I<DownloadManager>().downloadSong(song);
          },
        ),
        _buildAction(
          context,
          icon: AdaptiveIcons.library_add,
          title: S.of(context).Add_To_Playlist,
          onTap: () {
            Navigator.pop(context);
            Modals.addToPlaylist(context, song);
          },
        ),
        _buildAction(
          context,
          icon: AdaptiveIcons.radio,
          title: S.of(context).Start_Radio,
          onTap: () {
            Navigator.pop(context);
            GetIt.I<MediaPlayer>().startRelated(Map.from(song), radio: true);
          },
        ),
         const SizedBox(height: 8),
         const Divider(color: Colors.white12),
         const SizedBox(height: 8),
        if (song['artists'] != null)
        _buildAction(
          context,
          icon: AdaptiveIcons.people,
          title: S.of(context).Artists,
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.pop(context);
            Modals.showArtistsBottomModal(context, song['artists'],
                leading: song['thumbnails'].first['url']);
          },
        ),
        if (song['album'] != null)
        _buildAction(
          context,
          icon: AdaptiveIcons.album,
          title: S.of(context).Album,
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.pop(context);
             context.go('/browse', extra: {
                    'endpoint':
                        song['album']['endpoint'].cast<String, dynamic>(),
                  });
          },
        ),
      ],
    );
  }

  Widget _buildAction(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistWindowContent extends StatelessWidget {
  final Map playlist;
  const _PlaylistWindowContent({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (playlist['thumbnails']?.isNotEmpty == true)
                  ? CachedNetworkImage(
                      imageUrl: playlist['thumbnails'].first['url'],
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.music_note),
                    )
                  : Container(
                      height: 60,
                      width: 60,
                      color: Colors.grey[900],
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist['title'],
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (playlist['subtitle'] != null)
                    Text(
                      playlist['subtitle'],
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
         const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),

        _buildAction(
          context,
          icon: AdaptiveIcons.playlist_play,
          title: S.of(context).Play_Next,
          onTap: () async {
            Navigator.pop(context);
            await GetIt.I<MediaPlayer>().playNext(Map.from(playlist));
            GetIt.I<MediaPlayer>().player.play();
          },
        ),
        _buildAction(
          context,
          icon: AdaptiveIcons.queue_add,
          title: S.of(context).Add_To_Queue,
          onTap: () async {
            Navigator.pop(context);
            await GetIt.I<MediaPlayer>().addToQueue(Map.from(playlist));
          },
        ),
        _buildAction(
          context,
          icon: AdaptiveIcons.download,
          title: S.of(context).Download,
          onTap: () {
            Navigator.pop(context);
            BottomMessage.showText(context, S.of(context).Download_Started);
             GetIt.I<DownloadManager>().downloadPlaylist(playlist);
          },
        ),
        if (playlist['isPredefined'] == false)
        _buildAction(
          context,
          icon: Icons.title,
          title: S.of(context).Rename,
          onTap: () {
            Navigator.pop(context);
            Modals.showPlaylistRenameBottomModal(context,
                    playlistId: playlist['playlistId'],
                    name: playlist['title']);
          },
        ),
        _buildAction(
          context,
           icon: context.watch<LibraryService>().getPlaylist(
                        playlist['playlistId'] ??
                            playlist['endpoint']['browseId']) ==
                    null
                ? AdaptiveIcons.library_add
                : AdaptiveIcons.library_add_check,
          title: context.watch<LibraryService>().getPlaylist(
                          playlist['playlistId'] ??
                              playlist['endpoint']['browseId']) ==
                      null
                  ? S.of(context).Add_To_Library
                  : S.of(context).Remove_From_Library,
          onTap: () {
             Navigator.pop(context);
              if (context
                      .read<LibraryService>()
                      .getPlaylist(playlist['playlistId']) ==
                  null) {
                GetIt.I<LibraryService>()
                    .addToOrRemoveFromLibrary(playlist)
                    .then((String message) {
                  BottomMessage.showText(context, message);
                });
              } else {
                Modals.showConfirmBottomModal(
                  context,
                  message: S.of(context).Delete_Item_Message,
                  isDanger: true,
                ).then((bool confirm) {
                  if (confirm) {
                    GetIt.I<LibraryService>()
                        .addToOrRemoveFromLibrary(playlist)
                        .then((String message) {
                      BottomMessage.showText(context, message);
                    });
                  }
                });
              }
          },
        ),
        if (playlist['playlistId'] != null && playlist['type'] == 'ARTIST')
         _buildAction(
          context,
          icon: AdaptiveIcons.radio,
          title: S.of(context).Start_Radio,
          onTap: () async {
             Navigator.pop(context);
                BottomMessage.showText(
                    context, S.of(context).Songs_Will_Start_Playing_Soon);
                await GetIt.I<MediaPlayer>().startRelated(Map.from(playlist),
                    radio: true, isArtist: playlist['type'] == 'ARTIST');
          },
        ),
         const SizedBox(height: 8),
         const Divider(color: Colors.white12),
         const SizedBox(height: 8),

         if (playlist['artists'] != null && playlist['artists'].isNotEmpty)
         _buildAction(
          context,
          icon: AdaptiveIcons.people,
          title: S.of(context).Artists,
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
             Navigator.pop(context);
                Modals.showArtistsBottomModal(context, playlist['artists'],
                    leading: playlist['thumbnails'].first['url']);
          },
        ),
        if (playlist['album'] != null)
         _buildAction(
          context,
          icon: AdaptiveIcons.album,
          title: S.of(context).Album,
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
             context.push(
                '/browse',
                extra: {
                  'endpoint': playlist['album']['endpoint'],
                },
              );
          },
        ),

      ],
    );
  }

  Widget _buildAction(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePlaylistWindowContent extends StatefulWidget {
  final Map<dynamic, dynamic>? item;
  const _CreatePlaylistWindowContent({this.item});

  @override
  State<_CreatePlaylistWindowContent> createState() =>
      _CreatePlaylistWindowContentState();
}

class _CreatePlaylistWindowContentState
    extends State<_CreatePlaylistWindowContent> {
  String title = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
             AdaptiveTextField(
                  onChanged: (value) => title = value,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  hintText: S.of(context).Playlist_Name,
                  prefix: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.title, color: Colors.white),
                  ),
                ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                     Navigator.pop(context);
                  },
                  child: Text(S.of(context).Cancel, style: const TextStyle(color: Colors.white70)),
                ),
                 const SizedBox(width: 16),
                AdaptiveFilledButton(
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () async {
                    context
                        .read<LibraryService>()
                        .createPlaylist(title, item: widget.item)
                        .then((String message) {
                      Navigator.pop(context);
                      BottomMessage.showText(context, message);
                    });
                  },
                  child: Text(
                    S.of(context).Create,
                    style: const TextStyle(
                         color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )
          ],
        ));
  }
}

class _ImportPlaylistWindowContent extends StatefulWidget {
  const _ImportPlaylistWindowContent();

  @override
  State<_ImportPlaylistWindowContent> createState() =>
      _ImportPlaylistWindowContentState();
}

class _ImportPlaylistWindowContentState
    extends State<_ImportPlaylistWindowContent> {
  String title = '';
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
             AdaptiveTextField(
                  onChanged: (value) => title = value,
                  keyboardType: TextInputType.url,
                   fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  hintText: 'Spotify / YouTube / YTM Playlist URL',
                  prefix: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.link, color: Colors.white),
                  ),
                   contentPadding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                     Navigator.pop(context);
                  },
                  child: Text(S.of(context).Cancel, style: const TextStyle(color: Colors.white70)),
                ),
                 const SizedBox(width: 16),
                AdaptiveFilledButton(
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    Navigator.pop(context);
                    ImportService().import(title).listen((_) {});
                  },
                  child: Text(
                    S.of(context).Import,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )
          ],
        ));
  }
}
