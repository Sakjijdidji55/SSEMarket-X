import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/media_api.dart';
import 'package:sse_market_x/core/miniprogram/mini_program_runtime.dart';
import 'package:sse_market_x/core/models/media_models.dart';
import 'package:sse_market_x/core/models/music_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/media_cache_store.dart';
import 'package:sse_market_x/core/services/music_player_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/media/music_page.dart';

/// 原生「音乐视频」首页，对齐 Web `MediaHubView.vue`。
class MediaHubPage extends StatefulWidget {
  const MediaHubPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<MediaHubPage> createState() => _MediaHubPageState();
}

class _MediaHubPageState extends State<MediaHubPage> {
  final MediaApi _mediaApi = MediaApi();

  List<MusicModel> _songs = const <MusicModel>[];
  List<CoverWork> _covers = const <CoverWork>[];
  bool _loadingSongs = true;

  @override
  void initState() {
    super.initState();
    final cache = MediaCacheStore.instance;
    if (cache.songs.isNotEmpty) {
      _songs = cache.songs;
      _loadingSongs = false;
    }
    if (cache.covers.isNotEmpty) _covers = cache.covers;
    _load();
  }

  @override
  void dispose() {
    _mediaApi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final songs =
          await widget.apiService.getMusicList(limit: 4, offset: 0);
      if (!mounted) return;
      MediaCacheStore.instance.songs = songs;
      setState(() {
        _songs = songs;
        _loadingSongs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSongs = false);
    }

    try {
      final covers = await _mediaApi.covers(limit: 3);
      if (!mounted) return;
      MediaCacheStore.instance.covers = covers;
      setState(() => _covers = covers);
    } catch (_) {
      // 翻唱是增强功能，失败不影响入口。
    }
  }

  Future<void> _openMusic(MusicMode mode) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MusicPage(
          apiService: widget.apiService,
          initialMode: mode,
        ),
      ),
    );
  }

  void _openVideo() {
    // 视频页先回退 Vue 小程序：直接打开 media 小程序的 /video 路由。
    // 低频页面不值得为它常驻 video_player 插件。
    MiniProgramRuntime().openByKey('media', path: 'video');
  }

  Future<void> _playSong(MusicModel song) async {
    final ok = await MusicPlayerService().play(song);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音频播放失败，请稍后重试')),
      );
    }
  }

  Future<void> _playCover(CoverWork cover) async {
    final ok = await MusicPlayerService().play(
      MusicModel(
        musicID: -1,
        title: cover.displayTitle,
        artist: cover.voiceName.isEmpty ? 'AI 翻唱' : cover.voiceName,
        streamUrl: cover.audioUrl,
      ),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('翻唱播放失败，请稍后重试')),
      );
    }
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
          '音乐视频',
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
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
              children: <Widget>[
                _buildHero(),
                _buildFeatureGrid(),
                _buildRecentSongs(),
                if (_covers.isNotEmpty) _buildCovers(),
                const SizedBox(height: 14),
                Text(
                  '音乐播放后切到主站看帖子也会继续 · AI 声音由 Voice Studio 提供',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF111827),
            Color(0xFF2B1B3D),
            Color(0xFF4A1D3D),
          ],
          stops: <double>[0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -70,
            top: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFFF472B6).withOpacity(0.55),
                    const Color(0xFFF472B6).withOpacity(0),
                  ],
                  stops: const <double>[0, 0.65],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.album_rounded,
                      size: 14, color: Color(0xFFF9A8D4)),
                  SizedBox(width: 6),
                  Text(
                    'MEDIA · VOICE',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF9A8D4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '音乐视频',
                style: TextStyle(
                  fontSize: 28,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '听歌、看视频，也可以把文字变成声音，用 AI 音色唱一首歌。',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: Colors.white.withOpacity(0.66),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _HeroButton(
                    label: '打开音乐库',
                    icon: Icons.play_arrow_rounded,
                    primary: true,
                    onTap: () => _openMusic(MusicMode.library),
                  ),
                  _HeroButton(
                    label: 'AI 配音',
                    icon: Icons.mic_rounded,
                    onTap: () => _openMusic(MusicMode.tts),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final items = <_FeatureItem>[
      _FeatureItem(
        title: '音乐库',
        desc: '播放、搜索、上传',
        icon: Icons.music_note_rounded,
        iconBg: const Color(0xFFFCE7F3),
        iconColor: const Color(0xFFBE185D),
        onTap: () => _openMusic(MusicMode.library),
      ),
      _FeatureItem(
        title: 'AI 配音',
        desc: '文字转语音 · 7 种音色',
        icon: Icons.mic_rounded,
        iconBg: const Color(0xFFE0E7FF),
        iconColor: const Color(0xFF4338CA),
        onTap: () => _openMusic(MusicMode.tts),
      ),
      _FeatureItem(
        title: 'AI 翻唱',
        desc: '用 AI 音色唱整首歌',
        icon: Icons.auto_awesome_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFB45309),
        onTap: () => _openMusic(MusicMode.cover),
      ),
      _FeatureItem(
        title: '视频',
        desc: '视频列表与播放',
        icon: Icons.videocam_rounded,
        iconBg: const Color(0xFFFFE4E6),
        iconColor: const Color(0xFFBE123C),
        onTap: _openVideo,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 4 : 2;
          final width =
              (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final item in items)
                SizedBox(width: width, child: _FeatureCard(item: item)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentSongs() {
    return _Section(
      title: '最近音乐',
      actionLabel: '全部',
      onAction: () => _openMusic(MusicMode.library),
      child: _loadingSongs
          ? Column(
              children: <Widget>[
                for (var i = 0; i < 3; i++) ...<Widget>[
                  Container(
                    height: 42,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: context.backgroundColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              ],
            )
          : _songs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '还没有音乐，去音乐库上传第一首吧',
                    style: TextStyle(
                        fontSize: 12, color: context.textTertiaryColor),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final song in _songs)
                      _SongRow(
                        title: song.title,
                        subtitle:
                            '${song.artist.isEmpty ? '未知歌手' : song.artist} · ${_duration(song.durationSec)}',
                        coverUrl: song.coverUrl,
                        onTap: () => _playSong(song),
                      ),
                  ],
                ),
    );
  }

  Widget _buildCovers() {
    return _Section(
      title: 'AI 翻唱作品',
      actionLabel: '去创作',
      onAction: () => _openMusic(MusicMode.cover),
      child: Column(
        children: <Widget>[
          for (final cover in _covers)
            _SongRow(
              title: cover.displayTitle,
              subtitle:
                  '${cover.voiceName.isEmpty ? 'AI 音色' : cover.voiceName} · ${_duration(cover.duration.round())}',
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                ),
                child: const Icon(Icons.album_rounded,
                    size: 20, color: Color(0xFFB45309)),
              ),
              onTap: () => _playCover(cover),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(actionLabel!,
                          style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiaryColor)),
                      Icon(Icons.chevron_right_rounded,
                          size: 15, color: context.textTertiaryColor),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.coverUrl,
    this.leading,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? coverUrl;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: leading ??
                  (coverUrl != null && coverUrl!.isNotEmpty
                      ? CachedImage(
                          imageUrl: coverUrl!,
                          width: 42,
                          height: 42,
                          category: CacheCategory.music,
                          errorWidget: _coverFallback(context),
                        )
                      : _coverFallback(context)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4141).withOpacity(0.08),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  size: 20, color: Color(0xFFEC4141)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      color: context.backgroundColor,
      child: Icon(Icons.music_note_rounded,
          size: 20, color: context.textTertiaryColor),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String desc;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 19, color: item.iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.desc,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? const Color(0xFFEC4141) : Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: primary
                ? null
                : Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _duration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}