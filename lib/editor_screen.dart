import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'main.dart';

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
  String _folder = '';
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _folder = widget.note?.folder ?? widget.defaultFolder;

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() => _hasChanges = true;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

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
    );

    if (widget.note == null) {
      await DBHelper.insert(note);
    } else {
      await DBHelper.update(note);
    }

    if (mounted) Navigator.pop(context);
  }

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Save & go back',
            onPressed: _save,
          ),
          title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
          actions: [
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
                              value: folders.contains(_folder) ? _folder : '',
                              isExpanded: true,
                              hint: const Text('No folder',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).brightness ==
                                    Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('No folder'),
                                ),
                                ...folders.map((f) => DropdownMenuItem<String>(
                                  value: f,
                                  child: Text(f),
                                )),
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