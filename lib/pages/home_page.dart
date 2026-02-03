/// 应用程序首页
///
/// 采用响应式布局，包含：
/// - 顶部导航栏 (HeaderBar)
/// - 左侧/主内容区域：展示最新文章、热门文章列表及“清风明月”动态
/// - 右侧侧边栏 (HomeDashboard)：展示活跃度、签到榜、在线榜及聊天室入口
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../api/fishpi_api.dart';
import '../models/article.dart';
import '../widgets/header_bar.dart';
import '../widgets/footer_bar.dart';
import '../widgets/home_dashboard.dart';
import '../widgets/chat_room.dart';
import '../widgets/breezemoon_widget.dart';
import 'article_detail_page.dart';
import '../widgets/hover_user_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const HeaderBar(),
              const SizedBox(height: 12),
              // 1. Article List Section
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0x11000000)),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ArticleColumn(
                                title: '最近',
                                loader: (api) => api.getRecentArticles(),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Color(0x11000000),
                            ),
                            Expanded(
                              child: _ArticleColumn(
                                title: '热门',
                                loader: (api) => api.getHotArticles(),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Color(0x11000000),
                            ),
                            SizedBox(width: 300, child: _RightRankColumn()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 2. Dashboard Section
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: HomeDashboard(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 3. Interaction Section
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0x11000000)),
                      ),
                      child: SizedBox(
                        height: 800,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Chat Room
                            const Expanded(flex: 3, child: ChatRoomWidget()),
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Color(0x11000000),
                            ),
                            // Center: Hot Articles
                            Expanded(
                              flex: 4,
                              child: SingleChildScrollView(
                                child: _ArticleColumn(
                                  title: '热门',
                                  loader: (api) => api.getHotArticles(),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Color(0x11000000),
                            ),
                            // Right: Breeze Moon
                            const Expanded(flex: 3, child: BreezeMoonWidget()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const FooterBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleColumn extends StatelessWidget {
  final String title;
  final Future<List<ArticleSummary>> Function(FishPiApi api) loader;
  const _ArticleColumn({required this.title, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('更多')),
            ],
          ),
          const Divider(),
          FutureBuilder<List<ArticleSummary>>(
            future: loader(context.read<AuthProvider>().api),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(height: 24, child: LinearProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '加载失败：${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              final items = snapshot.data ?? const <ArticleSummary>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无数据'),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 8),
                    Builder(
                      builder: (context) {
                        final it = items[i];
                        return InkWell(
                          onTap: () {
                            if (it.id != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ArticleDetailPage(articleId: it.id!),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                HoverUserCard(
                                  userName: it.authorName ?? 'Unknown',
                                  avatarUrl: it.thumbnailURL ?? '',
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundImage: it.thumbnailURL != null
                                        ? NetworkImage(it.thumbnailURL!)
                                        : null,
                                    child: it.thumbnailURL == null
                                        ? const Text('U')
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.articleTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (it.articleViewCntDisplayFormat != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.whatshot,
                                          size: 12,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          it.articleViewCntDisplayFormat!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RightRankColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthProvider>().api;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '今日签到排行',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('更多')),
                ],
              ),
              const Divider(),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: api.getMockCheckinRank(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        height: 24,
                        child: LinearProgressIndicator(),
                      ),
                    );
                  }
                  final items = snapshot.data!;
                  return Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 8),
                        Row(
                          children: [
                            CircleAvatar(radius: 14, child: Text('${i + 1}')),
                            const SizedBox(width: 8),
                            Expanded(child: Text(items[i]['userName'])),
                            Text(
                              '${items[i]['days']}天',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0x11000000)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '在线时长排行',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('更多')),
                ],
              ),
              const Divider(),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: api.getMockOnlineRank(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        height: 24,
                        child: LinearProgressIndicator(),
                      ),
                    );
                  }
                  final items = snapshot.data!;
                  return Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 8),
                        Row(
                          children: [
                            CircleAvatar(radius: 14, child: Text('${i + 1}')),
                            const SizedBox(width: 8),
                            Expanded(child: Text(items[i]['userName'])),
                            Text(
                              '${items[i]['minutes']}分',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
