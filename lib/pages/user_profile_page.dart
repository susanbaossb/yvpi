import 'package:flutter/material.dart';

/// 用户个人主页
///
/// 展示用户的详细个人信息和动态。
/// 包含：
/// - 个人资料卡片（头像、角色、积分、统计数据等）
/// - 关注/取消关注功能
/// - Tab 页签切换展示用户的文章、回帖等动态内容
import 'package:provider/provider.dart';
import '../api/fishpi_api.dart';
import '../models/article.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/header_bar.dart';
import '../widgets/footer_bar.dart';
import '../widgets/hover_user_card.dart';

class UserProfilePage extends StatefulWidget {
  final String username;
  const UserProfilePage({super.key, required this.username});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? _user;
  bool _isLoadingUser = true;
  String? _error;
  bool _isFollowing = false;
  bool _isProcessingFollow = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final api = context.read<AuthProvider>().api;
      final user = await api.getUserInfo(widget.username);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoadingUser = false;
          _isFollowing =
              user?.canFollow == 'no'; // 'no' 表示已关注（不可再关注），'yes' 表示未关注
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null || _isProcessingFollow) return;

    setState(() {
      _isProcessingFollow = true;
    });

    try {
      final api = context.read<AuthProvider>().api;
      if (_isFollowing) {
        await api.unfollowUser(_user!.oId);
      } else {
        await api.followUser(_user!.oId);
      }

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _isProcessingFollow = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingFollow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 68),
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _isLoadingUser
                            ? const SizedBox(
                                height: 400,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _error != null
                            ? SizedBox(
                                height: 400,
                                child: Center(child: Text('加载失败: $_error')),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Content Area
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        _buildTabBar(),
                                        const SizedBox(height: 16),
                                        _buildTabContent(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right Sidebar
                                  Expanded(
                                    flex: 1,
                                    child: _buildUserProfileCard(),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const FooterBar(),
                ],
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: HeaderBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.orange,
        tabs: const [
          Tab(text: '帖子'),
          Tab(text: '长文章'),
          Tab(text: '回帖'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(minHeight: 500),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          switch (_tabController.index) {
            case 0:
              return _ArticleList(username: widget.username);
            case 1:
            case 2:
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    '没有鸡，哪来的鸡蛋呢？',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              );
            default:
              return const SizedBox();
          }
        },
      ),
    );
  }

  Widget _buildUserProfileCard() {
    if (_user == null) return const SizedBox();
    final u = _user!;
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            HoverUserCard(
              userName: u.userName,
              avatarUrl: u.userAvatarURL,
              child: ClipOval(
                child: Image.network(
                  u.userAvatarURL,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              u.userNickname.isNotEmpty ? u.userNickname : u.userName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              u.userName,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            // Badges from allMetalOwned
            if (u.allMetalOwned != null && u.allMetalOwned!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: u.allMetalOwned!.map((badge) {
                    final imageUrl = badge.imageUrl;
                    if (imageUrl != null) {
                      return Tooltip(
                        message:
                            '[${badge.type ?? "勋章"}] ${badge.name} - ${badge.description ?? ""}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                badge.backgroundColor ??
                                Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.network(
                                imageUrl,
                                width: 16,
                                height: 16,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                badge.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: badge.fontColor ?? Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  }).toList(),
                ),
              ),
            // Tags/Badges
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (u.userRole != '0') _buildBadge(u.userRole, Colors.pink),
                _buildBadge(
                  u.userOnlineFlag == true ? '在线' : '离线',
                  u.userOnlineFlag == true ? Colors.orange : Colors.grey,
                ),
                if (u.userAppRole == 0) _buildBadge('成员', Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _isFollowing
                  ? OutlinedButton(
                      onPressed: _isProcessingFollow ? null : _toggleFollow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: _isProcessingFollow
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('取消关注'),
                    )
                  : FilledButton(
                      onPressed: _isProcessingFollow ? null : _toggleFollow,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: _isProcessingFollow
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('关注'),
                    ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildInfoRow('摸鱼派 ${u.userNo ?? 0} 号成员', ''),
            if (u.userRole.isNotEmpty) _buildInfoRow('角色', u.userRole),
            _buildInfoRow('积分', '${u.userPoint ?? 0}'),
            _buildInfoRow('在线时长', '${((u.onlineMinute ?? 0))} 分钟'),
            if (u.userCity != null && u.userCity!.isNotEmpty)
              _buildInfoRow('位置', u.userCity!),
            const SizedBox(height: 24),
            // Stats Grid
            // Points (bottom part of image)
            // Just a placeholder or partial view as in image
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _ArticleList extends StatefulWidget {
  final String username;
  const _ArticleList({required this.username});

  @override
  State<_ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends State<_ArticleList> {
  List<ArticleSummary> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final api = context.read<AuthProvider>().api;
      final articles = await api.getUserArticles(widget.username);
      if (mounted) {
        setState(() {
          _articles = articles;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_articles.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32.0), child: Text('暂无数据')),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final article = _articles[index];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.articleTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (article.articleTags != null)
                          Text(
                            article.articleTags!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (article.articleTags != null)
                          const SizedBox(width: 8),
                        Text(
                          '${article.articleCommentCount ?? 0} 回帖 • ${article.articleViewCntDisplayFormat ?? 0} 浏览 • ${article.articleCreateTimeStr ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if ((article.articleCommentCount ?? 0) > 0)
                Container(
                  margin: const EdgeInsets.only(left: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${article.articleCommentCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
