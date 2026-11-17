import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/resume_api.dart';
import 'package:sse_market_x/core/models/resume_model.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class ResumeDetailPage extends StatefulWidget {
  const ResumeDetailPage({
    super.key,
    required this.apiService,
    required this.resumeID,
  });

  final ApiService apiService;
  final int resumeID;

  @override
  State<ResumeDetailPage> createState() => _ResumeDetailPageState();
}

class _ResumeDetailPageState extends State<ResumeDetailPage> {
  final ResumeApi _api = ResumeApi();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();

  ResumeItem? _item;
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await _api.getDetail(widget.resumeID);
      if (!mounted) return;
      if (item == null) {
        setState(() {
          _loading = false;
          _error = '简历不存在或无权查看';
        });
        return;
      }
      setState(() {
        _item = item;
        _title.text = item.title;
        _description.text = item.description;
        _loading = false;
      });
      if (item.isImage && item.canPreview) {
        final bytes = await _api.downloadBytes(item.resumeID);
        if (mounted && bytes != null) {
          setState(() => _imageBytes = bytes);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败，请稍后重试';
        });
      }
    }
  }

  Future<void> _openFile() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await _api.downloadBytes(widget.resumeID);
      if (bytes == null) {
        _toast('下载失败');
        return;
      }
      final dir = await getTemporaryDirectory();
      final ext = _item?.fileExt.isNotEmpty == true
          ? _item!.fileExt
          : 'pdf';
      final file = File('${dir.path}/resume-${widget.resumeID}.$ext');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (_) {
      _toast('无法打开文件');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _saveEdit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _toast('标题不能为空');
      return;
    }
    final updated = await _api.update(
      widget.resumeID,
      title,
      _description.text.trim(),
    );
    if (!mounted) return;
    if (updated == null) {
      _toast('保存失败');
      return;
    }
    setState(() => _item = updated);
    _toast('已保存');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除简历'),
        content: const Text('删除后无法恢复，确定继续吗？'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _api.delete(widget.resumeID);
    if (!mounted) return;
    if (!ok) {
      _toast('删除失败');
      return;
    }
    Navigator.of(context).pop(true);
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
        title: const Text('简历详情',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: <Widget>[
          if (_item?.isOwner == true)
            IconButton(
              tooltip: '删除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
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
                      Text(_error!),
                      const SizedBox(height: 10),
                      OutlinedButton(
                          onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final item = _item!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.isImage
                              ? Icons.image_outlined
                              : Icons.picture_as_pdf_outlined,
                          color: const Color(0xFF0078D4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title.isEmpty ? item.fileName : item.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item.uploader.isEmpty ? (item.isAnonymous ? '匿名用户' : '用户') : item.uploader} · ${_size(item.fileSize)}',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.textTertiaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (item.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(item.description,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: context.textSecondaryColor)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _downloading ? null : _openFile,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0078D4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                          icon: _downloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.open_in_new_rounded,
                                  size: 17),
                          label: const Text('下载 / 打开'),
                        ),
                      ),
                      if (item.isOwner) ...<Widget>[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _showEdit,
                          child: const Text('编辑'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (item.isImage && _imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      item.isImage
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                      size: 46,
                      color: const Color(0xFF0078D4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.canPreview
                          ? '点击上方按钮打开预览'
                          : '该文件暂不支持页内预览',
                      style: TextStyle(
                          fontSize: 12,
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

  void _showEdit() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑简历信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '描述'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消')),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveEdit();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
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