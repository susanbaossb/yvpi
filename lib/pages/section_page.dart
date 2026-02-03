/// 分区通用页面
///
/// 用于展示特定板块的内容列表，如“热门”、“关注”、“聊天室”等。
/// 结构类似于首页，但专注于特定分类的内容展示。
import 'package:flutter/material.dart';
import '../widgets/header_bar.dart';
import '../widgets/footer_bar.dart';

class SectionPage extends StatelessWidget {
  final String title;
  const SectionPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 68),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0x11000000)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('$title 区域占位（开发中...）'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
}
