import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/search_result.dart';
import '../services/wiki_service.dart';
import '../services/search_history_service.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/search_result_card.dart';
import '../services/api_error_handler.dart';
import '../widgets/error_display_widget.dart';
import '../widgets/loading_state_widget.dart';
import '../widgets/network_aware_widget.dart';
import 'article_details_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

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
    final searchHistoryService = Provider.of<SearchHistoryService>(context, listen: false);
    final history = searchHistoryService.getSearchHistory();
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

    final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivityProvider.isConnected) {
      setState(() {
        _error = 'You are offline. Cannot perform search.';
        _isLoading = false;
        _showHistory = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _showHistory = false;
    });

    try {
      final wikiService = Provider.of<WikiService>(context, listen: false);
      final searchHistoryService = Provider.of<SearchHistoryService>(context, listen: false);
      
      final results = _isSemanticSearch
          ? await wikiService.semanticSearch(
              query,
              connectivityProvider: connectivityProvider,
            )
          : await wikiService.search(
              query,
              connectivityProvider: connectivityProvider,
            );
      
      // Add to search history
      await searchHistoryService.addSearch(query);
      await _loadSearchHistory();

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiErrorHandler.getErrorMessage(e);
        _isLoading = false;
      });
      
      // Log error
      ApiErrorHandler.logError(
        'Search error: ${e.toString()}',
        showToast: false, // Don't show toast for this error
      );
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
    final searchHistoryService = Provider.of<SearchHistoryService>(context, listen: false);
    await searchHistoryService.clearHistory();
    await _loadSearchHistory();
  }

  void _retrySearch() {
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkAwareWidget(
      enforceConnectivity: false, // Allow showing search history when offline
      offlineMode: OfflineDisplayMode.inline,
      offlineMessage: 'You are offline. Showing recent searches only.',
      onlineContent: Column(
        children: [
          _buildSearchControls(),
          Expanded(child: _buildSearchContent()),
        ],
      ),
    );
  }

  Widget _buildSearchControls() {
    final isConnected = context.watch<ConnectivityProvider>().isConnected;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: isConnected ? 'Enter search query' : 'Search disabled while offline',
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
                enabled: isConnected,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 16.0),
          ToggleButtons(
            isSelected: [!_isSemanticSearch, _isSemanticSearch],
            onPressed: isConnected 
              ? (index) {
                  setState(() {
                    _isSemanticSearch = index == 1;
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  });
                }
              : null,
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
    );
  }

  Widget _buildSearchContent() {
    final isConnected = context.watch<ConnectivityProvider>().isConnected;
    
    // Show error state if error
    if (_error != null) {
      return ErrorDisplayWidget(
        errorType: isConnected ? ErrorType.network : ErrorType.offline,
        message: _error!,
        title: 'Search Error',
        onRetry: isConnected ? _retrySearch : null,
        showRetryButton: isConnected && _searchController.text.isNotEmpty,
        secondaryAction: isConnected ? null : TextButton(
          onPressed: () {
            setState(() {
              _showHistory = true;
              _error = null;
            });
          },
          child: const Text('View Recent Searches'),
        ),
      );
    }
    
    // Show loading state if searching
    if (_isLoading) {
      final searchType = _isSemanticSearch ? 'semantic' : 'text';
      return LoadingStateWidget(
        useSkeleton: true,
        skeletonType: SkeletonType.searchResult,
        skeletonItemCount: 5,
        fullHeight: true,
        message: 'Performing $searchType search...',
      );
    }
    
    // Show offline message when disconnected and not showing history
    if (!isConnected && !_showHistory) {
      return ErrorDisplayWidget(
        errorType: ErrorType.offline,
        message: 'Search requires an internet connection',
        showRetryButton: false,
        secondaryAction: TextButton(
          onPressed: () {
            setState(() {
              _showHistory = true;
            });
          },
          child: const Text('View Recent Searches'),
        ),
      );
    }
    
    // Show search history
    if (_showHistory) {
      if (_searchHistory.isEmpty) {
        return Center(
          child: Text(
            'No recent searches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      }
      
      return Column(
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
                      final searchHistoryService = Provider.of<SearchHistoryService>(context, listen: false);
                      await searchHistoryService.removeSearch(query);
                      await _loadSearchHistory();
                    },
                  ),
                  onTap: isConnected ? () {
                    _searchController.text = query;
                    _performSearch(query);
                  } : null,
                  enabled: isConnected,
                );
              },
            ),
          ),
        ],
      );
    }
    
    // Show search results
    if (_results != null) {
      // No results found state
      if (_results!.isEmpty) {
        return ErrorDisplayWidget(
          errorType: ErrorType.emptyData,
          message: 'No results found for "${_searchController.text}"',
          title: 'No Results',
          onRetry: null,
          showRetryButton: false,
          secondaryAction: TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _showHistory = true;
                _results = null;
              });
            },
            child: const Text('Clear Search'),
          ),
        );
      }
      
      // Results list
      return ListView.builder(
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
                    articleId: result.articleId,
                    title: result.title,
                  ),
                ),
              );
            },
          );
        },
      );
    }
    
    // Initial empty state
    return const Center(
      child: Text('Type something to search'),
    );
  }
} 