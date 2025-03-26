import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/wiki_service.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/article_card.dart';
import '../services/api_error_handler.dart';
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
        });
      } catch (e) {
        setState(() {
          _error = ApiErrorHandler.getErrorMessage(e);
          _isLoading = false;
        });
        
        // Show error snackbar
        if (mounted) {
          ApiErrorHandler.showErrorSnackBar(context, ApiErrorHandler.getErrorMessage(e));
        }
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ConnectivityProvider>().isConnected;

    if (_error != null && _articles == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load articles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isConnected 
                ? () {
                  setState(() {
                    _error = null;
                    _articles = null;
                    _currentPage = 0;
                    _hasMore = true;
                  });
                  _loadArticles();
                } 
                : null, // Disable retry button when offline
              child: const Text('Try Again'),
            ),
            if (!isConnected)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'You are offline. Please connect to load articles.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    if (_articles == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_articles!.isEmpty) {
      return Center(
        child: Text(
          'No articles found',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (isConnected) {
          setState(() {
            _articles = null;
            _currentPage = 0;
            _hasMore = true;
          });
          await _loadArticles();
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _articles!.length + (_hasMore && isConnected ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _articles!.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
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