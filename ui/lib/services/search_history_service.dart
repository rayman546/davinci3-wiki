import 'dart:convert';
import 'package:shared_preferences.dart';

class SearchHistoryService {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 10;
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<String> getSearchHistory() {
    final String? historyJson = _prefs.getString(_historyKey);
    if (historyJson == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.cast<String>();
    } catch (e) {
      print('Error loading search history: $e');
      return [];
    }
  }

  Future<void> addSearch(String query) async {
    if (query.isEmpty) {
      return;
    }

    final List<String> history = getSearchHistory();
    
    // Remove the query if it already exists
    history.remove(query);
    
    // Add the query to the beginning of the list
    history.insert(0, query);
    
    // Keep only the most recent searches
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await _prefs.setString(_historyKey, json.encode(history));
  }

  Future<void> removeSearch(String query) async {
    final List<String> history = getSearchHistory();
    history.remove(query);
    await _prefs.setString(_historyKey, json.encode(history));
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }
} 