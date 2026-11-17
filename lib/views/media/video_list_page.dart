import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/video_api.dart';
import 'package:sse_market_x/core/models/video_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/media/video_detail_page.dart';

/// 原生视频列表，对齐 Web `VideoView.vue`。
class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  final VideoApi _api = VideoApi();
  final TextEditingController _search = TextEditingController();

  List<VideoItem> _videos = const <VideoItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final result = await _api.getVideos(
        page: reset ? 1 : _page + 1,
        keyword: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _videos = reset ? result.list : <VideoItem>[..._videos, ...result.list];
        _page = reset ? 1 : _page + 1;
        _hasMore = _videos.length < result.total && result.list.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '视频加载失败，请稍后重试';
      });
    }
  }

  void _openVideo(VideoItem video) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VideoDetailPage(
          apiService: widget.apiService,
          video: video,
        ),
      ),
    );
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
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHead()),
                if (_loading)
                  SliverToBoxAdapter(child: _skeleton())
                else if (_error != null)
                  SliverToBoxAdapter(child: _errorState())
                else if (_videos.isEmpty)
                  SliverToBoxAdapter(child: _empty())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 360,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final video = _videos[index];
                          return _VideoCard(
                            video: video,
                            onTap: () => _openVideo(video),
                          );
                        },
                        childCount: _videos.length,
                      ),
                    ),
                  ),
                if (_hasMore && !_loading && _videos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: TextButton(
                        onPressed: () => _load(),
                        child: _loadingMore
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('加载更多'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '视频',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '本站视频与 B 站视频合集',
            style: TextStyle(
                fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(reset: true),
            decoration: InputDecoration(
              hintText: '搜索视频',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: context.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.dividerColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: <Widget>[
          Icon(Icons.videocam_off_rounded,
              size: 42, color: context.textTertiaryColor),
          const SizedBox(height: 10),
          Text('暂无视频',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded,
              size: 42, color: context.textTertiaryColor),
          const SizedBox(height: 10),
          Text(_error ?? '加载失败',
              style: TextStyle(
                  fontSize: 14, color: context.textSecondaryColor)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => _load(reset: true), child: const Text('重试')),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: video.coverURL.isEmpty
                  ? Container(
                      color: const Color(0xFF0F172A),
                      child: const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white54, size: 40),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        CachedImage(
                          imageUrl: video.coverURL,
                          fit: BoxFit.cover,
                          category: CacheCategory.other,
                          errorWidget: Container(
                            color: const Color(0xFF0F172A),
                            child: const Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white54, size: 40),
                          ),
                        ),
                        const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white70, size: 42),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${video.isBilibili ? 'B站视频' : '本站视频'} · ${video.playCount} 次播放',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: context.textTertiaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}