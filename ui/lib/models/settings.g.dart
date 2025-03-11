// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SettingsImpl _$$SettingsImplFromJson(Map<String, dynamic> json) =>
    _$SettingsImpl(
      ollamaUrl: json['ollamaUrl'] as String? ?? 'http://localhost:11434',
      maxImageSize: (json['maxImageSize'] as num?)?.toInt() ?? 10 * 1024 * 1024,
      maxBatchSize: (json['maxBatchSize'] as num?)?.toInt() ?? 32,
      darkMode: json['darkMode'] as bool? ?? true,
      fontSize: (json['fontSize'] as num?)?.toInt() ?? 16,
      language: json['language'] as String? ?? 'en',
      showImages: json['showImages'] as bool? ?? true,
      showRelatedArticles: json['showRelatedArticles'] as bool? ?? true,
      showCategories: json['showCategories'] as bool? ?? true,
    );

Map<String, dynamic> _$$SettingsImplToJson(_$SettingsImpl instance) =>
    <String, dynamic>{
      'ollamaUrl': instance.ollamaUrl,
      'maxImageSize': instance.maxImageSize,
      'maxBatchSize': instance.maxBatchSize,
      'darkMode': instance.darkMode,
      'fontSize': instance.fontSize,
      'language': instance.language,
      'showImages': instance.showImages,
      'showRelatedArticles': instance.showRelatedArticles,
      'showCategories': instance.showCategories,
    };
