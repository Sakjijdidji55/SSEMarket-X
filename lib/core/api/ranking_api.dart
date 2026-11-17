import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:sse_market_x/core/models/rank_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';

/// 排行榜接口。
///
/// 只读接口，挂在主站 `/auth/postRanking` 与 `/auth/userRanking`。
/// 与 Web 端 `src/api/rank/rank.ts` 保持同一套字段。
class RankingApi {
  RankingApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://ssemarket.cn/api';

  final http.Client _client;

  Future<List<PostRankItem>> getPostRanking() async {
    final list = await _getRanking('/auth/postRanking');
    return list.map(PostRankItem.fromDynamic).toList(growable: false);
  }

  Future<List<UserRankItem>> getUserRanking() async {
    final list = await _getRanking('/auth/userRanking');
    return list.map(UserRankItem.fromDynamic).toList(growable: false);
  }

  Future<List<dynamic>> _getRanking(String path) async {
    final token = StorageService().token;
    if (token.isEmpty) return const <dynamic>[];

    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return const <dynamic>[];

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return const <dynamic>[];
    if (decoded['code'] != null && decoded['code'] != 200) {
      return const <dynamic>[];
    }
    final data = decoded['data'];
    if (data is! Map) return const <dynamic>[];
    final ranking = data['ranking'];
    return ranking is List ? ranking : const <dynamic>[];
  }

  void dispose() => _client.close();
}