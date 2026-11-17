import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/resume_api.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class ResumeUploadPage extends StatefulWidget {
  const ResumeUploadPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ResumeUploadPage> createState() => _ResumeUploadPageState();
}

class _ResumeUploadPageState extends State<ResumeUploadPage> {
  final ResumeApi _api = ResumeApi();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();

  XFile? _file;
  bool _anonymous = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const group = XTypeGroup(
      label: '简历文件',
      extensions: <String>['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
      if (file == null) return;
      final size = await File(file.path).length();
      if (size > 20 * 1024 * 1024) {
        setState(() => _error = '文件不能超过 20MB');
        return;
      }
      setState(() {
        _file = file;
        _error = null;
        if (_title.text.trim().isEmpty) {
          _title.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
    } catch (_) {
      setState(() => _error = '无法打开文件选择器');
    }
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) {
      setState(() => _error = '请选择 PDF 或图片文件');
      return;
    }
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final id = await _api.upload(
        file: File(file.path),
        fileName: file.name,
        title: _title.text.trim().isEmpty
            ? file.name
            : _title.text.trim(),
        description: _description.text.trim(),
        isAnonymous: _anonymous,
      );
      if (!mounted) return;
      if (id == null) {
        setState(() {
          _uploading = false;
          _error = '上传失败，请检查文件类型或稍后重试';
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = '上传失败，请稍后重试';
        });
      }
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
        title: const Text('上传简历',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: <Widget>[
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: context.dividerColor, width: 1),
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        _file == null
                            ? Icons.upload_file_rounded
                            : Icons.description_rounded,
                        size: 42,
                        color: _file == null
                            ? context.textTertiaryColor
                            : const Color(0xFF0078D4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _file?.name ?? '选择 PDF / 图片简历',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('最大 20MB',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: context.textTertiaryColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _field('标题', _title, '例如：后端开发实习简历'),
              const SizedBox(height: 10),
              _field('描述', _description, '简单介绍这份简历', maxLines: 3),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('匿名上传',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text('不显示上传者昵称',
                    style: TextStyle(fontSize: 11)),
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB91C1C))),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _uploading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('上传'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint,
      {int maxLines = 1}) {
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