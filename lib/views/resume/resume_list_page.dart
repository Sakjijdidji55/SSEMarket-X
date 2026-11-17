import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/resume_api.dart';
import 'package:sse_market_x/core/models/resume_model.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/resume/resume_detail_page.dart';
import 'package:sse_market_x/views/resume/resume_upload_page.dart';

class ResumeListPage extends StatefulWidget {
  const ResumeListPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ResumeListPage> createState() => _ResumeListPageState();
}

class _ResumeListPageState extends State<ResumeListPage> {
  final ResumeApi _api = ResumeApi();
  final TextEditingController _search = TextEditingController();

  bool _mine = false;
  bool _loading = true;
  List<ResumeItem> _items = const <ResumeItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.getResumes(
        sort: _mine ? 'my' : 'home',
        search: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setTab(bool mine) {
    if (_mine == mine) return;
    setState(() {
      _mine = mine;
      _items = const <ResumeItem>[];
    });
    _load();
  }

  Future<void> _openUpload() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ResumeUploadPage(apiService: widget.apiService),
      ),
    );
    if (changed == true) _load();
  }

  void _openDetail(ResumeItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResumeDetailPage(
          apiService: widget.apiService,
          resumeID: item.resumeID,
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
        title: const Text('简历',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          IconButton(
            tooltip: '上传简历',
            onPressed: _openUpload,
            icon: const Icon(Icons.upload_file_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('公开简历'),
                      selected: !_mine,
                      onSelected: (_) => _setTab(false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('我的简历'),
                      selected: _mine,
                      onSelected: (_) => _setTab(true),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: '搜索标题 / 描述',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: context.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: context.dividerColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  for (var i = 0; i < 4; i++)
                    Container(
                      height: 86,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
                else if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.description_outlined,
                            size: 44, color: context.textTertiaryColor),
                        const SizedBox(height: 10),
                        Text(
                          _mine ? '还没有上传简历' : '暂无公开简历',
                          style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondaryColor),
                        ),
                        if (_mine) ...<Widget>[
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _openUpload,
                            child: const Text('上传第一份'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  for (final item in _items)
                    _ResumeCard(item: item, onTap: () => _openDetail(item)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.item, required this.onTap});

  final ResumeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.isImage
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isImage
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: const Color(0xFF0078D4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title.isEmpty ? item.fileName : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.uploader.isEmpty ? (item.isAnonymous ? '匿名用户' : '用户') : item.uploader} · ${_size(item.fileSize)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiaryColor),
                    ),
                    if (item.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondaryColor),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('${item.downloadNum} 下载',
                      style: TextStyle(
                          fontSize: 10,
                          color: context.textTertiaryColor)),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: context.textTertiaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()}KB';
    return '${bytes}B';
  }
}