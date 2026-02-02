/// 文章详情页面
///
/// 展示文章完整内容，包含：
/// - 顶部导航栏与文章元数据（标题、作者、标签）
/// - HTML 内容渲染（支持图片预览、代码高亮）
/// - 右侧悬浮目录导航（TOC，仅在大屏显示）
/// - 底部评论列表与回复输入框
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/article_detail.dart';
import '../providers/auth_provider.dart';
import '../widgets/header_bar.dart';
import '../widgets/hover_user_card.dart';
import '../widgets/reply_bottom_sheet.dart';

class TOCItem {
  final String title;
  final int level;
  final GlobalKey key = GlobalKey();

  TOCItem(this.title, this.level);
}

class ArticleData {
  final ArticleDetail article;
  final String content;
  final List<TOCItem> toc;

  ArticleData(this.article, this.content, this.toc);
}

class ArticleDetailPage extends StatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late Future<ArticleData> _articleFuture;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // --- 评论分页相关状态 ---
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  bool _loadingMore = false; // 是否正在加载下一页
  bool _hasMoreComments = true; // 是否还有更多评论数据
  int _currentPage = 1; // 当前页码
  final Set<String> _expandedComments = {}; // 展开的评论ID
  final List<SimpleUser> _participants = []; // 参与回帖的用户列表
  final Set<String> _participantNames = {}; // 参与者用户名去重集合
  final Set<String> _allLoadedCommentIds = {}; // 已加载的所有评论ID，用于去重检测

  @override
  void initState() {
    super.initState();
    _loadArticle();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  /// 滚动监听器：处理无限滚动加载逻辑
  void _onScroll() {
    // 当滚动到距离底部不足200像素时触发加载更多
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMoreComments && !_loadingComments) {
        _loadMoreComments();
      }
    }
  }

  void _loadArticle() {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _articleFuture = api.getArticleDetail(widget.articleId).then((article) {
        final toc = <TOCItem>[];
        // Process HTML to find headers and inject markers
        final processedContent = article.content.replaceAllMapped(
          RegExp(r'<h([1-3])(.*?)>(.*?)</h\1>', caseSensitive: false),
          (match) {
            final level = int.parse(match.group(1)!);
            final attrs = match.group(2) ?? '';
            final content = match.group(3) ?? '';

            // Strip HTML tags from title for TOC display
            final title = content.replaceAll(RegExp(r'<[^>]*>'), '');

            final index = toc.length;
            toc.add(TOCItem(title, level));

            // Inject a marker div before the header
            return '<div id="toc-marker-$index"></div><h$level$attrs>$content</h$level>';
          },
        );
        return ArticleData(article, processedContent, toc);
      });
    });
  }

  /// 加载下一页评论
  Future<void> _loadMoreComments() async {
    setState(() {
      _loadingMore = true;
      _currentPage++;
    });
    await _loadComments();
    if (mounted) {
      setState(() {
        _loadingMore = false;
      });
    }
  }

  /// 获取评论数据（包含分页、去重、处理嵌套）
  Future<void> _loadComments() async {
    final api = context.read<AuthProvider>().api;
    try {
      final comments = await api.getArticleComments(
        widget.articleId,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          if (comments.isEmpty) {
            _hasMoreComments = false;
          } else {
            // --- 分页结束判断 & 去重 ---
            // 过滤掉已加载的重复数据
            final List<ArticleComment> uniqueComments = [];
            if (_currentPage == 1) {
              _allLoadedCommentIds.clear();
              uniqueComments.addAll(comments);
              for (var c in comments) _allLoadedCommentIds.add(c.id);
            } else {
              bool allDuplicates = true;
              for (var c in comments) {
                if (!_allLoadedCommentIds.contains(c.id)) {
                  allDuplicates = false;
                  uniqueComments.add(c);
                  _allLoadedCommentIds.add(c.id);
                }
              }

              // 如果全是重复数据，说明 API 返回了最后一页的数据（某些后端分页行为），此时应停止加载
              if (allDuplicates && comments.isNotEmpty) {
                _hasMoreComments = false;
                _currentPage--; // 回滚页码
                _loadingComments = false;
                _loadingMore = false;
                return;
              }
            }

            // --- 更新回帖榜参与者 ---
            for (var c in uniqueComments) {
              if (!_participantNames.contains(c.userNickname)) {
                _participantNames.add(c.userNickname);
                _participants.add(
                  SimpleUser(
                    name: c.userNickname,
                    avatar: c.authorAvatar,
                    userName: c.userName,
                  ),
                );
              }
            }

            // --- 处理评论树形结构 ---
            final processedComments = _processComments(uniqueComments);
            if (_currentPage == 1) {
              _comments = processedComments;
            } else {
              _comments.addAll(processedComments);
            }
          }
          _loadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingComments = false;
          _loadingMore = false; // Also reset loading more on error
        });
      }
      print('Failed to load comments: $e');
    }
  }

  /// 处理评论列表：将扁平列表转换为树形结构（将所有子回复展平挂载到根评论下）
  List<ArticleComment> _processComments(List<ArticleComment> rawComments) {
    // 1. 创建映射表以便快速查找父评论
    final Map<String, ArticleComment> commentMap = {
      for (var c in rawComments) c.id: c,
    };

    // 2. 识别根评论并挂载子回复
    final List<ArticleComment> roots = [];

    // 按时间排序原始评论（旧在前），确保回复列表按时间顺序排列
    rawComments.sort((a, b) {
      if (a.created != null && b.created != null) {
        return a.created!.compareTo(b.created!);
      }
      return 0;
    });

    for (var comment in rawComments) {
      if (comment.originalCommentId.isEmpty) {
        roots.add(comment);
      } else {
        // 是回复：寻找最顶层的根评论
        // 如果是多级嵌套（C 回复 B，B 回复 A），我们需要找到 A，并将 C 挂载到 A 的 replies 中
        // 这样 UI 才能在 A 下面显示出 B 和 C（因为 UI 只支持一级展开）
        ArticleComment? root;
        var current = comment;
        int depth = 0;

        while (current.originalCommentId.isNotEmpty && depth < 50) {
          final parent = commentMap[current.originalCommentId];
          if (parent == null) {
            // 父评论不在当前列表中（可能在上一页），无法挂载到根
            break;
          }
          current = parent;
          depth++;
        }

        // 循环结束后，current 即为当前链条上能找到的最顶层评论（可能是真正的根评论，也可能是因跨页导致父级缺失的"临时根"）
        root = current;

        if (root != comment) {
          // 如果直接父级不是根评论，说明是"回复的回复"（如 C 回复 B，B 回复 A），
          // 此时需要在 UI 上显示"回复 B: ..."的引用信息
          if (comment.originalCommentId.isNotEmpty &&
              comment.originalCommentId != root.id) {
            final directParent = commentMap[comment.originalCommentId];
            if (directParent != null) {
              comment.replyToUserNickname =
                  '${directParent.userNickname}(${directParent.userName})';
              comment.replyToContent = directParent.content;
            }
          }
          root.replies.add(comment);
        } else {
          // 找不到父级（孤儿评论或跨页引用且父级不在当前页），作为根评论展示
          roots.add(comment);
        }
      }
    }

    // 3. 根评论排序：按最新时间倒序（新的在前）
    roots.sort((a, b) {
      if (a.created != null && b.created != null) {
        return b.created!.compareTo(a.created!);
      }
      return 0; // Fallback
    });

    return roots;
  }

  void _toggleComment(String commentId) {
    setState(() {
      if (_expandedComments.contains(commentId)) {
        _expandedComments.remove(commentId);
      } else {
        _expandedComments.add(commentId);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showReplySheet({
    String? replyToId,
    String? replyToName,
    String? replyToUserAvatar,
    String? articleTitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) => ReplyBottomSheet(
        articleId: widget.articleId,
        articleTitle: articleTitle,
        api: context.read<AuthProvider>().api,
        replyToId: replyToId,
        replyToName: replyToName,
        replyToUserAvatar: replyToUserAvatar,
        onSuccess: () {
          // Refresh comments
          setState(() {
            _currentPage = 1;
            _comments.clear();
            _loadingComments = true;
            _hasMoreComments = true;
          });
          _loadComments();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const HeaderBar(),
          Expanded(
            child: FutureBuilder<ArticleData>(
              future: _articleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('加载失败: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadArticle,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('未找到文章'));
                }

                final data = snapshot.data!;
                final article = data.article;
                final showTOC =
                    MediaQuery.of(context).size.width > 1200 &&
                    data.toc.isNotEmpty;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        size: 18,
                                      ),
                                      label: const Text('返回'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildArticleCard(data),
                                const SizedBox(height: 16),
                                _buildCommentsSection(article),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showTOC)
                      Container(
                        width: 250,
                        margin: const EdgeInsets.only(
                          top: 24,
                          right: 16,
                          bottom: 24,
                        ),
                        child: _buildTOC(data.toc),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTOC(List<TOCItem> toc) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '目录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: toc.length,
                itemBuilder: (context, index) {
                  final item = toc[index];
                  return InkWell(
                    onTap: () {
                      if (item.key.currentContext != null) {
                        Scrollable.ensureVisible(
                          item.key.currentContext!,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: 0.1,
                        );
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16 + (item.level - 1) * 12.0,
                        right: 16,
                        top: 10,
                        bottom: 10,
                      ),
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(ArticleData data) {
    final article = data.article;
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Center(
              child: Text(
                article.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Content
            HtmlWidget(
              data.content,
              textStyle: const TextStyle(fontSize: 16, height: 1.6),
              // Enable interaction with images, links etc.
              onTapUrl: (url) {
                // Handle link tap
                return true;
              },
              customWidgetBuilder: (element) {
                if (element.localName == 'div' &&
                    element.id.startsWith('toc-marker-')) {
                  final index = int.tryParse(element.id.substring(11));
                  if (index != null && index < data.toc.length) {
                    return SizedBox(height: 1, key: data.toc[index].key);
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // New Author & Meta Info Section
            _buildMetaInfoBox(article),

            const SizedBox(height: 24),

            // Interaction Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  Icons.thumb_up_outlined,
                  '点赞',
                  article.likeCount,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  Icons.favorite_border,
                  '收藏',
                  article.collectCount,
                ),
                const SizedBox(width: 12),
                _buildActionButton(Icons.card_giftcard, '感谢', 0),
                const SizedBox(width: 12),
                _buildActionButton(
                  Icons.comment_outlined,
                  '回帖',
                  article.commentCount,
                  onTap: () {
                    _showReplySheet(articleTitle: article.title);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfoBox(ArticleDetail article) {
    // Participants are now managed in state based on loaded comments
    // But we should also include any initial participants from article detail if available (and not duplicate)
    // Actually user requirement is "list changes based on comments loading"
    // So _participants in state is the source of truth for the UI list

    // We should ensure initial load of comments populates _participants (it does in _loadComments)
    // However, if article detail has some participants that are not in comments yet (e.g. pagination),
    // user said "based on comments loading". So let's stick to _participants which comes from loaded comments.

    // BUT, we should probably initialize _participants with article.participatingUsers if we want to show something initially?
    // User said "rank avatar changes based on comment loading".
    // Let's use _participants from state which is cumulative.

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Author Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(
                article.authorAvatar,
                article.userNickname,
                userName: article.userName,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${article.userNickname}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Stats
                        _buildStatText('${article.likeCount}', '点赞'),
                        const SizedBox(width: 8),
                        _buildStatText(
                          '0',
                          '关注',
                        ), // Placeholder for Follow count
                        const SizedBox(width: 8),
                        _buildStatText('${article.collectCount}', '收藏'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          article.timeAgo,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badges (Mocked for now as we don't have them in model)
                        _buildBadge('超级会员', Colors.orange),
                        const SizedBox(width: 4),
                        _buildBadge('摸鱼派5岁啦', Colors.pinkAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (article.rewardedUsers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 16),
            // Row 2: Rewards
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Text(
                        '${article.rewardedUsers.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const Text(
                        '感谢',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final user in article.rewardedUsers)
                        _buildAvatar(
                          user.avatar,
                          user.name,
                          userName: user.userName,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (_participants.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (article.rewardedUsers.isEmpty)
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
            if (article.rewardedUsers.isNotEmpty) const SizedBox(height: 16),

            if (article.rewardedUsers.isNotEmpty) const SizedBox(height: 0),
            const SizedBox(height: 16),
            const SizedBox(height: 16),

            // Row 3: Participants
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Text(
                        '${article.commentCount}', // Use total comment count from article API
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const Text(
                        '回帖',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final user in _participants)
                        _buildAvatar(
                          user.avatar,
                          user.name,
                          userName: user.userName,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatText(String count, String label) {
    return Text(
      '$count $label',
      style: TextStyle(color: Colors.grey[600], fontSize: 12),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String url,
    String name, {
    double size = 20,
    String? userName,
  }) {
    final avatar = CircleAvatar(
      radius: size,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: size),
            )
          : null,
    );

    if (userName != null && userName.isNotEmpty) {
      return HoverUserCard(userName: userName, avatarUrl: url, child: avatar);
    }

    return avatar;
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    int count, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              count > 0 ? '$count $label' : label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection(ArticleDetail article) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${article.commentCount} 回帖',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Comment Input Placeholder
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: InkWell(
                onTap: () {
                  _showReplySheet(articleTitle: article.title);
                },
                borderRadius: BorderRadius.circular(4),
                child: IgnorePointer(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: '请输入回帖内容...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
              ),
            ),

            // Comments List
            if (_loadingComments && _comments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_comments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('暂无评论'),
                ),
              )
            else
              Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 32,
                      thickness: 0.5,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return _buildCommentItem(comment);
                    },
                  ),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (!_hasMoreComments && _comments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          '已经到底了~',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(ArticleComment comment) {
    final hasReplies = comment.replies.isNotEmpty;
    final isExpanded = _expandedComments.contains(comment.id);
    final currentUserName = context
        .read<AuthProvider>()
        .user
        ?.userName; // 当前登录用户
    final canReply = currentUserName == null
        ? true
        : currentUserName != comment.userName; // 自己的评论不显示回复

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(
          comment.authorAvatar,
          comment.userNickname,
          userName: comment.userName,
          size: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${comment.userNickname}(${comment.userName})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.timeAgo,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              HtmlWidget(
                comment.content,
                textStyle: const TextStyle(fontSize: 14),
                // Limit image size to 150x150 in comments
                customStylesBuilder: (element) {
                  if (element.localName == 'img') {
                    return {'max-width': '100px', 'max-height': '100px'};
                  }
                  return null;
                },
                onTapUrl: (url) {
                  return true;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (canReply)
                    InkWell(
                      onTap: () {
                        _showReplySheet(
                          replyToId: comment.id,
                          replyToName: comment.userNickname,
                          replyToUserAvatar: comment.authorAvatar,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '回复',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Actions like Like/Dislike/Report can go here
                ],
              ),

              // Replies Section
              if (hasReplies) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _toggleComment(comment.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${comment.replies.length} 回复',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ),

                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: comment.replies.map((reply) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildReplyItem(reply),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyItem(ArticleComment reply) {
    final currentUserName = context
        .read<AuthProvider>()
        .user
        ?.userName; // 当前登录用户
    final canReply = currentUserName == null
        ? true
        : currentUserName != reply.userName; // 自己的评论不显示回复
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(
          reply.authorAvatar,
          reply.userNickname,
          userName: reply.userName,
          size: 12,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${reply.userNickname}(${reply.userName})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    reply.timeAgo,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 引用回复内容展示
              if (reply.replyToUserNickname != null &&
                  reply.replyToContent != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8, top: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: '回复 ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            TextSpan(
                              text: reply.replyToUserNickname,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const TextSpan(
                              text: '：',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      HtmlWidget(
                        reply.replyToContent!,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              HtmlWidget(
                reply.content,
                textStyle: const TextStyle(fontSize: 13),
                // Limit image size to 150x150 in replies
                customStylesBuilder: (element) {
                  if (element.localName == 'img') {
                    return {'max-width': '100px', 'max-height': '100px'};
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              if (canReply)
                InkWell(
                  onTap: () {
                    _showReplySheet(
                      replyToId: reply.id,
                      replyToName: reply.userNickname,
                      replyToUserAvatar: reply.authorAvatar,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '回复',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
