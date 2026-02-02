/// 页面底部栏组件
///
/// 显示应用版本信息、版权声明以及可能的底部导航链接。
/// 通常固定在页面最底部。
import 'package:flutter/material.dart';

class FooterBar extends StatelessWidget {
  const FooterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(label: Text('CDN高速资源支持')),
                    Chip(label: Text('云原图防盗链支持')),
                    Chip(label: Text('抓鱼器')),
                    Chip(label: Text('论坛社区')),
                    Chip(label: Text('NTab精选标注')),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Copyright © 2021 - 2026 W&P Tech. All Rights Reserved.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '京ICP备2022000226号-1 | 公安网安备 11011302003886号',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
