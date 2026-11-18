import 'package:sse_market_x/core/models/media_models.dart';
import 'package:sse_market_x/core/models/music_model.dart';

/// 媒体页的内存缓存（App 进程内有效）。
///
/// 目的：第二次打开音乐/媒体页时先显示上次内容，再后台刷新；
/// 不是离线数据库，跨进程冷启动仍会重新请求。
class MediaCacheStore {
  MediaCacheStore._();

  static final MediaCacheStore instance = MediaCacheStore._();

  List<MusicModel> songs = const <MusicModel>[];
  List<CoverWork> covers = const <CoverWork>[];
  List<TtsVoice> voices = const <TtsVoice>[];
  List<CoverSong> coverSongs = const <CoverSong>[];
  List<CoverWork> coverWorks = const <CoverWork>[];
  Map<String, dynamic>? me;

  bool get hasHubData => songs.isNotEmpty || covers.isNotEmpty;
  bool get hasMusicData => songs.isNotEmpty;
  bool get hasTtsData => voices.isNotEmpty;
  bool get hasCoverData => voices.isNotEmpty || coverSongs.isNotEmpty;
}