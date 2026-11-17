/// 公开视频（对齐 Web `PublicVideo`）。
class VideoItem {
  const VideoItem({
    required this.videoID,
    required this.title,
    this.description = '',
    this.coverURL = '',
    this.sourceType = '',
    this.sourceURL = '',
    this.bilibiliBVID = '',
    this.externalPageURL = '',
    this.durationSec = 0,
    this.playCount = 0,
    this.publishedAt = '',
  });

  final int videoID;
  final String title;
  final String description;
  final String coverURL;
  final String sourceType;
  final String sourceURL;
  final String bilibiliBVID;
  final String externalPageURL;
  final int durationSec;
  final int playCount;
  final String publishedAt;

  bool get isBilibili => sourceType == 'bilibili';
  bool get isSelfHosted => sourceType == 'mp4' || sourceType == 'hls';

  factory VideoItem.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return VideoItem(
      videoID: _int(map['videoID']),
      title: _str(map['title']),
      description: _str(map['description']),
      coverURL: _str(map['coverURL']),
      sourceType: _str(map['sourceType']),
      sourceURL: _str(map['sourceURL']),
      bilibiliBVID: _str(map['bilibiliBVID']),
      externalPageURL: _str(map['externalPageURL']),
      durationSec: _int(map['durationSec']),
      playCount: _int(map['playCount']),
      publishedAt: _str(map['publishedAt']),
    );
  }
}

class VideoPageResult {
  const VideoPageResult({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<VideoItem> list;
  final int total;
  final int page;
  final int pageSize;

  factory VideoPageResult.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    final list = map['list'];
    return VideoPageResult(
      list: list is List
          ? list.map(VideoItem.fromDynamic).toList(growable: false)
          : const <VideoItem>[],
      total: _int(map['total']),
      page: _int(map['page']),
      pageSize: _int(map['pageSize']),
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _str(dynamic value) => value?.toString() ?? '';