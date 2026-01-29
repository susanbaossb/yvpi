import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/fishpi_api.dart';
import '../models/breezemoon.dart';

class BreezeMoonWidget extends StatelessWidget {
  const BreezeMoonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  '清风明月',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () {}, // TODO: Implement refresh
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<BreezeMoon>>(
              future: context.read<FishPiApi>().getBreezeMoons(size: 10),
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
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(
                                item.authorAvatarURL,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              item.timeAgo,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.content.replaceAll(RegExp(r'<[^>]*>'), ''),
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (item.city != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.city!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
