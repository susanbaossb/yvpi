import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 文章评论列表组件
///
/// 展示文章的评论列表，支持：
/// - 渲染 HTML 评论内容
/// - 显示评论作者信息
/// - 评论回复功能（弹出底部输入框）
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/article_detail.dart';
import '../providers/auth_provider.dart';
import '../widgets/hover_user_card.dart';

class ArticleCommentsWidget extends StatefulWidget {
  final ArticleDetail article;
  final List<ArticleComment> comments;
  final bool loadingComments;
  final bool loadingMore;
  final bool hasMoreComments;
  final Function(String, String, String?)? onReplyTap;
  final Function()? onLoadMore;

  const ArticleCommentsWidget({
    super.key,
    required this.article,
    required this.comments,
    this.loadingComments = false,
    this.loadingMore = false,
    this.hasMoreComments = false,
    this.onReplyTap,
    this.onLoadMore,
  });

  @override
  State<ArticleCommentsWidget> createState() => _ArticleCommentsWidgetState();
}

class _ArticleCommentsWidgetState extends State<ArticleCommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _expandedComments = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
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
              '${widget.article.commentCount} 回帖',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Comment Input Placeholder
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: InkWell(
                onTap: () {
                  widget.onReplyTap?.call('', widget.article.title, null);
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
            if (widget.loadingComments && widget.comments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (widget.comments.isEmpty)
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
                    itemCount: widget.comments.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 32,
                      thickness: 0.5,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final comment = widget.comments[index];
                      return _buildCommentItem(comment);
                    },
                  ),
                  if (widget.loadingMore)
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
                  if (!widget.hasMoreComments && widget.comments.isNotEmpty)
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
        ?.userName;
    final canReply = currentUserName == null
        ? true
        : currentUserName != comment.userName;

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
                        widget.onReplyTap?.call(
                          comment.id,
                          comment.userNickname,
                          comment.authorAvatar,
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
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final reply in comment.replies)
                          _buildReplyItem(reply, canReply),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyItem(ArticleComment reply, bool canReply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (reply.replyToUserNickname != null)
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
                      widget.onReplyTap?.call(
                        reply.id,
                        reply.userNickname,
                        reply.authorAvatar,
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
      ),
    );
  }

  Widget _buildAvatar(
    String url,
    String name, {
    String userName = '',
    double size = 20,
  }) {
    return HoverUserCard(
      userName: userName.isNotEmpty ? userName : name,
      avatarUrl: url,
      child: CircleAvatar(
        radius: size,
        backgroundImage:
            url.isNotEmpty
                ? NetworkImage(url)
                : null,
        onBackgroundImageError: (exception, stackTrace) {},
        child: url.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: size),
              )
            : null,
      ),
    );
  }
}
