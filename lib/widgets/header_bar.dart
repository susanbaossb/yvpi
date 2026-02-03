/// 页面顶部导航栏组件
///
/// 包含：
/// - 应用 Logo 与标题
/// - 主要功能导航菜单 (首页, 热门, 关注等)
/// - 搜索输入框
/// - 用户个人中心入口 (头像, 下拉菜单)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🐟', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      _navButton(context, '最新', '/'),
                      _navButton(context, '热门', '/hot'),
                      _navButton(context, '聊天室', '/chat'),
                      _navButton(context, '关注', '/follow'),
                      const Spacer(),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            hintText: '搜索你感兴趣的内容',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.wb_sunny_outlined),
                        tooltip: '切换颜色模式',
                      ),
                      const SizedBox(width: 8),
                      _iconButtonWithCount(Icons.notifications_none, 0),
                      const SizedBox(width: 8),
                      _iconButtonWithCount(Icons.chat_bubble_outline, 0),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('发帖'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F5),
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final user = auth.user;
                          if (auth.isLoggedIn && user == null) {
                            return const SizedBox(
                              width: 36,
                              height: 36,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          if (user != null && user.userAvatarURL.isNotEmpty) {
                            return Builder(
                              builder: (context) {
                                return InkWell(
                                  onTap: () async {
                                    final RenderBox overlay =
                                        Overlay.of(
                                              context,
                                            ).context.findRenderObject()
                                            as RenderBox;
                                    final RenderBox button =
                                        context.findRenderObject() as RenderBox;
                                    final position = button.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    );
                                    final size = button.size;

                                    const menuWidth = 156.0;
                                    final centerX =
                                        position.dx + size.width / 2;
                                    final menuLeft = centerX - menuWidth / 2;

                                    final value = await showMenu<String>(
                                      context: context,
                                      position: RelativeRect.fromRect(
                                        Rect.fromLTWH(
                                          menuLeft,
                                          position.dy + size.height + 10,
                                          menuWidth,
                                          0,
                                        ),
                                        Offset.zero & overlay.size,
                                      ),
                                      items: [
                                        const PopupMenuItem(
                                          value: 'profile',
                                          child: Text('个人主页'),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'settings',
                                          child: Text('设置'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'countdown',
                                          child: Text('⏰ 下班倒计时'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'support',
                                          child: Text('❤️ 支持我们'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'vip',
                                          child: Text('👑 开通VIP'),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'help',
                                          child: Text('帮助'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'logout',
                                          child: Text('登出'),
                                        ),
                                      ],
                                      constraints: const BoxConstraints(
                                        minWidth: 156,
                                        maxWidth: 156,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    );

                                    if (value == 'logout') {
                                      auth.logout();
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(
                                      user.userAvatarURL,
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                          return InkWell(
                            onTap: () => context.go('/login'),
                            child: const CircleAvatar(
                              radius: 18,
                              child: Icon(Icons.person),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, String label, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextButton(onPressed: () => context.go(route), child: Text(label)),
    );
  }

  Widget _iconButtonWithCount(IconData icon, int count) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          if (count >= 0) ...[
            const SizedBox(width: 4),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}
