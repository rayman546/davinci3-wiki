import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_result.freezed.dart';
part 'search_result.g.dart';

class SearchResult {
  final String id;
  final String title;
  final String snippet;
  final double? score;

  const SearchResult({
    required this.id,
    required this.title,
    required this.snippet,
    this.score,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      snippet: json['snippet'] as String,
      score: json['score'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'snippet': snippet,
      if (score != null) 'score': score,
    };
  }

  @override
  String toString() {
    return 'SearchResult{id: $id, title: $title, snippet: $snippet, score: $score}';
  }
} 