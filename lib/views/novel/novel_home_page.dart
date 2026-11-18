import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/novel_api.dart';
import 'package:sse_market_x/core/models/novel_models.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/novel_cache_store.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/novel/novel_detail_page.dart';
import 'package:sse_market_x/views/novel/novel_points_page.dart';
import 'package:sse_market_x/views/novel/novel_write_page.dart';

const Color _novelAccent = Color(0xFF2C3D56);

/// 原生小说首页：发现 / 书架，对齐 Web `NovelView.vue`。
class NovelHomePage extends StatefulWidget {
  const NovelHomePage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<NovelHomePage> createState() => _NovelHomePageState();
}

class _NovelHomePageState extends State<NovelHomePage> {
  final NovelApi _api = NovelApi();
  final TextEditingController _search = TextEditingController();

  bool _shelf = false;
  List<NovelItem> _novels = const <NovelItem>[];
  List<NovelCategory> _categories = const <NovelCategory>[];
  String _category = '';
  int _total = 0;
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    if (NovelCacheStore.instance.categories.isNotEmpty) {
      _categories = NovelCacheStore.instance.categories;
    }
    _load(reset: true);
    _loadCategories();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _api.getCategories();
      NovelCacheStore.instance.categories = categories;
      if (mounted) setState(() => _categories = categories);
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    final cacheKey =
        '${_shelf ? 'shelf' : 'discover'}|$_category|${_search.text.trim()}';
    if (reset) {
      final cached = NovelCacheStore.instance.lists[cacheKey];
      if (cached != null && cached.novels.isNotEmpty) {
        setState(() {
          _novels = cached.novels;
          _total = cached.total;
          _offset = cached.novels.length;
          _hasMore = cached.novels.length < cached.total;
          _loading = false;
        });
      }
    }
    try {
      final result = _shelf
          ? await _api.getShelf(limit: 18, offset: reset ? 0 : _offset)
          : await _api.getNovels(
              keyword: _search.text.trim(),
              category: _category,
              limit: 18,
              offset: reset ? 0 : _offset,
            );
      if (!mounted) return;
      if (reset) {
        NovelCacheStore.instance.lists[cacheKey] = result;
      }
      setState(() {
        _novels = reset ? result.novels : <NovelItem>[..._novels, ...result.novels];
        _total = result.total;
        _offset = (reset ? 0 : _offset) + result.novels.length;
        _hasMore = _novels.length < _total && result.novels.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _selectTab(bool shelf) {
    if (_shelf == shelf) return;
    setState(() {
      _shelf = shelf;
      _category = '';
      _search.clear();
      _novels = const <NovelItem>[];
    });
    _load(reset: true);
  }

  void _selectCategory(String category) {
    if (_category == category) return;
    setState(() => _category = category);
    _load(reset: true);
  }

  void _openBook(NovelItem novel) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NovelDetailPage(
          apiService: widget.apiService,
          novelID: novel.novelID,
        ),
      ),
    );
  }

  void _openPoints() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NovelPointsPage(apiService: widget.apiService),
      ),
    );
  }

  void _openWrite() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NovelWritePage(apiService: widget.apiService),
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
        title: const Row(
          children: <Widget>[
            Icon(Icons.menu_book_rounded, size: 20, color: _novelAccent),
            SizedBox(width: 4),
            Text(
              '小说',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _novelAccent,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _openPoints,
            child: const Text('积分'),
          ),
          TextButton(
            onPressed: _openWrite,
            style: TextButton.styleFrom(
              backgroundColor: _novelAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('写书'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
              children: <Widget>[
                _buildTabs(),
                const SizedBox(height: 8),
                _buildSearch(),
                if (!_shelf) ...<Widget>[
                  const SizedBox(height: 6),
                  _buildCategories(),
                ],
                const SizedBox(height: 6),
                Text(
                  '${_shelf ? '我的书架' : '发现'} ${_total} 本',
                  style: TextStyle(
                      fontSize: 11, color: context.textTertiaryColor),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  _skeleton()
                else if (_novels.isEmpty)
                  _empty()
                else ...<Widget>[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 620 ? 4 : 3;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) /
                              columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 16,
                        children: <Widget>[
                          for (final novel in _novels)
                            SizedBox(
                              width: width,
                              child: _NovelCard(
                                novel: novel,
                                onTap: () => _openBook(novel),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (_hasMore)
                    Center(
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: <Widget>[
        _TopButton(
          label: '书架',
          icon: Icons.bookmark_border_rounded,
          active: _shelf,
          onTap: () => _selectTab(true),
        ),
        const SizedBox(width: 4),
        _TopButton(
          label: '发现',
          icon: Icons.explore_outlined,
          active: !_shelf,
          onTap: () => _selectTab(false),
        ),
        const Spacer(),
        Text(
          '共 ${_total} 本',
          style:
              TextStyle(fontSize: 11, color: context.textTertiaryColor),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded,
              size: 18, color: context.textTertiaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _search,
              enabled: !_shelf,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _shelf ? '书架内不支持搜索' : '搜索书名、作者或简介',
                hintStyle: TextStyle(
                    fontSize: 13, color: context.textTertiaryColor),
              ),
              style: TextStyle(
                  fontSize: 13, color: context.textPrimaryColor),
            ),
          ),
          TextButton(
            onPressed: _shelf ? null : () => _load(reset: true),
            style: TextButton.styleFrom(
              backgroundColor: _novelAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('搜', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final items = <Widget>[
      _CategoryPill(
        label: '全部',
        count: 0,
        active: _category.isEmpty,
        onTap: () => _selectCategory(''),
      ),
      for (final category in _categories)
        _CategoryPill(
          label: category.name,
          count: category.count,
          active: _category == category.name,
          onTap: () => _selectCategory(category.name),
        ),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) => items[index],
      ),
    );
  }

  Widget _skeleton() {
    return Wrap(
      spacing: 10,
      runSpacing: 16,
      children: <Widget>[
        for (var i = 0; i < 6; i++)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 50) / 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 5 / 7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 14,
                  width: double.infinity,
                  color: context.surfaceColor,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Icon(Icons.auto_stories_rounded,
              size: 44, color: context.textTertiaryColor),
          const SizedBox(height: 10),
          Text(
            _shelf
                ? '书架还是空的，去「发现」里找一本感兴趣的书吧'
                : '还没有书，点右上角「写书」开一本',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _novelAccent : _novelAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: active ? Colors.white : _novelAccent),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _novelAccent,
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? _novelAccent.withOpacity(0.08)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? _novelAccent : context.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? _novelAccent : context.textPrimaryColor,
                )),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? _novelAccent.withOpacity(0.75)
                        : context.textTertiaryColor,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({required this.novel, required this.onTap});

  final NovelItem novel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showProgress =
        novel.progressPercent > 0 && novel.progressPercent < 100;
    final done = novel.status == 'completed';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              AspectRatio(
                aspectRatio: 5 / 7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: novel.coverURL.isNotEmpty
                      ? CachedImage(
                          imageUrl: novel.coverURL,
                          fit: BoxFit.cover,
                          category: CacheCategory.other,
                          errorWidget: _coverFallback(context),
                        )
                      : _coverFallback(context),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0x9E10B981)
                        : const Color(0x6B0F172A),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    done ? '完结' : '连载',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            novel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            showProgress
                ? '读到 ${novel.progressChapterNum}章 · ${novel.progressPercent.toStringAsFixed(0)}%'
                : (novel.authorName.isEmpty ? '佚名' : novel.authorName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: showProgress ? FontWeight.w600 : FontWeight.w400,
              color: showProgress ? _novelAccent : context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${novel.chapterNum}章 · ${_wordCount(novel.wordNum)} · ${_count(novel.readNum)}人在读',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 10.5, color: context.textTertiaryColor),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback(BuildContext context) {
    return Container(
      color: context.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            novel.title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _novelAccent,
            ),
          ),
        ),
      ),
    );
  }
}

String _count(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

String _wordCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万字';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}千字';
  return '$n字';
}