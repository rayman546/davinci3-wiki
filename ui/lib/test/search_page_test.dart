import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../pages/search_page.dart';
import '../services/wiki_service.dart';
import '../providers/connectivity_provider.dart';
import '../models/article.dart';
import '../models/search_result.dart';
import '../services/cache_service.dart';

class MockWikiService extends Mock implements WikiService {
  @override
  Future<List<SearchResult>> searchArticles(String query, {bool useSemanticSearch = false}) async {
    return super.noSuchMethod(
      Invocation.method(#searchArticles, [query], {#useSemanticSearch: useSemanticSearch}),
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
  Future<List<String>> getSearchHistory() async {
    return super.noSuchMethod(
      Invocation.method(#getSearchHistory, []),
      returnValue: Future.value([]),
      returnValueForMissingStub: Future.value([]),
    );
  }

  @override
  Future<void> addSearchQuery(String query) async {
    return super.noSuchMethod(
      Invocation.method(#addSearchQuery, [query]),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }
}

void main() {
  group('SearchPage', () {
    late MockWikiService mockWikiService;
    late MockConnectivityProvider mockConnectivityProvider;
    late MockCacheService mockCacheService;

    setUp(() {
      mockWikiService = MockWikiService();
      mockConnectivityProvider = MockConnectivityProvider();
      mockCacheService = MockCacheService();
      
      when(mockConnectivityProvider.isConnected).thenReturn(true);
      when(mockCacheService.getSearchHistory()).thenAnswer((_) async => []);
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityProvider>.value(value: mockConnectivityProvider),
          Provider<WikiService>.value(value: mockWikiService),
          Provider<CacheService>.value(value: mockCacheService),
        ],
        child: MaterialApp(
          home: SearchPage(),
        ),
      );
    }

    testWidgets('displays search results when search is successful',
        (WidgetTester tester) async {
      // Mock successful search response
      final searchResults = [
        SearchResult(id: '1', title: 'Test Article 1', snippet: 'This is a snippet 1'),
        SearchResult(id: '2', title: 'Test Article 2', snippet: 'This is a snippet 2'),
      ];
      
      when(mockWikiService.searchArticles('test', useSemanticSearch: false))
          .thenAnswer((_) async => searchResults);

      await tester.pumpWidget(createTestWidget());

      // Enter search query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(); // Start search
      await tester.pump(const Duration(milliseconds: 300)); // Wait for search to complete

      // Verify search results are displayed
      expect(find.text('Test Article 1'), findsOneWidget);
      expect(find.text('Test Article 2'), findsOneWidget);
      expect(find.text('This is a snippet 1'), findsOneWidget);
      expect(find.text('This is a snippet 2'), findsOneWidget);
    });

    testWidgets('displays error message when search fails',
        (WidgetTester tester) async {
      // Mock failed search
      when(mockWikiService.searchArticles('test', useSemanticSearch: false))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(createTestWidget());

      // Enter search query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(); // Start search
      await tester.pump(const Duration(milliseconds: 300)); // Wait for search to complete

      // Verify error message is displayed
      expect(find.textContaining('Failed to perform search'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Verify retry button is displayed
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
    });

    testWidgets('retry button triggers new search',
        (WidgetTester tester) async {
      // Mock first search to fail, then succeed on retry
      when(mockWikiService.searchArticles('test', useSemanticSearch: false))
          .thenThrow(Exception('Network error'))
          .thenAnswer((_) async => [
                SearchResult(id: '1', title: 'Test Article 1', snippet: 'This is a snippet 1'),
              ]);

      await tester.pumpWidget(createTestWidget());

      // Enter search query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(); // Start search
      await tester.pump(const Duration(milliseconds: 300)); // Wait for search to complete

      // Verify error message is displayed
      expect(find.textContaining('Failed to perform search'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pump(); // Start retry
      await tester.pump(const Duration(milliseconds: 300)); // Wait for retry to complete

      // Verify search results are displayed after retry
      expect(find.text('Test Article 1'), findsOneWidget);
      expect(find.text('This is a snippet 1'), findsOneWidget);
      expect(find.textContaining('Failed to perform search'), findsNothing);
    });

    testWidgets('displays loading indicator while searching',
        (WidgetTester tester) async {
      // Mock search with delay to show loading
      when(mockWikiService.searchArticles('test', useSemanticSearch: false))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return [SearchResult(id: '1', title: 'Test Article 1', snippet: 'This is a snippet')];
      });

      await tester.pumpWidget(createTestWidget());

      // Enter search query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      
      // Pump frame immediately after search starts
      await tester.pump();
      
      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the search
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // Process results
      
      // Verify loading indicator is gone and results are shown
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Test Article 1'), findsOneWidget);
    });

    testWidgets('displays empty message when no search results found',
        (WidgetTester tester) async {
      // Mock empty search results
      when(mockWikiService.searchArticles('nonexistent', useSemanticSearch: false))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());

      // Enter search query
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(); // Start search
      await tester.pump(const Duration(milliseconds: 300)); // Wait for search to complete

      // Verify empty state message is displayed
      expect(find.textContaining('No results found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('disables search when offline',
        (WidgetTester tester) async {
      // Set offline mode
      when(mockConnectivityProvider.isConnected).thenReturn(false);
      
      await tester.pumpWidget(createTestWidget());

      // Verify offline message is displayed
      expect(find.textContaining('You\'re offline'), findsOneWidget);
      
      // Try entering search query
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      
      // Verify no search was performed
      verifyNever(mockWikiService.searchArticles(any, useSemanticSearch: anyNamed('useSemanticSearch')));
      
      // Verify search button is disabled
      final iconButtons = find.byType(IconButton);
      final searchButton = tester.widget<IconButton>(iconButtons.first);
      expect(searchButton.onPressed, isNull);
    });

    testWidgets('performs semantic search when semantic search mode is active',
        (WidgetTester tester) async {
      // Mock semantic search results
      when(mockWikiService.searchArticles('test', useSemanticSearch: true))
          .thenAnswer((_) async => [
                SearchResult(id: '1', title: 'Semantic Result', snippet: 'This is a semantic match'),
              ]);

      await tester.pumpWidget(createTestWidget());

      // Enter search query
      await tester.enterText(find.byType(TextField), 'test');
      
      // Switch to semantic search mode
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Perform search
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 300));

      // Verify semantic search was called
      verify(mockWikiService.searchArticles('test', useSemanticSearch: true)).called(1);
      
      // Verify results are displayed
      expect(find.text('Semantic Result'), findsOneWidget);
      expect(find.text('This is a semantic match'), findsOneWidget);
    });
  });
} 