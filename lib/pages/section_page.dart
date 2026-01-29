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
        child: SingleChildScrollView(
          child: Column(
            children: [
              const HeaderBar(),
              const SizedBox(height: 12),
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
      ),
    );
  }
}
