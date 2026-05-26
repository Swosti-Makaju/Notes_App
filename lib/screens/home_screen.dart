import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../main.dart';
import 'editor_screen.dart';

// Shared note color palette
const List<Color> kNoteColors = [
  Color(0xFFFFFFFF), // 0 = default (white / surface)
  Color(0xFFFFCDD2), // 1 = red
  Color(0xFFFFE0B2), // 2 = orange
  Color(0xFFFFF9C4), // 3 = yellow
  Color(0xFFC8E6C9), // 4 = green
  Color(0xFFBBDEFB), // 5 = blue
  Color(0xFFE1BEE7), // 6 = purple
  Color(0xFFD7CCC8), // 7 = brown
];

const List<Color> kNoteColorsDark = [
  Color(0xFF2C2C2C),
  Color(0xFF6D2E2E),
  Color(0xFF6D4A2E),
  Color(0xFF6D6430),
  Color(0xFF2E5E30),
  Color(0xFF2E4A6D),
  Color(0xFF4A2E6D),
  Color(0xFF4A3E38),
];

Color noteCardColor(int colorIndex, bool isDark) {
  final palette = isDark ? kNoteColorsDark : kNoteColors;
  if (colorIndex < 0 || colorIndex >= palette.length) return palette[0];
  return palette[colorIndex];
}

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
  bool _isGridView = false; // NEW: grid/list toggle

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

  // Note card (shared between list and grid)
  Widget _buildNoteCard(Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = noteCardColor(note.colorIndex, isDark);
    final isDefault = note.colorIndex == 0;

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        return confirmed == true;
      },
      onDismissed: (_) async {
        await DBHelper.delete(note.id!);
        _loadNotes();
      },
      child: Card(
        color: isDefault ? null : cardColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openEditor(note),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // pin + delete buttons
                    SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await DBHelper.togglePin(
                                  note.id!, note.isPinned);
                              _loadNotes();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                note.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 16,
                                color: note.isPinned
                                    ? Colors.blueAccent
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _confirmDelete(note.id!),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.delete_outline,
                                  size: 16, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: _isGridView ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(note.updatedAt,
                        style:
                        const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (note.folder.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.folder_outlined,
                          size: 10, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(note.folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
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
          // Grid / List toggle
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
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
          : _isGridView
          ? GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _buildNoteCard(_filtered[i]),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildNoteCard(_filtered[i]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}