import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/search_result.dart';
import 'cache_service.dart';
import 'api_error_handler.dart';
import '../providers/connectivity_provider.dart';

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
    required ConnectivityProvider connectivityProvider,
  }) async {
    final operationKey = 'getArticles_$page\_$limit';
    final stopwatch = Stopwatch()..start();
    
    try {
      return await ApiErrorHandler.execute<List<Article>>(
        apiCall: () async {
          final response = await _client.get(
            Uri.parse('$baseUrl/articles?page=$page&limit=$limit'),
          ).timeout(_cacheTimeout);
          
          return await ApiErrorHandler.handleResponse<List<Article>>(
            response: response,
            onSuccess: (jsonData) {
              final List<dynamic> jsonList = jsonData;
              final articles = jsonList.map((json) => Article.fromJson(json)).toList();
              
              // Cache articles in background
              _cacheArticlesInBackground(articles);
              
              return articles;
            },
            customErrorMessage: 'Failed to load articles',
          );
        },
        connectivityProvider: connectivityProvider,
        offlineErrorMessage: 'You are offline. Articles cannot be loaded.',
      );
    } catch (e) {
      // Record error timing
      _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
      
      // Try to get cached results if available
      try {
        final cachedArticles = await _cacheService.getCachedArticles(page, limit);
        if (cachedArticles != null && cachedArticles.isNotEmpty) {
          _incrementCacheHit(operationKey);
          return cachedArticles;
        }
      } catch (cacheError) {
        // Ignore cache errors
      }
      
      // If no cached results, rethrow the original error
      rethrow;
    } finally {
      // Record timing if not already recorded as an error
      if (stopwatch.isRunning) {
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        stopwatch.stop();
      }
    }
  }

  Future<Article> getArticle(
    String id, {
    required ConnectivityProvider connectivityProvider,
  }) async {
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
          if (connectivityProvider.isConnected) {
            _refreshArticleInBackground(id);
          }
          
          return cached;
        }
      } catch (e) {
        // Continue with network request if cache fails
      }
      _incrementCacheMiss(operationKey);
    }
    
    try {
      return await ApiErrorHandler.executeWithRetry<Article>(
        apiCall: () async {
          final response = await _client.get(Uri.parse('$baseUrl/articles/$id'))
              .timeout(_cacheTimeout);
              
          return await ApiErrorHandler.handleResponse<Article>(
            response: response,
            onSuccess: (jsonData) {
              final article = Article.fromJson(jsonData);
              
              // Cache article in background
              _cacheArticleInBackground(article);
              
              return article;
            },
            customErrorMessage: 'Failed to load article',
          );
        },
        connectivityProvider: connectivityProvider,
        offlineErrorMessage: 'You are offline. Article cannot be loaded.',
        maxRetries: 2,
      );
    } catch (e) {
      // Record error timing
      _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
      
      // Try to get from cache if network request failed
      final cached = await _cacheService.getCachedArticle(id);
      if (cached != null) {
        _incrementCacheHit(operationKey);
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
        return cached;
      }
      
      // If no cached article, rethrow the error
      rethrow;
    } finally {
      // Record timing if not already recorded
      if (stopwatch.isRunning) {
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        stopwatch.stop();
      }
    }
  }

  Future<List<SearchResult>> search(
    String query, {
    required ConnectivityProvider connectivityProvider,
  }) async {
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
          
          // Refresh from network in background if connected
          if (connectivityProvider.isConnected) {
            _refreshSearchInBackground(query, false);
          }
          
          return cached;
        }
      } catch (e) {
        // Continue with network request if cache fails
      }
      _incrementCacheMiss(operationKey);
    }

    try {
      return await ApiErrorHandler.execute<List<SearchResult>>(
        apiCall: () async {
          final response = await _client.get(
            Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}'),
          ).timeout(_cacheTimeout);
          
          return await ApiErrorHandler.handleResponse<List<SearchResult>>(
            response: response,
            onSuccess: (jsonData) {
              final List<dynamic> jsonList = jsonData;
              final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
              
              // Cache results in background
              _cacheSearchResultsInBackground(query, results, false);
              
              return results;
            },
            customErrorMessage: 'Failed to perform search',
          );
        },
        connectivityProvider: connectivityProvider,
        offlineErrorMessage: 'You are offline. Search cannot be performed.',
      );
    } catch (e) {
      // Record error timing
      _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
      
      // Try to get from cache if network request failed
      final cached = await _cacheService.getCachedSearchResults(query, false);
      if (cached != null) {
        _incrementCacheHit(operationKey);
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
        return cached;
      }
      
      // If no cached results, rethrow
      rethrow;
    } finally {
      // Record timing if not already recorded
      if (stopwatch.isRunning) {
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        stopwatch.stop();
      }
    }
  }

  Future<List<SearchResult>> semanticSearch(
    String query, {
    required ConnectivityProvider connectivityProvider,
  }) async {
    if (query.isEmpty) {
      return [];
    }
    
    final operationKey = 'semantic_search_${query.hashCode}';
    final stopwatch = Stopwatch()..start();
    
    // Try cache first if prioritizing cache
    if (_prioritizeCache) {
      try {
        final cached = await _cacheService.getCachedSearchResults(query, true);
        if (cached != null) {
          _incrementCacheHit(operationKey);
          _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
          
          // Refresh from network in background if connected
          if (connectivityProvider.isConnected) {
            _refreshSearchInBackground(query, true);
          }
          
          return cached;
        }
      } catch (e) {
        // Continue with network request if cache fails
      }
      _incrementCacheMiss(operationKey);
    }

    try {
      return await ApiErrorHandler.execute<List<SearchResult>>(
        apiCall: () async {
          final response = await _client.get(
            Uri.parse('$baseUrl/semantic-search?q=${Uri.encodeComponent(query)}'),
          ).timeout(_cacheTimeout);
          
          return await ApiErrorHandler.handleResponse<List<SearchResult>>(
            response: response,
            onSuccess: (jsonData) {
              final List<dynamic> jsonList = jsonData;
              final results = jsonList.map((json) => SearchResult.fromJson(json)).toList();
              
              // Cache results in background
              _cacheSearchResultsInBackground(query, results, true);
              
              return results;
            },
            customErrorMessage: 'Failed to perform semantic search',
          );
        },
        connectivityProvider: connectivityProvider,
        offlineErrorMessage: 'You are offline. Semantic search cannot be performed.',
      );
    } catch (e) {
      // Record error timing
      _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isError: true);
      
      // Try to get from cache if network request failed
      final cached = await _cacheService.getCachedSearchResults(query, true);
      if (cached != null) {
        _incrementCacheHit(operationKey);
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds, isCache: true);
        return cached;
      }
      
      // If no cached results, rethrow
      rethrow;
    } finally {
      // Record timing if not already recorded
      if (stopwatch.isRunning) {
        _recordTiming(operationKey, stopwatch.elapsedMilliseconds);
        stopwatch.stop();
      }
    }
  }
  
  // Background operations to avoid blocking UI
  Future<void> _cacheArticleInBackground(Article article) async {
    Timer(Duration.zero, () async {
      try {
        await _cacheService.cacheArticle(article);
      } catch (e) {
        ApiErrorHandler.logError('Error caching article in background: $e');
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
        ApiErrorHandler.logError('Error caching articles in background: $e');
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
        ApiErrorHandler.logError('Error caching search results in background: $e');
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
        // Silently log errors in background refresh
        ApiErrorHandler.logError('Background article refresh failed: $e', showToast: false);
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
        // Silently log errors in background refresh
        ApiErrorHandler.logError('Background search refresh failed: $e', showToast: false);
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