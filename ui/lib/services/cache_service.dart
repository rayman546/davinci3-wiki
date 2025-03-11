import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/article.dart';
import '../models/search_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _dbName = 'wiki_cache.db';
  static Database? _db;
  static const _articlesTable = 'articles';
  static const _accessLogTable = 'access_log';
  static const _cacheStatsTable = 'cache_stats';
  
  // Cache configuration
  static const int _maxCacheSize = 100; // Maximum number of articles to cache
  static const int _maxCacheSizeMB = 50; // Maximum cache size in MB
  static const Duration _defaultMaxAge = Duration(days: 14); // Default max age for cached items
  
  // Cache statistics
  int _cachedArticleCount = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  double _cacheHitRate = 0.0;

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, int> _accessCounts = {};
  final Map<String, DateTime> _lastAccessed = {};
  final int _maxCacheSize;
  final Duration _cacheTTL;
  
  CacheService({
    int maxCacheSize = 100, // Default max cache size in MB
    Duration? cacheTTL, // Default TTL for cache items
  }) : _maxCacheSize = maxCacheSize,
       _cacheTTL = cacheTTL ?? const Duration(hours: 24);
  
  Future<void> init() async {
    if (_db != null) return;

    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = path.join(dbPath, _dbName);

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2, // Increased version for schema changes
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    
    // Get initial article count
    _cachedArticleCount = await _getArticleCount();
    
    // Load cache statistics
    await _loadCacheStats();
    
    // Run cleanup to ensure we're within limits
    await _enforceRetentionPolicy();
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Create articles table
    await db.execute('''
      CREATE TABLE $_articlesTable (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        access_count INTEGER DEFAULT 0,
        last_accessed INTEGER
      )
    ''');

    // Create search results table
    await db.execute('''
      CREATE TABLE search_results (
        query TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_semantic INTEGER NOT NULL,
        access_count INTEGER DEFAULT 0,
        last_accessed INTEGER
      )
    ''');
    
    // Create access log table for analytics
    await db.execute('''
      CREATE TABLE $_accessLogTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        article_id TEXT,
        search_query TEXT,
        timestamp INTEGER NOT NULL,
        is_hit INTEGER NOT NULL
      )
    ''');
    
    // Create cache stats table
    await db.execute('''
      CREATE TABLE $_cacheStatsTable (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        hits INTEGER DEFAULT 0,
        misses INTEGER DEFAULT 0,
        last_cleanup INTEGER
      )
    ''');
    
    // Insert initial stats record
    await db.insert(
      _cacheStatsTable,
      {
        'id': 1,
        'hits': 0,
        'misses': 0,
        'last_cleanup': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to articles table
      await db.execute('ALTER TABLE $_articlesTable ADD COLUMN access_count INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $_articlesTable ADD COLUMN last_accessed INTEGER');
      
      // Add new columns to search_results table
      await db.execute('ALTER TABLE search_results ADD COLUMN access_count INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE search_results ADD COLUMN last_accessed INTEGER');
      
      // Create access log table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_accessLogTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          article_id TEXT,
          search_query TEXT,
          timestamp INTEGER NOT NULL,
          is_hit INTEGER NOT NULL
        )
      ''');
      
      // Create cache stats table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_cacheStatsTable (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          hits INTEGER DEFAULT 0,
          misses INTEGER DEFAULT 0,
          last_cleanup INTEGER
        )
      ''');
      
      // Insert initial stats record if not exists
      await db.insert(
        _cacheStatsTable,
        {
          'id': 1,
          'hits': 0,
          'misses': 0,
          'last_cleanup': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<int> _getArticleCount() async {
    if (_db == null) return 0;
    
    try {
      final result = await _db!.rawQuery('SELECT COUNT(*) FROM $_articlesTable');
      return result.isNotEmpty ? result.first.values.first as int : 0;
    } catch (e) {
      print('Error getting article count: $e');
      return 0;
    }
  }
  
  Future<void> _loadCacheStats() async {
    if (_db == null) return;
    
    try {
      final result = await _db!.query(_cacheStatsTable, where: 'id = 1');
      if (result.isNotEmpty) {
        _cacheHits = result.first['hits'] as int;
        _cacheMisses = result.first['misses'] as int;
        
        // Calculate hit rate
        final totalAccesses = _cacheHits + _cacheMisses;
        _cacheHitRate = totalAccesses > 0 ? _cacheHits / totalAccesses : 0.0;
      }
    } catch (e) {
      print('Error loading cache stats: $e');
    }
  }

  Future<void> cacheArticle(Article article) async {
    if (_db == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await _db!.insert(
      _articlesTable,
      {
        'id': article.id,
        'data': json.encode(article.toJson()),
        'timestamp': now,
        'access_count': 1, // Initialize with 1 access
        'last_accessed': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    _cachedArticleCount = await _getArticleCount();
    
    // Enforce retention policy after adding new article
    await _enforceRetentionPolicy();
  }

  Future<Article?> getCachedArticle(String id) async {
    if (_db == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    try {
      final result = await _db!.query(
        _articlesTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (result.isEmpty) {
        // Cache miss
        await _recordCacheMiss(articleId: id);
        return null;
      }

      // Cache hit - update access statistics
      await _db!.update(
        _articlesTable,
        {
          'access_count': (result.first['access_count'] as int) + 1,
          'last_accessed': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      await _recordCacheHit(articleId: id);
      
      return Article.fromJson(json.decode(result.first['data'] as String));
    } catch (e) {
      print('Error retrieving article from cache: $e');
      return null;
    }
  }

  Future<void> cacheSearchResults(
    String query,
    List<SearchResult> results,
    bool isSemantic,
  ) async {
    if (_db == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await _db!.insert(
      'search_results',
      {
        'query': query,
        'data': json.encode(results.map((r) => r.toJson()).toList()),
        'timestamp': now,
        'is_semantic': isSemantic ? 1 : 0,
        'access_count': 1,
        'last_accessed': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SearchResult>?> getCachedSearchResults(
    String query,
    bool isSemantic,
  ) async {
    if (_db == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    try {
      final result = await _db!.query(
        'search_results',
        where: 'query = ? AND is_semantic = ?',
        whereArgs: [query, isSemantic ? 1 : 0],
        limit: 1,
      );

      if (result.isEmpty) {
        // Cache miss
        await _recordCacheMiss(searchQuery: query);
        return null;
      }

      // Cache hit - update access statistics
      await _db!.update(
        'search_results',
        {
          'access_count': (result.first['access_count'] as int) + 1,
          'last_accessed': now,
        },
        where: 'query = ? AND is_semantic = ?',
        whereArgs: [query, isSemantic ? 1 : 0],
      );
      
      await _recordCacheHit(searchQuery: query);
      
      final List<dynamic> data = json.decode(result.first['data'] as String);
      return data.map((json) => SearchResult.fromJson(json)).toList();
    } catch (e) {
      print('Error retrieving search results from cache: $e');
      return null;
    }
  }
  
  Future<void> _recordCacheHit({String? articleId, String? searchQuery}) async {
    if (_db == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Record in access log
    await _db!.insert(
      _accessLogTable,
      {
        'article_id': articleId,
        'search_query': searchQuery,
        'timestamp': now,
        'is_hit': 1,
      },
    );
    
    // Update stats
    await _db!.rawUpdate(
      'UPDATE $_cacheStatsTable SET hits = hits + 1 WHERE id = 1'
    );
    
    // Update in-memory stats
    _cacheHits++;
    _updateHitRate();
  }
  
  Future<void> _recordCacheMiss({String? articleId, String? searchQuery}) async {
    if (_db == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Record in access log
    await _db!.insert(
      _accessLogTable,
      {
        'article_id': articleId,
        'search_query': searchQuery,
        'timestamp': now,
        'is_hit': 0,
      },
    );
    
    // Update stats
    await _db!.rawUpdate(
      'UPDATE $_cacheStatsTable SET misses = misses + 1 WHERE id = 1'
    );
    
    // Update in-memory stats
    _cacheMisses++;
    _updateHitRate();
  }
  
  void _updateHitRate() {
    final totalAccesses = _cacheHits + _cacheMisses;
    _cacheHitRate = totalAccesses > 0 ? _cacheHits / totalAccesses : 0.0;
  }

  Future<void> clearCache() async {
    if (_db == null) return;
    
    await _db!.delete(_articlesTable);
    await _db!.delete('search_results');
    
    // Reset stats
    await _db!.update(
      _cacheStatsTable,
      {
        'hits': 0,
        'misses': 0,
        'last_cleanup': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = 1',
    );
    
    // Clear access log
    await _db!.delete(_accessLogTable);
    
    // Reset in-memory stats
    _cachedArticleCount = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _cacheHitRate = 0.0;
  }

  Future<void> clearOldCache({Duration? maxAge}) async {
    if (_db == null) return;
    
    final age = maxAge ?? _defaultMaxAge;
    final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;

    await _db!.delete(
      _articlesTable,
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );

    await _db!.delete(
      'search_results',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
    
    // Update article count
    _cachedArticleCount = await _getArticleCount();
    
    // Update last cleanup time
    await _db!.update(
      _cacheStatsTable,
      {'last_cleanup': DateTime.now().millisecondsSinceEpoch},
      where: 'id = 1',
    );
  }
  
  /// Enforce cache retention policy based on size limits and access patterns
  Future<void> _enforceRetentionPolicy() async {
    if (_db == null) return;
    
    try {
      // Check if we're over the article count limit
      if (_cachedArticleCount > _maxCacheSize) {
        // Remove least recently accessed articles
        await _db!.execute('''
          DELETE FROM $_articlesTable 
          WHERE id IN (
            SELECT id FROM $_articlesTable 
            ORDER BY last_accessed ASC, access_count ASC 
            LIMIT ${_cachedArticleCount - _maxCacheSize}
          )
        ''');
      }
      
      // Check if we're over the size limit in MB
      if (getCacheSize() > _maxCacheSizeMB) {
        // Calculate how many articles to remove
        final excessMB = getCacheSize() - _maxCacheSizeMB;
        final articlesToRemove = (excessMB * 1024 / 15).ceil(); // 15KB per article
        
        // Remove least recently accessed articles
        await _db!.execute('''
          DELETE FROM $_articlesTable 
          WHERE id IN (
            SELECT id FROM $_articlesTable 
            ORDER BY last_accessed ASC, access_count ASC 
            LIMIT $articlesToRemove
          )
        ''');
      }
      
      // Update article count after cleanup
      _cachedArticleCount = await _getArticleCount();
      
      // Update last cleanup time
      await _db!.update(
        _cacheStatsTable,
        {'last_cleanup': DateTime.now().millisecondsSinceEpoch},
        where: 'id = 1',
      );
    } catch (e) {
      print('Error enforcing cache retention policy: $e');
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'articleCount': _cachedArticleCount,
      'sizeInMB': getCacheSize(),
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': _cacheHitRate,
    };
  }
  
  /// Get the most frequently accessed articles
  Future<List<Article>> getMostAccessedArticles({int limit = 10}) async {
    if (_db == null) return [];
    
    try {
      final result = await _db!.query(
        _articlesTable,
        orderBy: 'access_count DESC, last_accessed DESC',
        limit: limit,
      );
      
      return result.map((row) {
        return Article.fromJson(json.decode(row['data'] as String));
      }).toList();
    } catch (e) {
      print('Error getting most accessed articles: $e');
      return [];
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Get the current cache size in MB
  /// This is an estimate based on the number of cached articles
  /// and an assumed average article size of 15KB
  double getCacheSize() {
    // Assume average article is 15KB
    const averageArticleSizeKB = 15.0;
    // Convert to MB (KB / 1024)
    return (_cachedArticleCount * averageArticleSizeKB) / 1024;
  }

  /// Get an item from the cache
  Future<dynamic> get(String key) async {
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      final lastAccessed = _lastAccessed[key];
      if (lastAccessed != null && 
          DateTime.now().difference(lastAccessed) > _cacheTTL) {
        // Cache item has expired
        _memoryCache.remove(key);
        _lastAccessed.remove(key);
        _cacheMisses++;
        return null;
      }
      
      // Update access statistics
      _cacheHits++;
      _accessCounts[key] = (_accessCounts[key] ?? 0) + 1;
      _lastAccessed[key] = DateTime.now();
      
      return _memoryCache[key];
    }
    
    // Check disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(key);
      
      if (jsonData != null) {
        // Load from disk to memory
        final data = json.decode(jsonData);
        
        // Check if the item has metadata with timestamp
        if (data is Map && data.containsKey('timestamp') && data.containsKey('data')) {
          final timestamp = DateTime.parse(data['timestamp']);
          if (DateTime.now().difference(timestamp) > _cacheTTL) {
            // Cache item has expired
            prefs.remove(key);
            _cacheMisses++;
            return null;
          }
          
          // Store in memory cache
          _memoryCache[key] = data['data'];
          _lastAccessed[key] = DateTime.now();
          _accessCounts[key] = (_accessCounts[key] ?? 0) + 1;
          _cacheHits++;
          
          // Update cache size estimate
          _updateCacheSize();
          
          return data['data'];
        } else {
          // Legacy format without timestamp
          _memoryCache[key] = data;
          _lastAccessed[key] = DateTime.now();
          _accessCounts[key] = (_accessCounts[key] ?? 0) + 1;
          _cacheHits++;
          
          // Update cache size estimate
          _updateCacheSize();
          
          return data;
        }
      }
    } catch (e) {
      print('Error reading from disk cache: $e');
    }
    
    _cacheMisses++;
    return null;
  }
  
  /// Put an item in the cache
  Future<void> put(String key, dynamic value) async {
    // Check if we need to evict items
    await _evictIfNeeded();
    
    // Store in memory cache
    _memoryCache[key] = value;
    _lastAccessed[key] = DateTime.now();
    
    // Initialize access count if not exists
    if (!_accessCounts.containsKey(key)) {
      _accessCounts[key] = 0;
    }
    
    // Store on disk with timestamp
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': value,
      };
      await prefs.setString(key, json.encode(data));
      
      // Update cache size estimate
      _updateCacheSize();
    } catch (e) {
      print('Error writing to disk cache: $e');
    }
  }
  
  /// Remove an item from the cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _lastAccessed.remove(key);
    _accessCounts.remove(key);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      
      // Update cache size estimate
      _updateCacheSize();
    } catch (e) {
      print('Error removing from disk cache: $e');
    }
  }
  
  /// Clear the entire cache
  Future<void> clear() async {
    _memoryCache.clear();
    _lastAccessed.clear();
    _accessCounts.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Update cache size estimate
      _cacheSize = 0.0;
    } catch (e) {
      print('Error clearing disk cache: $e');
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRatio': _cacheHits + _cacheMisses > 0 
          ? _cacheHits / (_cacheHits + _cacheMisses) 
          : 0.0,
      'size': _cacheSize,
      'itemCount': _memoryCache.length,
      'oldestItem': _lastAccessed.isEmpty 
          ? null 
          : _lastAccessed.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key,
      'newestItem': _lastAccessed.isEmpty 
          ? null 
          : _lastAccessed.entries
              .reduce((a, b) => a.value.isAfter(b.value) ? a : b)
              .key,
    };
  }
  
  /// Get the current cache size in MB
  double getCacheSize() {
    return _cacheSize;
  }
  
  /// Get access counts for all cached items
  Map<String, int> getAccessCounts() {
    return Map<String, int>.from(_accessCounts);
  }
  
  /// Update the cache size estimate
  Future<void> _updateCacheSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final prefs = await SharedPreferences.getInstance();
      
      // Estimate size based on keys in SharedPreferences
      double totalSize = 0.0;
      for (final key in prefs.getKeys()) {
        final value = prefs.getString(key);
        if (value != null) {
          // Estimate size in MB (rough approximation)
          totalSize += value.length / (1024 * 1024);
        }
      }
      
      _cacheSize = totalSize;
    } catch (e) {
      print('Error calculating cache size: $e');
    }
  }
  
  /// Evict items if cache is too large
  Future<void> _evictIfNeeded() async {
    if (_cacheSize < _maxCacheSize) {
      return;
    }
    
    // Sort items by last accessed time (oldest first)
    final sortedItems = _lastAccessed.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    // Remove oldest items until we're under the limit
    for (final entry in sortedItems) {
      if (_cacheSize < _maxCacheSize * 0.8) {
        // Stop when we've reduced to 80% of max
        break;
      }
      
      final key = entry.key;
      await remove(key);
    }
  }
} 