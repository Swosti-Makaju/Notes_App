import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'main.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? selectedFolder;
  final ValueChanged<String?>? onFolderChanged;

  const HomeScreen({super.key, this.selectedFolder, this.onFolderChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  List<Note> _filtered = [];
  List<String> _folders = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadFolders();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.selectedFolder != widget.selectedFolder) {
      _loadNotes();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final notes = await DBHelper.getAll(folder: widget.selectedFolder);
    if (!mounted) return;
    setState(() {
      _allNotes = notes;
      _applySearch(_searchController.text, notify: false);
    });
  }

  Future<void> _loadFolders() async {
    final folders = await DBHelper.getFolders();
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  void _applySearch(String query, {bool notify = true}) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? _allNotes
        : _allNotes
        .where((n) =>
    n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q))
        .toList();
    if (notify) {
      setState(() => _filtered = filtered);
    } else {
      _filtered = filtered;
    }
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.delete(id);
      _loadNotes();
    }
  }

  Future<void> _confirmDeleteAll() async {
    if (_allNotes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete all notes?'),
        content: const Text(
            'All notes will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete All',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.deleteAll();
      _loadNotes();
    }
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EditorScreen(note: note, defaultFolder: widget.selectedFolder ?? '')),
    );
    _loadNotes();
    _loadFolders();
  }

  Future<void> _showAddFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      _loadFolders();
    }
  }

  Future<void> _confirmDeleteFolder(String folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "$folder"?'),
        content:
        const Text('Notes in this folder will be moved to All Notes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.deleteFolder(folder);
      if (widget.selectedFolder == folder) {
        widget.onFolderChanged?.call(null);
      }
      _loadFolders();
      _loadNotes();
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
              color: Theme.of(context).appBarTheme.backgroundColor,
              child: const Text(
                'My Notes',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            // All Notes
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('All Notes'),
              selected: widget.selectedFolder == null,
              selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer,
              onTap: () {
                widget.onFolderChanged?.call(null);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            // Folder list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('Folders',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined,
                        size: 20),
                    tooltip: 'New folder',
                    onPressed: () async {
                      Navigator.pop(context);
                      await _showAddFolderDialog();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _folders.isEmpty
                  ? Center(
                  child: Text('No folders yet',
                      style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                itemCount: _folders.length,
                itemBuilder: (_, i) {
                  final f = _folders[i];
                  final selected = widget.selectedFolder == f;
                  return ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(f),
                    selected: selected,
                    selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                    onTap: () {
                      widget.onFolderChanged?.call(f);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDeleteFolder(f);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
    widget.selectedFolder != null ? widget.selectedFolder! : 'All Notes';

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, mode, __) => IconButton(
              icon: Icon(mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              tooltip: 'Toggle theme',
              onPressed: () {
                themeNotifier.value =
                mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),
          if (_allNotes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete All',
              onPressed: _confirmDeleteAll,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _applySearch,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search notes...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.note_alt_outlined,
              size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isEmpty
                ? 'No notes yet.\nTap + to create one.'
                : 'No results found.',
            textAlign: TextAlign.center,
            style:
            TextStyle(color: Colors.grey.shade700, fontSize: 16),
          ),
        ]),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final note = _filtered[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              onTap: () => _openEditor(note),
              title: Row(
                children: [
                  if (note.isPinned) ...[
                    const Icon(Icons.push_pin,
                        size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(note.updatedAt,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      if (note.folder.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.folder_outlined,
                            size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(note.folder,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      note.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: note.isPinned
                          ? Colors.blueAccent
                          : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () async {
                      await DBHelper.togglePin(note.id!, note.isPinned);
                      _loadNotes();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () => _confirmDelete(note.id!),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}