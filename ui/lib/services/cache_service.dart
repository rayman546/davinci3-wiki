import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/article.dart';
import '../models/search_result.dart';

class CacheService {
  static const String _dbName = 'wiki_cache.db';
  static Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE articles (
              id TEXT PRIMARY KEY,
              data TEXT NOT NULL,
              timestamp INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE search_results (
              query TEXT PRIMARY KEY,
              data TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              is_semantic INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<void> cacheArticle(Article article) async {
    await _db?.insert(
      'articles',
      {
        'id': article.id,
        'data': json.encode(article.toJson()),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Article?> getCachedArticle(String id) async {
    final result = await _db?.query(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result == null || result.isEmpty) {
      return null;
    }

    return Article.fromJson(json.decode(result.first['data'] as String));
  }

  Future<void> cacheSearchResults(
    String query,
    List<SearchResult> results,
    bool isSemantic,
  ) async {
    await _db?.insert(
      'search_results',
      {
        'query': query,
        'data': json.encode(results.map((r) => r.toJson()).toList()),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'is_semantic': isSemantic ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SearchResult>?> getCachedSearchResults(
    String query,
    bool isSemantic,
  ) async {
    final result = await _db?.query(
      'search_results',
      where: 'query = ? AND is_semantic = ?',
      whereArgs: [query, isSemantic ? 1 : 0],
      limit: 1,
    );

    if (result == null || result.isEmpty) {
      return null;
    }

    final List<dynamic> data = json.decode(result.first['data'] as String);
    return data.map((json) => SearchResult.fromJson(json)).toList();
  }

  Future<void> clearCache() async {
    await _db?.delete('articles');
    await _db?.delete('search_results');
  }

  Future<void> clearOldCache({Duration? maxAge}) async {
    final age = maxAge ?? const Duration(days: 7);
    final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;

    await _db?.delete(
      'articles',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );

    await _db?.delete(
      'search_results',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
} 