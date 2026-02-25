import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/note_sync_service.dart';
import '../services/theme_service.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_card.dart';
import 'export_screen.dart';
import 'note_detail_screen.dart';
import 'search_screen.dart';

enum NoteSortOption { newest, oldest, titleAZ, titleZA }

enum HomeMenuAction { sort, backup, signOut }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  bool _isLoading = true;
  bool _showPinnedOnly = false;
  String _selectedCategory = 'All';
  NoteSortOption _sortOption = NoteSortOption.newest;
  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  List<Note> get _visibleNotes {
    final filtered = _allNotes.where((note) {
      if (_showPinnedOnly && !note.isPinned) return false;

      if (_selectedCategory != 'All') {
        final category = (note.category ?? '').trim().toLowerCase();
        if (category != _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (_sortOption) {
      case NoteSortOption.newest:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NoteSortOption.oldest:
        filtered.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case NoteSortOption.titleAZ:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case NoteSortOption.titleZA:
        filtered.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  List<String> get _categoryFilters {
    final categories = {
      ...AppConstants.categories,
      ..._allNotes
          .map((note) => note.category?.trim())
          .whereType<String>()
          .where((category) => category.isNotEmpty),
    }.toList()..sort();

    return ['All', ...categories];
  }

  Future<void> _bootstrap() async {
    await _loadNotes(showLoader: true);
    unawaited(_syncInBackground(showFailureSnackBar: false));
  }

  Future<void> _loadNotes({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    final allNotes = await DatabaseHelper.instance.getAllNotes();

    if (!mounted) return;
    setState(() {
      _allNotes = allNotes;
      if (_selectedCategory != 'All' &&
          !_categoryFilters.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
      _isLoading = false;
    });
  }

  Future<void> _syncInBackground({bool showFailureSnackBar = true}) async {
    try {
      await NoteSyncService.instance.syncAllNotes();
      if (mounted) {
        setState(() => _lastSyncedAt = DateTime.now());
      }
      await _loadNotes();
    } on NoteSyncException catch (e) {
      if (!mounted || !showFailureSnackBar) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted || !showFailureSnackBar) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud sync failed. Showing offline notes.'),
        ),
      );
    }
  }

  Future<void> _deleteNote(Note note) async {
    await DatabaseHelper.instance.deleteNote(note.id!);
    await ExportService.instance.deleteNoteFile(note);

    try {
      await NoteSyncService.instance.deleteNoteFromCloud(note);
    } catch (_) {}

    await _loadNotes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _togglePinStatus(int id, bool isPinned) async {
    await DatabaseHelper.instance.togglePinStatus(id, !isPinned);
    final updatedNote = await DatabaseHelper.instance.getNote(id);
    if (updatedNote != null) {
      try {
        await NoteSyncService.instance.upsertNote(updatedNote);
      } catch (_) {}
    }

    await _loadNotes();
  }

  Future<void> _navigateToNoteDetail([Note? note]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
    );

    if (result == true) {
      await _loadNotes();
    }
  }

  Future<void> _openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
    if (mounted) {
      unawaited(_loadNotes());
    }
  }

  Future<void> _openBackupScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExportScreen()),
    );
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    await DatabaseHelper.instance.clearAllNotes();
    await AuthService.instance.signOut();
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text(
          'This will remove the note from this device and cloud.',
        ),
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

  Future<void> _showThemeBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final activeMode = ThemeService.instance.themeMode;

        Future<void> setMode(ThemeMode mode) async {
          await ThemeService.instance.setThemeMode(mode);
          if (context.mounted) {
            Navigator.pop(context);
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('System'),
                trailing: activeMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => setMode(ThemeMode.system),
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Light'),
                trailing: activeMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => setMode(ThemeMode.light),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark'),
                trailing: activeMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => setMode(ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  String get _sortLabel {
    switch (_sortOption) {
      case NoteSortOption.newest:
        return 'Newest';
      case NoteSortOption.oldest:
        return 'Oldest';
      case NoteSortOption.titleAZ:
        return 'Title A-Z';
      case NoteSortOption.titleZA:
        return 'Title Z-A';
    }
  }

  void _showSortPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.access_time_filled_rounded),
                title: const Text('Newest first'),
                trailing: _sortOption == NoteSortOption.newest
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _sortOption = NoteSortOption.newest);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: const Text('Oldest first'),
                trailing: _sortOption == NoteSortOption.oldest
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _sortOption = NoteSortOption.oldest);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Title A-Z'),
                trailing: _sortOption == NoteSortOption.titleAZ
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _sortOption = NoteSortOption.titleAZ);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Title Z-A'),
                trailing: _sortOption == NoteSortOption.titleZA
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _sortOption = NoteSortOption.titleZA);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewPanel(BuildContext context) {
    final theme = Theme.of(context);
    final pinnedCount = _allNotes.where((note) => note.isPinned).length;
    final categoryCount = _categoryFilters.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.92),
            theme.colorScheme.tertiary.withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capture what matters today',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastSyncedAt == null
                ? 'Cloud sync is available when online.'
                : 'Last synced ${DateFormat('MMM d, h:mm a').format(_lastSyncedAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: 'Total',
                value: _allNotes.length.toString(),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
              ),
              _InfoChip(
                label: 'Pinned',
                value: pinnedCount.toString(),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
              ),
              _InfoChip(
                label: 'Categories',
                value: categoryCount.toString(),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Search notes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: _showSortPicker,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            selected: _showPinnedOnly,
            onSelected: (selected) {
              setState(() => _showPinnedOnly = selected);
            },
            avatar: const Icon(Icons.push_pin_rounded, size: 16),
            label: const Text('Pinned'),
          ),
          const SizedBox(width: 8),
          ..._categoryFilters.map((category) {
            final selected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selectedColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                selected: selected,
                label: Text(category),
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final visibleNotes = _visibleNotes;

    return RefreshIndicator(
      onRefresh: _syncInBackground,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildOverviewPanel(context)),
          SliverToBoxAdapter(child: _buildActionBar(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Sorted by $_sortLabel',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFilterStrip(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (visibleNotes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                title: _allNotes.isEmpty
                    ? 'Your notebook is waiting'
                    : 'No notes match these filters',
                subtitle: _allNotes.isEmpty
                    ? 'Create your first note and it will sync to your account.'
                    : 'Try another category, disable pinned-only mode, or clear filters.',
                icon: _allNotes.isEmpty
                    ? Icons.auto_awesome_outlined
                    : Icons.filter_alt_off_rounded,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final note = visibleNotes[index];
                return Dismissible(
                  key: Key(note.id.toString()),
                  background: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
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
              }, childCount: visibleNotes.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MyDiary'),
            Text(
              AuthService.instance.currentUser?.email ?? 'Offline mode',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.cloud_sync_rounded),
            onPressed: () => unawaited(_syncInBackground()),
          ),
          IconButton(
            tooltip: 'Theme',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showThemeBottomSheet,
          ),
          PopupMenuButton<HomeMenuAction>(
            onSelected: (action) {
              switch (action) {
                case HomeMenuAction.sort:
                  _showSortPicker();
                  break;
                case HomeMenuAction.backup:
                  _openBackupScreen();
                  break;
                case HomeMenuAction.signOut:
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: HomeMenuAction.sort,
                child: ListTile(
                  leading: Icon(Icons.sort_rounded),
                  title: Text('Sort notes'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: HomeMenuAction.backup,
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Backup & Export'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: HomeMenuAction.signOut,
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Sign out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToNoteDetail(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color foregroundColor;
  final Color backgroundColor;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
