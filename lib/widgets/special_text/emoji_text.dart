import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

/// Emoji 文本解析器
///
/// 用于识别和渲染文本中的 Emoji 语法（如 `![emoji]`）。
/// 继承自 `SpecialText`，配合 `ExtendedTextField` 使用。
class EmojiText extends SpecialText {
  EmojiText(TextStyle? textStyle, {this.start})
    : super(EmojiText.flag, ')', textStyle);

  static const String flag = '![';
  final int? start;

  @override
  InlineSpan finishText() {
    final String text = toString();
    // Validate it's a markdown image: ![...](...)
    final RegExp pattern = RegExp(r'^!\[(.*?)\]\((.*?)\)$');
    final Match? match = pattern.firstMatch(text);

    if (match != null) {
      final String url = match.group(2)!;

      // Only render if it looks like a valid image URL
      if (!url.startsWith('http')) {
        return TextSpan(text: text, style: textStyle);
      }

      // Use ExtendedWidgetSpan to render the image with error handling
      // We pass the actualText so that copying/backspacing works correctly (it deletes the whole block)
      return ExtendedWidgetSpan(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Image.network(
            url,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(text),
          ),
        ),
        actualText: text,
        start: start!,
        alignment: PlaceholderAlignment.middle,
      );
    }

    return TextSpan(text: text, style: textStyle);
  }
}

class EmojiTextSpanBuilder extends SpecialTextSpanBuilder {
  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    int? index,
  }) {
    if (flag == '') {
      return null;
    }

    // Check for markdown image start
    if (isStart(flag, EmojiText.flag)) {
      return EmojiText(textStyle, start: index);
    }
    return null;
  }
}
