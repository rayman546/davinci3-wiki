import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/wiki_service.dart';
import '../providers/connectivity_provider.dart';
import '../services/api_error_handler.dart';

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
  bool _isLoading = false;
  String? _error;

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
      
      // Show error dialog
      if (mounted) {
        ApiErrorHandler.showErrorSnackBar(context, ApiErrorHandler.getErrorMessage(e));
      }
    }
  }

  Future<void> _loadRelatedArticles() async {
    if (_article == null || _article!.relatedArticles.isEmpty) {
      return;
    }

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
          // Skip this related article
          debugPrint('Failed to load related article $id: ${e.toString()}');
        }
      }

      if (mounted) {
        setState(() {
          _relatedArticles = relatedArticles;
        });
      }
    } catch (e) {
      debugPrint('Error loading related articles: ${e.toString()}');
      // Don't show errors for related articles, just log them
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ConnectivityProvider>().isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh article',
            onPressed: isConnected ? _loadArticle : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _article == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _article == null) {
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
              'Failed to load article',
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
              onPressed: _loadArticle,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_article == null) {
      return const Center(
        child: Text('No article data available'),
      );
    }

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
          
          // Related articles
          if (_relatedArticles != null && _relatedArticles!.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Related Articles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ..._relatedArticles!.map((article) => _buildRelatedArticleItem(article)),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedArticleItem(Article article) {
    return ListTile(
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
    );
  }
} 