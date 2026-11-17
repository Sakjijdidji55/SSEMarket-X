import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:sse_market_x/core/models/resume_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';

class ResumeApi {
  ResumeApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://ssemarket.cn/api';

  final http.Client _client;

  Future<List<ResumeItem>> getResumes({
    String sort = 'home',
    String search = '',
  }) async {
    final data = await _postData('/auth/resume/list', <String, dynamic>{
      'searchinfo': search,
      'searchsort': sort,
      'limit': 200,
      'offset': 0,
    });
    final list = _listFrom(data);
    return list.map(ResumeItem.fromDynamic).toList(growable: false);
  }

  Future<ResumeItem?> getDetail(int id) async {
    final data =
        await _postData('/auth/resume/detail', <String, dynamic>{'resumeID': id});
    return data is Map ? ResumeItem.fromDynamic(data) : null;
  }

  Future<ResumeItem?> update(
      int id, String title, String description) async {
    final data = await _postData('/auth/resume/update', <String, dynamic>{
      'resumeID': id,
      'title': title,
      'description': description,
    });
    return data is Map ? ResumeItem.fromDynamic(data) : null;
  }

  Future<bool> delete(int id) async {
    final data =
        await _postData('/auth/resume/delete', <String, dynamic>{'resumeID': id});
    return data != null;
  }

  Future<Uint8List?> downloadBytes(int id) async {
    final token = StorageService().token;
    if (token.isEmpty) return null;
    final response = await _client.get(
      Uri.parse('$_base/auth/resume/preview/stream/$id'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  }

  Future<int?> upload({
    required File file,
    required String fileName,
    required String title,
    required String description,
    required bool isAnonymous,
  }) async {
    final token = StorageService().token;
    if (token.isEmpty) return null;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/auth/resume/upload'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['isAnonymous'] = isAnonymous ? 'true' : 'false'
      ..files.add(await http.MultipartFile.fromPath('file', file.path,
          filename: fileName));
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) {
      if (decoded['code'] != null && decoded['code'] != 200) return null;
      final data = decoded['data'];
      if (data is Map) {
        final id = data['resumeID'] ?? data['ResumeID'];
        return int.tryParse(id?.toString() ?? '');
      }
    }
    return null;
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
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map && decoded['data'] != null) return decoded['data'];
    return decoded;
  }

  List<dynamic> _listFrom(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in <String>['list', 'resumes', 'data']) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const <dynamic>[];
  }

  void dispose() => _client.close();
}