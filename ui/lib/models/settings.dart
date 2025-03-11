import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

@freezed
class Settings with _$Settings {
  const factory Settings({
    @Default('http://localhost:11434') String ollamaUrl,
    @Default(10 * 1024 * 1024) int maxImageSize,
    @Default(32) int maxBatchSize,
    @Default(true) bool darkMode,
    @Default(16) int fontSize,
    @Default('en') String language,
    @Default(true) bool showImages,
    @Default(true) bool showRelatedArticles,
    @Default(true) bool showCategories,
  }) = _Settings;

  factory Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);
} 