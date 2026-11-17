import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:sse_market_x/core/models/media_models.dart';

/// 音乐小程序媒体接口（AI 配音 / AI 翻唱）。
///
/// 全部走 applet 的 `/v1/tts/*` 同源代理；API Key 只在 mp-service 服务端，
/// App 不读取、不保存第三方语音密钥。
class MediaApi {
  MediaApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://applet.ssemarket.cn';

  final http.Client _client;

  Future<Map<String, dynamic>> me() => _getJson('/v1/tts/me');

  Future<List<TtsVoice>> voices({int limit = 30}) async {
    final json = await _getJson('/v1/tts/voices?limit=$limit');
    final list = json['voices'];
    if (list is! List) return const <TtsVoice>[];
    return list.map(TtsVoice.fromDynamic).toList(growable: false);
  }

  Future<List<CoverSong>> songs() async {
    final json = await _getJson('/v1/tts/songs');
    final list = json['songs'];
    if (list is! List) return const <CoverSong>[];
    return list.map(CoverSong.fromDynamic).toList(growable: false);
  }

  Future<List<CoverWork>> covers({int limit = 20}) async {
    final json = await _getJson('/v1/tts/covers?limit=$limit');
    final list = json['covers'];
    if (list is! List) return const <CoverWork>[];
    return list.map(CoverWork.fromDynamic).toList(growable: false);
  }

  /// 提交 TTS。返回 202 时是异步任务，返回 200 时直接是音频。
  Future<TtsSubmitResult> synthesize({
    required int voiceId,
    required String text,
    double speed = 1,
    String textLang = 'all_zh',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_base/v1/tts?timeout=60'),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'voice_id': voiceId,
            'text': text,
            'text_lang': textLang,
            'speed': speed,
          }),
        )
        .timeout(const Duration(seconds: 75));

    final type = response.headers['content-type'] ?? '';
    if (response.statusCode == 202) {
      final json = _decodeMap(response.bodyBytes);
      return TtsSubmitResult.job(_asInt(json['job_id'] ?? json['id']));
    }
    if (response.statusCode == 200 && type.startsWith('audio/')) {
      return TtsSubmitResult.audio(response.bodyBytes);
    }
    throw MediaApiException(_errorMessage(response));
  }

  Future<TtsJob> ttsTask(int jobId) async {
    final json = await _getJson('/v1/tts/tasks/$jobId');
    return TtsJob.fromDynamic(json);
  }

  Future<Uint8List> ttsAudio(int jobId) =>
      _getBytes('/v1/tts/tasks/$jobId/audio');

  Future<Uint8List> voiceSample(int voiceId) =>
      _getBytes('/v1/tts/voices/$voiceId/sample');

  Future<CoverJob> createCover({
    required int songId,
    required int voiceId,
    String synthesis = 'whole',
  }) async {
    final json = await _postJson('/v1/tts/covers', <String, dynamic>{
      'song_id': songId,
      'run_id': voiceId,
      'synthesis': synthesis,
    });
    return CoverJob.fromDynamic(json);
  }

  Future<CoverJob> coverStatus(int coverId) async {
    final json = await _getJson('/v1/tts/covers/$coverId');
    return CoverJob.fromDynamic(json);
  }

  Future<Uint8List> coverAudio(int coverId) =>
      _getBytes('/v1/tts/covers/$coverId/audio');

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _client
        .get(Uri.parse('$_base$path'),
            headers: <String, String>{'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaApiException(_errorMessage(response));
    }
    return _decodeMap(response.bodyBytes);
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$_base$path'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaApiException(_errorMessage(response));
    }
    return _decodeMap(response.bodyBytes);
  }

  Future<Uint8List> _getBytes(String path) async {
    final response = await _client
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 75));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaApiException(_errorMessage(response));
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _decodeMap(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  String _errorMessage(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map) {
        final message = json['message'] ?? json['detail'] ?? json['error'];
        if (message != null && message.toString().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {}
    return '媒体服务请求失败（${response.statusCode}）';
  }

  void dispose() => _client.close();
}

class TtsSubmitResult {
  const TtsSubmitResult({this.jobId = 0, this.audio});

  final int jobId;
  final Uint8List? audio;

  bool get isAudio => audio != null;

  factory TtsSubmitResult.job(int jobId) => TtsSubmitResult(jobId: jobId);

  factory TtsSubmitResult.audio(Uint8List bytes) =>
      TtsSubmitResult(audio: bytes);
}

class MediaApiException implements Exception {
  MediaApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}