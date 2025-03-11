import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/wiki_service.dart';
import '../widgets/article_card.dart';
import 'article_details_page.dart';

class ArticlesPage extends StatefulWidget {
  final WikiService wikiService;

  const ArticlesPage({
    super.key,
    required this.wikiService,
  });

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
        final articles = await widget.wikiService.getArticles(
          offset: _currentPage * _pageSize,
          limit: _pageSize,
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
          _error = e.toString();
          _isLoading = false;
        });
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
    if (_error != null) {
      return Center(
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
              onPressed: () {
                setState(() {
                  _error = null;
                  _articles = null;
                  _currentPage = 0;
                  _hasMore = true;
                });
                _loadArticles();
              },
              child: const Text('Retry'),
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _articles!.length + (_hasMore ? 1 : 0),
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
                  wikiService: widget.wikiService,
                  articleId: article.id,
                ),
              ),
            );
          },
        );
      },
    );
  }
} 