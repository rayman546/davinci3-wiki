import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:davinci3_wiki_ui/main.dart';
import 'package:davinci3_wiki_ui/models/article.dart';
import 'package:davinci3_wiki_ui/models/search_result.dart';
import 'package:davinci3_wiki_ui/services/wiki_service.dart';
import 'package:davinci3_wiki_ui/services/cache_service.dart';
import 'package:davinci3_wiki_ui/services/search_history_service.dart';
import 'package:davinci3_wiki_ui/services/connectivity_service.dart';
import 'package:davinci3_wiki_ui/providers/connectivity_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for our services
@GenerateMocks([
  WikiService, 
  CacheService, 
  SearchHistoryService, 
  ConnectivityService
])
import 'offline_mode_test.mocks.dart';

void main() {
  late MockWikiService mockWikiService;
  late MockCacheService mockCacheService;
  late MockSearchHistoryService mockSearchHistoryService;
  late MockConnectivityService mockConnectivityService;
  late ConnectivityProvider connectivityProvider;

  setUp(() {
    mockWikiService = MockWikiService();
    mockCacheService = MockCacheService();
    mockSearchHistoryService = MockSearchHistoryService();
    mockConnectivityService = MockConnectivityService();
    connectivityProvider = ConnectivityProvider(mockConnectivityService);
    
    // Set up default behavior for mocks
    when(mockConnectivityService.isConnected).thenReturn(true);
    when(mockCacheService.getCacheSize()).thenReturn(25.5);
    when(mockSearchHistoryService.getSearchHistory()).thenReturn([]);
    
    // Set up performance metrics
    when(mockWikiService.getPerformanceMetrics()).thenReturn({
      'cacheOverview': {
        'totalCacheSize': 25.5,
        'itemCount': 120,
        'hitRate': 0.85,
      },
    });
    
    // Set up articles
    when(mockWikiService.getArticles(page: 1, limit: 20))
        .thenAnswer((_) async => [
              Article(
                id: 'article1',
                title: 'Test Article 1',
                content: 'Content 1',
                lastModified: DateTime.now(),
                categories: ['Category'],
              ),
              Article(
                id: 'article2',
                title: 'Test Article 2',
                content: 'Content 2',
                lastModified: DateTime.now(),
                categories: ['Category'],
              ),
            ]);
    
    // Set up article details
    when(mockWikiService.getArticle('article1'))
        .thenAnswer((_) async => Article(
              id: 'article1',
              title: 'Test Article 1',
              content: 'Content 1',
              lastModified: DateTime.now(),
              categories: ['Category'],
            ));
    
    // Set up search results
    when(mockWikiService.search('test'))
        .thenAnswer((_) async => [
              SearchResult(
                id: 'article1',
                title: 'Test Article 1',
                snippet: 'Snippet 1',
              ),
              SearchResult(
                id: 'article2',
                title: 'Test Article 2',
                snippet: 'Snippet 2',
              ),
            ]);
  });

  Widget createAppWithMocks() {
    return MultiProvider(
      providers: [
        Provider<CacheService>.value(value: mockCacheService),
        Provider<WikiService>.value(value: mockWikiService),
        Provider<SearchHistoryService>.value(value: mockSearchHistoryService),
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: DavinciWikiApp(),
    );
  }

  testWidgets('App should display offline indicator in HomePage when offline', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame with connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pumpWidget(createAppWithMocks());
    await tester.pumpAndSettle();
    
    // Verify that the connected icon is displayed
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
    expect(find.text('You are offline. Some features may be limited.'), findsNothing);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the disconnected icon is displayed
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsNothing);
    
    // Verify that the offline message is displayed
    expect(find.text('You are offline. Some features may be limited.'), findsOneWidget);
  });

  testWidgets('ArticlesPage should disable refresh when offline', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createAppWithMocks());
    await tester.pumpAndSettle();
    
    // Verify that we're on the ArticlesPage (index 0)
    expect(find.text('Articles Page'), findsOneWidget);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Try to refresh by pulling down
    await tester.drag(find.text('Articles Page'), const Offset(0, 300));
    await tester.pumpAndSettle();
    
    // Verify that the refresh didn't trigger a new API call
    verify(mockWikiService.getArticles(page: 1, limit: 20)).called(1); // Only the initial call
  });

  testWidgets('SearchPage should disable search when offline', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createAppWithMocks());
    await tester.pumpAndSettle();
    
    // Navigate to the SearchPage (index 1)
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    
    // Verify that we're on the SearchPage
    expect(find.text('Search Page'), findsOneWidget);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the search field is disabled
    expect(find.text('Search disabled while offline'), findsOneWidget);
  });

  testWidgets('SettingsPage should disable clear cache when offline', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createAppWithMocks());
    await tester.pumpAndSettle();
    
    // Navigate to the SettingsPage (index 2)
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    
    // Verify that we're on the SettingsPage
    expect(find.text('Settings Page'), findsOneWidget);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the offline message is displayed
    expect(find.text('You are offline. Some settings are unavailable.'), findsOneWidget);
  });

  testWidgets('App should handle connectivity changes across all pages', 
      (WidgetTester tester) async {
    // Build our app and trigger a frame with connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pumpWidget(createAppWithMocks());
    await tester.pumpAndSettle();
    
    // Verify that the connected icon is displayed
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    
    // Navigate to the SearchPage (index 1)
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the disconnected icon is displayed
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    
    // Navigate to the SettingsPage (index 2)
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    
    // Verify that the offline message is still displayed
    expect(find.text('You are offline. Some settings are unavailable.'), findsOneWidget);
    
    // Change back to connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the connected icon is displayed again
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.text('You are offline. Some settings are unavailable.'), findsNothing);
    
    // Navigate back to the ArticlesPage (index 0)
    await tester.tap(find.byIcon(Icons.article));
    await tester.pumpAndSettle();
    
    // Verify that the offline message is gone
    expect(find.text('You are offline. Some features may be limited.'), findsNothing);
  });

  testWidgets('ConnectivityProvider should notify listeners when connectivity changes', 
      (WidgetTester tester) async {
    // Create a test widget that listens to the ConnectivityProvider
    final testWidget = MultiProvider(
      providers: [
        Provider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            final isConnected = context.watch<ConnectivityProvider>().isConnected;
            return Scaffold(
              body: Center(
                child: Text(isConnected ? 'Connected' : 'Disconnected'),
              ),
            );
          },
        ),
      ),
    );
    
    // Build our widget and trigger a frame with connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pumpWidget(testWidget);
    
    // Verify that the connected status is displayed
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Disconnected'), findsNothing);
    
    // Change to disconnected status
    when(mockConnectivityService.isConnected).thenReturn(false);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the disconnected status is displayed
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    
    // Change back to connected status
    when(mockConnectivityService.isConnected).thenReturn(true);
    connectivityProvider.update(mockConnectivityService);
    await tester.pump();
    
    // Verify that the connected status is displayed again
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Disconnected'), findsNothing);
  });
} 