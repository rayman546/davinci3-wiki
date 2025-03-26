import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../pages/article_details_page.dart';
import '../services/wiki_service.dart';
import '../providers/connectivity_provider.dart';
import '../models/article.dart';
import '../services/cache_service.dart';
import 'dart:async';

class MockWikiService extends Mock implements WikiService {
  @override
  Future<Article> getArticleById(String id) async {
    return super.noSuchMethod(
      Invocation.method(#getArticleById, [id]),
      returnValue: Future.value(Article(
        id: '1',
        title: 'Test Article',
        content: 'Test content',
        lastModified: DateTime.now(),
      )),
      returnValueForMissingStub: Future.value(Article(
        id: '1',
        title: 'Test Article',
        content: 'Test content',
        lastModified: DateTime.now(),
      )),
    );
  }

  @override
  Future<List<Article>> getRelatedArticles(String articleId) async {
    return super.noSuchMethod(
      Invocation.method(#getRelatedArticles, [articleId]),
      returnValue: Future.value([]),
      returnValueForMissingStub: Future.value([]),
    );
  }
}

class MockConnectivityProvider extends Mock implements ConnectivityProvider {
  @override
  bool get isConnected => super.noSuchMethod(
    Invocation.getter(#isConnected),
    returnValue: true,
    returnValueForMissingStub: true,
  );
}

class MockCacheService extends Mock implements CacheService {
  @override
  Future<Article?> getCachedArticle(String id) async {
    return super.noSuchMethod(
      Invocation.method(#getCachedArticle, [id]),
      returnValue: Future.value(null),
      returnValueForMissingStub: Future.value(null),
    );
  }

  @override
  Future<void> cacheArticle(Article article) async {
    return super.noSuchMethod(
      Invocation.method(#cacheArticle, [article]),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }
}

void main() {
  group('ArticleDetailsPage', () {
    late MockWikiService mockWikiService;
    late MockConnectivityProvider mockConnectivityProvider;
    late MockCacheService mockCacheService;

    setUp(() {
      mockWikiService = MockWikiService();
      mockConnectivityProvider = MockConnectivityProvider();
      mockCacheService = MockCacheService();
      
      when(mockConnectivityProvider.isConnected).thenReturn(true);
      when(mockCacheService.getCachedArticle(any)).thenAnswer((_) async => null);
    });

    Widget createTestWidget({required String articleId}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityProvider>.value(value: mockConnectivityProvider),
          Provider<WikiService>.value(value: mockWikiService),
          Provider<CacheService>.value(value: mockCacheService),
        ],
        child: MaterialApp(
          home: ArticleDetailsPage(articleId: articleId),
        ),
      );
    }

    testWidgets('displays article content when loading is successful',
        (WidgetTester tester) async {
      // Mock successful article response
      final article = Article(
        id: '1',
        title: 'Test Article',
        content: 'Test content with some details about the topic.',
        lastModified: DateTime.now(),
      );
      
      when(mockWikiService.getArticleById('1')).thenAnswer((_) async => article);
      when(mockWikiService.getRelatedArticles('1')).thenAnswer((_) async => [
        Article(id: '2', title: 'Related Article 1', content: 'Related content 1', lastModified: DateTime.now()),
        Article(id: '3', title: 'Related Article 2', content: 'Related content 2', lastModified: DateTime.now()),
      ]);

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify article content is displayed
      expect(find.text('Test Article'), findsOneWidget);
      expect(find.text('Test content with some details about the topic.'), findsOneWidget);
      
      // Verify related articles are displayed
      expect(find.text('Related Articles'), findsOneWidget);
      expect(find.text('Related Article 1'), findsOneWidget);
      expect(find.text('Related Article 2'), findsOneWidget);
    });

    testWidgets('displays error message when article loading fails',
        (WidgetTester tester) async {
      // Mock failed article loading
      when(mockWikiService.getArticleById('999'))
          .thenThrow(Exception('Failed to load article'));

      await tester.pumpWidget(createTestWidget(articleId: '999'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify error message is displayed
      expect(find.textContaining('Failed to load article'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      
      // Verify retry button is displayed
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
    });

    testWidgets('retry button loads article again after failure',
        (WidgetTester tester) async {
      // Mock first attempt to fail, then succeed on retry
      final article = Article(
        id: '1',
        title: 'Test Article',
        content: 'Test content',
        lastModified: DateTime.now(),
      );
      
      final completer = Completer<Article>();
      
      when(mockWikiService.getArticleById('1'))
          .thenThrow(Exception('Failed to load article'))
          .thenAnswer((_) async => article);
      
      when(mockWikiService.getRelatedArticles('1'))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify error message is displayed
      expect(find.textContaining('Failed to load article'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pump(); // Start retry
      await tester.pump(const Duration(milliseconds: 300)); // Wait for retry to complete

      // Verify article content is displayed after retry
      expect(find.text('Test Article'), findsOneWidget);
      expect(find.text('Test content'), findsOneWidget);
      expect(find.textContaining('Failed to load article'), findsNothing);
    });

    testWidgets('displays loading indicator while article is loading',
        (WidgetTester tester) async {
      // Mock article loading with delay to show loading
      when(mockWikiService.getArticleById('1'))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return Article(
          id: '1',
          title: 'Test Article',
          content: 'Test content',
          lastModified: DateTime.now(),
        );
      });
      
      when(mockWikiService.getRelatedArticles('1'))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      
      // Verify loading indicator is shown initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the loading
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // Process results
      
      // Verify loading indicator is gone and article is shown
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Test Article'), findsOneWidget);
    });

    testWidgets('displays error for related articles while showing main article content',
        (WidgetTester tester) async {
      // Mock main article to succeed but related articles to fail
      final article = Article(
        id: '1',
        title: 'Test Article',
        content: 'Test content',
        lastModified: DateTime.now(),
      );
      
      when(mockWikiService.getArticleById('1'))
          .thenAnswer((_) async => article);
      
      when(mockWikiService.getRelatedArticles('1'))
          .thenThrow(Exception('Failed to load related articles'));

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify main article content is displayed
      expect(find.text('Test Article'), findsOneWidget);
      expect(find.text('Test content'), findsOneWidget);
      
      // Verify related articles error is displayed
      expect(find.textContaining('Failed to load related articles'), findsOneWidget);
      
      // Verify retry button for related articles is displayed
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });

    testWidgets('shows cached article when offline',
        (WidgetTester tester) async {
      // Set offline mode
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      // Mock cached article
      final cachedArticle = Article(
        id: '1',
        title: 'Cached Article',
        content: 'This is cached content viewed offline',
        lastModified: DateTime.now().subtract(const Duration(days: 1)),
      );
      
      when(mockCacheService.getCachedArticle('1'))
          .thenAnswer((_) async => cachedArticle);

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify cached article is displayed
      expect(find.text('Cached Article'), findsOneWidget);
      expect(find.text('This is cached content viewed offline'), findsOneWidget);
      
      // Verify offline indicator is displayed
      expect(find.textContaining('Offline'), findsOneWidget);
      
      // Verify no network request was made
      verifyNever(mockWikiService.getArticleById(any));
    });

    testWidgets('shows error when offline with no cached article',
        (WidgetTester tester) async {
      // Set offline mode
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      // No cached article
      when(mockCacheService.getCachedArticle('1'))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify offline error is displayed
      expect(find.textContaining('You\'re offline'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      
      // Verify no network request was made
      verifyNever(mockWikiService.getArticleById(any));
    });

    testWidgets('updates article when refresh button is pressed',
        (WidgetTester tester) async {
      // Mock initial article
      final initialArticle = Article(
        id: '1',
        title: 'Initial Article',
        content: 'Initial content',
        lastModified: DateTime.now().subtract(const Duration(days: 1)),
      );
      
      // Mock updated article
      final updatedArticle = Article(
        id: '1',
        title: 'Updated Article',
        content: 'Updated content',
        lastModified: DateTime.now(),
      );
      
      when(mockWikiService.getArticleById('1'))
          .thenAnswer((_) async => initialArticle)
          .thenAnswer((_) async => updatedArticle);
      
      when(mockWikiService.getRelatedArticles('1'))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget(articleId: '1'));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 300)); // Wait for loading to complete

      // Verify initial article is displayed
      expect(find.text('Initial Article'), findsOneWidget);
      expect(find.text('Initial content'), findsOneWidget);
      
      // Find and press refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(); // Start refresh
      await tester.pump(const Duration(milliseconds: 300)); // Wait for refresh to complete
      
      // Verify updated article is displayed
      expect(find.text('Updated Article'), findsOneWidget);
      expect(find.text('Updated content'), findsOneWidget);
    });
  });
} 