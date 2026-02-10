import 'package:flutter/material.dart';
import '../models/note.dart';
import '../database/database_helper.dart';
import '../services/export_service.dart';
import '../widgets/note_card.dart';
import '../widgets/empty_state.dart';
import 'note_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> notes = [];
  bool isLoading = true;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => isLoading = true);
    final allNotes = await DatabaseHelper.instance.getAllNotes();
    if (allNotes.isEmpty) {
      final restored = await _restoreNotesFromFiles();
      if (restored) return;
    }
    setState(() {
      notes = allNotes;
      isLoading = false;
    });
  }

  Future<bool> _restoreNotesFromFiles() async {
    if (_isRestoring) return false;
    _isRestoring = true;

    try {
      final exportService = ExportService.instance;
      final granted = await exportService.ensureExportPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Storage access needed to restore notes from MyDiary folder.',
              ),
              action: SnackBarAction(
                label: 'Grant',
                onPressed: () async {
                  final ok = await exportService.ensureExportPermission(
                    openSettingsIfDenied: true,
                  );
                  if (ok && mounted) {
                    _loadNotes();
                  }
                },
              ),
            ),
          );
        }
        return false;
      }

      final fileNotes = await exportService.readNotesFromFolder();
      if (fileNotes.isEmpty) {
        return false;
      }

      for (final note in fileNotes) {
        await DatabaseHelper.instance.insertNote(note);
      }

      final refreshed = await DatabaseHelper.instance.getAllNotes();
      if (mounted) {
        setState(() {
          notes = refreshed;
          isLoading = false;
        });
      }
      return true;
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> _deleteNote(Note note) async {
    await DatabaseHelper.instance.deleteNote(note.id!);
    await ExportService.instance.deleteNoteFile(note);
    _loadNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _togglePinStatus(int id, bool isPinned) async {
    await DatabaseHelper.instance.togglePinStatus(id, !isPinned);
    _loadNotes();
  }

  void _navigateToNoteDetail([Note? note]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
    );

    if (result == true) {
      _loadNotes();
    }
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteNote(note);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final pinnedCount = notes.where((note) => note.isPinned).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Notes',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notes.isEmpty
                          ? 'Capture your thoughts with style'
                          : '${notes.length} notes • $pinnedCount pinned',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
              _loadNotes();
            },
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.12),
                    theme.colorScheme.secondary.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Search notes',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF525252),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.tune, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: 'All Notes',
                value: notes.length.toString(),
                color: theme.colorScheme.primary,
              ),
              _InfoChip(
                label: 'Pinned',
                value: pinnedCount.toString(),
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyDiary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadNotes,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  const EmptyState(),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotes,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final note = notes[index];
                        return Dismissible(
                          key: Key(note.id.toString()),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              _showDeleteDialog(note);
                              return false;
                            }
                            return null;
                          },
                          child: NoteCard(
                            note: note,
                            onTap: () => _navigateToNoteDetail(note),
                            onPinPressed: () =>
                                _togglePinStatus(note.id!, note.isPinned),
                          ),
                        );
                      },
                      childCount: notes.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToNoteDetail(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF5C5C5C),
                ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E1E1E),
                ),
          ),
        ],
      ),
    );
  }
}
