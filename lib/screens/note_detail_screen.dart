import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/export_service.dart';
import '../services/note_sync_service.dart';
import '../utils/constants.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note;

  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  Color _selectedColor = AppConstants.noteColors.first;
  bool _isPinned = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _contentController.addListener(_onContentChanged);
    _selectedColor = widget.note?.noteColor ?? AppConstants.noteColors.first;
    _isPinned = widget.note?.isPinned ?? false;
    _selectedCategory = (widget.note?.category ?? '').trim().isEmpty
        ? null
        : widget.note?.category?.trim();
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int get _wordCount {
    final trimmed = _contentController.text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int get _characterCount => _contentController.text.length;

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    final previousFileName = widget.note?.safeFileName;

    final note = Note(
      id: widget.note?.id,
      cloudId: widget.note?.cloudId,
      title: _titleController.text.trim().isEmpty
          ? 'Untitled'
          : _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      color: _selectedColor.toARGB32().toString(),
      isPinned: _isPinned,
      category: _selectedCategory,
    );

    if (widget.note == null) {
      final newId = await DatabaseHelper.instance.insertNote(note);
      note.id = newId;
    } else {
      await DatabaseHelper.instance.updateNote(note);
    }

    unawaited(_syncNoteToCloud(note, showFailureSnackBar: false));
    unawaited(
      _syncNoteFile(
        note,
        previousFileName: previousFileName,
        showFailureSnackBar: false,
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _syncNoteToCloud(
    Note note, {
    bool showFailureSnackBar = true,
  }) async {
    try {
      await NoteSyncService.instance.upsertNote(note);
    } on NoteSyncException catch (e) {
      if (!mounted || !showFailureSnackBar) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // Keep local save successful even when cloud sync fails.
    }
  }

  Future<void> _syncNoteFile(
    Note note, {
    String? previousFileName,
    bool showFailureSnackBar = true,
  }) async {
    try {
      final exportService = ExportService.instance;
      final granted = await exportService.ensureExportPermission(
        openSettingsIfDenied: showFailureSnackBar,
      );

      if (!granted) {
        if (!mounted || !showFailureSnackBar) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Note saved, but storage access is needed to write .md files to MyDiary folder.',
            ),
          ),
        );
        return;
      }

      await exportService.syncNoteFile(
        note,
        previousFileName: previousFileName,
      );
    } catch (e) {
      if (!mounted || !showFailureSnackBar) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to write file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose note color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _insertChecklistItem() {
    final currentText = _contentController.text;
    final selection = _contentController.selection;
    final cursor = selection.isValid ? selection.start : currentText.length;

    final safeCursor = cursor.clamp(0, currentText.length);
    final prefix = currentText.substring(0, safeCursor);
    final suffix = currentText.substring(safeCursor);
    final insertion =
        '${prefix.isEmpty || prefix.endsWith('\n') ? '' : '\n'}- [ ] ';
    final newText = '$prefix$insertion$suffix';

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: prefix.length + insertion.length,
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: _selectedCategory == null,
              label: const Text('None'),
              onSelected: (_) => setState(() => _selectedCategory = null),
            ),
            ...AppConstants.categories.map((category) {
              return ChoiceChip(
                selected: _selectedCategory == category,
                label: Text(category),
                onSelected: (_) => setState(() => _selectedCategory = category),
              );
            }),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveNote();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'Create Note' : 'Edit Note'),
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Unpin note' : 'Pin note',
              icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
              },
            ),
            IconButton(
              tooltip: 'Checklist item',
              icon: const Icon(Icons.checklist_rtl_rounded),
              onPressed: _insertChecklistItem,
            ),
            IconButton(
              tooltip: 'Color',
              icon: const Icon(Icons.palette_outlined),
              onPressed: _showColorPicker,
            ),
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveNote,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        _selectedColor.withValues(alpha: 0.18),
                        theme.colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _selectedColor.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricChip(label: 'Words', value: _wordCount.toString()),
                      _MetricChip(
                        label: 'Characters',
                        value: _characterCount.toString(),
                      ),
                      _MetricChip(
                        label: 'Pinned',
                        value: _isPinned ? 'Yes' : 'No',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _buildCategorySection(context),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  decoration: const InputDecoration(
                    hintText: 'Start writing, or insert checklist items...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  minLines: 12,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showColorPicker,
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('Color'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _insertChecklistItem,
                        icon: const Icon(Icons.checklist_rtl_rounded),
                        label: const Text('Checklist'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveNote,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
