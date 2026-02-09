/// 清风明月展示组件
///
/// 用于渲染单条“清风明月”动态内容，
/// 包含发布者头像、昵称、内容文本、发布时间及评论数统计。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/fishpi_api.dart';
import '../models/breezemoon.dart';
import 'hover_user_card.dart';

class BreezeMoonWidget extends StatefulWidget {
  const BreezeMoonWidget({super.key});

  @override
  State<BreezeMoonWidget> createState() => _BreezeMoonWidgetState();
}

class _BreezeMoonWidgetState extends State<BreezeMoonWidget> {
  late Future<List<BreezeMoon>> _breezeMoonsFuture;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _breezeMoonsFuture = context.read<FishPiApi>().getBreezeMoons(size: 20);
    });
  }

  Future<void> _sendBreezeMoon() async {
    if (_controller.text.trim().isEmpty) return;

    final content = _controller.text;
    _controller.clear();

    try {
      await context.read<FishPiApi>().sendBreezeMoon(content);
      if (!mounted) return;
      _refresh();
    } catch (e) {
      debugPrint('发布失败: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('清风明月', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
            ],
          ),
        ),
        const Divider(height: 1),
        // Input Area
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '清风明月',
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendBreezeMoon(),
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE0E0E0)),
                InkWell(
                  onTap: _sendBreezeMoon,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: const Text(
                      '发布',
                      style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        FutureBuilder<List<BreezeMoon>>(
          future: _breezeMoonsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('暂无内容'));
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (int i = 0; i < list.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final item = list[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HoverUserCard(
                              userName: item.authorName,
                              avatarUrl: item.authorAvatarURL,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundImage: NetworkImage(
                                  item.authorAvatarURL,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.content.replaceAll(RegExp(r'<[^>]*>'), ''),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
