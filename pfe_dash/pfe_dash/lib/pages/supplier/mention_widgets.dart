import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pfe_dash/services/api_service.dart';

/// Renders [text] with @mentions highlighted as colored chips.
Widget buildHighlightedText(String text, {double fontSize = 13, Color? defaultColor}) {
  final regex = RegExp(r'@(\w+)');
  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(
        text: text.substring(lastEnd, match.start),
        style: TextStyle(fontSize: fontSize, color: defaultColor),
      ));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.green.shade700,
      ),
    ));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastEnd),
      style: TextStyle(fontSize: fontSize, color: defaultColor),
    ));
  }

  if (spans.isEmpty) {
    return Text(text, style: TextStyle(fontSize: fontSize, color: defaultColor));
  }

  return RichText(
    text: TextSpan(children: spans),
  );
}

/// A TextField with @mention autocomplete.
/// When the user types `@` followed by characters, a dropdown with matching
/// users appears below the text field. Selecting a user inserts `@username`.
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final Function(String)? onSubmitted;
  final InputDecoration? decoration;
  final FocusNode? focusNode;

  const MentionTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.maxLines = 1,
    this.onSubmitted,
    this.decoration,
    this.focusNode,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.baseOffset <= 0) {
      _hideSuggestions();
      return;
    }

    final cursorPos = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);

    // Find the last @ before the cursor
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex < 0) {
      _hideSuggestions();
      return;
    }

    // Check there's no space between @ and cursor (single-word query)
    final afterAt = textBeforeCursor.substring(atIndex + 1);
    if (afterAt.contains(' ') || afterAt.contains('\n')) {
      _hideSuggestions();
      return;
    }

    // Also check that @ is at start or preceded by a space/newline
    if (atIndex > 0 && text[atIndex - 1] != ' ' && text[atIndex - 1] != '\n') {
      _hideSuggestions();
      return;
    }

    final query = afterAt;
    _mentionStartIndex = atIndex;

    if (query.isEmpty) {
      _hideSuggestions();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    try {
      final results = await ApiService.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    } catch (_) {
      _hideSuggestions();
    }
  }

  void _hideSuggestions() {
    if (_showSuggestions || _suggestions.isNotEmpty) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  void _insertMention(String username) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Replace from @ to cursor with @username plus a space
    final before = text.substring(0, _mentionStartIndex);
    final after = text.substring(cursorPos);
    final newText = '$before@$username $after';

    widget.controller.text = newText;
    final newCursorPos = _mentionStartIndex + username.length + 2;
    widget.controller.selection = TextSelection.collapsed(offset: newCursorPos);

    _hideSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            hintText: widget.hintText,
          ),
          onSubmitted: (val) {
            _hideSuggestions();
            widget.onSubmitted?.call(val);
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (ctx, i) {
                final user = _suggestions[i];
                final username = user['username']?.toString() ?? '';
                final picture = user['picture']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.green.shade50,
                    child: picture.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              picture,
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                        : Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 11),
                          ),
                  ),
                  title: Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _insertMention(username),
                );
              },
            ),
          ),
      ],
    );
  }
}
