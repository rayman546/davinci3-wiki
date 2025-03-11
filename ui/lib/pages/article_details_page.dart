import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/article.dart';
import '../services/wiki_service.dart';
import '../widgets/article_card.dart';

class ArticleDetailsPage extends StatefulWidget {
  final WikiService wikiService;
  final String articleId;

  const ArticleDetailsPage({
    super.key,
    required this.wikiService,
    required this.articleId,
  });

  @override
  State<ArticleDetailsPage> createState() => _ArticleDetailsPageState();
}

class _ArticleDetailsPageState extends State<ArticleDetailsPage> {
  Article? _article;
  List<Article>? _relatedArticles;
  String? _error;
  bool _isLoading = true;

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
      final article = await widget.wikiService.getArticle(widget.articleId);
      setState(() {
        _article = article;
        _isLoading = false;
      });

      if (article.relatedArticles != null && article.relatedArticles!.isNotEmpty) {
        _loadRelatedArticles(article.relatedArticles!);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRelatedArticles(List<String> articleIds) async {
    try {
      final articles = await Future.wait(
        articleIds.map((id) => widget.wikiService.getArticle(id)),
      );
      setState(() {
        _relatedArticles = articles;
      });
    } catch (e) {
      print('Error loading related articles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_error',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _loadArticle,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_article?.title ?? 'Article'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (_article?.summary != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            _article!.summary!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(
                      data: _article?.content ?? '',
                      selectable: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_relatedArticles != null && _relatedArticles!.isNotEmpty)
            SizedBox(
              width: 300,
              child: Card(
                margin: const EdgeInsets.all(16.0),
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Text(
                      'Related Articles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16.0),
                    ..._relatedArticles!.map((article) => ArticleCard(
                          article: article,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ArticleDetailsPage(
                                  wikiService: widget.wikiService,
                                  articleId: article.id,
                                ),
                              ),
                            );
                          },
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 