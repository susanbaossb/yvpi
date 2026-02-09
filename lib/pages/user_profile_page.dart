import 'package:flutter/material.dart';
import '../widgets/header_bar.dart';
import '../widgets/footer_bar.dart';

class UserProfilePage extends StatelessWidget {
  final String username;
  const UserProfilePage({super.key, required this.username});

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
                        child: Text('用户 $username 页面占位（开发中...）'),
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
