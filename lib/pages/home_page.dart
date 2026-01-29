import 'package:flutter/material.dart';
import '../widgets/header_bar.dart';
import '../widgets/footer_bar.dart';
import '../api/fishpi_api.dart';
import '../models/article.dart';
import '../widgets/hover_user_card.dart';
import '../widgets/home_dashboard.dart';
import '../widgets/chat_room.dart';
import '../widgets/breezemoon_widget.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ArticleColumn(
                            title: '最近',
                            loader: (api) => api.getRecentArticles(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ArticleColumn(
                            title: '热门',
                            loader: (api) => api.getHotArticles(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(width: 300, child: _RightRankColumn()),
                      ],
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Chat Room
                        const Expanded(
                          flex: 3,
                          child: SizedBox(height: 800, child: ChatRoomWidget()),
                        ),
                        const SizedBox(width: 16),
                        // Center: Hot Articles
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 800,
                            child: SingleChildScrollView(
                              child: _ArticleColumn(
                                title: '热门',
                                loader: (api) => api.getHotArticles(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right: Breeze Moon
                        const Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 800,
                            child: BreezeMoonWidget(),
                          ),
                        ),
                      ],
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
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Padding(
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
                    child: SizedBox(
                      height: 24,
                      child: LinearProgressIndicator(),
                    ),
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
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, i) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return Row(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (it.articleCommentCount != null)
                          Text(
                            '${it.articleCommentCount}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
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
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x11000000)),
          ),
          child: Padding(
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
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, i) =>
                          const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final it = items[index];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(it['userName'])),
                            Text(
                              '${it['days']}天',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x11000000)),
          ),
          child: Padding(
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
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, i) =>
                          const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final it = items[index];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(it['userName'])),
                            Text(
                              '${it['minutes']}分',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
