import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'special_text/emoji_text.dart';
import '../api/fishpi_api.dart';

/// 评论/回复输入框底部弹窗组件
///
/// 提供一个从底部弹出的文本输入区域，用于：
/// - 发布文章评论
/// - 回复他人的评论
/// - 支持输入内容验证与发送状态反馈
class ReplyBottomSheet extends StatefulWidget {
  final String articleId;
  final String? articleTitle;
  final FishPiApi api;
  final String? replyToId;
  final String? replyToName;
  final String? replyToUserAvatar;
  final VoidCallback? onSuccess;

  const ReplyBottomSheet({
    super.key,
    required this.articleId,
    this.articleTitle,
    required this.api,
    this.replyToId,
    this.replyToName,
    this.replyToUserAvatar,
    this.onSuccess,
  });

  @override
  State<ReplyBottomSheet> createState() => _ReplyBottomSheetState();
}

class _ReplyBottomSheetState extends State<ReplyBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isUploading = false;
  bool _visibleToUser = false; // 仅楼主可见
  String? _errorMessage;
  bool _showEmojis = false;
  bool _isLoadingEmojis = false;
  List<String> _emojis = [];

  @override
  void initState() {
    super.initState();
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEmojis() async {
    if (_emojis.isNotEmpty) return;

    setState(() {
      _isLoadingEmojis = true;
    });

    try {
      final emojis = await widget.api.getUserEmotions();
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
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        await _uploadFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '选择文件失败: $e';
        });
      }
    }
  }

  Future<void> _uploadFile(String path) async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.api.upload(path);
      if (mounted) {
        _onEmojiSelected(url);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
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

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.api.postComment(
        articleId: widget.articleId,
        content: content,
        originalCommentId: widget.replyToId,
        visibleToUser: _visibleToUser,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('回复成功')));
      }
    } on FishPiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildToolbarButton(
    IconData icon,
    VoidCallback? onPressed, {
    String? tooltip,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(8),
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.grey[700]),
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReplyToComment = widget.replyToId != null;
    final title = isReplyToComment
        ? '回复 ${widget.replyToName}'
        : (widget.articleTitle != null ? '回复 ${widget.articleTitle}' : '回复帖子');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                if (isReplyToComment && widget.replyToUserAvatar != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundImage: NetworkImage(widget.replyToUserAvatar!),
                    ),
                  )
                else
                  const Icon(Icons.reply, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildToolbarButton(Icons.mood, () {
                  setState(() {
                    _showEmojis = !_showEmojis;
                  });
                  if (_showEmojis) {
                    FocusScope.of(context).unfocus();
                    _loadEmojis();
                  }
                }, tooltip: '表情'),
                _buildToolbarButton(
                  Icons.format_size,
                  () => _wrapSelection('## ', ''),
                  tooltip: '标题',
                ),
                _buildToolbarButton(
                  Icons.format_bold,
                  () => _wrapSelection('**', '**'),
                  tooltip: '粗体',
                ),
                _buildToolbarButton(
                  Icons.format_italic,
                  () => _wrapSelection('*', '*'),
                  tooltip: '斜体',
                ),
                _buildToolbarButton(
                  Icons.strikethrough_s,
                  () => _wrapSelection('~~', '~~'),
                  tooltip: '删除线',
                ),
                _buildToolbarButton(
                  Icons.link,
                  () => _wrapSelection('[', '](url)'),
                  tooltip: '链接',
                ),
                _buildToolbarButton(
                  Icons.format_list_bulleted,
                  () => _insertText('\n- '),
                  tooltip: '列表',
                ),
                _buildToolbarButton(
                  Icons.check_box_outlined,
                  () => _insertText('\n- [ ] '),
                  tooltip: '任务列表',
                ),
                _buildToolbarButton(
                  Icons.code,
                  () => _wrapSelection('`', '`'),
                  tooltip: '代码',
                ),
                _buildToolbarButton(
                  Icons.format_quote,
                  () => _insertText('\n> '),
                  tooltip: '引用',
                ),
                _buildToolbarButton(
                  Icons.image,
                  _isUploading ? null : _pickAndUploadImage,
                  tooltip: '上传图片',
                  isLoading: _isUploading,
                ),
                _buildToolbarButton(
                  Icons.table_chart,
                  () => _insertText(
                    '\n| Header | Header |\n| --- | --- |\n| Cell | Cell |',
                  ),
                  tooltip: '表格',
                ),
              ],
            ),
          ),

          // Emoji Picker
          if (_showEmojis)
            Container(
              height: 200,
              color: Colors.grey[50],
              child: _isLoadingEmojis
                  ? const Center(child: CircularProgressIndicator())
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
                          onTap: () => _onEmojiSelected(emoji),
                          borderRadius: BorderRadius.circular(4),
                          child: _buildEmojiItem(emoji),
                        );
                      },
                    ),
            ),

          // Text Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                    _handlePaste,
                const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                    _handlePaste,
              },
              child: ExtendedTextField(
                specialTextSpanBuilder: EmojiTextSpanBuilder(),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                maxLines: 6,
                minLines: 3,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                decoration: const InputDecoration(
                  hintText: '友善地留下一条评论吧 :)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (!isReplyToComment) // Only show "Visible to OP" for top-level comments (or maybe replies too? FishPi usually allows it for replies too)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _visibleToUser = !_visibleToUser;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _visibleToUser
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: _visibleToUser ? Colors.amber : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        const Text('仅楼主可见', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (isReplyToComment)
                  // When replying to a comment, we usually don't have "Only visible to OP" option as strictly, but maybe "Only visible to comment author"?
                  // FishPi API 'commentVisibleToUser' means visible to the article author (OP) only.
                  // So it still makes sense if the user wants to say something private to the OP in a thread.
                  // But typically this is used for root comments. I'll keep it available but maybe less emphasized or just available.
                  // The user request screenshot showed it available.
                  InkWell(
                    onTap: () {
                      setState(() {
                        _visibleToUser = !_visibleToUser;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _visibleToUser
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: _visibleToUser ? Colors.amber : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        const Text('仅楼主可见', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                const Spacer(),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('提交'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
