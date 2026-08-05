import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:Coda/generated/l10n.dart';
import 'package:Coda/screens/settings/widgets/setting_item.dart';
import 'package:Coda/themes/text_styles.dart';
import 'package:Coda/utils/bottom_modals.dart';

import 'cubit/ytmusic_cubit.dart';


class YTMusicPage extends StatefulWidget {
  const YTMusicPage({super.key});

  @override
  State<YTMusicPage> createState() => _YTMusicPageState();
}

class _YTMusicPageState extends State<YTMusicPage> {
  late final AnimatedScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => YTMusicCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).YTMusic),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<YTMusicCubit, YTMusicState>(
              builder: (context, state) {
                final cubit = context.read<YTMusicCubit>();

                return ListView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    GroupTitle(title: "General"),

                    SettingTile(
                      title: S.of(context).Country,
                      leading: const Icon(Icons.location_pin),
                      isFirst: true,
                      trailing: DropdownButton<Map<String, String>>(
                          value: state.location,
                          items: cubit.locations
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(
                                    l['name']!.trim(),
                                    style: smallTextStyle(context),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              cubit.setLocation(v);
                            }
                          }),
                    ),

                    SettingTile(
                      title: S.of(context).Language,
                      leading: const Icon(Icons.language),
                      trailing: DropdownButton(
                        value: state.language,
                        items: cubit.languages
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(
                                  l['name']!.trim(),
                                  style: smallTextStyle(context),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            v != null ? cubit.setLanguage(v) : null,
                      ),
                    ),

                    SettingSwitchTile(
                      title: S.of(context).Translate_Lyrics,
                      leading: const Icon(Icons.translate_outlined),
                      value: state.translateLyrics,
                      onChanged: cubit.setTranslateLyrics,
                    ),

                    SettingSwitchTile(
                      title: S.of(context).Autofetch_Songs,
                      leading: const Icon(Icons.autorenew_outlined),
                      isLast: true,
                      value: state.autofetchSongs,
                      onChanged: cubit.setAutofetchSongs,
                    ),

                    GroupTitle(title: "Playback & download"),

                    SettingTile(
                      title: S.of(context).Streaming_Quality,
                      leading: const Icon(Icons.speaker_group_rounded),
                      isFirst: true,
                      trailing: DropdownButton(
                        value: state.streamingQuality,
                        items: cubit.audioQualities
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e.name.toUpperCase(),
                                  style: smallTextStyle(context),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: cubit.setStreamingQuality,
                      ),
                    ),

                    SettingTile(
                      title: S.of(context).DOwnload_Quality,
                      leading: const Icon(Icons.cloud_download_rounded),
                      isLast: true,
                      trailing: DropdownButton(
                        value: state.downloadQuality,
                        items: cubit.audioQualities
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e.name.toUpperCase(),
                                  style: smallTextStyle(context),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: cubit.setDownloadQuality,
                      ),
                    ),

                    GroupTitle(title: "Privacy"),

                    SettingSwitchTile(
                      title: S.of(context).Personalised_Content,
                      leading: const Icon(Icons.recommend_outlined),
                      isFirst: true,
                      value: state.personalisedContent,
                      onChanged: (v) async {
                        Modals.showCenterLoadingModal(context);
                        await cubit.setPersonalisedContent(v);
                        if (context.mounted) context.pop();
                      },
                    ),

                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
