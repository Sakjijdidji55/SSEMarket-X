import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/novel_api.dart';
import 'package:sse_market_x/core/models/novel_models.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

const Color _novelAccent = Color(0xFF2C3D56);

class NovelPointsPage extends StatefulWidget {
  const NovelPointsPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<NovelPointsPage> createState() => _NovelPointsPageState();
}

class _NovelPointsPageState extends State<NovelPointsPage> {
  final NovelApi _api = NovelApi();

  NovelPointsSummary? _summary;
  List<NovelLedgerItem> _ledger = const <NovelLedgerItem>[];
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait(<Future<Object?>>[
        _api.getPointsSummary(),
        _api.getLedger(limit: 40),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as NovelPointsSummary?;
        _ledger =
            (results[1] as ({List<NovelLedgerItem> items, int total})).items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkIn() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final result = await _api.checkIn();
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('签到失败，请稍后重试')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.already
                ? '今天已经签到过了'
                : '签到成功，经验 +${result.amount}'),
          ),
        );
        await _load();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
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
        title: const Text('小说积分',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                children: <Widget>[
                  _buildSummary(),
                  const SizedBox(height: 12),
                  _buildEventBreakdown(),
                  const SizedBox(height: 16),
                  Text('积分流水',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor)),
                  const SizedBox(height: 6),
                  if (_ledger.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('还没有流水',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiaryColor)),
                    )
                  else
                    for (final item in _ledger)
                      _LedgerRow(item: item),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary() {
    final summary = _summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2C3D56), Color(0xFF455A78)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('我的小说积分',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            '${summary?.pointsScore ?? 0}',
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _summaryItem('经验', '${summary?.experience ?? 0}'),
              _summaryItem('今日经验', '+${summary?.todayExp ?? 0}'),
              _summaryItem('连续签到', '${summary?.checkInStreak ?? 0} 天'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton(
              onPressed: _checking ? null : _checkIn,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _novelAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(
                _checking ? '签到中…' : '每日签到',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style:
                  const TextStyle(fontSize: 10.5, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildEventBreakdown() {
    final events = _summary?.byEvent ?? const <NovelPointsEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('经验构成',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 8),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(event.label,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondaryColor)),
                  ),
                  Text(
                    event.currency == 'point'
                        ? '${(event.amount / 10).toStringAsFixed(1)} 积分'
                        : '${event.amount} 经验',
                    style: TextStyle(
                        fontSize: 12,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                        color: context.textPrimaryColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.item});

  final NovelLedgerItem item;

  @override
  Widget build(BuildContext context) {
    final positive = item.amount >= 0;
    final value = item.currency == 'point'
        ? '${(item.amount / 10).toStringAsFixed(1)} 积分'
        : '${item.amount} 经验';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.label.isEmpty ? item.event : item.label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor)),
                const SizedBox(height: 2),
                Text(item.createdAt,
                    style: TextStyle(
                        fontSize: 10, color: context.textTertiaryColor)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}$value',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: positive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEC4141)),
          ),
        ],
      ),
    );
  }
}