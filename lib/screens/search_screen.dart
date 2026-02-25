import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../utils/constants.dart';
import '../widgets/note_card.dart';
import 'note_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Note> _searchResults = [];
  bool _isSearching = false;
  String _selectedCategory = 'All';

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await DatabaseHelper.instance.searchNotes(query);

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  List<Note> get _visibleResults {
    if (_selectedCategory == 'All') {
      return _searchResults;
    }

    return _searchResults.where((note) {
      return (note.category ?? '').trim().toLowerCase() ==
          _selectedCategory.toLowerCase();
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleResults = _visibleResults;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Notes')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by title or content...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                            setState(() => _selectedCategory = 'All');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  _performSearch(value);
                  setState(() {});
                },
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    selected: _selectedCategory == 'All',
                    label: const Text('All'),
                    onSelected: (_) =>
                        setState(() => _selectedCategory = 'All'),
                  ),
                  const SizedBox(width: 8),
                  ...AppConstants.categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _selectedCategory == category,
                        label: Text(category),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : visibleResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isEmpty
                                ? Icons.search_rounded
                                : Icons.search_off_rounded,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Type to search your notes'
                                : 'No matching notes found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try a different keyword or category filter.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: visibleResults.length,
                      itemBuilder: (context, index) {
                        final note = visibleResults[index];
                        return NoteCard(
                          note: note,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NoteDetailScreen(note: note),
                              ),
                            );
                            _performSearch(_searchController.text);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
