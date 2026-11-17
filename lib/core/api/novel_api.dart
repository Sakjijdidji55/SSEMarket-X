import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:sse_market_x/core/models/novel_models.dart';
import 'package:sse_market_x/core/services/storage_service.dart';

/// 小说接口（对齐 Web `src/api/novel/*`）。
class NovelApi {
  NovelApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://ssemarket.cn/api';

  final http.Client _client;

  Future<({List<NovelItem> novels, int total})> getNovels({
    String keyword = '',
    String category = '',
    String status = '',
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _postData('/auth/novel/list', <String, dynamic>{
      'keyword': keyword,
      'category': category,
      'status': status,
      'limit': limit,
      'offset': offset,
    });
    return _novels(data);
  }

  Future<({List<NovelItem> novels, int total})> getShelf({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _postData('/auth/novel/shelf/list', <String, dynamic>{
      'limit': limit,
      'offset': offset,
    });
    return _novels(data);
  }

  Future<List<NovelCategory>> getCategories() async {
    final data = await _postData('/auth/novel/categories', <String, dynamic>{});
    if (data is List) {
      return data.map(NovelCategory.fromDynamic).toList(growable: false);
    }
    final list = data is Map ? data['categories'] : null;
    return list is List
        ? list.map(NovelCategory.fromDynamic).toList(growable: false)
        : const <NovelCategory>[];
  }

  Future<NovelItem?> getNovelDetail(int novelID) async {
    final data = await _postData('/auth/novel/detail', <String, dynamic>{
      'novelID': novelID,
    });
    return data is Map ? NovelItem.fromDynamic(data) : null;
  }

  Future<({List<NovelChapter> chapters, int total})> getChapters(
    int novelID, {
    int limit = 200,
    int offset = 0,
  }) async {
    final data = await _postData('/auth/novel/chapters', <String, dynamic>{
      'novelID': novelID,
      'limit': limit,
      'offset': offset,
    });
    final map = data is Map ? data : const <String, dynamic>{};
    final list = map['chapters'];
    return (
      chapters: list is List
          ? list.map(NovelChapter.fromDynamic).toList(growable: false)
          : const <NovelChapter>[],
      total: _int(map['total']),
    );
  }


  Future<({List<NovelItem> novels, int total})> getMyNovels({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _postData('/auth/novel/mine', <String, dynamic>{
      'limit': limit,
      'offset': offset,
    });
    return _novels(data);
  }

  Future<int?> createNovel({
    required String title,
    String intro = '',
    String category = '',
    String coverURL = '',
  }) async {
    final data = await _postData('/auth/novel/create', <String, dynamic>{
      'title': title,
      'intro': intro,
      'category': category,
      'coverURL': coverURL,
    });
    if (data is Map) {
      final id = _int(data['novelID'] ?? data['NovelID']);
      return id > 0 ? id : null;
    }
    return null;
  }

  Future<NovelChapter?> createChapter({
    required int novelID,
    required String title,
    required String content,
  }) async {
    final data = await _postData('/auth/novel/chapter/create', <String, dynamic>{
      'novelID': novelID,
      'title': title,
      'content': content,
    });
    return data is Map ? NovelChapter.fromDynamic(data) : null;
  }

  Future<NovelChapterDetail?> getChapter(int chapterID) async {
    final data = await _postData('/auth/novel/chapter', <String, dynamic>{
      'chapterID': chapterID,
    });
    return data is Map ? NovelChapterDetail.fromDynamic(data) : null;
  }

  Future<({List<NovelComment> comments, int total})> getComments({
    required int novelID,
    String targetType = '',
    int chapterID = 0,
    int paragraphIndex = 0,
    String keyword = '',
    String order = 'latest',
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _postData('/auth/novel/comment/list', <String, dynamic>{
      'novelID': novelID,
      'targetType': targetType,
      'chapterID': chapterID,
      'paragraphIndex': paragraphIndex,
      'keyword': keyword,
      'order': order,
      'limit': limit,
      'offset': offset,
    });
    final map = data is Map ? data : const <String, dynamic>{};
    final list = map['comments'];
    return (
      comments: list is List
          ? list.map(NovelComment.fromDynamic).toList(growable: false)
          : const <NovelComment>[],
      total: _int(map['total']),
    );
  }

  Future<NovelComment?> createComment({
    required int novelID,
    required String targetType,
    required String content,
    int chapterID = 0,
    int paragraphIndex = 0,
  }) async {
    final data = await _postData('/auth/novel/comment/create', <String, dynamic>{
      'novelID': novelID,
      'targetType': targetType,
      'chapterID': chapterID,
      'paragraphIndex': paragraphIndex,
      'content': content,
    });
    return data is Map ? NovelComment.fromDynamic(data) : null;
  }

  Future<bool> likeComment(int commentID) async {
    final data =
        await _postData('/auth/novel/comment/like', <String, dynamic>{
      'commentID': commentID,
    });
    return data != null;
  }

  Future<bool> deleteComment(int commentID) async {
    final data =
        await _postData('/auth/novel/comment/delete', <String, dynamic>{
      'commentID': commentID,
    });
    return data != null;
  }

  Future<({bool onShelf, String msg})?> toggleShelf(int novelID) async {
    final data = await _postData('/auth/novel/shelf/toggle', <String, dynamic>{
      'novelID': novelID,
    });
    if (data is! Map) return null;
    return (
      onShelf: data['onShelf'] == true || data['OnShelf'] == true,
      msg: data['msg']?.toString() ?? '',
    );
  }

  Future<({bool changed, double ratingAvg, int ratingCount, String msg})?>
      rateNovel(int novelID, int score) async {
    final data = await _postData('/auth/novel/rate', <String, dynamic>{
      'novelID': novelID,
      'score': score,
    });
    if (data is! Map) return null;
    return (
      changed: data['changed'] == true,
      ratingAvg: _double(data['ratingAvg']),
      ratingCount: _int(data['ratingCount']),
      msg: data['msg']?.toString() ?? '已评分',
    );
  }

  Future<bool> reportProgress({
    required int novelID,
    required int chapterID,
    required int paragraphIndex,
    required double percent,
    int readSeconds = 0,
  }) async {
    final data = await _postData('/auth/novel/progress/report', <String, dynamic>{
      'novelID': novelID,
      'chapterID': chapterID,
      'paragraphIndex': paragraphIndex,
      'percent': percent,
      'readSeconds': readSeconds,
    });
    return data != null;
  }

  Future<NovelPointsSummary?> getPointsSummary() async {
    final data =
        await _postData('/auth/novel/points/summary', <String, dynamic>{});
    return data is Map ? NovelPointsSummary.fromDynamic(data) : null;
  }

  Future<({List<NovelLedgerItem> items, int total})> getLedger({
    int limit = 30,
    int offset = 0,
  }) async {
    final data = await _postData('/auth/novel/points/ledger', <String, dynamic>{
      'limit': limit,
      'offset': offset,
    });
    final map = data is Map ? data : const <String, dynamic>{};
    final list = map['items'];
    return (
      items: list is List
          ? list.map(NovelLedgerItem.fromDynamic).toList(growable: false)
          : const <NovelLedgerItem>[],
      total: _int(map['total']),
    );
  }

  Future<NovelCheckInResult?> checkIn() async {
    final data =
        await _postData('/auth/novel/points/checkin', <String, dynamic>{});
    if (data is Map && data['data'] is Map) {
      return NovelCheckInResult.fromDynamic(data['data']);
    }
    return data is Map ? NovelCheckInResult.fromDynamic(data) : null;
  }

  Future<dynamic> _postData(String path, Map<String, dynamic> body) async {
    final token = StorageService().token;
    if (token.isEmpty) return null;
    final response = await _client
        .post(
          Uri.parse('$_base$path'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) {
      final data = decoded['data'];
      if (data != null) return data;
    }
    return decoded;
  }

  ({List<NovelItem> novels, int total}) _novels(dynamic data) {
    final map = data is Map ? data : const <String, dynamic>{};
    final list = map['novels'];
    return (
      novels: list is List
          ? list.map(NovelItem.fromDynamic).toList(growable: false)
          : const <NovelItem>[],
      total: _int(map['total']),
    );
  }

  void dispose() => _client.close();
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}