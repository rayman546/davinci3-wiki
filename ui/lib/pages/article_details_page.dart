import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/wiki_service.dart';
import '../providers/connectivity_provider.dart';
import '../services/api_error_handler.dart';
import '../widgets/error_display_widget.dart';
import '../widgets/loading_state_widget.dart';
import '../widgets/network_aware_widget.dart';

class ArticleDetailsPage extends StatefulWidget {
  final String articleId;
  final String title;

  const ArticleDetailsPage({
    super.key,
    required this.articleId,
    required this.title,
  });

  @override
  State<ArticleDetailsPage> createState() => _ArticleDetailsPageState();
}

class _ArticleDetailsPageState extends State<ArticleDetailsPage> {
  Article? _article;
  List<Article>? _relatedArticles;
  bool _isLoading = true;
  bool _isLoadingRelated = false;
  String? _error;
  String? _relatedError;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final wikiService = Provider.of<WikiService>(context, listen: false);
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      
      final article = await wikiService.getArticle(
        widget.articleId,
        connectivityProvider: connectivityProvider,
      );
      
      setState(() {
        _article = article;
        _isLoading = false;
      });
      
      // Load related articles after the main article is loaded
      _loadRelatedArticles();
    } catch (e) {
      setState(() {
        _error = ApiErrorHandler.getErrorMessage(e);
        _isLoading = false;
      });
      
      // Log error
      ApiErrorHandler.logError(
        'Failed to load article ${widget.articleId}: ${e.toString()}',
        showToast: false, // Don't show toast for this error
      );
    }
  }

  Future<void> _loadRelatedArticles() async {
    if (_article == null || _article!.relatedArticles.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingRelated = true;
      _relatedError = null;
    });

    try {
      final wikiService = Provider.of<WikiService>(context, listen: false);
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      final relatedArticles = <Article>[];

      // Limit to first 5 related articles
      final relatedIds = _article!.relatedArticles.take(5).toList();
      
      for (final id in relatedIds) {
        try {
          final article = await wikiService.getArticle(
            id,
            connectivityProvider: connectivityProvider,
          );
          relatedArticles.add(article);
        } catch (e) {
          // Log individual related article load failures
          ApiErrorHandler.logError(
            'Failed to load related article $id: ${e.toString()}',
            showToast: false,
          );
        }
      }

      if (mounted) {
        setState(() {
          _relatedArticles = relatedArticles;
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _relatedError = ApiErrorHandler.getErrorMessage(e);
          _isLoadingRelated = false;
        });
      }
      
      // Log error
      ApiErrorHandler.logError(
        'Error loading related articles: ${e.toString()}',
        showToast: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Consumer<ConnectivityProvider>(
            builder: (context, connectivityProvider, child) {
              final isConnected = connectivityProvider.isConnected;
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: isConnected ? 'Refresh article' : 'Refresh not available offline',
                onPressed: isConnected ? _loadArticle : null,
              );
            },
          ),
        ],
      ),
      body: NetworkAwareWidget(
        enforceConnectivity: false, // Allow showing cached article when offline
        offlineMode: OfflineDisplayMode.badge,
        onlineContent: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Show loading state
    if (_isLoading && _article == null) {
      return LoadingStateWidget(
        useSkeleton: true,
        skeletonType: SkeletonType.articleDetail,
        message: 'Loading article...',
      );
    }

    // Show error state
    if (_error != null && _article == null) {
      return ErrorDisplayWidget(
        errorType: ErrorType.network,
        message: _error!,
        title: 'Failed to load article',
        onRetry: _loadArticle,
      );
    }

    // Show empty state
    if (_article == null) {
      return ErrorDisplayWidget(
        errorType: ErrorType.emptyData,
        message: 'No article data available',
        onRetry: _loadArticle,
      );
    }

    // Show article content
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and summary
          Text(
            _article!.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          if (_article!.summary.isNotEmpty) ...[
            Text(
              _article!.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
          
          // Main content
          MarkdownBody(
            data: _article!.content,
            selectable: true,
          ),
          
          // Related articles section
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Related Articles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // Related articles content
          _buildRelatedArticlesSection(),
        ],
      ),
    );
  }

  Widget _buildRelatedArticlesSection() {
    // No related articles available
    if (_article!.relatedArticles.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        alignment: Alignment.center,
        child: Text(
          'No related articles found',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    // Loading related articles
    if (_isLoadingRelated) {
      return LoadingStateWidget(
        loadingType: LoadingType.inline,
        message: 'Loading related articles...',
      );
    }
    
    // Error loading related articles
    if (_relatedError != null) {
      return ErrorDisplayWidget(
        errorType: ErrorType.network,
        message: _relatedError!,
        displayMode: ErrorDisplayMode.card,
        onRetry: _loadRelatedArticles,
      );
    }
    
    // No related articles loaded
    if (_relatedArticles == null || _relatedArticles!.isEmpty) {
      return ErrorDisplayWidget(
        errorType: ErrorType.emptyData,
        message: 'Failed to load related articles',
        displayMode: ErrorDisplayMode.card,
        onRetry: _loadRelatedArticles,
      );
    }
    
    // Display related articles
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _relatedArticles!.map((article) => _buildRelatedArticleItem(article)).toList(),
    );
  }

  Widget _buildRelatedArticleItem(Article article) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(article.title),
        subtitle: Text(
          article.summary.isNotEmpty ? article.summary : 'No summary available',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
      ),
    );
  }
} 