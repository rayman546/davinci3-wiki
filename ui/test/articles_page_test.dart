import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki_ui/pages/articles_page.dart';
import 'package:davinci3_wiki_ui/models/article.dart';
import 'package:davinci3_wiki_ui/services/wiki_service.dart';
import 'package:davinci3_wiki_ui/providers/connectivity_provider.dart';
import 'package:davinci3_wiki_ui/services/connectivity_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([WikiService, ConnectivityService])
import 'articles_page_test.mocks.dart';

void main() {
  late MockWikiService mockWikiService;
  late MockConnectivityService mockConnectivityService;
  late ConnectivityProvider connectivityProvider;

  setUp(() {
    mockWikiService = MockWikiService();
    mockConnectivityService = MockConnectivityService();
    connectivityProvider = ConnectivityProvider(mockConnectivityService);
    
    // Set up default behavior for mocks
    when(mockConnectivityService.isConnected).thenReturn(true);
  });

  // Helper function to create test articles
  List<Article> createTestArticles(int count) {
    return List.generate(
      count,
      (index) => Article(
        id: 'article_$index',
        title: 'Article $index',
        content: 'Content for article $index',
        lastModified: DateTime.now().subtract(Duration(days: index)),
        categories: ['Category ${index % 3}'],
        summary: 'Summary for article $index',
      ),
    );
  }

  Widget createArticlesPageWithMocks() {
    return MultiProvider(
      providers: [
        Provider<WikiService>.value(value: mockWikiService),
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ArticlesPage(),
        ),
      ),
    );
  }

  testWidgets('ArticlesPage should display loading indicator initially', 
      (WidgetTester tester) async {
    // Set up the mock to return a delayed response
    when(mockWikiService.getArticles(page: 1, limit: 20))
        .thenAnswer((_) async {
      await Future.delayed(Duration(milliseconds: 500));
      return createTestArticles(20);
    });
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticlesPageWithMocks());
    
    // Verify that a loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Wait for the articles to load
    await tester.pump(Duration(milliseconds: 600));
    
    // Verify that the loading indicator is gone
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ArticlesPage should display articles when loaded', 
      (WidgetTester tester) async {
    // Set up the mock to return test articles
    final testArticles = createTestArticles(20);
    when(mockWikiService.getArticles(page: 1, limit: 20))
        .thenAnswer((_) async => testArticles);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticlesPageWithMocks());
    
    // Wait for the articles to load
    await tester.pumpAndSettle();
    
    // Verify that the articles are displayed
    for (var i = 0; i < 5; i++) { // Check first 5 articles
      expect(find.text('Article $i'), findsOneWidget);
      expect(find.text('Summary for article $i'), findsOneWidget);
    }
  });

  testWidgets('ArticlesPage should display error message when loading fails', 
      (WidgetTester tester) async {
    // Set up the mock to throw an error
    when(mockWikiService.getArticles(page: 1, limit: 20))
        .thenThrow(Exception('Failed to load articles'));
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticlesPageWithMocks());
    
    // Wait for the error to be displayed
    await tester.pumpAndSettle();
    
    // Verify that the error message is displayed
    expect(find.text('Error: Exception: Failed to load articles'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('ArticlesPage should load more articles when scrolled to bottom', 
      (WidgetTester tester) async {
    // Set up the mock to return test articles for first and second page
    final firstPageArticles = createTestArticles(20);
    final secondPageArticles = createTestArticles(20).map((article) {
      return Article(
        id: 'article_2_${article.id}',
        title: 'Second Page ${article.title}',
        content: article.content,
        lastModified: article.lastModified,
        categories: article.categories,
        summary: article.summary,
      );
    }).toList();
    
    when(mockWikiService.getArticles(page: 1, limit: 20))
        .thenAnswer((_) async => firstPageArticles);
    when(mockWikiService.getArticles(page: 2, limit: 20))
        .thenAnswer((_) async => secondPageArticles);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticlesPageWithMocks());
    
    // Wait for the first page of articles to load
    await tester.pumpAndSettle();
    
    // Verify that the first page articles are displayed
    expect(find.text('Article 0'), findsOneWidget);
    
    // Scroll to the bottom to trigger loading more articles
    await tester.dragUntilVisible(
      find.byType(CircularProgressIndicator),
      find.byType(ListView),
      const Offset(0, 500),
    );
    
    // Wait for the second page to load
    await tester.pumpAndSettle();
    
    // Verify that the second page articles are displayed
    expect(find.text('Second Page Article 0'), findsOneWidget);
  });

  testWidgets('ArticlesPage should disable refresh when offline', 
      (WidgetTester tester) async {
    // Set up the mock to return test articles
    final testArticles = createTestArticles(20);
    when(mockWikiService.getArticles(page: 1, limit: 20))
        .thenAnswer((_) async => testArticles);
    
    // Build our app and trigger a frame with connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pumpWidget(createArticlesPageWithMocks());
    await tester.pumpAndSettle();
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Try to refresh by pulling down
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    
    // Verify that the refresh didn't trigger a new API call
    verify(mockWikiService.getArticles(page: 1, limit: 20)).called(1); // Only the initial call
  });
} 