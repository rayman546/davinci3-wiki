import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki_ui/pages/search_page.dart';
import 'package:davinci3_wiki_ui/models/search_result.dart';
import 'package:davinci3_wiki_ui/services/wiki_service.dart';
import 'package:davinci3_wiki_ui/services/search_history_service.dart';
import 'package:davinci3_wiki_ui/providers/connectivity_provider.dart';
import 'package:davinci3_wiki_ui/services/connectivity_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([WikiService, SearchHistoryService, ConnectivityService])
import 'search_page_test.mocks.dart';

void main() {
  late MockWikiService mockWikiService;
  late MockSearchHistoryService mockSearchHistoryService;
  late MockConnectivityService mockConnectivityService;
  late ConnectivityProvider connectivityProvider;

  setUp(() {
    mockWikiService = MockWikiService();
    mockSearchHistoryService = MockSearchHistoryService();
    mockConnectivityService = MockConnectivityService();
    connectivityProvider = ConnectivityProvider(mockConnectivityService);
    
    // Set up default behavior for mocks
    when(mockConnectivityService.isConnected).thenReturn(true);
    when(mockSearchHistoryService.getSearchHistory()).thenReturn([]);
  });

  // Helper function to create test search results
  List<SearchResult> createTestSearchResults(int count, {String prefix = ''}) {
    return List.generate(
      count,
      (index) => SearchResult(
        id: 'result_$index',
        title: '${prefix}Result $index',
        snippet: 'This is a snippet for result $index',
        score: index % 2 == 0 ? 0.9 - (index * 0.1) : null,
      ),
    );
  }

  Widget createSearchPageWithMocks() {
    return MultiProvider(
      providers: [
        Provider<WikiService>.value(value: mockWikiService),
        Provider<SearchHistoryService>.value(value: mockSearchHistoryService),
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SearchPage(),
        ),
      ),
    );
  }

  testWidgets('SearchPage should display initial empty state', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createSearchPageWithMocks());
    
    // Verify that the search field is displayed
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Type something to search'), findsOneWidget);
    
    // Verify that the toggle buttons for search type are displayed
    expect(find.byType(ToggleButtons), findsOneWidget);
    expect(find.byIcon(Icons.text_fields), findsOneWidget); // Regular search
    expect(find.byIcon(Icons.psychology), findsOneWidget); // Semantic search
  });

  testWidgets('SearchPage should perform search when text is entered', 
      (WidgetTester tester) async {
    // Set up the mock to return test results
    final testResults = createTestSearchResults(5);
    when(mockWikiService.search('test query'))
        .thenAnswer((_) async => testResults);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSearchPageWithMocks());
    
    // Enter text in the search field
    await tester.enterText(find.byType(TextField), 'test query');
    
    // Wait for debounce timer
    await tester.pump(const Duration(milliseconds: 600));
    
    // Verify that the search was performed
    verify(mockWikiService.search('test query')).called(1);
    
    // Wait for the results to load
    await tester.pumpAndSettle();
    
    // Verify that the results are displayed
    for (var i = 0; i < 5; i++) {
      expect(find.text('Result $i'), findsOneWidget);
      expect(find.text('This is a snippet for result $i'), findsOneWidget);
    }
  });

  testWidgets('SearchPage should switch between regular and semantic search', 
      (WidgetTester tester) async {
    // Set up the mocks to return different results for different search types
    final regularResults = createTestSearchResults(3, prefix: 'Regular ');
    final semanticResults = createTestSearchResults(3, prefix: 'Semantic ');
    
    when(mockWikiService.search('test query'))
        .thenAnswer((_) async => regularResults);
    when(mockWikiService.semanticSearch('test query'))
        .thenAnswer((_) async => semanticResults);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSearchPageWithMocks());
    
    // Enter text in the search field
    await tester.enterText(find.byType(TextField), 'test query');
    
    // Wait for debounce timer
    await tester.pump(const Duration(milliseconds: 600));
    
    // Verify that regular search was performed
    verify(mockWikiService.search('test query')).called(1);
    
    // Wait for the results to load
    await tester.pumpAndSettle();
    
    // Verify that regular results are displayed
    expect(find.text('Regular Result 0'), findsOneWidget);
    
    // Tap on the semantic search toggle
    await tester.tap(find.byIcon(Icons.psychology));
    await tester.pump();
    
    // Verify that semantic search was performed
    verify(mockWikiService.semanticSearch('test query')).called(1);
    
    // Wait for the results to load
    await tester.pumpAndSettle();
    
    // Verify that semantic results are displayed
    expect(find.text('Semantic Result 0'), findsOneWidget);
    expect(find.text('Regular Result 0'), findsNothing);
  });

  testWidgets('SearchPage should display and use search history', 
      (WidgetTester tester) async {
    // Set up the mock to return search history
    final searchHistory = ['previous query 1', 'previous query 2'];
    when(mockSearchHistoryService.getSearchHistory())
        .thenReturn(searchHistory);
    
    // Set up the mock to return test results
    final testResults = createTestSearchResults(3);
    when(mockWikiService.search('previous query 1'))
        .thenAnswer((_) async => testResults);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSearchPageWithMocks());
    
    // Tap on the search field and then clear it to show history
    await tester.tap(find.byType(TextField));
    await tester.pump();
    
    // Verify that search history is displayed
    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('previous query 1'), findsOneWidget);
    expect(find.text('previous query 2'), findsOneWidget);
    
    // Tap on a history item
    await tester.tap(find.text('previous query 1'));
    await tester.pump();
    
    // Verify that the search was performed with the history item
    verify(mockWikiService.search('previous query 1')).called(1);
    
    // Wait for the results to load
    await tester.pumpAndSettle();
    
    // Verify that the results are displayed
    expect(find.text('Result 0'), findsOneWidget);
  });

  testWidgets('SearchPage should handle search errors', 
      (WidgetTester tester) async {
    // Set up the mock to throw an error
    when(mockWikiService.search('error query'))
        .thenThrow(Exception('Search failed'));
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSearchPageWithMocks());
    
    // Enter text in the search field
    await tester.enterText(find.byType(TextField), 'error query');
    
    // Wait for debounce timer
    await tester.pump(const Duration(milliseconds: 600));
    
    // Wait for the error to be displayed
    await tester.pumpAndSettle();
    
    // Verify that the error message is displayed
    expect(find.text('Error: Exception: Search failed'), findsOneWidget);
  });

  testWidgets('SearchPage should handle offline mode', 
      (WidgetTester tester) async {
    // Set up the mock to return disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createSearchPageWithMocks());
    
    // Verify that the search field is disabled
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
    
    // Verify that the offline message is displayed
    expect(find.text('Search disabled while offline'), findsOneWidget);
    
    // Enter text in the search field (should not work, but we try anyway)
    await tester.enterText(find.byType(TextField), 'test query');
    
    // Wait for debounce timer
    await tester.pump(const Duration(milliseconds: 600));
    
    // Verify that no search was performed
    verifyNever(mockWikiService.search(any));
    
    // Verify that the offline message is displayed
    expect(find.text('You\'re offline'), findsOneWidget);
    expect(find.text('Search requires an internet connection'), findsOneWidget);
  });
} 