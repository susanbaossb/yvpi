import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../api/fishpi_api.dart';
import '../models/article_detail.dart';
import '../providers/auth_provider.dart';
import '../widgets/header_bar.dart';

class ArticleDetailPage extends StatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late Future<ArticleDetail> _articleFuture;
  final TextEditingController _commentController = TextEditingController();
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  int _currentPage = 1;
  final Set<String> _expandedComments = {};

  @override
  void initState() {
    super.initState();
    _loadArticle();
    _loadComments();
  }

  void _loadArticle() {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _articleFuture = api.getArticleDetail(widget.articleId);
    });
  }

  Future<void> _loadComments() async {
    final api = context.read<AuthProvider>().api;
    try {
      final comments = await api.getArticleComments(
        widget.articleId,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          final processedComments = _processComments(comments);
          if (_currentPage == 1) {
            _comments = processedComments;
          } else {
            // For pagination, we might need to merge or just append roots
            // This logic assumes we append roots.
            // Ideally, we should merge all raw comments and re-process,
            // but that might be expensive for large lists.
            // For now, let's just append new roots.
            _comments.addAll(processedComments);
          }
          _loadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingComments = false;
        });
      }
      print('Failed to load comments: $e');
    }
  }

  List<ArticleComment> _processComments(List<ArticleComment> rawComments) {
    // 1. Create a map for easy lookup
    final Map<String, ArticleComment> commentMap = {
      for (var c in rawComments) c.id: c,
    };

    // 2. Identify roots and attach replies
    final List<ArticleComment> roots = [];

    // Sort raw comments by time (oldest first) to ensure replies are ordered correctly when added
    rawComments.sort((a, b) {
      if (a.created != null && b.created != null) {
        return a.created!.compareTo(b.created!);
      }
      return 0;
    });

    for (var comment in rawComments) {
      // Initialize replies list if not already done (though we did it in factory)
      // comment.replies is already []

      if (comment.originalCommentId.isEmpty) {
        roots.add(comment);
      } else {
        final parent = commentMap[comment.originalCommentId];
        if (parent != null) {
          parent.replies.add(comment);
        } else {
          // Parent not found in this batch, treat as root or orphan
          // For now, treat as root to ensure it's displayed
          roots.add(comment);
        }
      }
    }

    // 3. Sort roots by Latest Time (Newest First) as requested
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const HeaderBar(),
          Expanded(
            child: FutureBuilder<ArticleDetail>(
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

                final article = snapshot.data!;
                return SingleChildScrollView(
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
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('返回'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildArticleCard(article),
                          const SizedBox(height: 16),
                          _buildCommentsSection(article),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(ArticleDetail article) {
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
              article.content,
              textStyle: const TextStyle(fontSize: 16, height: 1.6),
              // Enable interaction with images, links etc.
              onTapUrl: (url) {
                // Handle link tap
                return true;
              },
            ),

            const SizedBox(height: 32),

            // Actions & Author Info
            const Divider(height: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                // Author Info
                _buildAuthorInfo(article),
                const Spacer(),
                // Stats
                _buildStatItem(Icons.thumb_up_outlined, '${article.likeCount}'),
                const SizedBox(width: 16),
                _buildStatItem(
                  Icons.favorite_border,
                  '${article.collectCount}',
                ),
                const SizedBox(width: 16),
                _buildStatItem(
                  Icons.visibility_outlined,
                  '${article.viewCount}',
                ),
              ],
            ),

            const SizedBox(height: 16),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorInfo(ArticleDetail article) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: article.authorAvatar.isNotEmpty
              ? NetworkImage(article.authorAvatar)
              : null,
          child: article.authorAvatar.isEmpty
              ? Text(article.authorName[0].toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.authorName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '${article.timeAgo} · ${article.viewCount} 阅读',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, int count) {
    return InkWell(
      onTap: () {},
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
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return _buildCommentItem(comment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(ArticleComment comment) {
    final hasReplies = comment.replies.isNotEmpty;
    final isExpanded = _expandedComments.contains(comment.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: comment.authorAvatar.isNotEmpty
              ? NetworkImage(comment.authorAvatar)
              : null,
          child: comment.authorAvatar.isEmpty
              ? Text(comment.authorName[0].toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorName,
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
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.reply, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '回复',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundImage: reply.authorAvatar.isNotEmpty
              ? NetworkImage(reply.authorAvatar)
              : null,
          child: reply.authorAvatar.isEmpty
              ? Text(
                  reply.authorName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 10),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reply.authorName,
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
              HtmlWidget(
                reply.content,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
