import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/api/ranking_api.dart';
import 'package:sse_market_x/core/models/rank_model.dart';
import 'package:sse_market_x/core/services/media_cache_service.dart';
import 'package:sse_market_x/shared/components/media/cached_image.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/coin/coin_center_page.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/views/profile/user_profile_page.dart';

/// 原生排行榜：优质榜（帖子投币）/ 用户榜（收到投币）。
///
/// 对齐 Web `src/views/RankingView.vue`：
/// - 顶部标题/副标题 + iOS 分段控件；
/// - 前三名领奖台（左银、中金、右铜）；
/// - 第 4 名起列表；
/// - 加载骨架/空状态/失败重试。
class RankingPage extends StatefulWidget {
  const RankingPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

enum _RankTab { post, user }

class _RankingPageState extends State<RankingPage> {
  final RankingApi _api = RankingApi();

  _RankTab _tab = _RankTab.post;
  List<PostRankItem> _posts = const <PostRankItem>[];
  List<UserRankItem> _users = const <UserRankItem>[];
  final Set<int> _brokenAvatars = <int>{};

  bool _loading = true;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(<Future<Object>>[
        _api.getPostRanking(),
        _api.getUserRanking(),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<PostRankItem>;
        _users = results[1] as List<UserRankItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '排行榜加载失败，请稍后重试';
      });
    }
  }

  List<dynamic> get _currentList =>
      _tab == _RankTab.post ? _posts : _users;

  bool get _isEmpty => !_loading && _error == null && _currentList.isEmpty;

  String get _subtitle =>
      _tab == _RankTab.post ? '按投币数排序 · 前 100 名' : '按收到的投币数排序 · 前 100 名';

  void _setTab(_RankTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  void _openPost(int postID) {
    if (postID <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          postId: postID,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  void _openUser(int userID) {
    if (userID <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          apiService: widget.apiService,
          userId: userID,
        ),
      ),
    );
  }

  void _openCoin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoinCenterPage(apiService: widget.apiService),
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
          '排行榜',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _openCoin,
            child: const Text(
              '去投币',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHero()),
            if (_loading)
              SliverToBoxAdapter(child: _buildSkeleton())
            else if (_error != null)
              SliverToBoxAdapter(child: _buildError())
            else if (_isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else ..._buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 1.2,
          colors: <Color>[
            AppColors.primary.withOpacity(0.10),
            context.backgroundColor.withOpacity(0),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 10),
          _RankSwitch(
            userTab: _tab == _RankTab.user,
            onChanged: (user) =>
                _setTab(user ? _RankTab.user : _RankTab.post),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    final top = _currentList.take(3).toList(growable: false);
    final rest = _currentList.skip(3).toList(growable: false);
    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildPodium(top),
        ),
      ),
      if (rest.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList.separated(
            itemCount: rest.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rank = index + 4;
              if (_tab == _RankTab.post) {
                return _PostRankRow(
                  rank: rank,
                  item: rest[index] as PostRankItem,
                  onTap: () => _openPost((rest[index] as PostRankItem).postID),
                );
              }
              final user = rest[index] as UserRankItem;
              return _UserRankRow(
                rank: rank,
                item: user,
                avatarBroken: _brokenAvatars.contains(user.userID),
                onAvatarError: () => _markAvatarBroken(user.userID),
                onTap: () => _openUser(user.userID),
              );
            },
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _buildPodium(List<dynamic> top) {
    if (top.isEmpty) return const SizedBox.shrink();

    final cards = <Widget>[];
    if (top.length > 1) {
      cards.add(_buildPodiumCard(top[1], 1));
    }
    cards.add(_buildPodiumCard(top[0], 0));
    if (top.length > 2) {
      cards.add(_buildPodiumCard(top[2], 2));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (var i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            flex: i == 1 ? 112 : 100,
            child: cards[i],
          ),
        ],
      ],
    );
  }

  Widget _buildPodiumCard(dynamic item, int index) {
    final tier = _RankTier.of(index);
    final isPost = item is PostRankItem;
    final title = isPost ? item.title : _displayUserName(item as UserRankItem);

    return GestureDetector(
      onTap: () => isPost ? _openPost(item.postID) : _openUser(item.userID),
      child: Transform.translate(
        offset: Offset(0, index == 0 ? -6 : 0),
        child: Container(
          padding: EdgeInsets.fromLTRB(10, index == 0 ? 18 : 14, 10,
              index == 0 ? 16 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[tier.tint, context.surfaceColor],
              stops: const <double>[0, 0.4],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tier.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(index == 0 ? 0.10 : 0.06),
                blurRadius: index == 0 ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PodiumRankBadge(tier: tier, rank: index + 1),
              const SizedBox(height: 6),
              if (!isPost) ...<Widget>[
                _UserAvatar(
                  item: item as UserRankItem,
                  size: index == 0 ? 52 : 44,
                  tier: tier,
                  broken: _brokenAvatars.contains(item.userID),
                  onError: () => _markAvatarBroken(item.userID),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: index == 0 ? 13 : 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.monetization_on_rounded,
                      size: 12, color: Color(0xFFF5A623)),
                  const SizedBox(width: 2),
                  Text(
                    '${_formatCount(isPost ? item.coinNum : item.receivedCoins)} 币',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              if (isPost && item.partition.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.partition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _markAvatarBroken(int userID) {
    if (_brokenAvatars.contains(userID)) return;
    setState(() => _brokenAvatars.add(userID));
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: i == 1 ? 148 : 132,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 5; i++) ...<Widget>[
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 60),
      child: Column(
        children: <Widget>[
          Icon(Icons.bar_chart_rounded,
              size: 40, color: context.textTertiaryColor),
          const SizedBox(height: 10),
          Text('暂无数据',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 4),
          Text('投票或互动后，榜单会在这里更新',
              style: TextStyle(
                  fontSize: 12, color: context.textTertiaryColor)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 60),
      child: Column(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded,
              size: 40, color: context.textTertiaryColor),
          const SizedBox(height: 10),
          Text(_error ?? '加载失败',
              style: TextStyle(
                  fontSize: 14, color: context.textSecondaryColor)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _RankSwitch extends StatelessWidget {
  const _RankSwitch({required this.userTab, required this.onChanged});

  final bool userTab;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: const Cubic(0.32, 0.72, 0, 1),
            alignment: userTab ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _SwitchOption(
                  icon: Icons.local_fire_department_rounded,
                  label: '优质榜',
                  active: !userTab,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _SwitchOption(
                  icon: Icons.people_alt_rounded,
                  label: '用户榜',
                  active: userTab,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchOption extends StatelessWidget {
  const _SwitchOption({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon,
              size: 16,
              color: active
                  ? context.textPrimaryColor
                  : context.textSecondaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active
                  ? context.textPrimaryColor
                  : context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTier {
  const _RankTier({
    required this.color,
    required this.tint,
    required this.border,
  });

  final Color color;
  final Color tint;
  final Color border;

  static const _gold = Color(0xFFF5A623);
  static const _silver = Color(0xFF8E9AAF);
  static const _bronze = Color(0xFFC77B4A);

  static _RankTier of(int index) {
    switch (index) {
      case 0:
        return const _RankTier(
          color: _gold,
          tint: Color(0xFFFFFDF7),
          border: Color(0x40F5A623),
        );
      case 1:
        return const _RankTier(
          color: _silver,
          tint: Color(0xFFFAFBFC),
          border: Color(0x338E9AAF),
        );
      default:
        return const _RankTier(
          color: _bronze,
          tint: Color(0xFFFFFAF6),
          border: Color(0x33C77B4A),
        );
    }
  }

  LinearGradient get badgeGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(color, Colors.white, 0.28) ?? color,
          color,
        ],
      );
}

class _PodiumRankBadge extends StatelessWidget {
  const _PodiumRankBadge({required this.tier, required this.rank});

  final _RankTier tier;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final icon = switch (rank) {
      1 => Icons.emoji_events_rounded,
      2 => Icons.workspace_premium_rounded,
      _ => Icons.military_tech_rounded,
    };
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: tier.badgeGradient,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tier.color.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.item,
    required this.size,
    required this.tier,
    required this.broken,
    required this.onError,
  });

  final UserRankItem item;
  final double size;
  final _RankTier tier;
  final bool broken;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    final fallback = _avatarText(_displayUserName(item));
    final hasAvatar = !broken && item.avatarURL.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.backgroundColor,
        border: Border.all(color: tier.color.withOpacity(0.5), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? CachedImage(
              imageUrl: item.avatarURL.trim(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              category: CacheCategory.avatar,
              errorWidget: _AvatarFallback(
                  text: fallback, size: size * 0.35),
            )
          : _AvatarFallback(text: fallback, size: size * 0.35),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}

class _PostRankRow extends StatelessWidget {
  const _PostRankRow({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  final int rank;
  final PostRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RankRowShell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          _RankNumber(rank: rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    if (item.partition.isNotEmpty) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.partition,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Icon(Icons.monetization_on_outlined,
                        size: 13, color: Color(0xFFF5A623)),
                    const SizedBox(width: 3),
                    Text(
                      '${_formatCount(item.coinNum)} 币',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: context.textTertiaryColor),
        ],
      ),
    );
  }
}

class _UserRankRow extends StatelessWidget {
  const _UserRankRow({
    required this.rank,
    required this.item,
    required this.avatarBroken,
    required this.onAvatarError,
    required this.onTap,
  });

  final int rank;
  final UserRankItem item;
  final bool avatarBroken;
  final VoidCallback onAvatarError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _displayUserName(item);
    final hasAvatar =
        !avatarBroken && item.avatarURL.trim().isNotEmpty;
    return _RankRowShell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          _RankNumber(rank: rank),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.backgroundColor,
              border: Border.all(
                  color: Colors.black.withOpacity(0.06), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasAvatar
                ? CachedImage(
                    imageUrl: item.avatarURL.trim(),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    category: CacheCategory.avatar,
                    errorWidget: _AvatarFallback(
                        text: _avatarText(name), size: 14),
                  )
                : _AvatarFallback(text: _avatarText(name), size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    const Icon(Icons.monetization_on_outlined,
                        size: 13, color: Color(0xFFF5A623)),
                    const SizedBox(width: 3),
                    Text(
                      '收到 ${_formatCount(item.receivedCoins)} 币',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: context.textTertiaryColor),
        ],
      ),
    );
  }
}

class _RankRowShell extends StatelessWidget {
  const _RankRowShell({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.black.withOpacity(0.04), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RankNumber extends StatelessWidget {
  const _RankNumber({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          color: context.textTertiaryColor,
        ),
      ),
    );
  }
}

String _displayUserName(UserRankItem item) {
  final name = item.userName.trim();
  return name.isEmpty ? '匿名用户' : name;
}

String _avatarText(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '用';
  final chars = trimmed.runes.toList(growable: false);
  final first = String.fromCharCode(chars.first);
  if (RegExp(r'^[一-鿿]').hasMatch(first)) return first;
  if (chars.length >= 2 && RegExp(r'^[a-zA-Z]').hasMatch(first)) {
    return (first + String.fromCharCode(chars[1])).toUpperCase();
  }
  return first.toUpperCase();
}

String _formatCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}