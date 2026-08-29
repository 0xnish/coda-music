import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';



class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  String get Coda {
    return Intl.message('Coda', name: 'Coda', desc: '', args: []);
  }

  String get Next_Up {
    return Intl.message('Next Up', name: 'Next_Up', desc: '', args: []);
  }

  String get Shuffle {
    return Intl.message('Shuffle', name: 'Shuffle', desc: '', args: []);
  }

  String get Home {
    return Intl.message('Home', name: 'Home', desc: '', args: []);
  }

  String get Saved {
    return Intl.message('Saved', name: 'Saved', desc: '', args: []);
  }

  String get YTMusic {
    return Intl.message('YTMusic', name: 'YTMusic', desc: '', args: []);
  }

  String get Settings {
    return Intl.message('Settings', name: 'Settings', desc: '', args: []);
  }

  String get Search_Coda {
    return Intl.message(
      'Search Coda',
      name: 'Search_Coda',
      desc: '',
      args: [],
    );
  }

  String get Favourites {
    return Intl.message('Favourites', name: 'Favourites', desc: '', args: []);
  }

  String get Downloads {
    return Intl.message('Downloads', name: 'Downloads', desc: '', args: []);
  }

  String get History {
    return Intl.message('History', name: 'History', desc: '', args: []);
  }

  String nSongs(num count) {
    return Intl.plural(
      count,
      zero: 'No Songs',
      one: '1 Song',
      other: '$count Songs',
      name: 'nSongs',
      desc: 'Number of songs',
      args: [count],
    );
  }

  String get Songs {
    return Intl.message('Songs', name: 'Songs', desc: '', args: []);
  }

  String get Albums {
    return Intl.message('Albums', name: 'Albums', desc: '', args: []);
  }

  String get Playlists {
    return Intl.message('Playlists', name: 'Playlists', desc: '', args: []);
  }

  String get Artists {
    return Intl.message('Artists', name: 'Artists', desc: '', args: []);
  }

  String get Subscriptions {
    return Intl.message(
      'Subscriptions',
      name: 'Subscriptions',
      desc: '',
      args: [],
    );
  }

  String get Search_Settings {
    return Intl.message(
      'Search Settings',
      name: 'Search_Settings',
      desc: '',
      args: [],
    );
  }

  String get Battery_Optimisation_title {
    return Intl.message(
      'Battery Optimisation Detected',
      name: 'Battery_Optimisation_title',
      desc: '',
      args: [],
    );
  }

  String get Battery_Optimisation_message {
    return Intl.message(
      'Click here disable battery optimisation for Coda to work properly',
      name: 'Battery_Optimisation_message',
      desc: '',
      args: [],
    );
  }

  String get Donate {
    return Intl.message('Donate', name: 'Donate', desc: '', args: []);
  }

  String get Donate_Message {
    return Intl.message(
      'Support the development of Coda',
      name: 'Donate_Message',
      desc: '',
      args: [],
    );
  }

  String get Payment_Methods {
    return Intl.message(
      'Payment Methods',
      name: 'Payment_Methods',
      desc: '',
      args: [],
    );
  }

  String get Pay_With_UPI {
    return Intl.message(
      'Pay with UPI',
      name: 'Pay_With_UPI',
      desc: '',
      args: [],
    );
  }

  String get Support_Me_On_Kofi {
    return Intl.message(
      'Support me on Ko-fi',
      name: 'Support_Me_On_Kofi',
      desc: '',
      args: [],
    );
  }

  String get Buy_Me_A_Coffee {
    return Intl.message(
      'Buy me a Coffee',
      name: 'Buy_Me_A_Coffee',
      desc: '',
      args: [],
    );
  }

  String get Google_Account {
    return Intl.message(
      'Google Account',
      name: 'Google_Account',
      desc: '',
      args: [],
    );
  }

  String get Appearence {
    return Intl.message('Appearence', name: 'Appearence', desc: '', args: []);
  }

  String get Theme_Mode {
    return Intl.message('Theme Mode', name: 'Theme_Mode', desc: '', args: []);
  }

  String get Window_Effect {
    return Intl.message(
      'Window Effect',
      name: 'Window_Effect',
      desc: '',
      args: [],
    );
  }

  String get Dynamic_Colors {
    return Intl.message(
      'Dynamic Colors',
      name: 'Dynamic_Colors',
      desc: '',
      args: [],
    );
  }

  String get Content {
    return Intl.message('Content', name: 'Content', desc: '', args: []);
  }

  String get Country {
    return Intl.message('Country', name: 'Country', desc: '', args: []);
  }

  String get Language {
    return Intl.message('Language', name: 'Language', desc: '', args: []);
  }

  String get Translate_Lyrics {
    return Intl.message(
      'Translate Lyrics',
      name: 'Translate_Lyrics',
      desc: '',
      args: [],
    );
  }

  String get Autofetch_Songs {
    return Intl.message(
      'Autoplay Similar Songs',
      name: 'Autofetch_Songs',
      desc: '',
      args: [],
    );
  }

  String get Personalised_Content {
    return Intl.message(
      'Personalised Content',
      name: 'Personalised_Content',
      desc: '',
      args: [],
    );
  }

  String get Enter_Visitor_Id {
    return Intl.message(
      'Enter Visitor Id',
      name: 'Enter_Visitor_Id',
      desc: '',
      args: [],
    );
  }

  String get Visitor_Id {
    return Intl.message('Visitor Id', name: 'Visitor_Id', desc: '', args: []);
  }

  String get Reset_Visitor_Id {
    return Intl.message(
      'Reset Visitor Id',
      name: 'Reset_Visitor_Id',
      desc: '',
      args: [],
    );
  }

  String get Audio_And_Playback {
    return Intl.message(
      'Audio and Playback',
      name: 'Audio_And_Playback',
      desc: '',
      args: [],
    );
  }

  String get Loudness_And_Equalizer {
    return Intl.message(
      'Loudness And Equalizer',
      name: 'Loudness_And_Equalizer',
      desc: '',
      args: [],
    );
  }

  String get Loudness_Enhancer {
    return Intl.message(
      'Loudness Enhancer',
      name: 'Loudness_Enhancer',
      desc: '',
      args: [],
    );
  }

  String get Enable_Equalizer {
    return Intl.message(
      'Enable Equalizer',
      name: 'Enable_Equalizer',
      desc: '',
      args: [],
    );
  }

  String get Streaming_Quality {
    return Intl.message(
      'Streaming Quality',
      name: 'Streaming_Quality',
      desc: '',
      args: [],
    );
  }

  String get DOwnload_Quality {
    return Intl.message(
      'Download Quality',
      name: 'DOwnload_Quality',
      desc: '',
      args: [],
    );
  }

  String get App_Folder {
    return Intl.message('App Folder', name: 'App_Folder', desc: '', args: []);
  }

  String get Skip_Silence {
    return Intl.message(
      'Skip Silence',
      name: 'Skip_Silence',
      desc: '',
      args: [],
    );
  }

  String get Enable_Playback_History {
    return Intl.message(
      'Enable Playback History',
      name: 'Enable_Playback_History',
      desc: '',
      args: [],
    );
  }

  String get Delete_Playback_History {
    return Intl.message(
      'Delete Playback History',
      name: 'Delete_Playback_History',
      desc: '',
      args: [],
    );
  }

  String get Delete_Playback_History_Confirm_Message {
    return Intl.message(
      'Are you sure you want to delete Playback History.',
      name: 'Delete_Playback_History_Confirm_Message',
      desc: '',
      args: [],
    );
  }

  String get Playback_History_Deleted {
    return Intl.message(
      'Playback History Deleted',
      name: 'Playback_History_Deleted',
      desc: '',
      args: [],
    );
  }

  String get Enable_Search_History {
    return Intl.message(
      'Enable Search History',
      name: 'Enable_Search_History',
      desc: '',
      args: [],
    );
  }

  String get Delete_Search_History {
    return Intl.message(
      'Delete Search History',
      name: 'Delete_Search_History',
      desc: '',
      args: [],
    );
  }

  String get Delete_Search_History_Confirm_Message {
    return Intl.message(
      'Are you sure you want to delete Search History.',
      name: 'Delete_Search_History_Confirm_Message',
      desc: '',
      args: [],
    );
  }

  String get Search_History_Deleted {
    return Intl.message(
      'Search History Deleted',
      name: 'Search_History_Deleted',
      desc: '',
      args: [],
    );
  }

  String get Backup_And_Restore {
    return Intl.message(
      'Backup and Restore',
      name: 'Backup_And_Restore',
      desc: '',
      args: [],
    );
  }

  String get Backup {
    return Intl.message('Backup', name: 'Backup', desc: '', args: []);
  }

  String get Restore {
    return Intl.message('Restore', name: 'Restore', desc: '', args: []);
  }

  String get Share {
    return Intl.message('Share', name: 'Share', desc: '', args: []);
  }

  String get Save {
    return Intl.message('Save', name: 'Save', desc: '', args: []);
  }

  String get Backup_Success {
    return Intl.message(
      'Backed up successfully at',
      name: 'Backup_Success',
      desc: '',
      args: [],
    );
  }

  String get Backup_Failed {
    return Intl.message(
      'Failed to back up Data',
      name: 'Backup_Failed',
      desc: '',
      args: [],
    );
  }

  String get Restore_Success {
    return Intl.message(
      'Data successfully restored',
      name: 'Restore_Success',
      desc: '',
      args: [],
    );
  }

  String get Restore_Failed {
    return Intl.message(
      'Failed to restore Data',
      name: 'Restore_Failed',
      desc: '',
      args: [],
    );
  }

  String get Select_Backup {
    return Intl.message(
      'Select Backup',
      name: 'Select_Backup',
      desc: '',
      args: [],
    );
  }

  String get About {
    return Intl.message('About', name: 'About', desc: '', args: []);
  }

  String get Name {
    return Intl.message('Name', name: 'Name', desc: '', args: []);
  }

  String get Version {
    return Intl.message('Version', name: 'Version', desc: '', args: []);
  }

  String get Developer {
    return Intl.message('Developer', name: 'Developer', desc: '', args: []);
  }

  String get Sheikh_Haziq {
    return Intl.message(
      'Sheikh Haziq',
      name: 'Sheikh_Haziq',
      desc: '',
      args: [],
    );
  }

  String get Organisation {
    return Intl.message(
      'Organisation',
      name: 'Organisation',
      desc: '',
      args: [],
    );
  }

  String get Jhelum_Corp {
    return Intl.message('Jhelum Corp', name: 'Jhelum_Corp', desc: '', args: []);
  }

  String get Telegram {
    return Intl.message('Telegram', name: 'Telegram', desc: '', args: []);
  }

  String get Contributors {
    return Intl.message(
      'Contributors',
      name: 'Contributors',
      desc: '',
      args: [],
    );
  }

  String get Source_Code {
    return Intl.message('Source Code', name: 'Source_Code', desc: '', args: []);
  }

  String get Bug_Report {
    return Intl.message('Bug Report', name: 'Bug_Report', desc: '', args: []);
  }

  String get Feature_Request {
    return Intl.message(
      'Feature Request',
      name: 'Feature_Request',
      desc: '',
      args: [],
    );
  }

  String get Made_In_Kashmir {
    return Intl.message(
      'Made in Kashmir',
      name: 'Made_In_Kashmir',
      desc: '',
      args: [],
    );
  }

  String get Check_For_Update {
    return Intl.message(
      'Check for Update',
      name: 'Check_For_Update',
      desc: '',
      args: [],
    );
  }

  String get Progress {
    return Intl.message('Progress', name: 'Progress', desc: '', args: []);
  }

  String get Play_Next {
    return Intl.message('Play Next', name: 'Play_Next', desc: '', args: []);
  }

  String get Add_To_Queue {
    return Intl.message(
      'Add To Queue',
      name: 'Add_To_Queue',
      desc: '',
      args: [],
    );
  }

  String get Add_To_Favourites {
    return Intl.message(
      'Add To Favourites',
      name: 'Add_To_Favourites',
      desc: '',
      args: [],
    );
  }

  String get Remove_From_Favourites {
    return Intl.message(
      'Remove From Favourites',
      name: 'Remove_From_Favourites',
      desc: '',
      args: [],
    );
  }

  String get Download {
    return Intl.message('Download', name: 'Download', desc: '', args: []);
  }

  String get Add_To_Playlist {
    return Intl.message(
      'Add To Playlist',
      name: 'Add_To_Playlist',
      desc: '',
      args: [],
    );
  }

  String get Start_Radio {
    return Intl.message('Start Radio', name: 'Start_Radio', desc: '', args: []);
  }

  String get Album {
    return Intl.message('Album', name: 'Album', desc: '', args: []);
  }

  String get Rename {
    return Intl.message('Rename', name: 'Rename', desc: '', args: []);
  }

  String get Add_To_Library {
    return Intl.message(
      'Add To Library',
      name: 'Add_To_Library',
      desc: '',
      args: [],
    );
  }

  String get Remove_From_Library {
    return Intl.message(
      'Remove From Library',
      name: 'Remove_From_Library',
      desc: '',
      args: [],
    );
  }

  String get Delete_Item_Message {
    return Intl.message(
      'Are you sure you want to delete this item?',
      name: 'Delete_Item_Message',
      desc: '',
      args: [],
    );
  }

  String get Sleep_Timer {
    return Intl.message('Sleep Timer', name: 'Sleep_Timer', desc: '', args: []);
  }

  String get Equalizer {
    return Intl.message('Equalizer', name: 'Equalizer', desc: '', args: []);
  }

  String get Create_Playlist {
    return Intl.message(
      'Create Playlist',
      name: 'Create_Playlist',
      desc: '',
      args: [],
    );
  }

  String get Playlist_Name {
    return Intl.message(
      'Playlist Name',
      name: 'Playlist_Name',
      desc: '',
      args: [],
    );
  }

  String get Create {
    return Intl.message('Create', name: 'Create', desc: '', args: []);
  }

  String get Import_Playlist {
    return Intl.message(
      'Import Playlist',
      name: 'Import_Playlist',
      desc: '',
      args: [],
    );
  }

  String get Import {
    return Intl.message('Import', name: 'Import', desc: '', args: []);
  }

  String get Rename_Playlist {
    return Intl.message(
      'Rename Playlist',
      name: 'Rename_Playlist',
      desc: '',
      args: [],
    );
  }

  String get Done {
    return Intl.message('Done', name: 'Done', desc: '', args: []);
  }

  String get Cancel {
    return Intl.message('Cancel', name: 'Cancel', desc: '', args: []);
  }

  String get Confirm {
    return Intl.message('Confirm', name: 'Confirm', desc: '', args: []);
  }

  String get Yes {
    return Intl.message('Yes', name: 'Yes', desc: '', args: []);
  }

  String get No {
    return Intl.message('No', name: 'No', desc: '', args: []);
  }

  String get Show_More {
    return Intl.message('Show More', name: 'Show_More', desc: '', args: []);
  }

  String get Show_Less {
    return Intl.message('Show Less', name: 'Show_Less', desc: '', args: []);
  }

  String get Remove {
    return Intl.message('Remove', name: 'Remove', desc: '', args: []);
  }

  String get High {
    return Intl.message('High', name: 'High', desc: '', args: []);
  }

  String get Low {
    return Intl.message('Low', name: 'Low', desc: '', args: []);
  }

  String get Songs_Will_Start_Playing_Soon {
    return Intl.message(
      'Songs will start playing soon.',
      name: 'Songs_Will_Start_Playing_Soon',
      desc: '',
      args: [],
    );
  }

  String get Remove_Message {
    return Intl.message(
      'Are you sure you want to remove it?',
      name: 'Remove_Message',
      desc: '',
      args: [],
    );
  }

  String get Remove_From_YTMusic_Message {
    return Intl.message(
      'Are you sure you want to remove it from YTMusic?',
      name: 'Remove_From_YTMusic_Message',
      desc: '',
      args: [],
    );
  }

  String get Remove_All_History_Message {
    return Intl.message(
      'Are you sure you want to clear all history?',
      name: 'Remove_All_History_Message',
      desc: '',
      args: [],
    );
  }

  String get Copied_To_Clipboard {
    return Intl.message(
      'Copied to Clipboard',
      name: 'Copied_To_Clipboard',
      desc: '',
      args: [],
    );
  }

  String get No_Internet_Connection {
    return Intl.message(
      'No Internet Connection',
      name: 'No_Internet_Connection',
      desc: '',
      args: [],
    );
  }

  String get Go_To_Downloads {
    return Intl.message(
      'Go to Downloads',
      name: 'Go_To_Downloads',
      desc: '',
      args: [],
    );
  }

  String get Retry {
    return Intl.message('Retry', name: 'Retry', desc: '', args: []);
  }

  String get Playlist_Not_Available {
    return Intl.message(
      'Playlist not available',
      name: 'Playlist_Not_Available',
      desc: '',
      args: [],
    );
  }

  String get Confirm_Delete_All_Message {
    return Intl.message(
      'Are you sure you want to delete them?',
      name: 'Confirm_Delete_All_Message',
      desc: '',
      args: [],
    );
  }

  String get Downloading {
    return Intl.message('Downloading', name: 'Downloading', desc: '', args: []);
  }

  String get Restore_Missing_Songs {
    return Intl.message(
      'Restore Missing Songs',
      name: 'Restore_Missing_Songs',
      desc: '',
      args: [],
    );
  }

  String get Delete_All_Songs {
    return Intl.message(
      'Delete All Songs',
      name: 'Delete_All_Songs',
      desc: '',
      args: [],
    );
  }

  String get Download_Started {
    return Intl.message(
      'Download started...',
      name: 'Download_Started',
      desc: '',
      args: [],
    );
  }

  String get Restoring_Missing_Songs {
    return Intl.message(
      'Restoring Missing Songs...',
      name: 'Restoring_Missing_Songs',
      desc: '',
      args: [],
    );
  }

  String get Deleting_Songs {
    return Intl.message(
      'Deleting Songs...',
      name: 'Deleting_Songs',
      desc: '',
      args: [],
    );
  }

  String get In_Progress {
    return Intl.message('In Progress', name: 'In_Progress', desc: '', args: []);
  }

  String get Queued {
    return Intl.message('Queued', name: 'Queued', desc: '', args: []);
  }

  String QueuedCount(Object count) {
    return Intl.message(
      'Queued ($count)',
      name: 'QueuedCount',
      desc: '',
      args: [count],
    );
  }

  String get FileNotFound {
    return Intl.message(
      'File not found',
      name: 'FileNotFound',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'es'),
      Locale.fromSubtags(languageCode: 'hi'),
      Locale.fromSubtags(languageCode: 'it'),
      Locale.fromSubtags(languageCode: 'tr'),
      Locale.fromSubtags(languageCode: 'ur'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
