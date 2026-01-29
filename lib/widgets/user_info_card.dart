import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user.dart';

class UserInfoCard extends StatelessWidget {
  final String userName;
  final String avatarUrl;
  final User? userDetails;
  final bool isLoading;

  const UserInfoCard({
    super.key,
    required this.userName,
    required this.avatarUrl,
    this.userDetails,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg =
        userDetails?.cardBg != null && userDetails!.cardBg!.isNotEmpty;

    return Container(
      width: 320,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 1. Full Background Image
            Positioned.fill(
              child: hasBg
                  ? Image.network(
                      userDetails!.cardBg!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.white),
                    )
                  : Container(color: Colors.white),
            ),

            // 2. Bottom Blur/Frosted Glass Area
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.02),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Tags (Indented to avoid avatar)
                        Padding(
                          padding: const EdgeInsets.only(left: 108),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    flex: 3,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.bottomLeft,
                                      child: Text(
                                        userDetails?.userNickname ?? userName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (userDetails?.userName != null &&
                                      userDetails?.userName !=
                                          userDetails?.userNickname)
                                    Flexible(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.bottomLeft,
                                          child: Text(
                                            userDetails!.userName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                              height: 1.1,
                                            ),
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Intro
                              Text(
                                userDetails?.userIntro ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[900],
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Stats/Badges
                        Padding(
                          padding: const EdgeInsets.only(left: 108),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (userDetails?.userAppRole == 0)
                                _buildBadge(Icons.security, '黑客', Colors.black),
                              if (userDetails?.userAppRole == 1)
                                _buildBadge(Icons.brush, '画家', Colors.blue),
                              if (userDetails?.userCity != null &&
                                  userDetails!.userCity!.isNotEmpty)
                                _buildBadge(
                                  Icons.location_on,
                                  userDetails!.userCity!,
                                  Colors.green,
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Bottom Row: Stats Left, Buttons Right
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (userDetails?.userRole != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          userDetails?.userRole ?? 'User',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.purple,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (userDetails?.userNo != null)
                                      Text(
                                        '# ${userDetails!.userNo}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Stats (Online/ID)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: userDetails?.userOnlineFlag == true
                                        ? Colors.red
                                        : Colors.grey,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    userDetails?.userOnlineFlag == true
                                        ? '在线'
                                        : '离线',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Buttons
                            FilledButton(
                              onPressed: () {},
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                minimumSize: const Size(60, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('私信'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                minimumSize: const Size(80, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('取消关注'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Avatar (Overlapping)
            Positioned(
              left: 16,
              top: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    avatarUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
