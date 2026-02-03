import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/article_detail.dart';
import '../widgets/hover_user_card.dart';

class ArticleContentWidget extends StatelessWidget {
  final ArticleDetail article;
  final String processedContent;
  final Function(String?, String?, String?)? onAvatarTap;
  final Function(String, String, int)? onActionButtonTap;

  const ArticleContentWidget({
    super.key,
    required this.article,
    required this.processedContent,
    this.onAvatarTap,
    this.onActionButtonTap,
  });

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
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Center(
              child: SelectableText(
                article.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Content
            HtmlWidget(
              processedContent,
              textStyle: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Color(0xFF333333),
              ),
              customStylesBuilder: (element) {
                if (element.localName == 'pre') {
                  return {
                    'background-color': '#f6f8fa',
                    'padding': '16px',
                    'border-radius': '8px',
                    'overflow-x': 'auto',
                  };
                }
                if (element.localName == 'code') {
                  return {
                    'font-family': 'monospace',
                    'background-color': '#f6f8fa',
                    'padding': '2px 4px',
                    'border-radius': '4px',
                  };
                }
                if (element.localName == 'blockquote') {
                  return {
                    'margin': '0',
                    'padding-left': '16px',
                    'border-left': '4px solid #dfe2e5',
                    'color': '#6a737d',
                  };
                }
                if (element.localName == 'img') {
                  return {'max-width': '100%'};
                }
                return null;
              },
              onTapUrl: (url) async {
                return true;
              },
            ),
            const SizedBox(height: 32),
            // Meta Info Box (Participants, Rewards, etc.)
            _buildMetaInfoBox(),
            const SizedBox(height: 24),
            // Interaction Buttons
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     _buildActionButton(
            //       Icons.thumb_up_outlined,
            //       '点赞',
            //       article.likeCount,
            //       onTap: () => onActionButtonTap?.call('vote', '', 0),
            //       isActive: article.likeCount > 0, // Simplified check
            //     ),
            //     const SizedBox(width: 12),
            //     _buildActionButton(
            //       Icons.favorite_border,
            //       '收藏',
            //       article.collectCount,
            //       onTap: () => onActionButtonTap?.call('collect', '', 0),
            //     ),
            //     const SizedBox(width: 12),
            //     _buildActionButton(
            //       Icons.card_giftcard,
            //       '感谢',
            //       article.rewardCount,
            //       onTap: () => onActionButtonTap?.call('reward', '', 0),
            //       isActive: article.isReward,
            //     ),
            //     const SizedBox(width: 12),
            //     _buildActionButton(
            //       Icons.comment_outlined,
            //       '回帖',
            //       article.commentCount,
            //       onTap: () => onActionButtonTap?.call('reply', '', 0),
            //     ),
            //   ],
            // ),
          ],
        ),
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
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
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

  Widget _buildMetaInfoBox() {
    // Note: The original implementation in ArticleDetailPage used _participants from state.
    // Here we use article.participatingUsers or article.rewardedUsers as passed in article.
    // If dynamic updates are needed, parent should update the 'article' object.

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
          // Row 1: Author Info & Stats
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
                          article.userNickname,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildStatText('${article.likeCount}', '点赞'),
                        const SizedBox(width: 8),
                        _buildStatText('0', '关注'),
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

          if (article.participatingUsers.isNotEmpty) ...[
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
                        '${article.commentCount}',
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
                      for (final user in article.participatingUsers)
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withAlpha(128), width: 0.5),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
