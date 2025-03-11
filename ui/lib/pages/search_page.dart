import 'package:flutter/material.dart';
import 'dart:async';
import '../models/search_result.dart';
import '../services/wiki_service.dart';
import '../services/search_history_service.dart';
import '../widgets/search_result_card.dart';
import 'article_details_page.dart';

class SearchPage extends StatefulWidget {
  final WikiService wikiService;
  final SearchHistoryService searchHistoryService;

  const SearchPage({
    super.key,
    required this.wikiService,
    required this.searchHistoryService,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<SearchResult>? _results;
  List<String> _searchHistory = [];
  String? _error;
  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _isSemanticSearch = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = widget.searchHistoryService.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _showHistory = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _showHistory = false;
    });

    try {
      final results = _isSemanticSearch
          ? await widget.wikiService.semanticSearch(query)
          : await widget.wikiService.search(query);
      
      // Add to search history
      await widget.searchHistoryService.addSearch(query);
      await _loadSearchHistory();

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _showHistory = query.isEmpty;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _clearSearchHistory() async {
    await widget.searchHistoryService.clearHistory();
    await _loadSearchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Enter search query',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 16.0),
              ToggleButtons(
                isSelected: [!_isSemanticSearch, _isSemanticSearch],
                onPressed: (index) {
                  setState(() {
                    _isSemanticSearch = index == 1;
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  });
                },
                children: const [
                  Tooltip(
                    message: 'Regular Search',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(Icons.text_fields),
                    ),
                  ),
                  Tooltip(
                    message: 'Semantic Search',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(Icons.psychology),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error: $_error',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        if (_isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_showHistory && _searchHistory.isNotEmpty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        'Recent Searches',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _clearSearchHistory,
                        child: const Text('Clear History'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _searchHistory.length,
                    itemBuilder: (context, index) {
                      final query = _searchHistory[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(query),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await widget.searchHistoryService.removeSearch(query);
                            await _loadSearchHistory();
                          },
                        ),
                        onTap: () {
                          _searchController.text = query;
                          _performSearch(query);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        else if (_results != null)
          Expanded(
            child: _results!.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _results!.length,
                    itemBuilder: (context, index) {
                      final result = _results![index];
                      return SearchResultCard(
                        result: result,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArticleDetailsPage(
                                wikiService: widget.wikiService,
                                articleId: result.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
      ],
    );
  }
} 