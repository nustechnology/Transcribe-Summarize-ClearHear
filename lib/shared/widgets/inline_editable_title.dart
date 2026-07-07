import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/highlighted_text.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';

class InlineEditableTitle extends StatefulWidget {
  const InlineEditableTitle({
    super.key,
    required this.initialTitle,
    required this.onSave,
    this.isSelectionMode = false,
    this.searchKeyword = '',
    this.onTapSelectionMode,
    this.onEditingChanged,
    this.textStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.title,
    ),
    this.inputStyle,
    this.showTrailingIcon = true,
    this.maxLines = 1,
  });

  final String initialTitle;
  final bool isSelectionMode;
  final String searchKeyword;
  final Future<void> Function(String title) onSave;
  final VoidCallback? onTapSelectionMode;
  final ValueChanged<bool>? onEditingChanged;
  final TextStyle textStyle;
  final TextStyle? inputStyle;
  final bool showTrailingIcon;
  final int maxLines;

  @override
  State<InlineEditableTitle> createState() => _InlineEditableTitleState();
}

class _InlineEditableTitleState extends State<InlineEditableTitle> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialTitle);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant InlineEditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTitle != widget.initialTitle && !_isEditing) {
      _textController.text = widget.initialTitle;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _saveAndExit();
    }
  }

  void _startEditing() {
    if (widget.isSelectionMode) {
      widget.onTapSelectionMode?.call();
      return;
    }

    setState(() {
      _isEditing = true;
      _textController.text = widget.initialTitle;
    });
    widget.onEditingChanged?.call(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isEditing) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _saveAndExit() async {
    if (!_isEditing || _isSaving) return;

    _isSaving = true;
    final newTitle = _textController.text.trim();
    try {
      if (newTitle.isNotEmpty && newTitle != widget.initialTitle) {
        await widget.onSave(newTitle);
      }
    } catch (e) {
      AppLogger.error(error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _textController.text =
              newTitle.isEmpty ? widget.initialTitle : newTitle;
        });
        widget.onEditingChanged?.call(false);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _textController,
        focusNode: _focusNode,
        style: widget.inputStyle ?? widget.textStyle,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        maxLines: widget.maxLines,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focusNode.unfocus(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _startEditing,
            child: HighlightedText(
              text: widget.initialTitle,
              keyword: widget.searchKeyword,
              enabled: widget.searchKeyword.isNotEmpty,
              maxLines: widget.maxLines,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: widget.textStyle,
            ),
          ),
        ),
        if (widget.showTrailingIcon) ...[
          const SizedBox(width: 2.0),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16.0,
          ),
        ],
      ],
    );
  }
}
