/// 音乐小程序的媒体扩展模型（AI 配音 / AI 翻唱）。
///
/// 这些接口走 applet 的 `/v1/tts/*` 同源代理，API Key 只存在 mp-service，
/// App 不保存任何第三方语音密钥。
library;

class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.name,
    this.description = '',
    this.owner = '',
    this.owned = false,
    this.sampleUrl = '',
  });

  final int id;
  final String name;
  final String description;
  final String owner;
  final bool owned;
  final String sampleUrl;

  factory TtsVoice.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return TtsVoice(
      id: _int(map['id']),
      name: _str(map['name']),
      description: _str(map['description']),
      owner: _str(map['owner']),
      owned: map['owned'] == true,
      sampleUrl: _str(map['sample_url']),
    );
  }
}

class CoverSong {
  const CoverSong({
    required this.id,
    required this.title,
    required this.duration,
    this.separated = false,
  });

  final int id;
  final String title;
  final double duration;
  final bool separated;

  factory CoverSong.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return CoverSong(
      id: _int(map['id']),
      title: _str(map['title']),
      duration: _double(map['duration']),
      separated: map['separated'] == true,
    );
  }

  String get artist {
    final i = title.indexOf(' - ');
    return i > 0 ? title.substring(0, i) : '';
  }

  String get displayTitle {
    final i = title.indexOf(' - ');
    return i > 0 ? title.substring(i + 3) : title;
  }
}

class CoverWork {
  const CoverWork({
    required this.id,
    required this.title,
    this.voiceName = '',
    this.duration = 0,
    this.createdAt = '',
    this.ready = false,
  });

  final int id;
  final String title;
  final String voiceName;
  final double duration;
  final String createdAt;
  final bool ready;

  factory CoverWork.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return CoverWork(
      id: _int(map['id']),
      title: _str(map['title']),
      voiceName: _str(map['voice_name']),
      duration: _double(map['duration']),
      createdAt: _str(map['created_at']),
      ready: map['ready'] == true,
    );
  }

  String get audioUrl =>
      'https://applet.ssemarket.cn/v1/tts/covers/$id/audio';

  String get artist {
    final i = title.indexOf(' - ');
    return i > 0 ? title.substring(0, i) : '';
  }

  String get displayTitle {
    final i = title.indexOf(' - ');
    return i > 0 ? title.substring(i + 3) : title;
  }
}

class TtsJob {
  const TtsJob({
    required this.id,
    required this.status,
    this.progress = 0,
    this.message = '',
    this.error = '',
    this.queueAhead = 0,
  });

  final int id;
  final String status;
  final double progress;
  final String message;
  final String error;
  final int queueAhead;

  bool get done => const <String>{'success', 'succeeded', 'done', 'completed'}
      .contains(status);
  bool get failed =>
      const <String>{'failed', 'error', 'cancelled'}.contains(status);

  factory TtsJob.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return TtsJob(
      id: _int(map['job_id'] ?? map['id']),
      status: _str(map['status']),
      progress: _double(map['progress']),
      message: _str(map['message']),
      error: _str(map['error']),
      queueAhead: _int(map['queue_ahead']),
    );
  }
}

class CoverJob {
  const CoverJob({
    required this.id,
    required this.status,
    this.progress = 0,
    this.message = '',
    this.error = '',
  });

  final int id;
  final String status;
  final double progress;
  final String message;
  final String error;

  bool get done => status == 'completed' || status == 'success' || status == 'done';
  bool get failed => status == 'failed' || status == 'error';

  factory CoverJob.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return CoverJob(
      id: _int(map['cover_id'] ?? map['id']),
      status: _str(map['status']),
      progress: _double(map['progress']),
      message: _str(map['message']),
      error: _str(map['error']),
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _str(dynamic value) => value?.toString() ?? '';