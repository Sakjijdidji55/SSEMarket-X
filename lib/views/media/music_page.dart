import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/media_api.dart';
import 'package:sse_market_x/core/models/media_models.dart';
import 'package:sse_market_x/core/models/music_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/music_player_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

enum MusicMode { library, tts, cover }

/// 原生音乐页：音乐库 / AI 配音 / AI 翻唱，对齐 Web `MusicView.vue`。
class MusicPage extends StatefulWidget {
  const MusicPage({
    super.key,
    required this.apiService,
    this.initialMode = MusicMode.library,
  });

  final ApiService apiService;
  final MusicMode initialMode;

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final MediaApi _mediaApi = MediaApi();
  final MusicPlayerService _player = MusicPlayerService();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _ttsText = TextEditingController();

  late MusicMode _mode = widget.initialMode;

  // 音乐库
  List<MusicModel> _songs = const <MusicModel>[];
  bool _libraryLoading = true;
  bool _libraryLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  // AI 配音
  bool _ttsLoaded = false;
  bool _ttsLoading = false;
  List<TtsVoice> _voices = const <TtsVoice>[];
  int? _voiceId;
  double _speed = 1;
  String _ttsStatus = '';
  String _ttsError = '';
  MusicModel? _ttsResult;

  // AI 翻唱
  bool _coverLoaded = false;
  bool _coverLoading = false;
  List<CoverSong> _coverSongs = const <CoverSong>[];
  List<CoverWork> _coverWorks = const <CoverWork>[];
  int? _coverSongId;
  String _coverStatus = '';
  String _coverError = '';
  MusicModel? _coverResult;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    if (_mode == MusicMode.tts) unawaited(_loadTts());
    if (_mode == MusicMode.cover) unawaited(_loadCover());
  }

  @override
  void dispose() {
    _search.dispose();
    _ttsText.dispose();
    _mediaApi.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary({bool more = false}) async {
    if (more) {
      if (_libraryLoadingMore || !_hasMore) return;
      setState(() => _libraryLoadingMore = true);
    } else {
      setState(() {
        _libraryLoading = true;
        _offset = 0;
        _hasMore = true;
      });
    }
    try {
      final list = await widget.apiService.getMusicList(
        search: _search.text.trim(),
        limit: 20,
        offset: more ? _offset : 0,
      );
      if (!mounted) return;
      setState(() {
        _songs = more ? <MusicModel>[..._songs, ...list] : list;
        _offset = (more ? _offset : 0) + list.length;
        _hasMore = list.length >= 20;
        _libraryLoading = false;
        _libraryLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _libraryLoading = false;
        _libraryLoadingMore = false;
      });
    }
  }

  Future<void> _loadTts() async {
    if (_ttsLoaded) return;
    _ttsLoaded = true;
    setState(() => _ttsLoading = true);
    try {
      final results = await Future.wait(<Future<Object>>[
        _mediaApi.me(),
        _mediaApi.voices(),
      ]);
      if (!mounted) return;
      final voices = results[1] as List<TtsVoice>;
      setState(() {
        _voices = voices;
        _voiceId ??= voices.isEmpty ? null : voices.first.id;
        _ttsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ttsLoading = false;
        _ttsError = 'AI 配音服务暂时不可用';
      });
    }
  }

  Future<void> _loadCover() async {
    if (_coverLoaded) return;
    _coverLoaded = true;
    setState(() => _coverLoading = true);
    try {
      final results = await Future.wait(<Future<Object>>[
        _mediaApi.voices(),
        _mediaApi.songs(),
        _mediaApi.covers(limit: 6),
      ]);
      if (!mounted) return;
      final voices = results[0] as List<TtsVoice>;
      final songs = results[1] as List<CoverSong>;
      final works = results[2] as List<CoverWork>;
      setState(() {
        _voices = voices;
        _voiceId ??= voices.isEmpty ? null : voices.first.id;
        _coverSongs = songs;
        _coverWorks = works;
        _coverLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coverLoading = false;
        _coverError = '翻唱服务暂时不可用';
      });
    }
  }

  Future<void> _switchMode(MusicMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == MusicMode.tts) unawaited(_loadTts());
    if (mode == MusicMode.cover) unawaited(_loadCover());
  }

  Future<void> _playSong(MusicModel song) async {
    if (_player.current.value?.fileUrl == song.fileUrl &&
        _player.playing.value) {
      await _player.pause();
      return;
    }
    final ok = await _player.play(song);
    if (!ok && mounted) {
      _toast('音频播放失败，请稍后重试');
    }
  }

  Future<void> _previewVoice(TtsVoice voice) async {
    final ok = await _player.play(MusicModel(
      musicID: -1,
      title: '${voice.name} · 试听',
      artist: 'AI 音色',
      streamUrl: 'https://applet.ssemarket.cn/v1/tts/voices/${voice.id}/sample',
    ));
    if (!ok && mounted) _toast('音色试听失败');
  }

  Future<void> _generateTts() async {
    final text = _ttsText.text.trim();
    if (text.isEmpty) {
      setState(() => _ttsError = '请先输入要朗读的文字');
      return;
    }
    final voiceId = _voiceId;
    if (voiceId == null) {
      setState(() => _ttsError = '请选择一个音色');
      return;
    }
    setState(() {
      _ttsLoading = true;
      _ttsError = '';
      _ttsStatus = '正在提交合成任务…';
      _ttsResult = null;
    });
    try {
      final result = await _mediaApi.synthesize(
        voiceId: voiceId,
        text: text,
        speed: _speed,
      );
      Uint8List? audio = result.audio;
      if (!result.isAudio) {
        setState(() => _ttsStatus = '排队中…');
        audio = await _pollTts(result.jobId);
      }
      if (!mounted) return;
      final path = await _writeTemp(audio!, 'tts-${DateTime.now().millisecondsSinceEpoch}.wav');
      if (!mounted) return;
      setState(() {
        _ttsStatus = '合成完成';
        _ttsLoading = false;
        _ttsResult = MusicModel(
          musicID: -1,
          title: text.length > 30 ? '${text.substring(0, 30)}…' : text,
          artist: _voiceName(voiceId),
          streamUrl: path,
        );
      });
      await _player.play(_ttsResult!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ttsLoading = false;
        _ttsStatus = '';
        _ttsError = e is MediaApiException ? e.message : '语音合成失败，请稍后重试';
      });
    }
  }

  Future<Uint8List> _pollTts(int jobId) async {
    for (var i = 0; i < 150; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final job = await _mediaApi.ttsTask(jobId);
      if (!mounted) throw MediaApiException('页面已关闭');
      if (job.done) return _mediaApi.ttsAudio(jobId);
      if (job.failed) {
        throw MediaApiException(job.error.isEmpty ? '语音合成失败' : job.error);
      }
      setState(() {
        _ttsStatus = job.queueAhead > 0
            ? '排队中（前方 ${job.queueAhead} 个任务）'
            : '${job.message.isEmpty ? '正在合成…' : job.message}'
                '${job.progress > 0 ? ' · ${job.progress.round()}%' : ''}';
      });
    }
    throw MediaApiException('合成等待超时，请稍后重试');
  }

  Future<void> _generateCover() async {
    final songId = _coverSongId;
    final voiceId = _voiceId;
    if (songId == null) {
      setState(() => _coverError = '请选择一首歌');
      return;
    }
    if (voiceId == null) {
      setState(() => _coverError = '请选择一个 AI 音色');
      return;
    }
    setState(() {
      _coverLoading = true;
      _coverError = '';
      _coverStatus = '正在提交翻唱任务…';
      _coverResult = null;
    });
    try {
      final job = await _mediaApi.createCover(
        songId: songId,
        voiceId: voiceId,
      );
      final coverId = job.id;
      if (coverId <= 0) throw MediaApiException('翻唱任务创建失败');
      CoverJob status = job;
      for (var i = 0; i < 180; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        status = await _mediaApi.coverStatus(coverId);
        if (!mounted) throw MediaApiException('页面已关闭');
        if (status.done) break;
        if (status.failed) {
          throw MediaApiException(status.error.isEmpty ? '翻唱失败' : status.error);
        }
        setState(() {
          _coverStatus = status.message.isEmpty
              ? '正在生成翻唱${status.progress > 0 ? ' · ${status.progress.round()}%' : ''}'
              : status.message;
        });
      }
      if (!status.done) throw MediaApiException('翻唱等待超时，请稍后重试');
      final audio = await _mediaApi.coverAudio(coverId);
      final path = await _writeTemp(audio, 'cover-$coverId.mp3');
      final song = _coverSongs.firstWhere((s) => s.id == songId,
          orElse: () => const CoverSong(id: 0, title: 'AI 翻唱', duration: 0));
      if (!mounted) return;
      setState(() {
        _coverLoading = false;
        _coverStatus = '翻唱完成';
        _coverResult = MusicModel(
          musicID: -1,
          title: song.displayTitle,
          artist: _voiceName(voiceId),
          streamUrl: path,
        );
      });
      await _player.play(_coverResult!);
      final works = await _mediaApi.covers(limit: 6);
      if (mounted) setState(() => _coverWorks = works);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coverLoading = false;
        _coverStatus = '';
        _coverError = e is MediaApiException ? e.message : '翻唱失败，请稍后重试';
      });
    }
  }

  Future<String> _writeTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _voiceName(int id) {
    for (final voice in _voices) {
      if (voice.id == id) return voice.name;
    }
    return 'AI 音色';
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: context.textPrimaryColor),
        ),
        title: Text(
          '音乐',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: _ModeSwitch(mode: _mode, onChanged: _switchMode),
              ),
              Expanded(
                child: switch (_mode) {
                  MusicMode.library => _buildLibrary(),
                  MusicMode.tts => _buildTts(),
                  MusicMode.cover => _buildCover(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrary() {
    return RefreshIndicator(
      onRefresh: () => _loadLibrary(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: <Widget>[
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadLibrary(),
            decoration: InputDecoration(
              hintText: '搜索歌曲 / 歌手 / 专辑',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: context.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.dividerColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_libraryLoading)
            _SkeletonList(rows: 6)
          else if (_songs.isEmpty)
            _EmptyState(
              icon: Icons.library_music_rounded,
              title: '还没有音乐',
              hint: '去 Web 端上传第一首吧',
            )
          else ...<Widget>[
            for (final song in _songs)
              _LibraryRow(
                song: song,
                onTap: () => _playSong(song),
              ),
            if (_hasMore)
              Center(
                child: TextButton(
                  onPressed: () => _loadLibrary(more: true),
                  child: _libraryLoadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('加载更多'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTts() {
    if (_ttsLoading && _voices.isEmpty) {
      return const _SkeletonList(rows: 6);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: <Widget>[
        _Panel(
          title: '选择音色',
          child: SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _voices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final voice = _voices[index];
                final active = voice.id == _voiceId;
                return GestureDetector(
                  onTap: () => setState(() => _voiceId = voice.id),
                  onLongPress: () => _previewVoice(voice),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary.withOpacity(0.08)
                          : context.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : context.dividerColor,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.12),
                          child: Text(
                            voice.name.isEmpty ? '音' : voice.name[0],
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(voice.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimaryColor)),
                              Text(voice.owned ? '我的音色' : '公开音色',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: context.textTertiaryColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _Panel(
          title: '朗读文字',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _ttsText,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                decoration: InputDecoration(
                  hintText: '输入要朗读的文字…',
                  filled: true,
                  fillColor: context.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.dividerColor),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Text('语速',
                      style: TextStyle(
                          fontSize: 12, color: context.textSecondaryColor)),
                  Expanded(
                    child: Slider(
                      value: _speed,
                      min: 0.5,
                      max: 2,
                      divisions: 15,
                      label: _speed.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _speed = v),
                    ),
                  ),
                  Text('${_speed.toStringAsFixed(1)}x',
                      style: TextStyle(
                          fontSize: 12, color: context.textSecondaryColor)),
                ],
              ),
            ],
          ),
        ),
        if (_ttsError.isNotEmpty) _ErrorText(text: _ttsError),
        if (_ttsStatus.isNotEmpty) _StatusText(text: _ttsStatus),
        _PrimaryButton(
          label: _ttsLoading ? '正在合成…' : '生成语音',
          loading: _ttsLoading,
          onTap: _ttsLoading ? null : _generateTts,
        ),
        if (_ttsResult != null) ...<Widget>[
          const SizedBox(height: 12),
          _ResultCard(
            title: '合成结果',
            subtitle: '${_ttsResult!.artist} · 本地试听',
            onPlay: () => _player.play(_ttsResult!),
          ),
        ],
        const SizedBox(height: 10),
        Text('长按音色可以试听 · 合成由 Voice Studio 提供',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10.5, color: context.textTertiaryColor)),
      ],
    );
  }

  Widget _buildCover() {
    if (_coverLoading && _coverSongs.isEmpty) {
      return const _SkeletonList(rows: 6);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: <Widget>[
        _Panel(
          title: '选择音色',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final voice in _voices)
                ChoiceChip(
                  label: Text(voice.name),
                  selected: voice.id == _voiceId,
                  onSelected: (_) => setState(() => _voiceId = voice.id),
                ),
            ],
          ),
        ),
        _Panel(
          title: '选择歌曲',
          child: Column(
            children: <Widget>[
              for (final song in _coverSongs)
                _CoverSongRow(
                  song: song,
                  selected: song.id == _coverSongId,
                  onTap: () => setState(() => _coverSongId = song.id),
                ),
            ],
          ),
        ),
        if (_coverError.isNotEmpty) _ErrorText(text: _coverError),
        if (_coverStatus.isNotEmpty) _StatusText(text: _coverStatus),
        _PrimaryButton(
          label: _coverLoading ? '正在生成翻唱…' : '生成翻唱',
          loading: _coverLoading,
          onTap: _coverLoading ? null : _generateCover,
        ),
        if (_coverResult != null) ...<Widget>[
          const SizedBox(height: 12),
          _ResultCard(
            title: '翻唱结果',
            subtitle: '${_coverResult!.artist} · 本地试听',
            onPlay: () => _player.play(_coverResult!),
          ),
        ],
        if (_coverWorks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text('我的翻唱',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 6),
          for (final work in _coverWorks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFEF3C7),
                child: const Icon(Icons.album_rounded,
                    color: Color(0xFFB45309), size: 20),
              ),
              title: Text(work.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor)),
              subtitle: Text(
                  '${work.voiceName.isEmpty ? 'AI 音色' : work.voiceName} · ${_duration(work.duration.round())}',
                  style: TextStyle(
                      fontSize: 10.5, color: context.textTertiaryColor)),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: Color(0xFFEC4141)),
                onPressed: () => _player.play(MusicModel(
                  musicID: -1,
                  title: work.displayTitle,
                  artist: work.voiceName,
                  streamUrl: work.audioUrl,
                )),
              ),
            ),
        ],
        const SizedBox(height: 10),
        Text('整首合成可能需要几分钟 · 生成完成可在这里试听',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10.5, color: context.textTertiaryColor)),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final MusicMode mode;
  final ValueChanged<MusicMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = <(MusicMode, String, IconData)>[
      (MusicMode.library, '音乐库', Icons.library_music_rounded),
      (MusicMode.tts, 'AI 配音', Icons.mic_rounded),
      (MusicMode.cover, 'AI 翻唱', Icons.auto_awesome_rounded),
    ];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          for (final item in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(item.$1),
                child: Container(
                  decoration: BoxDecoration(
                    color: mode == item.$1
                        ? context.surfaceColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: mode == item.$1
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(item.$3,
                          size: 15,
                          color: mode == item.$1
                              ? context.textPrimaryColor
                              : context.textSecondaryColor),
                      const SizedBox(width: 4),
                      Text(item.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: mode == item.$1
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: mode == item.$1
                                ? context.textPrimaryColor
                                : context.textSecondaryColor,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.song,
    required this.onTap,
  });

  final MusicModel song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MusicModel?>(
      valueListenable: MusicPlayerService().current,
      builder: (context, current, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: MusicPlayerService().playing,
          builder: (context, playing, __) {
            final active = current?.fileUrl == song.fileUrl && playing;
            return _row(context, active);
          },
        );
      },
    );
  }

  Widget _row(BuildContext context, bool playing) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: song.coverUrl != null
                  ? CachedImage(
                      imageUrl: song.coverUrl!,
                      width: 46,
                      height: 46,
                      category: CacheCategory.music,
                      errorWidget: _fallback(context),
                    )
                  : _fallback(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimaryColor)),
                  const SizedBox(height: 3),
                  Text(
                      '${song.artist.isEmpty ? '未知歌手' : song.artist} · ${_duration(song.durationSec)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: context.textTertiaryColor)),
                ],
              ),
            ),
            Icon(
              playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 30,
              color: const Color(0xFFEC4141),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      color: context.backgroundColor,
      child: Icon(Icons.music_note_rounded,
          color: context.textTertiaryColor),
    );
  }
}

class _CoverSongRow extends StatelessWidget {
  const _CoverSongRow({
    required this.song,
    required this.selected,
    required this.onTap,
  });

  final CoverSong song;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? const Color(0xFFEC4141).withOpacity(0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFCE7F3), Color(0xFFFBCFE8)],
                ),
              ),
              child: const Icon(Icons.music_note_rounded,
                  size: 18, color: Color(0xFFBE185D)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(song.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimaryColor)),
                  Text(song.artist.isEmpty ? '未知歌手' : song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: context.textTertiaryColor)),
                ],
              ),
            ),
            Text(_duration(song.duration.round()),
                style: TextStyle(
                    fontSize: 11.5,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                    color: context.textTertiaryColor)),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 20,
              color: selected
                  ? const Color(0xFFEC4141)
                  : context.textTertiaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEC4141),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11)),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEC4141).withOpacity(0.1),
            child: const Icon(Icons.play_arrow_rounded,
                color: Color(0xFFEC4141)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: context.textTertiaryColor)),
              ],
            ),
          ),
          TextButton(onPressed: onPlay, child: const Text('播放')),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: context.textSecondaryColor)),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: <Widget>[
        for (var i = 0; i < rows; i++) ...<Widget>[
          Container(
            height: 58,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 42, color: context.textTertiaryColor),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 4),
          Text(hint,
              style: TextStyle(
                  fontSize: 12, color: context.textTertiaryColor)),
        ],
      ),
    );
  }
}

String _duration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}