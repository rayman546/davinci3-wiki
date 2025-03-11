import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/search_result.dart';
import 'cache_service.dart';

class WikiService {
  final String baseUrl;
  final http.Client _client;
  final CacheService _cacheService;
  
  // Performance metrics
  final Map<String, List<int>> _queryTimings = {};
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};
  
  // Cache configuration
  final bool _prioritizeCache;
  final Duration _cacheTimeout;
  
  WikiService({
    required this.baseUrl,
    required CacheService cacheService,
    http.Client? client,
    bool prioritizeCache = true,
    Duration? cacheTimeout,
  })  : _cacheService = cacheService,
        _client = client ?? http.Client(),
        _prioritizeCache = prioritizeCache,
        _cacheTimeout = cacheTimeout ?? const Duration(milliseconds: 500);

  Future<List<Article>> getArticles({
    int page = 1,
    int limit = 20,
  }) async {
    final operationKey = 'getArticles_$page\_$limit';
    final stopwatch = Stopwatch()..start();
    
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/articles?page=$page&limit=$limit'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final articles = jsonList.map((json) => Article.fromJson(json)).toList();
        
        // Cache articles in background
        _cacheArticlesInBackground(articles);
        
        // Record timing
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        
        return articles;
      } else {
        throw Exception('Failed to load articles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching articles: $e');
      // Return empty list if offline and no cache
      _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
      return [];
    }
  }

  Future<Article> getArticle(String id) async {
    final operationKey = 'getArticle_$id';
    final stopwatch = Stopwatch()..start();
    
    // Try cache first if prioritizing cache
    if (_prioritizeCache) {
      try {
        final cached = await _cacheService.getCachedArticle(id);
        if (cached != null) {
          _incrementCacheHit(operationKey);
          _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
          
          // Refresh from network in background if we have connectivity
          _refreshArticleInBackground(id);
          
          return cached;
        }
      } catch (e) {
        print('Error accessing cache: $e');
      }
      _incrementCacheMiss(operationKey);
    }
    
    // Set up a timeout for the network request
    try {
      final response = await _client.get(Uri.parse('$baseUrl/articles/$id'))
          .timeout(_cacheTimeout);

      if (response.statusCode == 200) {
        final article = Article.fromJson(json.decode(response.body));
        
        // Cache article in background
        _cacheArticleInBackground(article);
        
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        return article;
      }
    } catch (e) {
      print('Error fetching article: $e');
      // Try to get from cache if network request failed
      final cached = await _cacheService.getCachedArticle(id);
      if (cached != null) {
        _incrementCacheHit(operationKey);
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
        return cached;
      }
      _incrementCacheMiss(operationKey);
    }

    _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
    throw Exception('Failed to load article');
  }

  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    final operationKey = 'search_${query.hashCode}';
    final stopwatch = Stopwatch()..start();
    
    // Try cache first if prioritizing cache
    if (_prioritizeCache) {
      try {
        final cached = await _cacheService.getCachedSearchResults(query, false);
        if (cached != null) {
          _incrementCacheHit(operationKey);
          _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
          
          // Refresh from network in background
          _refreshSearchInBackground(query, false);
          
          return cached;
        }
      } catch (e) {
        print('Error accessing search cache: $e');
      }
      _incrementCacheMiss(operationKey);
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}'),
      ).timeout(_cacheTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
        
        // Cache results in background
        _cacheSearchResultsInBackground(query, results, false);
        
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        return results;
      }
    } catch (e) {
      print('Error performing search: $e');
      // Try to get from cache if network request failed
      final cached = await _cacheService.getCachedSearchResults(query, false);
      if (cached != null) {
        _incrementCacheHit(operationKey);
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
        return cached;
      }
      _incrementCacheMiss(operationKey);
    }

    _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
    throw Exception('Failed to perform search');
  }

  Future<List<SearchResult>> semanticSearch(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    final operationKey = 'semanticSearch_${query.hashCode}';
    final stopwatch = Stopwatch()..start();
    
    // Try cache first if prioritizing cache
    if (_prioritizeCache) {
      try {
        final cached = await _cacheService.getCachedSearchResults(query, true);
        if (cached != null) {
          _incrementCacheHit(operationKey);
          _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
          
          // Refresh from network in background
          _refreshSearchInBackground(query, true);
          
          return cached;
        }
      } catch (e) {
        print('Error accessing semantic search cache: $e');
      }
      _incrementCacheMiss(operationKey);
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/semantic-search?q=${Uri.encodeComponent(query)}'),
      ).timeout(_cacheTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
        
        // Cache results in background
        _cacheSearchResultsInBackground(query, results, true);
        
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        return results;
      }
    } catch (e) {
      print('Error performing semantic search: $e');
      // Try to get from cache if network request failed
      final cached = await _cacheService.getCachedSearchResults(query, true);
      if (cached != null) {
        _incrementCacheHit(operationKey);
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
        return cached;
      }
      _incrementCacheMiss(operationKey);
    }

    _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
    throw Exception('Failed to perform semantic search');
  }
  
  // Background operations to avoid blocking UI
  Future<void> _cacheArticleInBackground(Article article) async {
    Timer(Duration.zero, () async {
      try {
        await _cacheService.cacheArticle(article);
      } catch (e) {
        print('Error caching article in background: $e');
      }
    });
  }
  
  Future<void> _cacheArticlesInBackground(List<Article> articles) async {
    Timer(Duration.zero, () async {
      try {
        for (final article in articles) {
          await _cacheService.cacheArticle(article);
        }
      } catch (e) {
        print('Error caching articles in background: $e');
      }
    });
  }
  
  Future<void> _cacheSearchResultsInBackground(
    String query,
    List<SearchResult> results,
    bool isSemantic,
  ) async {
    Timer(Duration.zero, () async {
      try {
        await _cacheService.cacheSearchResults(query, results, isSemantic);
      } catch (e) {
        print('Error caching search results in background: $e');
      }
    });
  }
  
  Future<void> _refreshArticleInBackground(String id) async {
    Timer(Duration.zero, () async {
      try {
        final response = await _client.get(Uri.parse('$baseUrl/articles/$id'));
        if (response.statusCode == 200) {
          final article = Article.fromJson(json.decode(response.body));
          await _cacheService.cacheArticle(article);
        }
      } catch (e) {
        // Ignore errors in background refresh
      }
    });
  }
  
  Future<void> _refreshSearchInBackground(String query, bool isSemantic) async {
    Timer(Duration.zero, () async {
      try {
        final endpoint = isSemantic ? 'semantic-search' : 'search';
        final response = await _client.get(
          Uri.parse('$baseUrl/$endpoint?q=${Uri.encodeComponent(query)}'),
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> jsonList = json.decode(response.body);
          final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
          await _cacheService.cacheSearchResults(query, results, isSemantic);
        }
      } catch (e) {
        // Ignore errors in background refresh
      }
    });
  }
  
  // Performance metrics methods
  void _recordTiming(String operation, int milliseconds, {bool isCache = false, bool isError = false}) {
    if (!_queryTimings.containsKey(operation)) {
      _queryTimings[operation] = [];
    }
    _queryTimings[operation]!.add(milliseconds);
    
    // Keep only the last 100 timings
    if (_queryTimings[operation]!.length > 100) {
      _queryTimings[operation]!.removeAt(0);
    }
  }
  
  void _incrementCacheHit(String operation) {
    _cacheHits[operation] = (_cacheHits[operation] ?? 0) + 1;
  }
  
  void _incrementCacheMiss(String operation) {
    _cacheMisses[operation] = (_cacheMisses[operation] ?? 0) + 1;
  }
  
  // Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final metrics = <String, dynamic>{};
    
    // Add cache overview
    final cacheStats = _cacheService.getCacheStats();
    metrics['cacheSize'] = cacheStats['size'];
    metrics['cacheItemCount'] = cacheStats['itemCount'];
    
    // Add query timings
    metrics['queryTimings'] = Map<String, dynamic>.from(_queryTimings);
    
    // Add cache hit/miss stats
    metrics['cacheHits'] = Map<String, int>.from(_cacheHits);
    metrics['cacheMisses'] = Map<String, int>.from(_cacheMisses);
    
    // Add overall cache stats
    metrics['overallCacheStats'] = {
      'totalHits': _cacheHits.values.fold(0, (sum, count) => sum + count),
      'totalMisses': _cacheMisses.values.fold(0, (sum, count) => sum + count),
      'hitRatio': _calculateHitRatio(),
    };
    
    return metrics;
  }

  Future<void> clearCache() async {
    await _cacheService.clearCache();
    _cacheHits.clear();
    _cacheMisses.clear();
  }

  Future<void> clearOldCache({Duration? maxAge}) async {
    await _cacheService.clearOldCache(maxAge: maxAge);
  }
  
  Future<List<Article>> getMostAccessedArticles({int limit = 10}) async {
    return _cacheService.getMostAccessedArticles(limit: limit);
  }

  void dispose() {
    _client.close();
  }

  /// Get the most frequently accessed articles
  Future<List<dynamic>> getMostAccessedArticles({int limit = 5}) async {
    try {
      // Get access counts from cache service
      final accessCounts = _cacheService.getAccessCounts();
      
      // Sort by access count (descending)
      final sortedIds = accessCounts.entries
          .where((entry) => entry.value > 0) // Only include articles that have been accessed
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      // Limit the number of results
      final topIds = sortedIds.take(limit).map((e) => e.key).toList();
      
      if (topIds.isEmpty) {
        return [];
      }
      
      // Fetch article details for each ID
      final articles = <dynamic>[];
      for (final id in topIds) {
        try {
          final article = await getArticle(id);
          if (article != null) {
            articles.add(article);
          }
        } catch (e) {
          print('Error fetching article $id: $e');
          // Continue with next article
        }
      }
      
      return articles;
    } catch (e) {
      print('Error getting most accessed articles: $e');
      return [];
    }
  }

  /// Calculate cache hit ratio
  double _calculateHitRatio() {
    final totalHits = _cacheHits.values.fold(0, (sum, count) => sum + count);
    final totalMisses = _cacheMisses.values.fold(0, (sum, count) => sum + count);
    final total = totalHits + totalMisses;
    
    if (total == 0) {
      return 0.0;
    }
    
    return totalHits / total;
  }
} 