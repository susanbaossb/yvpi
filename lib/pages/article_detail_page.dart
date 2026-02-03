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
import '../widgets/article_content.dart';
import '../widgets/article_comments.dart';

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
  final ScrollController _scrollController = ScrollController();
  // --- 评论分页相关状态 ---
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  bool _loadingMore = false; // 是否正在加载下一页
  bool _hasMoreComments = true; // 是否还有更多评论数据
  int _currentPage = 1; // 当前页码
  final List<SimpleUser> _participants = []; // 参与回帖的用户列表
  final Set<String> _participantNames = {}; // 参与者用户名去重集合
  final Set<String> _allLoadedCommentIds = {}; // 已加载的所有评论ID，用于去重检测
  bool _showStickyHeader = false;
  ArticleData? _data;

  // Interaction states
  int _voteStatus = 0; // 0: None, -1: Liked
  bool _isReward = false;
  int _likeCount = 0;
  int _rewardCount = 0;

  @override
  void initState() {
    super.initState();
    _loadArticle();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  /// 滚动监听器：处理无限滚动加载逻辑
  void _onScroll() {
    // 1. 处理 Sticky Header 显示/隐藏
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 200;
      if (show != _showStickyHeader) {
        setState(() {
          _showStickyHeader = show;
        });
      }
    }

    // 2. 当滚动到距离底部不足200像素时触发加载更多
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
        final data = ArticleData(article, processedContent, toc);
        if (mounted) {
          setState(() {
            _data = data;
            _likeCount = data.article.likeCount;
            _isReward = data.article.isReward;
            _rewardCount = data.article.rewardCount;
          });
        }
        return data;
      });
    });
  }

  Future<void> _handleVote() async {
    final api = context.read<AuthProvider>().api;
    try {
      final newStatus = await api.voteArticle(widget.articleId);
      if (mounted) {
        setState(() {
          if (newStatus == -1) {
            // Became liked
            if (_voteStatus != -1) _likeCount++;
            _voteStatus = -1;
          } else {
            // Became unliked (0 returned means we canceled a like)
            _likeCount--;
            _voteStatus = 0;
          }
        });
      }
    } catch (e) {
      // Quietly handle error
      debugPrint('Vote failed: $e');
    }
  }

  Future<void> _handleReward() async {
    if (_isReward) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('感谢作者'),
        content: const Text('确定赠送 20 积分给该帖作者以表谢意？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = context.read<AuthProvider>().api;
              try {
                await api.rewardArticle(widget.articleId);
                if (mounted) {
                  setState(() {
                    _isReward = true;
                    _rewardCount++;
                  });
                }
              } catch (e) {
                // Quietly handle error
                debugPrint('Reward failed: $e');
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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

  @override
  void dispose() {
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

  Widget _buildStickyHeader(ArticleDetail article) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: NavigationToolbar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
        ),
        middle: Text(
          article.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStickyStatItem(
              _voteStatus == -1
                  ? Icons.thumb_up_alt
                  : Icons.thumb_up_alt_outlined,
              _likeCount,
              '点赞',
              color: _voteStatus == -1 ? Colors.red : null,
              onTap: _handleVote,
            ),
            const SizedBox(width: 8),
            _buildStickyStatItem(
              _isReward ? Icons.favorite : Icons.favorite_border,
              _rewardCount,
              '感谢',
              color: _isReward ? Colors.red : null,
              onTap: _handleReward,
            ),
          ],
        ),
        centerMiddle: true,
      ),
    );
  }

  Widget _buildStickyStatItem(
    IconData icon,
    int count,
    String tooltip, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Tooltip(
          message: tooltip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color ?? Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: color ?? Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Column(
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
                                constraints: const BoxConstraints(
                                  maxWidth: 1000,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        // TextButton.icon(
                                        //   onPressed: () =>
                                        //       Navigator.pop(context),
                                        //   icon: const Icon(
                                        //     Icons.arrow_back,
                                        //     size: 18,
                                        //   ),
                                        //   label: const Text('返回'),
                                        //   style: TextButton.styleFrom(
                                        //     foregroundColor: Colors.grey[700],
                                        //   ),
                                        // ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ArticleContentWidget(
                                      article: article.copyWith(
                                        likeCount: _likeCount,
                                        rewardCount: _rewardCount,
                                        isReward: _isReward,
                                        participatingUsers: _participants,
                                      ),
                                      processedContent: data.content,
                                      onActionButtonTap: (type, _, __) {
                                        if (type == 'vote') _handleVote();
                                        if (type == 'reward') _handleReward();
                                        if (type == 'reply') {
                                          _showReplySheet(
                                            articleTitle: article.title,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    ArticleCommentsWidget(
                                      article: article,
                                      comments: _comments,
                                      loadingComments: _loadingComments,
                                      loadingMore: _loadingMore,
                                      hasMoreComments: _hasMoreComments,
                                      onLoadMore: _loadMoreComments,
                                      onReplyTap:
                                          (
                                            replyToId,
                                            replyToName,
                                            replyToUserAvatar,
                                          ) {
                                            _showReplySheet(
                                              replyToId: replyToId,
                                              replyToName: replyToName,
                                              replyToUserAvatar:
                                                  replyToUserAvatar,
                                              articleTitle: article.title,
                                            );
                                          },
                                    ),
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
          if (_showStickyHeader && _data != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildStickyHeader(_data!.article),
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
}
