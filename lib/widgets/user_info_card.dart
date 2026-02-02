/// 用户信息卡片展示组件
///
/// 展示用户的详细资料，包括：
/// - 头像、背景图、昵称、简介
/// - 用户角色标签、在线状态
/// - 关注/取消关注按钮（支持乐观 UI 更新）
/// - 私信入口
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class UserInfoCard extends StatefulWidget {
  final String userName;
  final String avatarUrl;
  final User? userDetails;
  final bool isLoading;

  const UserInfoCard({
    super.key,
    required this.userName,
    required this.avatarUrl,
    this.userDetails,
    this.isLoading = false,
  });

  @override
  State<UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends State<UserInfoCard> {
  String? _canFollow;

  @override
  void initState() {
    super.initState();
    _canFollow = widget.userDetails?.canFollow;
  }

  @override
  void didUpdateWidget(covariant UserInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userDetails?.canFollow != oldWidget.userDetails?.canFollow) {
      setState(() {
        _canFollow = widget.userDetails?.canFollow;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_canFollow == null || widget.userDetails?.oId == null) return;

    final currentCanFollow = _canFollow;
    final newCanFollow = currentCanFollow == 'yes' ? 'no' : 'yes';

    // Optimistic Update
    setState(() {
      _canFollow = newCanFollow;
    });

    try {
      final api = context.read<AuthProvider>().api;
      if (currentCanFollow == 'yes') {
        // Was "Follow", user clicked "Follow". We want to follow.
        await api.followUser(widget.userDetails!.oId);
      } else {
        // Was "Unfollow", user clicked "Unfollow". We want to unfollow.
        await api.unfollowUser(widget.userDetails!.oId);
      }
    } catch (e) {
      // User request: "Regardless of whether interface returns correctly... changes"
      // So we do NOT revert state.
      debugPrint('Follow/Unfollow failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作请求已发送 (后台可能报错: $e)'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBg =
        widget.userDetails?.cardBg != null &&
        widget.userDetails!.cardBg!.isNotEmpty;

    return Container(
      width: 320,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 1. Full Background Image
            Positioned.fill(
              child: hasBg
                  ? Image.network(
                      widget.userDetails!.cardBg!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.white),
                    )
                  : Container(color: Colors.white),
            ),

            // 2. Bottom Blur/Frosted Glass Area
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 170,
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Tags (Indented to avoid avatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 108),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                flex: 3,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    widget.userDetails?.userNickname ??
                                        widget.userName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.userDetails?.userName != null &&
                                  widget.userDetails?.userName !=
                                      widget.userDetails?.userNickname)
                                Flexible(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.bottomLeft,
                                      child: Text(
                                        widget.userDetails!.userName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Intro
                          Text(
                            widget.userDetails?.userIntro ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[900],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Stats/Badges
                    Padding(
                      padding: const EdgeInsets.only(left: 108),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.userDetails?.userAppRole == 0)
                            _buildBadge(Icons.security, '黑客', Colors.black),
                          if (widget.userDetails?.userAppRole == 1)
                            _buildBadge(Icons.brush, '画家', Colors.blue),
                          if (widget.userDetails?.userCity != null &&
                              widget.userDetails!.userCity!.isNotEmpty)
                            _buildBadge(
                              Icons.location_on,
                              widget.userDetails!.userCity!,
                              Colors.green,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bottom Row: Stats Left, Buttons Right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (widget.userDetails?.userRole != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.userDetails?.userRole ?? 'User',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.userDetails?.userNo != null)
                                  Text(
                                    '# ${widget.userDetails!.userNo}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Stats (Online/ID)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    widget.userDetails?.userOnlineFlag == true
                                    ? Colors.red
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.userDetails?.userOnlineFlag == true
                                    ? '在线'
                                    : '离线',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Buttons
                        FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(60, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('私信'),
                        ),
                        const SizedBox(width: 8),
                        if (_canFollow == 'yes')
                          FilledButton(
                            onPressed: _toggleFollow,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue,
                              minimumSize: const Size(60, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('关注'),
                          )
                        else if (_canFollow == 'no')
                          OutlinedButton(
                            onPressed: _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: const Size(80, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('取消关注'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. Avatar (Overlapping)
            Positioned(
              left: 16,
              top: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    widget.avatarUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
