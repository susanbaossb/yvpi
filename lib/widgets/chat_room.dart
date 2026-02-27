/// 聊天室组件
///
/// 实现实时聊天功能，包含：
/// - WebSocket 消息接收与展示
/// - 消息列表自动滚动与分页加载
/// - 消息输入框与发送逻辑
/// - 红包消息类型的特殊渲染支持
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../providers/auth_provider.dart';
import '../api/fishpi_api.dart';
import '../models/chat_message.dart';
import 'hover_user_card.dart';
import 'red_packet_dialog.dart';

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
    _loadHistory();
    _connect();
  }

  Future<void> _loadHistory() async {
    final auth = context.read<AuthProvider>();
    if (auth.apiKey == null) return;
    try {
      final api = context.read<FishPiApi>();
      final history = await api.getChatRoomHistory(page: 1);
      if (!mounted) return;
      for (final msg in history) {
        _messages.insert(0, msg);
        _listKey.currentState?.insertItem(
          0,
          duration: const Duration(milliseconds: 200),
        );
      }
    } catch (e) {
      debugPrint('加载聊天室历史失败: $e');
    }
  }

  void _connect() async {
    final auth = context.read<AuthProvider>();
    if (auth.apiKey == null) return;

    // First get the dynamic node address
    try {
      final api = context.read<FishPiApi>();
      final nodeUrl = await api.getChatRoomNode();

      if (nodeUrl == null) {
        debugPrint('Failed to get chat room node');
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
          debugPrint('WebSocket error: $error');
          // Reconnect logic could go here
        },
        onDone: () {
          debugPrint('WebSocket closed');
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'online') {
        if (mounted) {
          _onlineCount.value = data['onlineChatCnt'] ?? 0;
        }
      } else if (data['type'] == 'msg' || data['type'] == 'redPacket') {
        final chatMsg = ChatMessage.fromJson(data);
        if (mounted) {
          _messages.insert(0, chatMsg);
          _listKey.currentState?.insertItem(
            0,
            duration: const Duration(milliseconds: 500),
          );

          // Limit message count
          if (_messages.length > 100) {
            _messages.removeLast();
            _listKey.currentState?.removeItem(
              _messages.length, // index 100
              (context, animation) => const SizedBox.shrink(),
              duration: Duration.zero,
            );
          }

          // Scroll to top
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final auth = context.read<AuthProvider>();
              final isSelf = chatMsg.userName == auth.user?.userName;
              // 只有当用户在顶部附近，或者是自己发送的消息时，才自动滚动
              if (isSelf || _scrollController.offset < 100) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final content = _controller.text;
    _controller.clear();

    try {
      await context.read<FishPiApi>().sendChatMessage(content);
    } catch (e) {
      if (!mounted) return;
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
    String linkifyMentions(String content) {
      if (content.contains('<a')) return content;
      return content.replaceAllMapped(
        RegExp(r'@([a-zA-Z0-9_\-]+)'),
        (m) => '@<a href="https://fishpi.cn/member/${m[1]}">${m[1]}</a>',
      );
    }

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
                onPressed: () => context.go('/chat'),
                child: const Text('进入完整版聊天室'),
              ),
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
        // Chat List
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
                        HoverUserCard(
                          userName: msg.userName,
                          avatarUrl: msg.userAvatarURL,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: ClipOval(
                              child: msg.userAvatarURL.isNotEmpty
                                  ? Image.network(
                                      msg.userAvatarURL,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const ColoredBox(
                                              color: Color(0xFFE0E0E0),
                                              child: Center(
                                                child: Icon(
                                                  Icons.person,
                                                  size: 20,
                                                ),
                                              ),
                                            );
                                          },
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFFE0E0E0),
                                      child: Center(
                                        child: Icon(Icons.person, size: 20),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    msg.userNickname.isNotEmpty
                                        ? '${msg.userNickname}（${msg.userName}）'
                                        : msg.userName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.time.length >= 16
                                        ? msg.time.substring(11, 16)
                                        : msg.time, // Safe substring
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (msg.type == 'redPacket' &&
                                  msg.redPacket != null)
                                Builder(
                                  builder: (context) {
                                    final auth = context.read<AuthProvider>();
                                    final isCollected = msg.redPacket!.who.any(
                                      (e) =>
                                          e['userName'] == auth.user?.userName,
                                    );
                                    return InkWell(
                                      onTap: () async {
                                        try {
                                          final api = context.read<FishPiApi>();
                                          final result = await api
                                              .openRedPacket(msg.oId);
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  RedPacketDetailDialog(
                                                    data: result,
                                                    senderUserName:
                                                        msg.userName,
                                                    senderNickname:
                                                        msg.userNickname,
                                                    senderAvatar:
                                                        msg.userAvatarURL,
                                                  ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('打开红包失败: $e'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        width: 240,
                                        decoration: BoxDecoration(
                                          color: isCollected
                                              ? const Color(0xFFF8F8F8)
                                              : const Color(0xFFD32F2F),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: isCollected
                                              ? Border.all(
                                                  color: const Color(
                                                    0xFFEEEEEE,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.redeem,
                                              color: isCollected
                                                  ? const Color(0xFFEF9A9A)
                                                  : const Color(0xFFFFD700),
                                              size: 40,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    msg
                                                            .redPacket!
                                                            .msg
                                                            .isNotEmpty
                                                        ? msg.redPacket!.msg
                                                        : '恭喜发财，大吉大利',
                                                    style: TextStyle(
                                                      color: isCollected
                                                          ? Colors.grey[400]
                                                          : Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    msg.redPacket!.typeName,
                                                    style: TextStyle(
                                                      color: isCollected
                                                          ? Colors.grey[400]
                                                          : Colors.white70,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.toll,
                                                        size: 14,
                                                        color: isCollected
                                                            ? Colors.grey[300]
                                                            : const Color(
                                                                0xFFFFD700,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${msg.redPacket!.money}',
                                                        style: TextStyle(
                                                          color: isCollected
                                                              ? Colors.grey[400]
                                                              : Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (isCollected) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '已经被抢光啦',
                                                      style: TextStyle(
                                                        color: Colors.grey[300],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else
                                HtmlWidget(
                                  linkifyMentions(msg.content),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
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
