import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/novel_api.dart';
import 'package:sse_market_x/core/models/novel_models.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';

const Color _novelAccent = Color(0xFF2C3D56);

class NovelReaderPage extends StatefulWidget {
  const NovelReaderPage({
    super.key,
    required this.apiService,
    required this.chapterID,
    this.novelTitle = '',
  });

  final ApiService apiService;
  final int chapterID;
  final String novelTitle;

  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage> {
  final NovelApi _api = NovelApi();
  final ScrollController _scroll = ScrollController();

  NovelChapterDetail? _detail;
  bool _loading = true;
  String? _error;
  double _fontSize = 17;
  int _themeIndex = 0;
  Timer? _reportTimer;
  double _progress = 0;
  DateTime _lastReport = DateTime.now();

  static const _themes = <_ReaderTheme>[
    _ReaderTheme('日间', Color(0xFFF8F7F2), Color(0xFF1E293B)),
    _ReaderTheme('夜间', Color(0xFF121212), Color(0xFFC9C9C9)),
    _ReaderTheme('护眼', Color(0xFFE8F3E8), Color(0xFF1F3A2E)),
    _ReaderTheme('羊皮纸', Color(0xFFF4EBDD), Color(0xFF3B2F2A)),
  ];

  _ReaderTheme get _theme => _themes[_themeIndex.clamp(0, _themes.length - 1)];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _load();
    _scroll.addListener(_onScroll);
    _reportTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _flushProgress();
    });
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    unawaited(_flushProgress()
        .catchError((Object _) {})
        .whenComplete(_api.dispose));
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('novel_font_size') ?? 17;
      _themeIndex = prefs.getInt('novel_theme') ?? 0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('novel_font_size', _fontSize);
    await prefs.setInt('novel_theme', _themeIndex);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getChapter(widget.chapterID);
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = '章节不存在或已被删除';
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
        _progress = detail.progressPercent / 100;
      });
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('novel_progress_${detail.novelID}');
      if (saved != null && saved > 0 && saved < 1) {
        _progress = saved;
      }
      await _restoreScroll();
      _lastReport = DateTime.now();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '章节加载失败，请稍后重试';
      });
    }
  }

  Future<void> _restoreScroll() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    _scroll.jumpTo(max * _progress.clamp(0, 1));
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    _progress = (_scroll.offset / max).clamp(0, 1);
  }

  Future<void> _flushProgress() async {
    final detail = _detail;
    if (detail == null) return;
    final now = DateTime.now();
    final seconds = now.difference(_lastReport).inSeconds;
    _lastReport = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('novel_progress_${detail.novelID}', _progress);
    await _api.reportProgress(
      novelID: detail.novelID,
      chapterID: detail.chapter.chapterID,
      paragraphIndex: (_progress * detail.paragraphs.length).round(),
      percent: _progress * 100,
      readSeconds: seconds,
    );
  }

  Future<void> _openChapter(NovelAdjacent? adjacent) async {
    if (adjacent == null || adjacent.chapterID <= 0) return;
    await _flushProgress();
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => NovelReaderPage(
          apiService: widget.apiService,
          chapterID: adjacent.chapterID,
          novelTitle: widget.novelTitle,
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('阅读设置',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        const Text('字号'),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 14,
                            max: 24,
                            divisions: 10,
                            onChanged: (value) {
                              setState(() => _fontSize = value);
                              setSheetState(() {});
                              _saveSettings();
                            },
                          ),
                        ),
                        Text('${_fontSize.round()}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('背景'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (var i = 0; i < _themes.length; i++)
                          ChoiceChip(
                            label: Text(_themes[i].name),
                            selected: _themeIndex == i,
                            onSelected: (_) {
                              setState(() => _themeIndex = i);
                              setSheetState(() {});
                              _saveSettings();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        foregroundColor: theme.text,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _detail?.novelTitle.isNotEmpty == true
                  ? _detail!.novelTitle
                  : widget.novelTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
            Text(
              _detail?.chapter.title ?? '加载中…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '目录',
            onPressed: _openToc,
            icon: const Icon(Icons.list_rounded),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_error!,
                          style: TextStyle(color: theme.text.withOpacity(0.7))),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
                        itemCount: _detail!.paragraphs.length,
                        itemBuilder: (context, index) {
                          final paragraph = _detail!.paragraphs[index];
                          if (paragraph.isImage) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedImage(
                                  imageUrl: paragraph.imageURL,
                                  fit: BoxFit.contain,
                                  category: CacheCategory.other,
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: SelectableText(
                              paragraph.text,
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.85,
                                color: theme.text,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildBottomBar(theme),
                  ],
                ),
    );
  }

  Widget _buildBottomBar(_ReaderTheme theme) {
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.text.withOpacity(0.08))),
      ),
      child: Row(
        children: <Widget>[
          TextButton(
            onPressed: detail.prev == null ? null : () => _openChapter(detail.prev),
            child: const Text('上一章'),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LinearProgressIndicator(
                  value: _progress.clamp(0, 1),
                  minHeight: 3,
                  backgroundColor: theme.text.withOpacity(0.08),
                  color: _novelAccent,
                ),
                const SizedBox(height: 3),
                Text('${(_progress * 100).round()}%',
                    style: TextStyle(
                        fontSize: 10, color: theme.text.withOpacity(0.55))),
              ],
            ),
          ),
          TextButton(
            onPressed: detail.next == null ? null : () => _openChapter(detail.next),
            child: const Text('下一章'),
          ),
        ],
      ),
    );
  }

  Future<void> _openToc() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      final result = await _api.getChapters(detail.novelID);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView.builder(
              itemCount: result.chapters.length,
              itemBuilder: (context, index) {
                final chapter = result.chapters[index];
                final current = chapter.chapterID == detail.chapter.chapterID;
                return ListTile(
                  dense: true,
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          current ? FontWeight.w700 : FontWeight.w400,
                      color: current ? _novelAccent : null,
                    ),
                  ),
                  subtitle: Text('第 ${chapter.chapterNum} 章',
                      style: const TextStyle(fontSize: 10.5)),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!current) {
                      Navigator.of(context).pushReplacement<void, void>(
                        MaterialPageRoute<void>(
                          builder: (_) => NovelReaderPage(
                            apiService: widget.apiService,
                            chapterID: chapter.chapterID,
                            novelTitle: detail.novelTitle,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目录加载失败')),
        );
      }
    }
  }
}

class _ReaderTheme {
  const _ReaderTheme(this.name, this.background, this.text);

  final String name;
  final Color background;
  final Color text;
}