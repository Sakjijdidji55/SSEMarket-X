import 'package:sse_market_x/core/models/novel_models.dart';

/// 小说页内存缓存（App 进程内有效）。
///
/// 先显示上次内容，再后台刷新；不是离线数据库，冷启动仍会重新请求。
class NovelCacheStore {
  NovelCacheStore._();

  static final NovelCacheStore instance = NovelCacheStore._();

  List<NovelCategory> categories = const <NovelCategory>[];
  final Map<String, ({List<NovelItem> novels, int total})> lists =
      <String, ({List<NovelItem> novels, int total})>{};
  final Map<int, NovelItem> details = <int, NovelItem>{};
  final Map<int, NovelChapterDetail> chapters = <int, NovelChapterDetail>{};
}