import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/wiki_service.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/article_card.dart';
import '../services/api_error_handler.dart';
import '../widgets/error_display_widget.dart';
import '../widgets/loading_state_widget.dart';
import '../widgets/network_aware_widget.dart';
import 'article_details_page.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  List<Article>? _articles;
  String? _error;
  bool _isLoading = true;
  final _scrollController = ScrollController();
  static const _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    if (!_isLoading && _hasMore) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final wikiService = Provider.of<WikiService>(context, listen: false);
        final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
        
        final articles = await wikiService.getArticles(
          page: _currentPage + 1,
          limit: _pageSize,
          connectivityProvider: connectivityProvider,
        );

        setState(() {
          if (_articles == null) {
            _articles = articles;
          } else {
            _articles!.addAll(articles);
          }
          _hasMore = articles.length == _pageSize;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } catch (e) {
        setState(() {
          _error = ApiErrorHandler.getErrorMessage(e);
          _isLoading = false;
          _isLoadingMore = false;
        });
        
        // Log the error
        ApiErrorHandler.logError(
          'Failed to load articles: ${e.toString()}',
          showToast: false, // Don't show toast for this error
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && 
        _hasMore) {
      setState(() {
        _isLoadingMore = true;
      });
      _loadArticles();
    }
  }

  void _refreshArticles() {
    setState(() {
      _articles = null;
      _currentPage = 0;
      _hasMore = true;
      _error = null;
    });
    _loadArticles();
  }

  @override
  Widget build(BuildContext context) {
    return NetworkAwareWidget(
      enforceConnectivity: false, // Allow showing cached content when offline
      offlineMode: OfflineDisplayMode.inline,
      offlineMessage: 'You are offline. Showing cached articles.',
      offlineAction: _refreshArticles,
      offlineActionText: 'Refresh',
      onlineContent: _buildPageContent(),
    );
  }
  
  Widget _buildPageContent() {
    // Show error state if error and no articles
    if (_error != null && _articles == null) {
      return ErrorDisplayWidget(
        errorType: ErrorType.network,
        message: _error!,
        title: 'Failed to load articles',
        onRetry: _refreshArticles,
      );
    }
    
    // Show loading state if no articles yet
    if (_articles == null) {
      return LoadingStateWidget(
        useSkeleton: true,
        skeletonType: SkeletonType.article,
        skeletonItemCount: 5,
        fullHeight: true,
        message: 'Loading articles...',
      );
    }
    
    // Show empty state if no articles found
    if (_articles!.isEmpty) {
      return ErrorDisplayWidget(
        errorType: ErrorType.emptyData,
        message: 'No articles found in the database.',
        onRetry: _refreshArticles,
      );
    }
    
    // Show article list
    return RefreshIndicator(
      onRefresh: () async {
        final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
        if (connectivityProvider.isConnected) {
          _refreshArticles();
        } else {
          // Show error message when trying to refresh while offline
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Can\'t refresh while offline'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _articles!.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end when loading more
          if (index == _articles!.length) {
            return LoadingStateWidget(
              loadingType: LoadingType.pagination,
              message: 'Loading more articles...',
            );
          }

          final article = _articles![index];
          return ArticleCard(
            article: article,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArticleDetailsPage(
                    articleId: article.id,
                    title: article.title,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 