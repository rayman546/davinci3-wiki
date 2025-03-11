import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/search_result.dart';
import 'cache_service.dart';

class WikiService {
  final String baseUrl;
  final http.Client _client;
  final CacheService _cacheService;

  WikiService({
    required this.baseUrl,
    required CacheService cacheService,
    http.Client? client,
  })  : _cacheService = cacheService,
        _client = client ?? http.Client();

  Future<List<Article>> getArticles({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/articles?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final articles = jsonList.map((json) => Article.fromJson(json)).toList();
        
        // Cache articles
        for (final article in articles) {
          await _cacheService.cacheArticle(article);
        }
        
        return articles;
      } else {
        throw Exception('Failed to load articles: ${response.statusCode}');
      }
    } catch (e) {
      // Return empty list if offline and no cache
      return [];
    }
  }

  Future<Article> getArticle(String id) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/articles/$id'));

      if (response.statusCode == 200) {
        final article = Article.fromJson(json.decode(response.body));
        await _cacheService.cacheArticle(article);
        return article;
      }
    } catch (e) {
      // Try to get from cache if offline
      final cached = await _cacheService.getCachedArticle(id);
      if (cached != null) {
        return cached;
      }
    }

    throw Exception('Failed to load article');
  }

  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
        await _cacheService.cacheSearchResults(query, results, false);
        return results;
      }
    } catch (e) {
      // Try to get from cache if offline
      final cached = await _cacheService.getCachedSearchResults(query, false);
      if (cached != null) {
        return cached;
      }
    }

    throw Exception('Failed to perform search');
  }

  Future<List<SearchResult>> semanticSearch(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/semantic-search?q=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
        await _cacheService.cacheSearchResults(query, results, true);
        return results;
      }
    } catch (e) {
      // Try to get from cache if offline
      final cached = await _cacheService.getCachedSearchResults(query, true);
      if (cached != null) {
        return cached;
      }
    }

    throw Exception('Failed to perform semantic search');
  }

  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }

  Future<void> clearOldCache({Duration? maxAge}) async {
    await _cacheService.clearOldCache(maxAge: maxAge);
  }

  void dispose() {
    _client.close();
  }
} 