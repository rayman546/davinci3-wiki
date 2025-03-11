import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki_ui/pages/article_details_page.dart';
import 'package:davinci3_wiki_ui/models/article.dart';
import 'package:davinci3_wiki_ui/services/wiki_service.dart';
import 'package:davinci3_wiki_ui/providers/connectivity_provider.dart';
import 'package:davinci3_wiki_ui/services/connectivity_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([WikiService, ConnectivityService])
import 'article_details_page_test.mocks.dart';

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

  // Helper function to create a test article
  Article createTestArticle({
    String id = 'test_article',
    String title = 'Test Article',
    String content = '# Test Content\n\nThis is a test article content.',
    List<String>? relatedArticles,
    String? summary,
  }) {
    return Article(
      id: id,
      title: title,
      content: content,
      lastModified: DateTime.now(),
      categories: ['Test Category'],
      relatedArticles: relatedArticles,
      summary: summary,
    );
  }

  Widget createArticleDetailsPageWithMocks(String articleId) {
    return MultiProvider(
      providers: [
        Provider<WikiService>.value(value: mockWikiService),
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: MaterialApp(
        home: ArticleDetailsPage(articleId: articleId),
      ),
    );
  }

  testWidgets('ArticleDetailsPage should display loading indicator initially', 
      (WidgetTester tester) async {
    // Set up the mock to return a delayed response
    when(mockWikiService.getArticle('test_article'))
        .thenAnswer((_) async {
      await Future.delayed(Duration(milliseconds: 500));
      return createTestArticle();
    });
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticleDetailsPageWithMocks('test_article'));
    
    // Verify that a loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
    
    // Wait for the article to load
    await tester.pump(Duration(milliseconds: 600));
    
    // Verify that the loading indicator is gone
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Loading...'), findsNothing);
  });

  testWidgets('ArticleDetailsPage should display article content when loaded', 
      (WidgetTester tester) async {
    // Set up the mock to return a test article
    final testArticle = createTestArticle(
      title: 'Test Article Title',
      content: '# Test Content\n\nThis is a test article content.',
      summary: 'This is a summary of the test article.',
    );
    when(mockWikiService.getArticle('test_article'))
        .thenAnswer((_) async => testArticle);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticleDetailsPageWithMocks('test_article'));
    
    // Wait for the article to load
    await tester.pumpAndSettle();
    
    // Verify that the article title is displayed in the app bar
    expect(find.text('Test Article Title'), findsOneWidget);
    
    // Verify that the summary is displayed
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('This is a summary of the test article.'), findsOneWidget);
    
    // Verify that the content is displayed in a markdown widget
    expect(find.byType(MarkdownBody), findsOneWidget);
    
    // Verify that the refresh button is displayed
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('ArticleDetailsPage should display related articles when available', 
      (WidgetTester tester) async {
    // Set up the mock to return a test article with related articles
    final testArticle = createTestArticle(
      title: 'Main Article',
      relatedArticles: ['related1', 'related2'],
    );
    when(mockWikiService.getArticle('main_article'))
        .thenAnswer((_) async => testArticle);
    
    // Set up the mock to return related articles
    final relatedArticle1 = createTestArticle(
      id: 'related1',
      title: 'Related Article 1',
    );
    final relatedArticle2 = createTestArticle(
      id: 'related2',
      title: 'Related Article 2',
    );
    when(mockWikiService.getArticle('related1'))
        .thenAnswer((_) async => relatedArticle1);
    when(mockWikiService.getArticle('related2'))
        .thenAnswer((_) async => relatedArticle2);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticleDetailsPageWithMocks('main_article'));
    
    // Wait for the article and related articles to load
    await tester.pumpAndSettle();
    
    // Verify that the related articles section is displayed
    expect(find.text('Related Articles'), findsOneWidget);
    
    // Verify that the related article titles are displayed
    expect(find.text('Related Article 1'), findsOneWidget);
    expect(find.text('Related Article 2'), findsOneWidget);
  });

  testWidgets('ArticleDetailsPage should display error message when loading fails', 
      (WidgetTester tester) async {
    // Set up the mock to throw an error
    when(mockWikiService.getArticle('error_article'))
        .thenThrow(Exception('Failed to load article'));
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticleDetailsPageWithMocks('error_article'));
    
    // Wait for the error to be displayed
    await tester.pumpAndSettle();
    
    // Verify that the error message is displayed
    expect(find.text('Error: Exception: Failed to load article'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('ArticleDetailsPage should handle refresh action', 
      (WidgetTester tester) async {
    // Set up the mock to return a test article
    final testArticle = createTestArticle(title: 'Original Title');
    when(mockWikiService.getArticle('test_article'))
        .thenAnswer((_) async => testArticle);
    
    // Build our app and trigger a frame
    await tester.pumpWidget(createArticleDetailsPageWithMocks('test_article'));
    
    // Wait for the article to load
    await tester.pumpAndSettle();
    
    // Verify that the original title is displayed
    expect(find.text('Original Title'), findsOneWidget);
    
    // Change the mock to return a different article on the second call
    final updatedArticle = createTestArticle(title: 'Updated Title');
    when(mockWikiService.getArticle('test_article'))
        .thenAnswer((_) async => updatedArticle);
    
    // Tap on the refresh button
    await tester.tap(find.byIcon(Icons.refresh));
    
    // Wait for the article to reload
    await tester.pumpAndSettle();
    
    // Verify that the updated title is displayed
    expect(find.text('Updated Title'), findsOneWidget);
    expect(find.text('Original Title'), findsNothing);
    
    // Verify that getArticle was called twice
    verify(mockWikiService.getArticle('test_article')).called(2);
  });

  testWidgets('ArticleDetailsPage should handle offline mode', 
      (WidgetTester tester) async {
    // Set up the mock to return a test article
    final testArticle = createTestArticle();
    when(mockWikiService.getArticle('test_article'))
        .thenAnswer((_) async => testArticle);
    
    // Build our app and trigger a frame with connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pumpWidget(createArticleDetailsPageWithMocks('test_article'));
    await tester.pumpAndSettle();
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the refresh button is disabled
    final refreshButton = tester.widget<IconButton>(
      find.byIcon(Icons.refresh),
    );
    expect(refreshButton.onPressed, isNull);
    
    // Set up the mock to throw an error
    when(mockWikiService.getArticle('error_article'))
        .thenThrow(Exception('Failed to load article'));
    
    // Build our app with an error article in offline mode
    await tester.pumpWidget(createArticleDetailsPageWithMocks('error_article'));
    await tester.pumpAndSettle();
    
    // Verify that the offline message is displayed
    expect(find.text('You are offline. Please reconnect to retry.'), findsOneWidget);
    
    // Verify that the retry button is disabled
    final retryButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Retry'),
    );
    expect(retryButton.onPressed, isNull);
  });
} 