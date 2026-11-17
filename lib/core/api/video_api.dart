import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:sse_market_x/core/models/video_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';

/// 主站公开视频接口。
class VideoApi {
  VideoApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://ssemarket.cn/api';

  final http.Client _client;

  Future<VideoPageResult> getVideos({
    int page = 1,
    int pageSize = 12,
    String keyword = '',
  }) async {
    final uri = Uri.parse('$_base/auth/videos').replace(
      queryParameters: <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
        'keyword': keyword,
      },
    );
    final json = await _getJson(uri);
    final data = json['data'];
    return VideoPageResult.fromDynamic(data);
  }

  Future<VideoItem?> getVideo(int id) async {
    final json = await _getJson(Uri.parse('$_base/auth/videos/$id'));
    final data = json['data'];
    if (data is! Map) return null;
    final video = data['video'];
    return video is Map ? VideoItem.fromDynamic(video) : null;
  }

  Future<void> recordPlayed(int id) async {
    try {
      await _client
          .post(Uri.parse('$_base/auth/videos/$id/played'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final token = StorageService().token;
    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
  }

  void dispose() => _client.close();
}