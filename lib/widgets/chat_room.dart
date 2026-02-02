import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/auth_provider.dart';
import '../api/fishpi_api.dart';
import '../models/chat_message.dart';

class ChatRoomWidget extends StatefulWidget {
  const ChatRoomWidget({super.key});

  @override
  State<ChatRoomWidget> createState() => _ChatRoomWidgetState();
}

class _ChatRoomWidgetState extends State<ChatRoomWidget> {
  final List<ChatMessage> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _onlineCount = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() async {
    final auth = context.read<AuthProvider>();
    if (auth.apiKey == null) return;

    // First get the dynamic node address
    try {
      final api = context.read<FishPiApi>();
      final nodeUrl = await api.getChatRoomNode();

      if (nodeUrl == null) {
        print('Failed to get chat room node');
        return;
      }

      // nodeUrl already contains apiKey from the server, but let's double check or use it directly
      // Documentation says: "wss://x.x.x.x:10832?apiKey=xxx"
      // So we can use it directly.

      _channel = WebSocketChannel.connect(Uri.parse(nodeUrl));
      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          // Reconnect logic could go here
        },
        onDone: () {
          print('WebSocket closed');
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'online') {
        if (mounted) {
          _onlineCount.value = data['onlineChatCnt'] ?? 0;
        }
      } else if (data['type'] == 'msg') {
        final chatMsg = ChatMessage.fromJson(data);
        if (mounted) {
          _messages.insert(0, chatMsg);
          _listKey.currentState?.insertItem(
            0,
            duration: const Duration(milliseconds: 500),
          );

          // Limit message count
          if (_messages.length > 100) {
            final removedItem = _messages.removeLast();
            // Optional: remove animation for off-screen item
            // Using a dummy builder since it's likely not visible
            _listKey.currentState?.removeItem(
              _messages.length, // index 100
              (context, animation) => const SizedBox.shrink(),
              duration: Duration.zero,
            );
          }

          // Scroll to top
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final content = _controller.text;
    _controller.clear();

    try {
      await context.read<FishPiApi>().sendChatMessage(content);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    _onlineCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('聊天室', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: _onlineCount,
                builder: (context, value, child) {
                  return Text(
                    '($value人在线)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  );
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('进入完整版', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
                      hintText: '说点什么...',
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE0E0E0)),
                InkWell(
                  onTap: _sendMessage,
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
                      '发送',
                      style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedList(
            key: _listKey,
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            initialItemCount: _messages.length,
            itemBuilder: (context, index, animation) {
              if (index >= _messages.length) return const SizedBox.shrink();
              final msg = _messages[index];
              return SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: msg.userAvatarURL.isNotEmpty
                              ? NetworkImage(msg.userAvatarURL)
                              : null,
                          onBackgroundImageError: (exception, stackTrace) {
                            print('Avatar load failed: $exception');
                          },
                          child: msg.userAvatarURL.isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    msg.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.time.length >= 16
                                        ? msg.time.substring(11, 16)
                                        : msg.time, // Safe substring
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.content.replaceAll(
                                  RegExp(r'<[^>]*>'),
                                  '',
                                ), // Simple HTML strip
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
