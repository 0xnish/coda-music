import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:Coda/themes/theme.dart';
import 'package:Coda/ytmusic/modals/yt_config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'generated/l10n.dart';
import 'services/download_manager.dart';
import 'services/equalizer_service.dart';
import 'services/file_storage.dart';
import 'services/library.dart';
import 'services/lyrics.dart';
import 'services/media_player.dart';
import 'services/providers/google_translate_provider.dart';
import 'services/settings_manager.dart';
import 'utils/router.dart';
import 'ytmusic/ytmusic.dart';
import 'services/window_service.dart';
import 'services/yt_audio_stream.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initialiseHive();

  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
    JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
    JustAudioMediaKit.title = 'Coda Music';
    JustAudioMediaKit.prefetchPlaylist = true;
    JustAudioMediaKit.pitch = true;
  }

  String? visitorId = await Hive.box('SETTINGS').get('VISITOR_ID');

  YTMusic ytMusic = YTMusic(
    config:
        YTConfig(visitorData: visitorId ?? '', language: 'en', location: 'IN'),
    onIdUpdate: (visitorId) async {
      await Hive.box('SETTINGS').put('VISITOR_ID', visitorId);
    },
  );

  final GlobalKey<NavigatorState> panelKey = GlobalKey<NavigatorState>();

  SettingsManager settingsManager = SettingsManager();
  MediaPlayer mediaPlayer = MediaPlayer();

  GetIt.I.registerSingleton<SettingsManager>(settingsManager);
  GetIt.I.registerSingleton<MediaPlayer>(mediaPlayer);
  GetIt.I.registerSingleton<EqualizerService>(EqualizerService());
  GetIt.I.registerSingleton<LibraryService>(LibraryService());
  GetIt.I.registerSingleton<DownloadManager>(DownloadManager());
  GetIt.I.registerSingleton(panelKey);
  GetIt.I.registerSingleton<YTMusic>(ytMusic);
  GetIt.I.registerSingleton<LyricsService>(LyricsService());
  GetIt.I.registerSingleton<GoogleTranslateTranslator>(GoogleTranslateTranslator());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsManager),
        ChangeNotifierProvider(create: (_) => mediaPlayer),
        ChangeNotifierProvider(create: (_) => GetIt.I<LibraryService>()),
      ],
      child: const Coda(),
    ),
  );

  _initialiseHeavyServices();
}

Future<void> _initialiseHeavyServices() async {
  if (Platform.isWindows) {
    WindowService.maximize();
  }

  await FileStorage.initialise();
  GetIt.I.registerSingleton<FileStorage>(FileStorage());

  final audioStreamUrl = await createAudioStreamServer();
  GetIt.I.registerSingleton<String>(audioStreamUrl,
      instanceName: 'audioStreamUrl');
}

class Coda extends StatelessWidget {
  const Coda({super.key});
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      child: MaterialApp.router(
        title: 'Coda Music',
        scrollBehavior: const SmoothScrollBehavior(),
        routerConfig: router,
        locale: Locale(context.watch<SettingsManager>().language['value']!),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: AppTheme.light(
          primary: Colors.black,
        ),
        darkTheme: AppTheme.dark(
          primary: Colors.white,
        ),
      ),
    );
  }
}

Future<void> initialiseHive() async {
  String? applicationDataDirectoryPath;
  if (Platform.isWindows) {
    applicationDataDirectoryPath =
        "${(await getApplicationSupportDirectory()).path}/database";
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Future.wait([
    Hive.openBox('SETTINGS'),
    Hive.openBox('LIBRARY'),
    Hive.openBox('SEARCH_HISTORY'),
    Hive.openBox('SONG_HISTORY'),
    Hive.openBox('FAVOURITES'),
    Hive.openBox('DOWNLOADS'),
    Hive.openBox('BLOCKED_SONGS'),
  ]);
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
