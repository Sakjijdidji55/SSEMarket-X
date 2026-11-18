import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/novel_api.dart';
import 'package:sse_market_x/core/models/novel_models.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/core/services/novel_cache_store.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/novel/novel_reader_page.dart';

const Color _novelAccent = Color(0xFF2C3D56);

class NovelDetailPage extends StatefulWidget {
  const NovelDetailPage({
    super.key,
    required this.apiService,
    required this.novelID,
  });

  final ApiService apiService;
  final int novelID;

  @override
  State<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends State<NovelDetailPage> {
  final NovelApi _api = NovelApi();
  final TextEditingController _comment = TextEditingController();

  NovelItem? _novel;
  List<NovelChapter> _chapters = const <NovelChapter>[];
  List<NovelComment> _comments = const <NovelComment>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = NovelCacheStore.instance.details[widget.novelID];
    if (cached != null) {
      _novel = cached;
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getNovelDetail(widget.novelID);
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = '书不存在或已删除';
        });
        return;
      }
      final results = await Future.wait(<Future<Object>>[
        _api.getChapters(widget.novelID, limit: 200),
        _api.getComments(novelID: widget.novelID, limit: 30),
      ]);
      if (!mounted) return;
      final chapters = (results[0] as ({List<NovelChapter> chapters, int total}))
          .chapters;
      final comments =
          (results[1] as ({List<NovelComment> comments, int total})).comments;
      NovelCacheStore.instance.details[widget.novelID] = detail;
      setState(() {
        _novel = detail;
        _chapters = chapters;
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败，请稍后重试';
      });
    }
  }

  Future<void> _toggleShelf() async {
    final result = await _api.toggleShelf(widget.novelID);
    if (!mounted || result == null) return;
    setState(() {
      final current = _novel;
      if (current != null) {
        _novel = NovelItem(
          novelID: current.novelID,
          title: current.title,
          authorID: current.authorID,
          authorName: current.authorName,
          coverURL: current.coverURL,
          category: current.category,
          intro: current.intro,
          status: current.status,
          chapterNum: current.chapterNum,
          wordNum: current.wordNum,
          readNum: current.readNum,
          shelfNum: current.shelfNum,
          commentNum: current.commentNum,
          coinNum: current.coinNum,
          ratingCount: current.ratingCount,
          ratingAvg: current.ratingAvg,
          myCoins: current.myCoins,
          myRating: current.myRating,
          latestChapterID: current.latestChapterID,
          latestChapterTitle: current.latestChapterTitle,
          latestChapterAt: current.latestChapterAt,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
          onShelf: result.onShelf,
          progressPercent: current.progressPercent,
          progressChapterID: current.progressChapterID,
          progressChapterNum: current.progressChapterNum,
        );
      }
    });
    if (result.msg.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.msg)));
    }
  }

  void _openReader({int? chapterID}) {
    final id = chapterID ?? (_novel?.progressChapterID ?? 0);
    final target = id > 0
        ? id
        : (_chapters.isNotEmpty ? _chapters.first.chapterID : 0);
    if (target <= 0) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NovelReaderPage(
          apiService: widget.apiService,
          chapterID: target,
          novelTitle: _novel?.title ?? '',
        ),
      ),
    );
  }

  Future<void> _rate() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        var value = _novel?.myRating ?? 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('给这本书评分'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setDialogState(() => value = i),
                      icon: Icon(
                        i <= value
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFF5A623),
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      value <= 0 ? null : () => Navigator.of(context).pop(value),
                  child: const Text('提交'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null || selected <= 0) return;
    final result = await _api.rateNovel(widget.novelID, selected);
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.msg)));
    _load();
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await _api.createComment(
        novelID: widget.novelID,
        targetType: 'book',
        content: text,
      );
      if (!mounted) return;
      _comment.clear();
      if (comment != null) {
        setState(() => _comments = <NovelComment>[comment, ..._comments]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论失败，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like(NovelComment comment) async {
    final ok = await _api.likeComment(comment.commentID);
    if (!mounted || !ok) return;
    setState(() {
      _comments = _comments
          .map((c) => c.commentID == comment.commentID
              ? NovelComment(
                  commentID: c.commentID,
                  novelID: c.novelID,
                  chapterID: c.chapterID,
                  paragraphIndex: c.paragraphIndex,
                  targetType: c.targetType,
                  paragraphExcerpt: c.paragraphExcerpt,
                  authorID: c.authorID,
                  author: c.author,
                  authorTelephone: c.authorTelephone,
                  authorScore: c.authorScore,
                  authorAvatar: c.authorAvatar,
                  authorIdentity: c.authorIdentity,
                  commentTime: c.commentTime,
                  content: c.content,
                  isRating: c.isRating,
                  likeNum: c.likeNum + (c.isLiked ? -1 : 1),
                  isLiked: !c.isLiked,
                )
              : c)
          .toList(growable: false);
    });
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
        title: const Text('书籍详情',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_error!),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final novel = _novel!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: <Widget>[
        _buildHeader(novel),
        const SizedBox(height: 12),
        _buildIntro(novel),
        const SizedBox(height: 14),
        _buildChapters(),
        const SizedBox(height: 16),
        _buildComments(),
      ],
    );
  }

  Widget _buildHeader(NovelItem novel) {
    final done = novel.status == 'completed';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: 92,
              height: 129,
              child: novel.coverURL.isNotEmpty
                  ? CachedImage(
                      imageUrl: novel.coverURL,
                      fit: BoxFit.cover,
                      category: CacheCategory.other,
                      errorWidget: _coverFallback(novel),
                    )
                  : _coverFallback(novel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  novel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  novel.authorName.isEmpty ? '佚名' : novel.authorName,
                  style: TextStyle(
                      fontSize: 13, color: context.textSecondaryColor),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    _Badge(
                      text: done ? '完结' : '连载',
                      color: done ? const Color(0xFF10B981) : _novelAccent,
                    ),
                    if (novel.category.isNotEmpty)
                      _Badge(text: novel.category, color: _novelAccent),
                    _Badge(
                      text:
                          '${novel.chapterNum}章 · ${_wordCount(novel.wordNum)}',
                      color: context.textSecondaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: <Widget>[
                    const Icon(Icons.star_rounded,
                        size: 15, color: Color(0xFFF5A623)),
                    const SizedBox(width: 2),
                    Text(
                      novel.ratingCount == 0
                          ? '暂无评分'
                          : '${novel.ratingAvg.toStringAsFixed(1)} · ${novel.ratingCount}人',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: context.textSecondaryColor),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.monetization_on_outlined,
                        size: 14, color: context.textTertiaryColor),
                    const SizedBox(width: 2),
                    Text('${novel.coinNum} 币',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: context.textSecondaryColor)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openReader(),
                        style: FilledButton.styleFrom(
                          backgroundColor: _novelAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(0, 36),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          novel.progressChapterNum > 0 ? '继续阅读' : '开始阅读',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _toggleShelf,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: BorderSide(
                            color: novel.onShelf
                                ? _novelAccent
                                : context.dividerColor),
                      ),
                      child: Text(
                        novel.onShelf ? '已在书架' : '加书架',
                        style: TextStyle(
                            fontSize: 12,
                            color: novel.onShelf
                                ? _novelAccent
                                : context.textSecondaryColor),
                      ),
                    ),
                    IconButton(
                      tooltip: '评分',
                      onPressed: _rate,
                      icon: const Icon(Icons.star_border_rounded,
                          color: Color(0xFFF5A623)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(NovelItem novel) {
    if (novel.intro.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        novel.intro,
        style: TextStyle(
            fontSize: 13, height: 1.7, color: context.textSecondaryColor),
      ),
    );
  }

  Widget _buildChapters() {
    if (_chapters.isEmpty) {
      return Text('还没有章节',
          style: TextStyle(fontSize: 12, color: context.textTertiaryColor));
    }
    final shown = _chapters.take(12).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('章节',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor)),
              TextButton(
                onPressed: () => _showAllChapters(),
                child: Text('共 ${_chapters.length} 章',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          for (final chapter in shown)
            InkWell(
              onTap: () => _openReader(chapterID: chapter.chapterID),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: context.textPrimaryColor),
                      ),
                    ),
                    Text('${chapter.wordNum}字',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: context.textTertiaryColor)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllChapters() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final chapter = _chapters[index];
              return ListTile(
                dense: true,
                title: Text(chapter.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('第 ${chapter.chapterNum} 章',
                    style: const TextStyle(fontSize: 10.5)),
                onTap: () {
                  Navigator.of(context).pop();
                  _openReader(chapterID: chapter.chapterID);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildComments() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('书评',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _comment,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '写一条书评…',
                    isDense: true,
                    filled: true,
                    fillColor: context.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.dividerColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _sendComment,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: _novelAccent, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('还没有书评，来写第一条吧',
                  style: TextStyle(
                      fontSize: 12, color: context.textTertiaryColor)),
            )
          else
            for (final comment in _comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _novelAccent.withOpacity(0.1),
                      child: Text(
                        comment.author.isEmpty
                            ? '读'
                            : comment.author.substring(0, 1),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _novelAccent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            comment.author.isEmpty ? '读者' : comment.author,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 2),
                          Text(comment.content,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: context.textSecondaryColor)),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              GestureDetector(
                                onTap: () => _like(comment),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      comment.isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 12,
                                      color: comment.isLiked
                                          ? const Color(0xFFEC4141)
                                          : context.textTertiaryColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text('${comment.likeNum}',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color:
                                                context.textTertiaryColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(_timeAgo(comment.commentTime),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: context.textTertiaryColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _coverFallback(NovelItem novel) {
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
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _novelAccent),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

String _wordCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万字';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}千字';
  return '$n字';
}

String _timeAgo(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  return '${d.month}/${d.day}';
}