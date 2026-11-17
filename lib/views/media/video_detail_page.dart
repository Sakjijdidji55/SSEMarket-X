import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/video_api.dart';
import 'package:sse_market_x/core/models/video_model.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 原生视频详情，对齐 Web `VideoDetailView.vue`。
///
/// - 本站 mp4/hls 用 `video_player`；
/// - B 站视频在 Android/iOS 用内嵌 WebView，其它平台回退到浏览器；
/// - 播放开始时只上报一次播放量。
class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.apiService,
    required this.video,
  });

  final ApiService apiService;
  final VideoItem video;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final VideoApi _api = VideoApi();

  VideoPlayerController? _controller;
  WebViewController? _webController;
  bool _loading = true;
  String? _error;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final video = widget.video;
    try {
      if (video.isSelfHosted && video.sourceURL.isNotEmpty) {
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(video.sourceURL));
        _controller = controller;
        await controller.initialize();
        controller.addListener(_onPlayerChanged);
        if (!mounted) return;
        setState(() => _loading = false);
        await controller.play();
      } else if (video.isBilibili &&
          (Platform.isAndroid || Platform.isIOS)) {
        final bvid = video.bilibiliBVID;
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF000000))
          ..setNavigationDelegate(NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted) return;
              setState(() => _loading = false);
              _recordPlayed();
            },
          ))
          ..loadRequest(Uri.parse(
              'https://player.bilibili.com/player.html?bvid=$bvid&autoplay=0'));
        _webController = controller;
        if (mounted) setState(() => _loading = false);
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '视频加载失败，请稍后重试';
      });
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying && controller.value.position > Duration.zero) {
      _recordPlayed();
    }
  }

  void _recordPlayed() {
    if (_recorded) return;
    _recorded = true;
    unawaited(_api.recordPlayed(widget.video.videoID));
  }

  Future<void> _openExternal() async {
    final url = widget.video.externalPageURL.isNotEmpty
        ? widget.video.externalPageURL
        : widget.video.sourceURL;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
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
          '视频',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: const Color(0xFF0F172A),
                    child: _buildPlayer(video),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                video.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: <Widget>[
                  Text(
                    video.isBilibili ? 'B站视频' : '本站视频',
                    style: TextStyle(
                        fontSize: 13, color: context.textSecondaryColor),
                  ),
                  if (video.publishedAt.isNotEmpty)
                    Text(
                      _date(video.publishedAt),
                      style: TextStyle(
                          fontSize: 13, color: context.textSecondaryColor),
                    ),
                  Text(
                    '${video.playCount} 次播放',
                    style: TextStyle(
                        fontSize: 13, color: context.textTertiaryColor),
                  ),
                  if (video.isBilibili && video.externalPageURL.isNotEmpty)
                    GestureDetector(
                      onTap: _openExternal,
                      child: const Text(
                        '去 B 站观看',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E)),
                      ),
                    ),
                ],
              ),
              if (video.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  video.description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(VideoItem video) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded,
                color: Colors.white54, size: 36),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _openExternal,
              child: const Text('打开来源页面'),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.only(bottom: 0),
            colors: const VideoProgressColors(
              playedColor: Color(0xFF0F766E),
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: _RoundControl(
              icon: controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: () {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              },
            ),
          ),
        ],
      );
    }

    final web = _webController;
    if (web != null) {
      return WebViewWidget(controller: web);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.open_in_browser_rounded,
              color: Colors.white54, size: 38),
          const SizedBox(height: 8),
          const Text(
            '当前平台暂不支持内嵌播放',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _openExternal,
            child: const Text('在浏览器打开'),
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

String _date(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  final local = d.toLocal();
  return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}