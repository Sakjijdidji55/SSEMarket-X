import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/home/teacher_page.dart';

/// 原生课程专区：复用已有教师/课程页，不重复写一套列表。
class CoursePage extends StatelessWidget {
  const CoursePage({super.key, required this.apiService});

  final ApiService apiService;

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
        title: const Text('课程专区',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: TeacherPage(
        apiService: apiService,
        contentPadding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      ),
    );
  }
}