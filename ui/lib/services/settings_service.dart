import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsService {
  static const String _settingsKey = 'settings';
  late SharedPreferences _prefs;
  Settings _settings = const Settings();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    final String? settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        _settings = Settings.fromJson(json.decode(settingsJson));
      } catch (e) {
        print('Error loading settings: $e');
        _settings = const Settings();
      }
    }
  }

  Future<void> saveSettings(Settings settings) async {
    _settings = settings;
    await _prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  Settings get settings => _settings;

  Future<void> updateOllamaUrl(String url) async {
    await saveSettings(_settings.copyWith(ollamaUrl: url));
  }

  Future<void> updateMaxImageSize(int size) async {
    await saveSettings(_settings.copyWith(maxImageSize: size));
  }

  Future<void> updateMaxBatchSize(int size) async {
    await saveSettings(_settings.copyWith(maxBatchSize: size));
  }

  Future<void> updateDarkMode(bool enabled) async {
    await saveSettings(_settings.copyWith(darkMode: enabled));
  }

  Future<void> updateFontSize(int size) async {
    await saveSettings(_settings.copyWith(fontSize: size));
  }

  Future<void> updateLanguage(String language) async {
    await saveSettings(_settings.copyWith(language: language));
  }

  Future<void> updateShowImages(bool show) async {
    await saveSettings(_settings.copyWith(showImages: show));
  }

  Future<void> updateShowRelatedArticles(bool show) async {
    await saveSettings(_settings.copyWith(showRelatedArticles: show));
  }

  Future<void> updateShowCategories(bool show) async {
    await saveSettings(_settings.copyWith(showCategories: show));
  }
} 