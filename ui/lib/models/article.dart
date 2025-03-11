import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class Article {
  final String id;
  final String title;
  final String content;
  final DateTime lastModified;
  final List<String> categories;
  final List<String>? relatedArticles;
  final String? summary;

  const Article({
    required this.id,
    required this.title,
    required this.content,
    required this.lastModified,
    required this.categories,
    this.relatedArticles,
    this.summary,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      lastModified: DateTime.parse(json['last_modified'] as String),
      categories: (json['categories'] as List<dynamic>).cast<String>(),
      relatedArticles: json['related_articles'] != null
          ? (json['related_articles'] as List<dynamic>).cast<String>()
          : null,
      summary: json['summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'last_modified': lastModified.toIso8601String(),
      'categories': categories,
      if (relatedArticles != null) 'related_articles': relatedArticles,
      if (summary != null) 'summary': summary,
    };
  }

  @override
  String toString() {
    return 'Article{id: $id, title: $title, categories: $categories, lastModified: $lastModified}';
  }
} 