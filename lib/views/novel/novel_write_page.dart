import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/novel_api.dart';
import 'package:sse_market_x/core/models/novel_models.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 原生小说写作页（第一版）：新建书 / 选择已有书，写章节并提交。
///
/// 暂未做：封面裁剪上传、正文插图、富文本、本地草稿；见技术债文档。
class NovelWritePage extends StatefulWidget {
  const NovelWritePage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<NovelWritePage> createState() => _NovelWritePageState();
}

class _NovelWritePageState extends State<NovelWritePage> {
  final NovelApi _api = NovelApi();
  final TextEditingController _novelTitle = TextEditingController();
  final TextEditingController _intro = TextEditingController();
  final TextEditingController _chapterTitle = TextEditingController();
  final TextEditingController _content = TextEditingController();

  List<NovelItem> _myNovels = const <NovelItem>[];
  int? _selectedNovelId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _novelTitle.dispose();
    _intro.dispose();
    _chapterTitle.dispose();
    _content.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _api.getMyNovels(limit: 50);
      if (!mounted) return;
      setState(() {
        _myNovels = result.novels;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final chapterTitle = _chapterTitle.text.trim();
    final content = _content.text.trim();
    if (chapterTitle.isEmpty) {
      _toast('请填写章节标题');
      return;
    }
    if (content.isEmpty) {
      _toast('请填写章节正文');
      return;
    }
    setState(() => _submitting = true);
    try {
      var novelId = _selectedNovelId;
      if (novelId == null) {
        final title = _novelTitle.text.trim();
        if (title.isEmpty) {
          _toast('请填写书名');
          setState(() => _submitting = false);
          return;
        }
        novelId = await _api.createNovel(
          title: title,
          intro: _intro.text.trim(),
        );
        if (novelId == null) {
          _toast('创建书籍失败');
          setState(() => _submitting = false);
          return;
        }
      }
      final chapter = await _api.createChapter(
        novelID: novelId,
        title: chapterTitle,
        content: content,
      );
      if (!mounted) return;
      if (chapter == null) {
        _toast('提交章节失败');
        return;
      }
      _toast('提交成功');
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) _toast('提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
        title: const Text('写书',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('提交'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                  children: <Widget>[
                    _buildNovelPicker(),
                    const SizedBox(height: 12),
                    if (_selectedNovelId == null) ...<Widget>[
                      _field(
                        label: '书名',
                        controller: _novelTitle,
                        hint: '给你的书起个名字',
                      ),
                      const SizedBox(height: 10),
                      _field(
                        label: '简介',
                        controller: _intro,
                        hint: '一句话介绍这本书（可选）',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _field(
                      label: '章节标题',
                      controller: _chapterTitle,
                      hint: '第 1 章 · 开端',
                    ),
                    const SizedBox(height: 10),
                    _field(
                      label: '正文',
                      controller: _content,
                      hint: '开始写正文…',
                      minLines: 10,
                      maxLines: 24,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '第一版暂不支持封面、插图和本地草稿；提交前请保留副本。',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: context.textTertiaryColor),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNovelPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('选择书籍',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('新建书籍'),
                selected: _selectedNovelId == null,
                onSelected: (_) => setState(() => _selectedNovelId = null),
              ),
              for (final novel in _myNovels)
                ChoiceChip(
                  label: Text(novel.title, overflow: TextOverflow.ellipsis),
                  selected: _selectedNovelId == novel.novelID,
                  onSelected: (_) =>
                      setState(() => _selectedNovelId = novel.novelID),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.surfaceColor,
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
      ],
    );
  }
}