import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 完整版聊天室页面
///
/// 这是一个全屏的聊天室页面，提供更完整的聊天体验。
/// 功能包括：
/// - 实时消息展示与发送
/// - 图片/文件上传
/// - 粘贴板图片发送支持
/// - 拖拽文件发送支持（桌面端）
/// - 消息引用回复
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../providers/auth_provider.dart';
import '../api/fishpi_api.dart';
import '../models/chat_message.dart';
import '../models/breezemoon.dart';
import '../widgets/header_bar.dart';
import '../widgets/special_text/emoji_text.dart';
import '../widgets/hover_user_card.dart';
import '../widgets/red_packet_dialog.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final List<ChatMessage> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final ValueNotifier<int> _onlineCount = ValueNotifier(0);
  final ValueNotifier<List<BreezeMoon>> _breezeMoons = ValueNotifier([]);
  final TextEditingController _breezeMoonController = TextEditingController();

  bool _showEmojis = false;
  bool _isLoadingEmojis = false;
  List<String> _emojis = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connect();
    _loadBreezeMoons();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() {
        _showEmojis = false;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    _onlineCount.dispose();
    _breezeMoons.dispose();
    _breezeMoonController.dispose();
    super.dispose();
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

    try {
      final api = context.read<FishPiApi>();
      final nodeUrl = await api.getChatRoomNode();

      if (nodeUrl == null) {
        debugPrint('Failed to get chat room node');
        return;
      }

      _channel = WebSocketChannel.connect(Uri.parse(nodeUrl));
      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
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

          if (_messages.length > 200) {
            _messages.removeLast();
            _listKey.currentState?.removeItem(
              _messages.length,
              (context, animation) => const SizedBox.shrink(),
              duration: Duration.zero,
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final auth = context.read<AuthProvider>();
              final isSelf = chatMsg.userName == auth.user?.userName;
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

  Future<void> _loadBreezeMoons() async {
    try {
      final api = context.read<FishPiApi>();
      final list = await api.getBreezeMoons(page: 1, size: 20);
      if (mounted) {
        _breezeMoons.value = list;
      }
    } catch (e) {
      debugPrint('加载清风明月失败: $e');
    }
  }

  Future<void> _sendBreezeMoon() async {
    if (_breezeMoonController.text.trim().isEmpty) return;
    try {
      await context.read<FishPiApi>().sendBreezeMoon(
        _breezeMoonController.text,
      );
      _breezeMoonController.clear();
      _loadBreezeMoons();
    } catch (e) {
      debugPrint('发送失败: $e');
    }
  }

  Future<void> _loadEmojis() async {
    if (_emojis.isNotEmpty) return;

    setState(() {
      _isLoadingEmojis = true;
    });

    try {
      final api = context.read<FishPiApi>();
      final emojis = await api.getUserEmotions();
      if (mounted) {
        setState(() {
          _emojis = emojis;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEmojis = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      String? initialDirectory;
      if (Platform.isWindows) {
        // 使用环境变量快速获取路径，避免 path_provider 可能的延迟
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          initialDirectory = '$userProfile\\Downloads';
        }
      }

      // 如果上述方法失败或非 Windows 平台，尝试使用 path_provider (可选)
      // 但为了响应速度，如果已经有 initialDirectory 就不再 await path_provider

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        lockParentWindow: false, // 关闭锁定父窗口可能提高响应速度
        initialDirectory: initialDirectory,
      );

      if (result != null && result.files.single.path != null) {
        await _uploadFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
  }

  Future<void> _handlePaste() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await tempFile.writeAsBytes(imageBytes);
        await _uploadFile(tempFile.path);
        return;
      }

      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (var path in files) {
          await _uploadFile(path);
        }
        return;
      }

      // Fallback to text paste
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        _insertText(data!.text!);
      }
    } catch (e) {
      // Ignore paste errors
    }
  }

  Future<void> _uploadFile(String path) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final api = context.read<FishPiApi>();
      final url = await api.upload(path);
      if (mounted) {
        _onFileUploadComplete(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _onFileUploadComplete(String url) {
    final lowerUrl = url.toLowerCase();
    final isImage =
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp');

    if (isImage) {
      _insertText(' ![]($url) ');
    } else {
      String name = 'file';
      try {
        final uri = Uri.parse(url);
        if (uri.pathSegments.isNotEmpty) {
          name = uri.pathSegments.last;
        }
      } catch (_) {}
      _insertText(' [$name]($url) ');
    }
  }

  Widget _buildEmojiItem(String emoji) {
    if (emoji.startsWith('http')) {
      return Image.network(emoji, width: 32, height: 32, fit: BoxFit.contain);
    }
    return Center(child: Text(emoji, style: const TextStyle(fontSize: 20)));
  }

  void _onEmojiSelected(String emoji) {
    if (emoji.startsWith('http')) {
      _insertText(' ![]($emoji) ');
    } else {
      _insertText(' $emoji ');
    }
  }

  void _insertText(String text, {int cursorOffset = 0}) {
    final currentText = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? currentText.length : selection.start;
    final end = selection.end < 0 ? currentText.length : selection.end;

    final newText = currentText.replaceRange(start, end, text);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + cursorOffset + text.length,
      ),
    );
  }

  void _wrapSelection(String prefix, String suffix) {
    final currentText = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? currentText.length : selection.start;
    final end = selection.end < 0 ? currentText.length : selection.end;

    final selectedText = currentText.substring(start, end);
    final newText = currentText.replaceRange(
      start,
      end,
      '$prefix$selectedText$suffix',
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + prefix.length + selectedText.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const HeaderBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Chat Area
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Rich Text Editor Placeholder
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFEEEEEE)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Toolbar
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildToolIcon(
                                      Icons.emoji_emotions_outlined,
                                      onTap: () {
                                        setState(() {
                                          _showEmojis = !_showEmojis;
                                        });
                                        if (_showEmojis) {
                                          _focusNode.unfocus();
                                          _loadEmojis();
                                        }
                                      },
                                      tooltip: '表情',
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: PopupMenuButton<String>(
                                        tooltip: '标题',
                                        offset: const Offset(0, 30),
                                        icon: Text(
                                          'H',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        padding: EdgeInsets.zero,
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            height: 32,
                                            value: '# ',
                                            child: Text(
                                              '一级标题',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            height: 32,
                                            value: '## ',
                                            child: Text(
                                              '二级标题',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            height: 32,
                                            value: '### ',
                                            child: Text(
                                              '三级标题',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            height: 32,
                                            value: '#### ',
                                            child: Text(
                                              '四级标题',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            height: 32,
                                            value: '##### ',
                                            child: Text(
                                              '五级标题',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            height: 32,
                                            value: '###### ',
                                            child: Text(
                                              '六级标题',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                        onSelected: (value) =>
                                            _wrapSelection(value, ''),
                                      ),
                                    ),
                                    _buildToolIcon(
                                      Icons.format_bold,
                                      onTap: () => _wrapSelection('**', '**'),
                                      tooltip: '粗体',
                                    ),
                                    _buildToolIcon(
                                      Icons.format_italic,
                                      onTap: () => _wrapSelection('*', '*'),
                                      tooltip: '斜体',
                                    ),
                                    _buildToolIcon(
                                      Icons.link,
                                      onTap: () =>
                                          _wrapSelection('[', '](url)'),
                                      tooltip: '链接',
                                    ),
                                    _buildToolIcon(
                                      Icons.image_outlined,
                                      onTap: _isUploading
                                          ? null
                                          : _pickAndUploadImage,
                                      tooltip: '上传文件',
                                      isLoading: _isUploading,
                                    ),
                                    _buildToolIcon(
                                      Icons.code,
                                      onTap: () => _wrapSelection('`', '`'),
                                      tooltip: '代码',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Emoji Picker
                              if (_showEmojis)
                                Container(
                                  height: 200,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: Colors.grey[50],
                                  child: _isLoadingEmojis
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : _emojis.isEmpty
                                      ? const Center(child: Text('暂无常用表情'))
                                      : GridView.builder(
                                          padding: const EdgeInsets.all(8),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 50,
                                                mainAxisSpacing: 8,
                                                crossAxisSpacing: 8,
                                              ),
                                          itemCount: _emojis.length,
                                          itemBuilder: (context, index) {
                                            final emoji = _emojis[index];
                                            return InkWell(
                                              onTap: () =>
                                                  _onEmojiSelected(emoji),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: _buildEmojiItem(emoji),
                                            );
                                          },
                                        ),
                                ),
                              CallbackShortcuts(
                                bindings: {
                                  const SingleActivator(
                                    LogicalKeyboardKey.keyV,
                                    control: true,
                                  ): _handlePaste,
                                  const SingleActivator(
                                    LogicalKeyboardKey.keyV,
                                    meta: true,
                                  ): _handlePaste,
                                },
                                child: ExtendedTextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  maxLines: 4,
                                  minLines: 2,
                                  specialTextSpanBuilder:
                                      EmojiTextSpanBuilder(),
                                  decoration: const InputDecoration(
                                    hintText: '说点什么...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Bottom Actions
                              Row(
                                children: [
                                  _buildActionButton(
                                    Icons.redeem,
                                    '红包',
                                    Colors.red,
                                    onTap: _showRedPacketDialog,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    Icons.topic,
                                    '话题',
                                    Colors.green,
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('清屏'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _sendMessage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('发送'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Online Count
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ValueListenableBuilder<int>(
                            valueListenable: _onlineCount,
                            builder: (context, value, _) {
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.people,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '当前在线 $value',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        // Chat List
                        Expanded(
                          child: AnimatedList(
                            key: _listKey,
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            initialItemCount: _messages.length,
                            itemBuilder: (context, index, animation) {
                              if (index >= _messages.length) {
                                return const SizedBox.shrink();
                              }
                              final msg = _messages[index];
                              return SizeTransition(
                                sizeFactor: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: _buildMessageItem(msg),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Sidebar
                SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      top: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Column(
                      children: [
                        // User Stats Card
                        _buildUserStatsCard(),
                        const SizedBox(height: 16),
                        // BreezeMoon Panel
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _breezeMoonController,
                                        decoration: const InputDecoration(
                                          hintText: '清风明月',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onSubmitted: (_) => _sendBreezeMoon(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: _sendBreezeMoon,
                                      child: const Text('发布'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ValueListenableBuilder<List<BreezeMoon>>(
                                valueListenable: _breezeMoons,
                                builder: (context, list, _) {
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(12),
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: list.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = list[index];
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              item.content.replaceAll(
                                                RegExp(r'<[^>]*>'),
                                                '',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRedPacketDialog() {
    showDialog(
      context: context,
      builder: (context) => const _RedPacketDialog(),
    );
  }

  Widget _buildToolIcon(
    IconData icon, {
    VoidCallback? onTap,
    String? tooltip,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Icon(icon, color: Colors.grey[600], size: 20),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsCard() {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('关注标签', '0'), // API Missing
          _buildStatItem('关注用户', '${user.followingUserCount ?? 0}'),
          _buildStatItem('积分', '${user.userPoint ?? 0}'),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: 0.7, // Mock value
                  backgroundColor: Colors.grey[200],
                  color: Colors.blue,
                ),
              ),
              const Text('7%', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    String linkifyMentions(String content) {
      if (content.contains('<a')) return content;
      return content.replaceAllMapped(
        RegExp(r'@([a-zA-Z0-9_\-]+)'),
        (m) => '@<a href="https://fishpi.cn/member/${m[1]}">${m[1]}</a>',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HoverUserCard(
            userName: msg.userName,
            avatarUrl: msg.userAvatarURL,
            child: ClipOval(
              child: Image.network(
                msg.userAvatarURL,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      msg.userNickname.isNotEmpty
                          ? msg.userNickname
                          : msg.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      msg.time,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (msg.type == 'redPacket' && msg.redPacket != null)
                  Builder(
                    builder: (context) {
                      final auth = context.read<AuthProvider>();
                      final isCollected = msg.redPacket!.who.any(
                        (e) => e['userName'] == auth.user?.userName,
                      );
                      return InkWell(
                        onTap: () async {
                          try {
                            final api = context.read<FishPiApi>();
                            final result = await api.openRedPacket(msg.oId);
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => RedPacketDetailDialog(
                                  data: result,
                                  senderUserName: msg.userName,
                                  senderNickname: msg.userNickname,
                                  senderAvatar: msg.userAvatarURL,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('打开红包失败: $e')),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: 260,
                          decoration: BoxDecoration(
                            color: isCollected
                                ? const Color(0xFFF8F8F8)
                                : const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(8),
                            border: isCollected
                                ? Border.all(color: const Color(0xFFEEEEEE))
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.redPacket!.msg.isNotEmpty
                                          ? msg.redPacket!.msg
                                          : '恭喜发财，大吉大利',
                                      style: TextStyle(
                                        color: isCollected
                                            ? Colors.grey[400]
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                              : const Color(0xFFFFD700),
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
                    textStyle: const TextStyle(fontSize: 15, height: 1.5),
                    customStylesBuilder: (element) {
                      if (element.localName == 'img') {
                        return {'max-width': '100%', 'border-radius': '4px'};
                      }
                      if (element.localName == 'blockquote') {
                        return {
                          'color': 'grey',
                          'margin': '0',
                          'padding-left': '10px',
                          'border-left': '3px solid #e0e0e0',
                        };
                      }
                      return null;
                    },
                    onTapUrl: (url) async {
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        final isMemberLink =
                            (uri.host == 'fishpi.cn' || uri.host.isEmpty) &&
                            uri.path.startsWith('/member/');
                        if (isMemberLink) {
                          final username = uri.pathSegments.isNotEmpty
                              ? uri.pathSegments.last
                              : '';
                          if (username.isNotEmpty) {
                            context.push('/member/$username');
                            return true;
                          }
                        }
                      }
                      return false;
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RedPacketDialog extends StatefulWidget {
  const _RedPacketDialog();

  @override
  State<_RedPacketDialog> createState() => _RedPacketDialogState();
}

class _RedPacketDialogState extends State<_RedPacketDialog> {
  String _type = 'random';
  int _gesture = 0;
  String? _selectedReceiverAvatar;
  String _receiverName = '';
  final _moneyController = TextEditingController(text: '32');
  final _countController = TextEditingController(text: '1');
  final _msgController = TextEditingController(text: '恭喜发财，大吉大利！');
  bool _isSending = false;

  final Map<String, String> _types = {
    'random': '拼手气红包',
    'average': '普通红包',
    'specify': '专属红包',
    'rockPaperScissors': '猜拳红包',
    'heartbeat': '心跳红包',
  };

  final Map<int, String> _gestures = {0: '石头', 1: '剪刀', 2: '布'};

  @override
  void dispose() {
    _moneyController.dispose();
    _countController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final money = int.tryParse(_moneyController.text);
    final count = int.tryParse(_countController.text);
    final msg = _msgController.text;

    if (money == null || money <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的积分')));
      return;
    }
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的个数')));
      return;
    }

    if (_type == 'heartbeat' && count < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('心跳红包数量不能少于5个')));
      return;
    }

    if (_type == 'specify' && _receiverName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入接收者用户名')));
      return;
    }

    setState(() => _isSending = true);
    try {
      await context.read<FishPiApi>().sendRedPacket(
        type: _type,
        money: money,
        count: count,
        msg: msg,
        gesture: _type == 'rockPaperScissors' ? _gesture : null,
        receivers: _type == 'specify' ? [_receiverName] : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('红包发送成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '发红包',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '红包类型',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: _types.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _type = v);
                  if (v == 'heartbeat') {
                    _countController.text = '5';
                  } else {
                    _countController.text = '1';
                  }
                }
              },
            ),
            if (_type == 'rockPaperScissors') ...[
              const SizedBox(height: 16),
              const Text(
                '出拳',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _gesture,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _gestures.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _gesture = v);
                },
              ),
            ],
            if (_type == 'specify') ...[
              const SizedBox(height: 8),
              if (_selectedReceiverAvatar != null) ...[
                Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(_selectedReceiverAvatar!),
                  ),
                ),
              ],
              const Text(
                '给谁',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) =>
                    option['userName'] as String? ?? '',
                optionsBuilder: (textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  return await context.read<FishPiApi>().suggestUsers(
                    textEditingValue.text,
                  );
                },
                onSelected: (option) {
                  setState(() {
                    _receiverName = option['userName'] as String? ?? '';
                    _selectedReceiverAvatar =
                        option['userAvatarURL'] as String?;
                  });
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          hintText: '输入用户名',
                        ),
                        onChanged: (v) {
                          _receiverName = v;
                          if (_selectedReceiverAvatar != null) {
                            setState(() {
                              _selectedReceiverAvatar = null;
                            });
                          }
                        },
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        width: 272, // Container width (320) - padding (24*2)
                        height: 200,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  option['userAvatarURL'] as String? ?? '',
                                ),
                              ),
                              title: Text(option['userName'] as String? ?? ''),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '积分',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _moneyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _type == 'heartbeat' ? '个数（最少5个）' : '个数',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '留言',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _msgController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('发送'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
