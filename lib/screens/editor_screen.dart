import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../main.dart';
import 'home_screen.dart' show kNoteColors, kNoteColorsDark;

// Lightweight snapshot: text + cursor position
// Defined at top level so it is always resolved before use.
class EditorSnapshot {
  final String text;
  final int cursor;
  const EditorSnapshot(this.text, this.cursor);
}

class EditorScreen extends StatefulWidget {
  final Note? note;
  final String defaultFolder;

  const EditorScreen({super.key, this.note, this.defaultFolder = ''});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // Undo / Redo
  // Each entry stores the full text + cursor offset so we can restore both.
  final List<EditorSnapshot> _undoStack = [];
  final List<EditorSnapshot> _redoStack = [];

  bool _suppressListener = false; // true while we are restoring a snapshot
  Timer? _debounce;              // batches rapid keystrokes into one undo step

  String _folder = '';
  int _colorIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _folder = widget.note?.folder ?? widget.defaultFolder;
    _colorIndex = widget.note?.colorIndex ?? 0;

    // Seed the undo stack with the initial state.
    _pushSnapshot(clearRedo: false);

    _contentController.addListener(_onContentChanged);
  }

  // Called on every keystroke.  We debounce so that a burst of typing
  // produces one undo step, not one per character.
  void _onContentChanged() {
    if (_suppressListener) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Only push if content actually changed since the last snapshot.
      final text = _contentController.text;
      if (_undoStack.isEmpty || text != _undoStack.last.text) {
        _pushSnapshot(clearRedo: true);
      }
    });
  }

  void _pushSnapshot({required bool clearRedo}) {
    final offset = _contentController.selection.isValid
        ? _contentController.selection.baseOffset
        : _contentController.text.length;
    _undoStack.add(EditorSnapshot(_contentController.text, offset));
    if (clearRedo) _redoStack.clear();
    if (mounted) setState(() {});
  }

  void _restoreSnapshot(EditorSnapshot snap) {
    _suppressListener = true;
    _contentController.value = TextEditingValue(
      text: snap.text,
      selection: TextSelection.collapsed(
        offset: snap.cursor.clamp(0, snap.text.length),
      ),
    );
    // Reset the flag after the current event loop tick so that the listener
    // (which runs synchronously with the value setter above) has already fired
    // and been ignored before we re-enable it.
    Future.microtask(() {
      _suppressListener = false;
    });
    setState(() {});
  }

  void _undo() {
    if (_undoStack.length <= 1) return;
    _debounce?.cancel(); // flush any pending debounced snapshot first
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    _restoreSnapshot(_undoStack.last);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _debounce?.cancel();
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _restoreSnapshot(next);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Save
  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && widget.note == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final now = DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now());
    final note = Note(
      id: widget.note?.id,
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      updatedAt: now,
      isPinned: widget.note?.isPinned ?? false,
      folder: _folder,
      colorIndex: _colorIndex,
    );

    if (widget.note == null) {
      await DBHelper.insert(note);
    } else {
      await DBHelper.update(note);
    }

    if (mounted) Navigator.pop(context);
  }

  // Folder helpers
  Future<void> _addFolderInline(
      StateSetter setDialogState, List<String> folders) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await DBHelper.insertFolder(name);
      setDialogState(() {
        if (!folders.contains(name)) folders.add(name);
        _folder = name;
      });
      setState(() => _folder = name);
    }
  }

  // Color picker
  Widget _buildColorPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? kNoteColorsDark : kNoteColors;
    const labels = [
      'Default', 'Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple', 'Brown'
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: palette.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = _colorIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _colorIndex = i),
            child: Tooltip(
              message: labels[i],
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 30 : 26,
                height: selected ? 30 : 26,
                decoration: BoxDecoration(
                  color: palette[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                    const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ]
                      : [],
                ),
                child: selected
                    ? Icon(Icons.check,
                    size: 14,
                    color: isDark ? Colors.white : Colors.black54)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? kNoteColorsDark : kNoteColors;
    final bgColor = _colorIndex == 0 ? null : palette[_colorIndex];

    final canUndo = _undoStack.length > 1;
    final canRedo = _redoStack.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _save();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor:
          bgColor ?? Theme.of(context).appBarTheme.backgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Save & go back',
            onPressed: _save,
          ),
          title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
          actions: [
            IconButton(
              icon: Icon(Icons.undo,
                  color: canUndo ? Colors.white : Colors.white38),
              tooltip: 'Undo',
              onPressed: canUndo ? _undo : null,
            ),
            IconButton(
              icon: Icon(Icons.redo,
                  color: canRedo ? Colors.white : Colors.white38),
              tooltip: 'Redo',
              onPressed: canRedo ? _redo : null,
            ),
            _isSaving
                ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ))
                : TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              _buildColorPicker(),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                future: DBHelper.getFolders(),
                builder: (_, snap) {
                  final List<String> folders =
                  List<String>.from(snap.data ?? []);
                  if (_folder.isNotEmpty && !folders.contains(_folder)) {
                    folders.add(_folder);
                  }
                  return StatefulBuilder(
                    builder: (_, setLocal) => Row(
                      children: [
                        const Icon(Icons.folder_outlined,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                              folders.contains(_folder) ? _folder : '',
                              isExpanded: true,
                              hint: const Text('No folder',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                Theme.of(context).brightness ==
                                    Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('No folder')),
                                ...folders.map((f) => DropdownMenuItem<String>(
                                    value: f, child: Text(f))),
                                const DropdownMenuItem<String>(
                                  value: '__new__',
                                  child: Row(children: [
                                    Icon(Icons.add, size: 16),
                                    SizedBox(width: 4),
                                    Text('New folder…'),
                                  ]),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == '__new__') {
                                  await _addFolderInline(setLocal, folders);
                                } else {
                                  setLocal(() => _folder = v ?? '');
                                  setState(() => _folder = v ?? '');
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(color: Colors.blue.shade100),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Write your note here...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}